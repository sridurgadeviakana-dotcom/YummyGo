import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yummy_go_application/models/food_items_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';

class RestaurantOwnerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Stream restaurant for current owner
  Stream<RestaurantModel?> streamOwnerRestaurant() {
    final user = currentUser;
    if (user == null) return Stream.value(null);

    return _firestore.collection('restaurants').snapshots().map((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['ownerId'] == user.uid ||
            data['ownerEmail'] == user.email ||
            doc.id == user.uid) {
          return RestaurantModel.fromFirestore(doc);
        }
      }
      return null;
    });
  }

  /// Register new restaurant for current owner
  Future<String> registerRestaurant({
    required String name,
    required String branchName,
    required String area,
    required String cuisine,
    required String deliveryTime,
    String imageUrl = '',
    String openingHours = '9:00 AM - 11:00 PM',
    String phone = '',
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Please login first');

    final ref = _firestore.collection('restaurants').doc();
    final data = {
      'id': ref.id,
      'name': name.trim(),
      'branchName': branchName.trim(),
      'area': area.trim(),
      'cuisine': cuisine.trim(),
      'deliveryTime': deliveryTime.trim(),
      'imageUrl': imageUrl.trim(),
      'rating': 4.5,
      'isAvailable': false, // Hidden & not available until Admin review & approval
      'isActive': false,
      'status': 'pending', // Pending Admin review
      'ownerId': user.uid,
      'ownerEmail': user.email ?? '',
      'openingHours': openingHours,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await ref.set(data);

    // Update user doc with restaurantId
    await _firestore.collection('users').doc(user.uid).set({
      'restaurantId': ref.id,
      'restaurantName': name.trim(),
      'role': 'restaurant_owner',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return ref.id;
  }

  /// Update existing restaurant details
  Future<void> updateRestaurant(String restaurantId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('restaurants').doc(restaurantId).update(updates);
  }

  /// Stream food items for this restaurant
  Stream<List<FoodItemModel>> streamMenuItems(String restaurantId, {String? restaurantName}) {
    return _firestore.collection('food_items').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => FoodItemModel.fromMap(doc.id, doc.data()))
          .where((food) => food.belongsToRestaurant(
                restaurantId: restaurantId,
                restaurantName: restaurantName ?? '',
              ))
          .toList();
    });
  }

  /// Add food item
  Future<String> addFoodItem({
    required String restaurantId,
    required String restaurantName,
    required String name,
    required String category,
    required double price,
    required bool isVeg,
    String description = '',
    String image = '',
    String time = '20-30 min',
    bool isBestSeller = false,
  }) async {
    // Only approved restaurants can add menu items
    final restDoc = await _firestore.collection('restaurants').doc(restaurantId).get();
    if (restDoc.exists) {
      final rData = restDoc.data() ?? {};
      final isAvail = rData['isAvailable'] == true;
      final status = (rData['status'] ?? '').toString().toLowerCase();
      final isApproved = isAvail && (status == 'active' || status == 'approved' || status.isEmpty);
      if (!isApproved) {
        throw Exception('Only approved restaurants can add menu items.');
      }
    }

    final ref = _firestore.collection('food_items').doc();
    final data = {
      'name': name.trim(),
      'restaurantId': restaurantId,
      'restaurant': restaurantName,
      'restaurantName': restaurantName,
      'category': category.trim(),
      'price': price,
      'isVeg': isVeg,
      'description': description.trim(),
      'image': image.trim(),
      'imageUrl': image.trim(),
      'time': time,
      'rating': 4.5,
      'isAvailable': true,
      'isBestSeller': isBestSeller,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await ref.set(data);
    return ref.id;
  }

  /// Update food item
  Future<void> updateFoodItem(String itemId, Map<String, dynamic> updates, {String? restaurantId}) async {
    if (restaurantId != null && restaurantId.isNotEmpty) {
      final restDoc = await _firestore.collection('restaurants').doc(restaurantId).get();
      if (restDoc.exists) {
        final rData = restDoc.data() ?? {};
        final isAvail = rData['isAvailable'] == true;
        final status = (rData['status'] ?? '').toString().toLowerCase();
        final isApproved = isAvail && (status == 'active' || status == 'approved');
        if (!isApproved) {
          throw Exception('Only approved restaurants can edit menu items.');
        }
      }
    }
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('food_items').doc(itemId).update(updates);
  }

  /// Delete food item
  Future<void> deleteFoodItem(String itemId, {String? restaurantId}) async {
    if (restaurantId != null && restaurantId.isNotEmpty) {
      final restDoc = await _firestore.collection('restaurants').doc(restaurantId).get();
      if (restDoc.exists) {
        final rData = restDoc.data() ?? {};
        final isAvail = rData['isAvailable'] == true;
        final status = (rData['status'] ?? '').toString().toLowerCase();
        final isApproved = isAvail && (status == 'active' || status == 'approved');
        if (!isApproved) {
          throw Exception('Only approved restaurants can delete menu items.');
        }
      }
    }
    await _firestore.collection('food_items').doc(itemId).delete();
  }
}

