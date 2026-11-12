import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yummy_go_application/models/order_model.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      _firestore.collection('orders');

  /// Stream all orders for Admin
  Stream<List<OrderModel>> streamAllOrders() {
    return _ordersCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList())
        .handleError((error) {
      // In case composite index is missing or collection is empty, fallback to simple stream
      return _ordersCol.snapshots().map((snapshot) {
        final list =
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });
    });
  }

  /// Stream orders for a specific restaurant
  Stream<List<OrderModel>> streamRestaurantOrders(
    String restaurantId, {
    String? restaurantName,
  }) {
    return _ordersCol.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where((order) {
            if (order.restaurantId == restaurantId) return true;
            if (restaurantName != null &&
                restaurantName.isNotEmpty &&
                order.restaurantName.toLowerCase() ==
                    restaurantName.toLowerCase()) {
              return true;
            }
            return false;
          })
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// Stream delivery orders assigned to this partner by Admin waiting for acceptance
  Stream<List<OrderModel>> streamAvailableDeliveryOrders({String? partnerId}) {
    return _ordersCol.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where((order) {
            // Only orders assigned to this partner by Admin that need acceptance
            if (partnerId != null &&
                order.deliveryPartnerId == partnerId &&
                !order.deliveryAccepted &&
                order.orderStatus != 'delivered' &&
                order.orderStatus != 'completed') {
              return true;
            }
            return false;
          })
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// Stream active or past orders for a delivery partner
  Stream<List<OrderModel>> streamPartnerOrders(String partnerId) {
    return _ordersCol.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where((order) => order.deliveryPartnerId == partnerId)
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// Stream customer orders (both individual orders and group orders where user is member)
  Stream<List<OrderModel>> streamCustomerOrders(String userId) {
    return _ordersCol.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where((order) => order.isUserInOrder(userId))
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// Stream active customer orders (Confirmed, Preparing, Ready, Out for Delivery)
  Stream<List<OrderModel>> streamCustomerActiveOrders(String userId) {
    return streamCustomerOrders(userId).map((orders) {
      return orders.where((order) => order.isActive).toList();
    });
  }

  /// Stream the single most recent active order for the user (or null if none)
  Stream<OrderModel?> streamUserActiveOrder(String userId) {
    return streamCustomerActiveOrders(userId).map((orders) {
      return orders.isNotEmpty ? orders.first : null;
    });
  }

  /// Check whether the customer has any active order (individual or group).
  /// Returns the active OrderModel if found, otherwise null.
  Future<OrderModel?> getActiveUserOrder(String userId) async {
    if (userId.isEmpty) return null;
    try {
      // 1. Check orders collection specifically for this user with timeout
      final snapshot = await _ordersCol
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 3));
      for (final doc in snapshot.docs) {
        final order = OrderModel.fromFirestore(doc);
        if (order.isUserInOrder(userId) && order.isActive) {
          return order;
        }
      }

      // 2. Fallback check group_orders collection in case order document is syncing
      final groupSnap = await _firestore
          .collection('group_orders')
          .where('memberUids', arrayContains: userId)
          .get()
          .timeout(const Duration(seconds: 3));
      for (final doc in groupSnap.docs) {
        final data = doc.data();
        final status = (data['orderStatus'] ?? data['status'])?.toString().toLowerCase() ?? '';
        final isPaid = data['paymentStatus'] == 'paid' || data['paidBy'] != null;
        final isDelivered = status == 'delivered' || status == 'completed';
        final isCancelled = status == 'cancelled';
        if (isPaid && !isDelivered && !isCancelled) {
          final orderId = data['orderId']?.toString() ?? doc.id;
          return OrderModel(
            id: orderId,
            userId: userId,
            customerName: data['paidByName']?.toString() ?? 'Group Order',
            restaurantId: data['restaurantId']?.toString() ?? '',
            restaurantName: data['restaurantName']?.toString() ?? 'Group Restaurant',
            items: const [],
            totalAmount: (data['restaurantTotal'] as num?)?.toDouble() ?? 0.0,
            orderStatus: status.isNotEmpty ? status : 'confirmed',
            groupId: doc.id,
            orderType: 'group',
            groupName: data['groupName']?.toString(),
            memberUids: List<String>.from(data['memberUids'] ?? [userId]),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Stream delivered customer orders (Delivered, Completed)
  Stream<List<OrderModel>> streamCustomerDeliveredOrders(String userId) {
    return streamCustomerOrders(userId).map((orders) {
      return orders.where((order) => order.isDelivered).toList();
    });
  }

  /// Stream a single order by ID in real-time
  Stream<OrderModel?> streamOrder(String orderId) {
    return _ordersCol.doc(orderId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return OrderModel.fromFirestore(doc);
    });
  }

  /// Update live tracking coordinates for an active delivery order
  Future<void> updateDeliveryTracking({
    required String orderId,
    required double latitude,
    required double longitude,
    double heading = 0.0,
    double speed = 0.0,
  }) async {
    await _ordersCol.doc(orderId).collection('tracking').doc('current').set({
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Create a new order in Firestore
  Future<String> createOrder(OrderModel order) async {
    final docRef = _ordersCol.doc();
    final data = order.toMap();
    data['id'] = docRef.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.set(data);

    // Also mirror into user's private orders subcollection for legacy profile screen
    try {
      await _firestore
          .collection('users')
          .doc(order.userId)
          .collection('orders')
          .doc(docRef.id)
          .set(data);
    } catch (_) {}

    return docRef.id;
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final updateData = {
      'orderStatus': newStatus,
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _ordersCol.doc(orderId).update(updateData);

    // Mirror to user subcollection if exists
    try {
      final doc = await _ordersCol.doc(orderId).get();
      final userId = doc.data()?['userId']?.toString();
      if (userId != null && userId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('orders')
            .doc(orderId)
            .update(updateData);
      }
    } catch (_) {}
  }

  /// Assign delivery partner to order (Admin step: sets deliveryPartnerId, deliveryAccepted = false)
  /// Only online partners can receive orders.
  Future<bool> assignDeliveryPartner({
    required String orderId,
    required String partnerId,
    required String partnerName,
    String partnerPhone = '',
  }) async {
    // Ensure partner is online before assigning
    try {
      final pDoc = await _firestore.collection('delivery_partners').doc(partnerId).get();
      final pData = pDoc.data();
      final isOnline = pData?['isAvailable'] == true || pData?['isOnline'] == true;
      if (!isOnline) {
        return false;
      }
    } catch (_) {}

    final updateData = {
      'deliveryPartnerId': partnerId,
      'deliveryPartnerName': partnerName,
      'deliveryPartnerPhone': partnerPhone,
      'deliveryAccepted': false,
      'assignedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _ordersCol.doc(orderId).update(updateData);

    // Notify partner by setting assignedOrderId
    await _firestore.collection('delivery_partners').doc(partnerId).set({
      'assignedOrderId': orderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Mirror to user subcollection if exists
    try {
      final doc = await _ordersCol.doc(orderId).get();
      final userId = doc.data()?['userId']?.toString();
      if (userId != null && userId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('orders')
            .doc(orderId)
            .update(updateData);
      }
    } catch (_) {}

    return true;
  }

  /// Delivery Partner accepts the assigned order
  Future<void> acceptDeliveryOrder({
    required String orderId,
    required String partnerId,
    String? partnerName,
    String? partnerPhone,
  }) async {
    final updateData = <String, dynamic>{
      'deliveryAccepted': true,
      'deliveryPartnerId': partnerId,
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (partnerName != null && partnerName.isNotEmpty) {
      updateData['deliveryPartnerName'] = partnerName;
    }
    if (partnerPhone != null && partnerPhone.isNotEmpty) {
      updateData['deliveryPartnerPhone'] = partnerPhone;
    }

    await _ordersCol.doc(orderId).update(updateData);

    // Update partner's active order and clear pending assignedOrderId
    await _firestore.collection('delivery_partners').doc(partnerId).set({
      'activeOrderId': orderId,
      'assignedOrderId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Mirror to user subcollection if exists
    try {
      final doc = await _ordersCol.doc(orderId).get();
      final userId = doc.data()?['userId']?.toString();
      if (userId != null && userId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('orders')
            .doc(orderId)
            .update(updateData);
      }
    } catch (_) {}
  }

  /// Delivery partner picks up food from restaurant -> order moves to 'on_the_way'
  Future<void> markPickedUp(String orderId) async {
    final updateData = {
      'orderStatus': 'on_the_way',
      'status': 'on_the_way',
      'pickedUpAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _ordersCol.doc(orderId).update(updateData);

    // Also mirror to tracking document
    try {
      await _ordersCol.doc(orderId).collection('tracking').doc('current').set({
        'orderStatus': 'on_the_way',
        'stage': 'on_the_way',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    // Mirror to user subcollection if exists
    try {
      final doc = await _ordersCol.doc(orderId).get();
      final userId = doc.data()?['userId']?.toString();
      if (userId != null && userId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('orders')
            .doc(orderId)
            .update(updateData);
      }
    } catch (_) {}
  }

  /// Complete delivery with customer name verification
  Future<void> completeDelivery(
    String orderId,
    String partnerId, {
    String? customerVerifiedName,
  }) async {
    final updateData = {
      'orderStatus': 'delivered',
      'status': 'delivered',
      if (customerVerifiedName != null && customerVerifiedName.isNotEmpty)
        'customerVerifiedName': customerVerifiedName,
      'deliveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _ordersCol.doc(orderId).update(updateData);

    // Also update tracking document to delivered
    try {
      await _ordersCol.doc(orderId).collection('tracking').doc('current').set({
        'orderStatus': 'delivered',
        'stage': 'delivered',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    // Update partner record (increment deliveries and earnings by ₹50)
    final partnerRef = _firestore.collection('delivery_partners').doc(partnerId);
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(partnerRef);
      if (doc.exists) {
        final currentCount = (doc.data()?['totalDeliveries'] as num?)?.toInt() ?? 0;
        final currentEarnings = (doc.data()?['earnings'] as num?)?.toDouble() ?? 0.0;
        tx.update(partnerRef, {
          'activeOrderId': FieldValue.delete(),
          'assignedOrderId': FieldValue.delete(),
          'totalDeliveries': currentCount + 1,
          'earnings': currentEarnings + 50.0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    // Mirror to user subcollection if exists
    try {
      final doc = await _ordersCol.doc(orderId).get();
      final userId = doc.data()?['userId']?.toString();
      if (userId != null && userId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('orders')
            .doc(orderId)
            .update(updateData);
      }
    } catch (_) {}
  }
}

