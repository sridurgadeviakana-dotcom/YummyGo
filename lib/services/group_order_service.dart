import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yummy_go_application/models/address_model.dart';
import 'package:yummy_go_application/models/poll_model.dart';
import 'package:yummy_go_application/models/restaurant_conflict.dart';

export 'package:yummy_go_application/models/poll_model.dart';
export 'package:yummy_go_application/models/restaurant_conflict.dart';

class GroupOrderService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  User get currentUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please login first.');
    }
    return user;
  }

  String get userId => currentUser.uid;

  String get userName =>
      currentUser.displayName ??
      currentUser.email?.split('@').first ??
      'Customer';

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // CREATE GROUP
  Future<String> createGroup(String groupName) async {
    if (groupName.trim().isEmpty) {
      throw Exception('Enter a group name.');
    }

    final groupRef = db.collection('group_orders').doc();
    final code = _generateCode();

    final batch = db.batch();

    batch.set(groupRef, {
      'groupName': groupName.trim(),
      'createdBy': userId,
      'memberUids': [userId],
      'inviteCode': code,
      'maxMembers': 10,
      'memberCount': 1,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(groupRef.collection('members').doc(userId), {
      'userId': userId,
      'name': userName,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return groupRef.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myGroupsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return db
        .collection('group_orders')
        .where('createdBy', isEqualTo: user.uid)
        .snapshots();
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> userGroupsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    final uid = user.uid;
    final controller =
        StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>();
    final createdGroupsById =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    final memberGroupsById =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? createdGroups;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? memberGroups;

    void emitGroups() {
      final groupsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
        ...createdGroupsById,
        ...memberGroupsById,
      };
      controller.add(groupsById.values.toList());
    }

    controller.onListen = () {
      createdGroups = db
          .collection('group_orders')
          .where('createdBy', isEqualTo: uid)
          .snapshots()
          .listen((snapshot) {
            createdGroupsById.clear();
            for (final group in snapshot.docs) {
              createdGroupsById[group.id] = group;
            }
            emitGroups();
          }, onError: controller.addError);
      memberGroups = db
          .collection('group_orders')
          .where('memberUids', arrayContains: uid)
          .snapshots()
          .listen((snapshot) {
            memberGroupsById.clear();
            for (final group in snapshot.docs) {
              memberGroupsById[group.id] = group;
            }
            emitGroups();
          }, onError: controller.addError);
    };
    controller.onCancel = () async {
      await createdGroups?.cancel();
      await memberGroups?.cancel();
    };

    return controller.stream.asBroadcastStream();
  }

  // JOIN GROUP VIA GROUP CODE
  Future<String> joinGroup(String input) async {
    String clean = input.trim();
    if (clean.isEmpty) {
      throw Exception('Please enter the 6-character Group Code.');
    }

    // 1. If it's a URL/link, parse code or id from query parameters or path
    if (clean.contains('http://') || clean.contains('https://') || clean.contains('yummygo') || clean.contains('code=')) {
      final uri = Uri.tryParse(clean);
      if (uri != null) {
        if (uri.queryParameters.containsKey('code')) {
          clean = uri.queryParameters['code']!.trim();
        } else if (uri.queryParameters.containsKey('id')) {
          clean = uri.queryParameters['id']!.trim();
        } else if (uri.pathSegments.isNotEmpty) {
          clean = uri.pathSegments.last.trim();
        }
      }
    }

    clean = clean.replaceAll(RegExp(r'[\s]'), '');
    if (clean.isEmpty) {
      throw Exception('Invalid Group Code.');
    }

    DocumentReference<Map<String, dynamic>>? groupRef;

    // 2. Look up by inviteCode (case-insensitive / uppercase)
    final normalizedCode = clean.replaceAll('-', '').toUpperCase();
    final query = await db
        .collection('group_orders')
        .where('inviteCode', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      groupRef = query.docs.first.reference;
    } else {
      // 3. Fallback to direct document ID for backwards compatibility
      final docSnapshot = await db.collection('group_orders').doc(clean).get();
      if (docSnapshot.exists) {
        groupRef = docSnapshot.reference;
      }
    }

    if (groupRef == null) {
      throw Exception('Group not found. Please verify the Group Code with your friend.');
    }

    final memberRef = groupRef.collection('members').doc(userId);

    await db.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef!);
      final memberSnapshot = await transaction.get(memberRef);

      if (!groupSnapshot.exists) {
        throw Exception('Group not found.');
      }

      final data = groupSnapshot.data()!;
      if (memberSnapshot.exists) {
        transaction.update(groupRef!, {
          'memberUids': FieldValue.arrayUnion([userId]),
        });
        return;
      }

      if ((data['status']?.toString().toLowerCase() ?? 'open') != 'open') {
        throw Exception('This group order is closed or completed.');
      }

      final count = (data['memberCount'] as num?)?.toInt() ?? 1;
      final maximum = (data['maxMembers'] as num?)?.toInt() ?? 10;
      if (count >= maximum) {
        throw Exception('Group is full (maximum $maximum members).');
      }

      transaction.set(memberRef, {
        'userId': userId,
        'name': userName,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(groupRef!, {
        'memberCount': count + 1,
        'memberUids': FieldValue.arrayUnion([userId]),
      });
    });

    return groupRef.id;
  }

  // JOIN GROUP DIRECTLY BY GROUP ID
  Future<void> joinGroupById(String groupId) async {
    final groupRef = db.collection('group_orders').doc(groupId);
    final memberRef = groupRef.collection('members').doc(userId);

    await db.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      final memberSnapshot = await transaction.get(memberRef);

      if (!groupSnapshot.exists) {
        throw Exception('Group not found.');
      }

      final data = groupSnapshot.data()!;
      if (memberSnapshot.exists) {
        transaction.update(groupRef, {
          'memberUids': FieldValue.arrayUnion([userId]),
        });
        return;
      }

      if ((data['status']?.toString().toLowerCase() ?? 'open') != 'open') {
        throw Exception('This group is closed.');
      }

      final count = (data['memberCount'] as num?)?.toInt() ?? 1;
      final maximum = (data['maxMembers'] as num?)?.toInt() ?? 10;
      if (count >= maximum) {
        throw Exception('Group is full. Maximum $maximum members.');
      }

      transaction.set(memberRef, {
        'userId': userId,
        'name': userName,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(groupRef, {
        'memberCount': count + 1,
        'memberUids': FieldValue.arrayUnion([userId]),
      });
    });
  }

  // CHECK IF ADDING THIS RESTAURANT'S FOOD CONFLICTS WITH CURRENT GROUP CART
  Future<CartConflictResult> checkGroupConflict({
    required String groupId,
    String? restaurantId,
    String? restaurantName,
  }) async {
    final groupRef = db.collection('group_orders').doc(groupId);
    final groupSnapshot = await groupRef.get();
    if (!groupSnapshot.exists) {
      return const CartConflictResult(hasConflict: false);
    }

    final cartSnapshot = await groupRef.collection('cart').limit(20).get();
    if (cartSnapshot.docs.isEmpty) {
      return const CartConflictResult(hasConflict: false);
    }

    final groupData = groupSnapshot.data() ?? {};
    String existingRestId = groupData['restaurantId']?.toString().trim() ?? '';
    String existingRestName = groupData['restaurantName']?.toString().trim() ?? '';

    if (existingRestId.isEmpty && existingRestName.isEmpty) {
      for (final doc in cartSnapshot.docs) {
        final d = doc.data();
        if (existingRestId.isEmpty && d['restaurantId'] != null) {
          existingRestId = d['restaurantId'].toString().trim();
        }
        if (existingRestName.isEmpty && d['restaurantName'] != null) {
          existingRestName = d['restaurantName'].toString().trim();
        }
        if (existingRestId.isNotEmpty || existingRestName.isNotEmpty) break;
      }
    }

    final newId = (restaurantId ?? '').trim();
    final newName = (restaurantName ?? '').trim();

    if (newId.isEmpty && newName.isEmpty) {
      return const CartConflictResult(hasConflict: false);
    }
    if (existingRestId.isEmpty && existingRestName.isEmpty) {
      return const CartConflictResult(hasConflict: false);
    }

    final bool idMatches =
        newId.isNotEmpty && existingRestId.isNotEmpty && newId == existingRestId;
    final bool nameMatches =
        newName.isNotEmpty &&
        existingRestName.isNotEmpty &&
        newName.toLowerCase() == existingRestName.toLowerCase();

    if (idMatches || nameMatches) {
      return const CartConflictResult(hasConflict: false);
    }

    return CartConflictResult(
      hasConflict: true,
      existingRestaurantId: existingRestId,
      existingRestaurantName: existingRestName.isNotEmpty
          ? existingRestName
          : 'another restaurant',
      itemCount: cartSnapshot.docs.length,
    );
  }

  // ADD FOOD TO SHARED CART
  Future<void> addFood({
    required String groupId,
    required String foodId,
    required String foodName,
    required String image,
    required double price,
    String? restaurantId,
    String? restaurantName,
  }) async {
    await adjustFoodQuantity(
      groupId: groupId,
      foodId: foodId,
      foodName: foodName,
      image: image,
      price: price,
      changeBy: 1,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );
  }

  Future<void> selectRestaurant({
    required String groupId,
    required String restaurantId,
    required String restaurantName,
  }) async {
    final groupRef = db.collection('group_orders').doc(groupId);
    await groupRef.update({
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearGroupCart(String groupId) async {
    final groupRef = db.collection('group_orders').doc(groupId);
    final groupSnapshot = await groupRef.get();
    if (groupSnapshot.exists) {
      final status = groupSnapshot.data()?['status']?.toString();
      final pStatus = groupSnapshot.data()?['paymentStatus']?.toString();
      final orderId = groupSnapshot.data()?['orderId']?.toString();
      if (status != 'open' || pStatus == 'paid' || (orderId != null && orderId.isNotEmpty)) {
        throw Exception('Cannot modify group cart: order is in progress and cart is locked.');
      }
    }
    final cartCollection = groupRef.collection('cart');
    final snapshot = await cartCollection.get();
    final batch = db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> clearGroupCartAndSelectRestaurant({
    required String groupId,
    required String restaurantId,
    required String restaurantName,
  }) async {
    await clearGroupCart(groupId);
    await selectRestaurant(
      groupId: groupId,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );
  }

  Future<void> clearGroupCartAndAddFood({
    required String groupId,
    required String foodId,
    required String foodName,
    required String image,
    required double price,
    String? restaurantId,
    String? restaurantName,
  }) async {
    await clearGroupCart(groupId);
    if ((restaurantId ?? '').trim().isNotEmpty ||
        (restaurantName ?? '').trim().isNotEmpty) {
      await selectRestaurant(
        groupId: groupId,
        restaurantId: restaurantId ?? '',
        restaurantName: restaurantName ?? '',
      );
    }
    await adjustFoodQuantity(
      groupId: groupId,
      foodId: foodId,
      foodName: foodName,
      image: image,
      price: price,
      changeBy: 1,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );
  }

  Future<void> selectCategory({
    required String groupId,
    required String category,
  }) async {
    await db.collection('group_orders').doc(groupId).update({
      'selectedCategory': category,
    });
  }

  Future<void> adjustFoodQuantity({
    required String groupId,
    required String foodId,
    required String foodName,
    required String image,
    required double price,
    required int changeBy,
    String? restaurantId,
    String? restaurantName,
  }) async {
    if (changeBy == 0) return;

    final groupRef = db.collection('group_orders').doc(groupId);
    final groupSnapshot = await groupRef.get();
    if (!groupSnapshot.exists ||
        groupSnapshot.data()?['status'] != 'open' ||
        groupSnapshot.data()?['paymentStatus'] == 'paid' ||
        (groupSnapshot.data()?['orderId']?.toString().isNotEmpty == true)) {
      throw Exception('This group cart is locked while an order is in progress.');
    }

    if (changeBy > 0) {
      final conflict = await checkGroupConflict(
        groupId: groupId,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
      );
      if (conflict.hasConflict) {
        throw RestaurantConflictException(
          existingRestaurantName: conflict.existingRestaurantName,
          newRestaurantName: restaurantName ?? 'another restaurant',
        );
      }
    }

    final groupData = groupSnapshot.data() ?? {};
    final currentGroupRestId =
        groupData['restaurantId']?.toString().trim() ?? '';
    if (currentGroupRestId.isEmpty &&
        ((restaurantId ?? '').trim().isNotEmpty ||
            (restaurantName ?? '').trim().isNotEmpty)) {
      await groupRef.update({
        if ((restaurantId ?? '').trim().isNotEmpty)
          'restaurantId': restaurantId!.trim(),
        if ((restaurantName ?? '').trim().isNotEmpty)
          'restaurantName': restaurantName!.trim(),
        'restaurantUpdatedAt': FieldValue.serverTimestamp(),
      });
    }

    final cart = groupRef.collection('cart');
    final existingItems = (await cart.where('addedBy', isEqualTo: userId).get())
        .docs
        .where((document) => document.data()['foodId'] == foodId)
        .toList();
    final itemRefs = existingItems.map((item) => item.reference).toList();
    if (itemRefs.isEmpty) itemRefs.add(cart.doc('${userId}_$foodId'));

    await db.runTransaction((transaction) async {
      final itemSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final itemRef in itemRefs) {
        itemSnapshots.add(await transaction.get(itemRef));
      }

      final existingSnapshots = itemSnapshots
          .where((snapshot) => snapshot.exists)
          .toList();
      final currentQuantity = existingSnapshots.fold<int>(
        0,
        (total, snapshot) =>
            total + ((snapshot.data()?['quantity'] as num?)?.toInt() ?? 1),
      );
      final nextQuantity = currentQuantity + changeBy;

      if (nextQuantity <= 0) {
        for (final snapshot in existingSnapshots) {
          transaction.delete(snapshot.reference);
        }
        return;
      }

      final primarySnapshot = existingSnapshots.isNotEmpty
          ? existingSnapshots.first
          : itemSnapshots.first;
      final primaryData = primarySnapshot.data();
      final itemData = {
        'foodId': foodId,
        'foodName': foodName,
        'image': image,
        'price': price,
        'quantity': nextQuantity,
        'addedBy': userId,
        'memberName': userName,
        if ((restaurantId ?? '').trim().isNotEmpty)
          'restaurantId': restaurantId!.trim(),
        if ((restaurantName ?? '').trim().isNotEmpty)
          'restaurantName': restaurantName!.trim(),
        if (primaryData?['createdAt'] != null)
          'createdAt': primaryData!['createdAt']
        else
          'createdAt': FieldValue.serverTimestamp(),
      };

      transaction.set(primarySnapshot.reference, itemData);
      for (final duplicate in existingSnapshots.skip(1)) {
        transaction.delete(duplicate.reference);
      }
    });
  }

  Future<void> createGroupSplit({
    required String groupId,
    required String splitType,
    required double total,
    required List<Map<String, dynamic>> memberShares,
  }) async {
    if (!total.isFinite ||
        total <= 0 ||
        memberShares.isEmpty ||
        splitType.trim().isEmpty) {
      throw ArgumentError('Invalid split details.');
    }
    final shareIds = <String>{};
    for (final share in memberShares) {
      final memberId = share['userId'];
      final amount = share['amountDue'];
      if (memberId is! String ||
          memberId.isEmpty ||
          !shareIds.add(memberId) ||
          amount is! num ||
          !amount.toDouble().isFinite ||
          amount < 0) {
        throw ArgumentError('A member share is invalid.');
      }
    }
    final allocatedTotal = memberShares.fold<double>(
      0,
      (runningTotal, share) =>
          runningTotal + ((share['amountDue'] as num?)?.toDouble() ?? 0),
    );
    if ((allocatedTotal - total).abs() >= 0.01) {
      throw ArgumentError('Member shares must add up to the group total.');
    }

    final groupRef = db.collection('group_orders').doc(groupId);
    final currentMembers = await groupRef.collection('members').get();
    if (currentMembers.docs.length != shareIds.length ||
        !shareIds.containsAll(currentMembers.docs.map((member) => member.id))) {
      throw ArgumentError('Split shares must include every current member.');
    }

    await db.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      if (!groupSnapshot.exists) {
        throw Exception('Group order not found.');
      }
      final groupData = groupSnapshot.data()!;
      final payment = groupData['restaurantPayment'];
      final paidTotal =
          ((payment is Map ? payment['amount'] : null) as num?)?.toDouble() ??
          (groupData['restaurantTotal'] as num?)?.toDouble() ??
          0;
      final paidBy =
          (payment is Map ? payment['paidBy'] : null)?.toString() ??
          groupData['paidBy']?.toString();
      if ((groupData['paymentStatus'] != 'paid' && paidBy == null) ||
          paidBy != userId) {
        throw Exception('Only the restaurant payer can create the split.');
      }
      if ((paidTotal - total).abs() >= 0.01) {
        throw Exception(
          'Split total must match the restaurant payment amount.',
        );
      }
      if (groupData['split'] != null) {
        throw Exception('A split has already been created for this group.');
      }

      final savedShares = memberShares.map((share) {
        final isPayer = share['userId'] == userId;
        final amountDue = (share['amountDue'] as num).toDouble();
        return {
          ...share,
          'amountPaid': isPayer ? amountDue : 0.0,
          'paymentStatus': isPayer ? 'paid' : 'pending',
          'paymentMethod': isPayer ? 'restaurant_payment' : null,
        };
      }).toList();

      transaction.update(groupRef, {
        'split': {
          'createdBy': userId,
          'splitType': splitType,
          'total': total,
          'createdAt': FieldValue.serverTimestamp(),
          'testMode': true,
        },
        'splitMembers': savedShares,
        'status': 'split_created',
      });
    });
  }

  // RECORD RESTAURANT PAYMENT (GROUP ORDER VIA RAZORPAY TEST MODE)
  Future<String> recordRestaurantPayment({
    required String groupId,
    required String paymentId,
    required double totalAmount,
    List<Map<String, dynamic>>? items,
    String? restaurantId,
    String? restaurantName,
    AddressModel? address,
  }) async {
    final groupRef = db.collection('group_orders').doc(groupId);
    final groupDoc = await groupRef.get();
    if (!groupDoc.exists) {
      throw Exception('Group order not found.');
    }

    final data = groupDoc.data() ?? {};
    final restId = restaurantId ?? data['restaurantId']?.toString() ?? '';
    final restName = restaurantName ??
        data['restaurantName']?.toString() ??
        'YummyGo Restaurant';

    // Fetch cart items if not passed
    List<Map<String, dynamic>> finalItems = items ?? [];
    if (finalItems.isEmpty) {
      final cartSnap = await groupRef.collection('cart').get();
      finalItems = cartSnap.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'name': (d['foodName'] ?? d['name'])?.toString() ?? 'Food Item',
          'quantity': (d['quantity'] as num?)?.toInt() ?? 1,
          'price': (d['price'] as num?)?.toDouble() ?? 0.0,
          'image': d['image']?.toString() ?? '',
          'addedBy': d['addedBy']?.toString() ?? '',
          'addedByName': d['addedByName']?.toString() ?? '',
        };
      }).toList();
    }

    // Save order in orders collection
    final orderRef = db.collection('orders').doc();
    final orderId = orderRef.id;

    final memberUids = List<String>.from(data['memberUids'] ?? [userId]);
    if (!memberUids.contains(userId)) memberUids.add(userId);
    final groupCreator = data['createdBy']?.toString() ?? userId;

    final formattedAddress = address?.formattedAddress.isNotEmpty == true
        ? address!.formattedAddress
        : (data['deliveryAddress']?.toString() ?? 'Group Delivery Point');
    final customerName = address?.receiverName.isNotEmpty == true
        ? address!.receiverName
        : userName;
    final customerPhone = address?.receiverPhone.isNotEmpty == true
        ? address!.receiverPhone
        : '';

    final orderData = {
      'id': orderId,
      'groupId': groupId,
      'orderType': 'group',
      'groupName': data['groupName'] ?? 'Group Order',
      'customerId': userId,
      'userId': userId,
      'createdBy': groupCreator,
      'memberUids': memberUids,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': formattedAddress,
      'address': formattedAddress,
      'receiverDetails': address?.toMap() ?? data['receiverDetails'],
      'deliveryLatitude': address?.latitude ?? (data['deliveryLatitude'] as num?)?.toDouble() ?? 17.4442,
      'deliveryLongitude': address?.longitude ?? (data['deliveryLongitude'] as num?)?.toDouble() ?? 78.3845,
      'customerLatitude': address?.latitude ?? (data['customerLatitude'] as num?)?.toDouble() ?? 17.4442,
      'customerLongitude': address?.longitude ?? (data['customerLongitude'] as num?)?.toDouble() ?? 78.3845,
      'deliveryInstructions': address?.deliveryInstructions ?? (data['deliveryInstructions']?.toString() ?? ''),
      'restaurantId': restId,
      'restaurantName': restName,
      'items': finalItems,
      'totalAmount': totalAmount,
      'total': totalAmount,
      'amount': totalAmount,
      'paymentMethod': 'razorpay',
      'paymentStatus': 'paid',
      'paymentId': paymentId,
      'orderStatus': 'confirmed',
      'status': 'confirmed',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await orderRef.set(orderData);

    // Initialize real-time delivery tracking doc
    try {
      await db
          .collection('orders')
          .doc(orderId)
          .collection('tracking')
          .doc('current')
          .set({
        'orderStatus': 'confirmed',
        'customerLatitude': orderData['customerLatitude'],
        'customerLongitude': orderData['customerLongitude'],
        'customerAddress': formattedAddress,
        'latitude': 17.4442,
        'longitude': 78.3845,
        'partnerAssigned': false,
        'deliveryPartnerName': null,
        'deliveryPartnerPhone': null,
        'estimatedMinutes': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    // Mirror to every group member's order collection
    for (final mUid in memberUids) {
      try {
        await db
            .collection('users')
            .doc(mUid)
            .collection('orders')
            .doc(orderId)
            .set(orderData);
      } catch (_) {}
    }

    // Update group document
    await groupRef.update({
      'paymentStatus': 'paid',
      'paidBy': userId,
      'paidByName': userName,
      'restaurantTotal': totalAmount,
      'paymentId': paymentId,
      'restaurantPayment': {
        'paidBy': userId,
        'paidByName': userName,
        'amount': totalAmount,
        'paymentId': paymentId,
        'paidAt': FieldValue.serverTimestamp(),
      },
      'status': 'paid',
      'orderId': orderId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Automatically close all active polls after successful order placement
    try {
      await closeAllActivePolls(groupId);
    } catch (e) {
      // Non-blocking catch to ensure order ID is returned reliably
    }

    return orderId;
  }

  // PAY SPLIT SHARE FOR AN INDIVIDUAL MEMBER (RAZORPAY TEST MODE)
  Future<void> paySplitShare({
    required String groupId,
    required String memberUserId,
    required String paymentId,
    required double amount,
  }) async {
    final groupRef = db.collection('group_orders').doc(groupId);

    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(groupRef);
      if (!snapshot.exists) throw Exception('Group order not found.');
      final data = snapshot.data()!;
      final rawMembers = data['splitMembers'];
      if (rawMembers is! List) throw Exception('Split details not found.');

      bool found = false;
      bool allPaid = true;

      final updatedMembers = rawMembers.map((m) {
        final map = Map<String, dynamic>.from(m as Map);
        if (map['userId'] == memberUserId ||
            (memberUserId.isEmpty && map['paymentStatus'] != 'paid')) {
          found = true;
          map['paymentStatus'] = 'paid';
          map['amountPaid'] = amount;
          map['paymentId'] = paymentId;
          map['paymentMethod'] = 'razorpay';
          map['paidAt'] = DateTime.now().toIso8601String();
        }
        if (map['paymentStatus'] != 'paid') {
          allPaid = false;
        }
        return map;
      }).toList();

      if (!found) {
        throw Exception('Member share was not found in this group split.');
      }

      final updateData = <String, dynamic>{
        'splitMembers': updatedMembers,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (allPaid) {
        updateData['status'] = 'split_completed';
      }

      transaction.update(groupRef, updateData);
    });
  }

  // UPDATE QUANTITY
  Future<void> updateQuantity({
    required String groupId,
    required String itemId,
    required int quantity,
  }) async {
    final groupSnapshot = await db
        .collection('group_orders')
        .doc(groupId)
        .get();
    if (!groupSnapshot.exists ||
        groupSnapshot.data()?['status'] != 'open' ||
        groupSnapshot.data()?['paymentStatus'] == 'paid' ||
        (groupSnapshot.data()?['orderId']?.toString().isNotEmpty == true)) {
      throw Exception('This group cart is locked while an order is in progress.');
    }

    final itemRef = db
        .collection('group_orders')
        .doc(groupId)
        .collection('cart')
        .doc(itemId);

    if (quantity <= 0) {
      await itemRef.delete();
    } else {
      await itemRef.update({'quantity': quantity});
    }
  }

  // REAL-TIME GROUP DETAILS
  Stream<DocumentSnapshot<Map<String, dynamic>>> groupStream(String groupId) {
    return db.collection('group_orders').doc(groupId).snapshots();
  }

  // REAL-TIME MEMBERS
  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream(String groupId) {
    return db
        .collection('group_orders')
        .doc(groupId)
        .collection('members')
        .orderBy('joinedAt')
        .snapshots();
  }

  // REAL-TIME CART
  Stream<QuerySnapshot<Map<String, dynamic>>> cartStream(String groupId) {
    return db
        .collection('group_orders')
        .doc(groupId)
        .collection('cart')
        .orderBy('createdAt')
        .snapshots();
  }

  /// Checks synchronously if the currently signed-in user belongs to the group.
  bool isCurrentUserGroupMember(Map<String, dynamic>? groupData) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || groupData == null) return false;
    if (groupData['createdBy'] == uid) return true;
    final memberUids = groupData['memberUids'];
    return memberUids is List && memberUids.contains(uid);
  }

  /// Verifies that the signed-in user is an active member of [groupId].
  Future<Map<String, dynamic>> _requireGroupMembership(String groupId) async {
    final uid = userId;
    final groupRef = db.collection('group_orders').doc(groupId);
    final groupSnapshot = await groupRef.get();
    if (!groupSnapshot.exists) {
      throw Exception('Group order not found.');
    }

    final data = groupSnapshot.data() ?? {};
    final isCreator = data['createdBy'] == uid;
    final memberUids = data['memberUids'];
    final inMemberList = memberUids is List && memberUids.contains(uid);

    if (isCreator || inMemberList) {
      return data;
    }

    final memberDoc = await groupRef.collection('members').doc(uid).get();
    if (memberDoc.exists) {
      return data;
    }

    throw Exception('Only group members can chat, create polls, or vote.');
  }

  Future<String> _resolveMemberName(String groupId) async {
    final uid = userId;
    try {
      final memberDoc = await db
          .collection('group_orders')
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .get();
      final memberName = memberDoc.data()?['name']?.toString().trim();
      if (memberName != null && memberName.isNotEmpty) {
        return memberName;
      }

      final userDoc = await db.collection('users').doc(uid).get();
      final userDocName = (userDoc.data()?['name'] ?? userDoc.data()?['fullName'])
          ?.toString()
          .trim();
      if (userDocName != null && userDocName.isNotEmpty) {
        return userDocName;
      }
    } catch (_) {
      // Fallback to FirebaseAuth display info below.
    }
    return userName;
  }

  // ---------------------------------------------------------------------------
  // GROUP CHAT (`group_orders/{groupId}/messages`)
  // ---------------------------------------------------------------------------

  /// Real-time stream of chat messages ordered newest first.
  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String groupId) {
    return db
        .collection('group_orders')
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Sends a chat message to `group_orders/{groupId}/messages` after verifying membership.
  Future<void> sendMessage({
    required String groupId,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw Exception('Enter a message.');
    }

    await _requireGroupMembership(groupId);
    final senderName = await _resolveMemberName(groupId);

    await db
        .collection('group_orders')
        .doc(groupId)
        .collection('messages')
        .add({
          'groupId': groupId,
          'senderId': userId,
          'senderName': senderName,
          'message': trimmed,
          'createdAt': FieldValue.serverTimestamp(),
          'clientSentAt': Timestamp.now(),
        });
  }

  // ---------------------------------------------------------------------------
  // GROUP VOTING (`group_orders/{groupId}/polls`)
  // ---------------------------------------------------------------------------

  /// Real-time stream of polls under `group_orders/{groupId}/polls`.
  Stream<QuerySnapshot<Map<String, dynamic>>> pollsStream(String groupId) {
    return db
        .collection('group_orders')
        .doc(groupId)
        .collection('polls')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Creates a new poll under `group_orders/{groupId}/polls` (members only).
  /// Poll remains active until the group order is successfully placed (no timer-based expiry).
  Future<String> createPoll({
    required String groupId,
    required String question,
    required List<String> options,
  }) async {
    await _requireGroupMembership(groupId);

    final groupRef = db.collection('group_orders').doc(groupId);
    final groupSnapshot = await groupRef.get();
    if (!groupSnapshot.exists) {
      throw Exception('Group order not found.');
    }
    final gData = groupSnapshot.data() ?? {};
    if (gData['status'] != 'open' ||
        gData['paymentStatus'] == 'paid' ||
        (gData['orderId']?.toString().isNotEmpty == true)) {
      throw Exception(
        'Cannot create polls because the group order has already been placed.',
      );
    }

    final cleanQuestion = question.trim().isEmpty
        ? 'What should we order?'
        : question.trim();

    final seen = <String>{};
    final cleanOptions = <String>[];
    for (final raw in options) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final normalized = trimmed.toLowerCase();
      if (seen.add(normalized)) {
        cleanOptions.add(trimmed);
      }
    }

    if (cleanOptions.length < 2) {
      throw Exception('Please provide at least 2 distinct poll options.');
    }

    final creatorName = await _resolveMemberName(groupId);
    final pollRef = groupRef.collection('polls').doc();

    await pollRef.set({
      'groupId': groupId,
      'question': cleanQuestion,
      'options': cleanOptions,
      'votes': <String, int>{},
      'voterNames': <String, String>{},
      'createdBy': userId,
      'createdByName': creatorName,
      'createdAt': FieldValue.serverTimestamp(),
      'clientCreatedAt': Timestamp.now(),
      'isClosed': false,
    });

    return pollRef.id;
  }

  /// Casts or changes a member's vote using an atomic Firestore transaction.
  /// - Enforces strictly one active vote per user UID.
  /// - Allows members to change their vote any number of times before order placement.
  /// - Voting and vote changes are rejected once the poll is closed or order is placed.
  Future<void> submitVote({
    required String groupId,
    required String pollId,
    required int optionIndex,
  }) async {
    await _requireGroupMembership(groupId);
    final voterName = await _resolveMemberName(groupId);
    final groupRef = db.collection('group_orders').doc(groupId);
    final pollRef = groupRef.collection('polls').doc(pollId);

    await db.runTransaction((transaction) async {
      final groupSnap = await transaction.get(groupRef);
      if (!groupSnap.exists) {
        throw Exception('Group order not found.');
      }

      final groupData = groupSnap.data() ?? {};
      final isCreator = groupData['createdBy'] == userId;
      final memberUids = groupData['memberUids'];
      final inMembers = memberUids is List && memberUids.contains(userId);
      if (!isCreator && !inMembers) {
        final memberDoc =
            await transaction.get(groupRef.collection('members').doc(userId));
        if (!memberDoc.exists) {
          throw Exception('Only group members can vote in this poll.');
        }
      }

      // Check if group order has already been placed
      final groupStatus = groupData['status']?.toString().toLowerCase();
      final paymentStatus = groupData['paymentStatus']?.toString().toLowerCase();
      final hasOrderId =
          groupData['orderId'] != null && groupData['orderId'].toString().isNotEmpty;
      if (groupStatus != 'open' || paymentStatus == 'paid' || hasOrderId) {
        throw Exception(
          'Voting is disabled because the group order has already been placed.',
        );
      }

      final pollSnap = await transaction.get(pollRef);
      if (!pollSnap.exists) {
        throw Exception('Poll no longer exists.');
      }

      final pollData = pollSnap.data() ?? {};
      if (pollData['isClosed'] == true) {
        throw Exception('This poll is closed. Voting and vote changes are disabled.');
      }

      final options = List<dynamic>.from(pollData['options'] ?? const []);
      if (optionIndex < 0 || optionIndex >= options.length) {
        throw Exception('Invalid poll option selected.');
      }

      final rawVotes = pollData['votes'];
      final votes = rawVotes is Map
          ? Map<String, dynamic>.from(rawVotes)
          : <String, dynamic>{};

      // If user tapped their existing active vote, no change needed
      if (votes[userId] == optionIndex) {
        return;
      }

      // Allow members to change their votes any number of times before order placement.
      // Store strictly one active vote per user keyed by Firebase UID.
      votes[userId] = optionIndex;

      final rawNames = pollData['voterNames'];
      final voterNames = rawNames is Map
          ? Map<String, dynamic>.from(rawNames)
          : <String, dynamic>{};
      voterNames[userId] = voterName;

      transaction.update(pollRef, {
        'votes': votes,
        'voterNames': voterNames,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Automatically closes all active polls after successful group order placement.
  /// Computes final tally, winning food item, or tied options, and stores them in Firestore.
  /// Disables any further voting or vote changes.
  Future<void> closeAllActivePolls(String groupId) async {
    final groupRef = db.collection('group_orders').doc(groupId);
    final pollsSnap = await groupRef.collection('polls').get();
    if (pollsSnap.docs.isEmpty) return;

    final batch = db.batch();
    bool hasUpdates = false;

    for (final doc in pollsSnap.docs) {
      final data = doc.data();
      if (data['isClosed'] == true) continue;

      hasUpdates = true;
      final rawOptions = data['options'] as List<dynamic>? ?? const [];
      final options = rawOptions.map((e) => e.toString().trim()).toList();
      final rawVotes = (data['votes'] as Map<dynamic, dynamic>?) ?? const {};

      final result = PollResult.calculate(options: options, votes: rawVotes);

      batch.update(doc.reference, {
        'isClosed': true,
        'closedAt': FieldValue.serverTimestamp(),
        'closedReason': 'order_placed',
        'winningOption': result.winningOption,
        'winningOptions': result.winningOptions,
        'isTie': result.isTie,
        'totalVotes': result.totalVotes,
        'maxVotes': result.maxVotes,
        'resultSummary': result.resultSummary,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  /// Closes a specific poll, calculates the winner or ties, and persists final results.
  Future<void> closePoll({
    required String groupId,
    required String pollId,
    String reason = 'manual',
  }) async {
    await _requireGroupMembership(groupId);
    final pollRef = db
        .collection('group_orders')
        .doc(groupId)
        .collection('polls')
        .doc(pollId);

    final pollSnap = await pollRef.get();
    if (!pollSnap.exists) throw Exception('Poll not found.');
    final data = pollSnap.data() ?? {};
    if (data['isClosed'] == true) return;

    final rawOptions = data['options'] as List<dynamic>? ?? const [];
    final options = rawOptions.map((e) => e.toString().trim()).toList();
    final rawVotes = (data['votes'] as Map<dynamic, dynamic>?) ?? const {};
    final result = PollResult.calculate(options: options, votes: rawVotes);

    await pollRef.update({
      'isClosed': true,
      'closedAt': FieldValue.serverTimestamp(),
      'closedReason': reason,
      'winningOption': result.winningOption,
      'winningOptions': result.winningOptions,
      'isTie': result.isTie,
      'totalVotes': result.totalVotes,
      'maxVotes': result.maxVotes,
      'resultSummary': result.resultSummary,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGroup(String groupId) async {
    final groupRef = db.collection('group_orders').doc(groupId);
    final groupSnapshot = await groupRef.get();

    if (!groupSnapshot.exists) {
      throw Exception('This group no longer exists.');
    }

    if (groupSnapshot.data()?['createdBy'] != userId) {
      throw Exception('Only the group creator can delete this group.');
    }

    for (final subcollection in ['cart', 'members', 'messages', 'polls']) {
      final collectionRef = groupRef.collection(subcollection);
      while (true) {
        final snapshot = await collectionRef.limit(450).get();
        if (snapshot.docs.isEmpty) break;

        final batch = db.batch();
        for (final document in snapshot.docs) {
          batch.delete(document.reference);
        }
        await batch.commit();
      }
    }

    await groupRef.delete();
  }

  /// REUSABLE GROUPS:
  /// Resets a delivered group order so the same members can place another order.
  /// Archives the completed order into 'orderHistory' subcollection on the group doc.
  /// Clears the shared cart, resets status to 'open', and preserves member list and invite code.
  Future<void> resetGroupForNewOrder(String groupId) async {
    final groupRef = db.collection('group_orders').doc(groupId);
    final groupDoc = await groupRef.get();
    if (!groupDoc.exists) {
      throw Exception('Group not found.');
    }

    final data = groupDoc.data() ?? {};
    final currentOrderId = data['orderId']?.toString();

    // Check that order is either delivered or completed (or if no orderId, already open)
    if (currentOrderId != null && currentOrderId.isNotEmpty) {
      try {
        final orderDoc = await db.collection('orders').doc(currentOrderId).get();
        final orderStatus = (orderDoc.data()?['orderStatus'] ??
                orderDoc.data()?['status'] ??
                data['orderStatus'] ??
                '')
            .toString()
            .toLowerCase();

        // Allow reset only after order is delivered or completed
        if (orderStatus != 'delivered' &&
            orderStatus != 'completed' &&
            orderStatus != 'cancelled') {
          throw Exception(
            'A new group order can only be started after the current order is delivered.',
          );
        }

        // Archive into orderHistory subcollection
        final archiveData = {
          'orderId': currentOrderId,
          'completedAt': FieldValue.serverTimestamp(),
          'restaurantId': data['restaurantId'] ?? '',
          'restaurantName': data['restaurantName'] ?? '',
          'totalAmount': (data['restaurantPayment'] is Map
                  ? data['restaurantPayment']['amount']
                  : null) ??
              data['restaurantTotal'] ??
              0.0,
          'paidBy': data['paidBy'] ?? '',
          'paidByName': data['paidByName'] ?? '',
          'orderStatus': orderStatus.isNotEmpty ? orderStatus : 'delivered',
          'split': data['split'],
          'splitMembers': data['splitMembers'],
        };

        await groupRef
            .collection('orderHistory')
            .doc(currentOrderId)
            .set(archiveData);
      } catch (e) {
        if (e.toString().contains('only be started after')) rethrow;
        // Proceed if order doc is inaccessible but group doc was delivered
      }
    }

    // Ensure all polls from the previous order are closed with final results
    try {
      await closeAllActivePolls(groupId);
    } catch (_) {}

    // Clear cart items in group_orders/{groupId}/cart
    final cartSnap = await groupRef.collection('cart').get();
    final batch = db.batch();
    for (final doc in cartSnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Reset group doc to 'open' while keeping groupName, createdBy, inviteCode, memberUids, memberCount
    await groupRef.update({
      'status': 'open',
      'orderId': FieldValue.delete(),
      'orderStatus': FieldValue.delete(),
      'paymentStatus': FieldValue.delete(),
      'paidBy': FieldValue.delete(),
      'paidByName': FieldValue.delete(),
      'paymentId': FieldValue.delete(),
      'restaurantPayment': FieldValue.delete(),
      'restaurantTotal': FieldValue.delete(),
      'restaurantId': '',
      'restaurantName': '',
      'split': FieldValue.delete(),
      'splitMembers': FieldValue.delete(),
      'lastCompletedOrderId': currentOrderId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // REAL-TIME ORDER HISTORY FOR REUSABLE GROUPS
  Stream<QuerySnapshot<Map<String, dynamic>>> orderHistoryStream(String groupId) {
    return db
        .collection('group_orders')
        .doc(groupId)
        .collection('orderHistory')
        .orderBy('completedAt', descending: true)
        .snapshots();
  }
}
