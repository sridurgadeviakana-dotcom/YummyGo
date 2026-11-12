import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yummy_go_application/models/restaurant_conflict.dart';

export 'package:yummy_go_application/models/restaurant_conflict.dart';

class CartService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  String get _userId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please login first to manage your cart.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>>? get _cartRefNullable {
    final uid = currentUserId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('cart');
  }

  CollectionReference<Map<String, dynamic>> get _cartRef {
    return _db.collection('users').doc(_userId).collection('cart');
  }

  // CHECK IF ADDING THIS RESTAURANT'S FOOD CONFLICTS WITH CURRENT CART
  Future<CartConflictResult> checkConflict({
    String? restaurantId,
    String? restaurantName,
  }) async {
    final ref = _cartRefNullable;
    if (ref == null) {
      return const CartConflictResult(hasConflict: false);
    }

    final snapshot = await ref.get();
    if (snapshot.docs.isEmpty) {
      return const CartConflictResult(hasConflict: false);
    }

    String existingRestId = '';
    String existingRestName = '';
    int totalItems = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final qty = (data['quantity'] as num?)?.toInt() ?? 1;
      totalItems += qty;

      if (existingRestId.isEmpty &&
          data['restaurantId'] != null &&
          data['restaurantId'].toString().trim().isNotEmpty) {
        existingRestId = data['restaurantId'].toString().trim();
      }
      if (existingRestName.isEmpty &&
          data['restaurantName'] != null &&
          data['restaurantName'].toString().trim().isNotEmpty) {
        existingRestName = data['restaurantName'].toString().trim();
      }
    }

    final newId = (restaurantId ?? '').trim();
    final newName = (restaurantName ?? '').trim();

    // If no restaurant info on the new item or cart, no conflict
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
      itemCount: totalItems,
    );
  }

  // ADD FOOD TO INDIVIDUAL CART
  Future<void> addToCart({
    required String foodId,
    required String foodName,
    required String image,
    required double price,
    String? restaurantId,
    String? restaurantName,
  }) async {
    if (price <= 0) {
      throw Exception('Invalid food price.');
    }

    final conflict = await checkConflict(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );
    if (conflict.hasConflict) {
      throw RestaurantConflictException(
        existingRestaurantName: conflict.existingRestaurantName,
        newRestaurantName: restaurantName ?? 'another restaurant',
      );
    }

    final itemRef = _cartRef.doc(foodId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(itemRef);

      if (snapshot.exists) {
        final currentQuantity =
            (snapshot.data()?['quantity'] as num?)?.toInt() ?? 0;

        transaction.update(itemRef, {'quantity': currentQuantity + 1});
      } else {
        transaction.set(itemRef, {
          'foodId': foodId,
          'foodName': foodName,
          'image': image,
          'price': price,
          'quantity': 1,
          'restaurantId': restaurantId,
          'restaurantName': restaurantName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // CLEAR CART AND ADD NEW RESTAURANT ITEM
  Future<void> clearAndAddToCart({
    required String foodId,
    required String foodName,
    required String image,
    required double price,
    String? restaurantId,
    String? restaurantName,
  }) async {
    await clearCart();
    await addToCart(
      foodId: foodId,
      foodName: foodName,
      image: image,
      price: price,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );
  }

  // GET REAL-TIME CART ITEMS (Safely returns empty stream if not logged in)
  Stream<QuerySnapshot<Map<String, dynamic>>> cartStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _db.collection('users').doc(user.uid).collection('cart').snapshots();
  }

  // UPDATE QUANTITY
  Future<void> updateQuantity({
    required String foodId,
    required int quantity,
  }) async {
    final itemRef = _cartRef.doc(foodId);

    if (quantity <= 0) {
      await itemRef.delete();
    } else {
      await itemRef.update({'quantity': quantity});
    }
  }

  Future<void> adjustQuantity({
    required String foodId,
    required String foodName,
    required String image,
    required double price,
    required int change,
    String? restaurantId,
    String? restaurantName,
  }) async {
    if (change == 0) return;
    if (price <= 0) {
      throw Exception('Invalid food price.');
    }

    if (change > 0) {
      final conflict = await checkConflict(
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

    final itemRef = _cartRef.doc(foodId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(itemRef);
      final currentQuantity =
          (snapshot.data()?['quantity'] as num?)?.toInt() ?? 0;
      final nextQuantity = currentQuantity + change;

      if (nextQuantity <= 0) {
        if (snapshot.exists) transaction.delete(itemRef);
        return;
      }

      if (snapshot.exists) {
        transaction.update(itemRef, {'quantity': nextQuantity});
      } else {
        transaction.set(itemRef, {
          'foodId': foodId,
          'foodName': foodName,
          'image': image,
          'price': price,
          'quantity': nextQuantity,
          'restaurantId': restaurantId,
          'restaurantName': restaurantName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // CLEAR CART AND ADJUST QUANTITY FOR NEW RESTAURANT ITEM
  Future<void> clearAndAdjustQuantity({
    required String foodId,
    required String foodName,
    required String image,
    required double price,
    required int change,
    String? restaurantId,
    String? restaurantName,
  }) async {
    await clearCart();
    await adjustQuantity(
      foodId: foodId,
      foodName: foodName,
      image: image,
      price: price,
      change: change,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );
  }

  // REMOVE FOOD
  Future<void> removeItem(String foodId) async {
    await _cartRef.doc(foodId).delete();
  }

  // CLEAR CART
  Future<void> clearCart() async {
    final ref = _cartRefNullable;
    if (ref == null) return;

    final snapshot = await ref.get();
    final batch = _db.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
