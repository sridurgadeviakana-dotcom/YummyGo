import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yummy_go_application/models/app_user_model.dart';
import 'package:yummy_go_application/models/delivery_partner_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream all users
  Stream<List<AppUserModel>> streamUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUserModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Update user status (active / suspended)
  Future<void> updateUserStatus(String uid, String status) async {
    await _firestore.collection('users').doc(uid).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update user role directly by Admin
  Future<void> updateUserRole(String uid, String role) async {
    await _firestore.collection('users').doc(uid).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream all restaurants with raw status
  Stream<List<RestaurantModel>> streamAllRestaurants() {
    return _firestore.collection('restaurants').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => RestaurantModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Approve or reject restaurant
  Future<void> setRestaurantStatus(String restaurantId, String status) async {
    final isAvailable = status.toLowerCase() == 'active' || status.toLowerCase() == 'approved';
    await _firestore.collection('restaurants').doc(restaurantId).set({
      'status': status,
      'isAvailable': isAvailable,
      'isActive': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Also update owner in users collection
    try {
      final doc = await _firestore.collection('restaurants').doc(restaurantId).get();
      final ownerId = doc.data()?['ownerId']?.toString() ?? restaurantId;
      if (ownerId.isNotEmpty) {
        await _firestore.collection('users').doc(ownerId).set({
          'status': isAvailable ? 'active' : status,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  /// Add new restaurant directly
  Future<String> addRestaurant(Map<String, dynamic> data) async {
    final ref = _firestore.collection('restaurants').doc();
    data['id'] = ref.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  /// Delete restaurant
  Future<void> deleteRestaurant(String restaurantId) async {
    await _firestore.collection('restaurants').doc(restaurantId).delete();
  }

  /// Stream delivery partners
  Stream<List<DeliveryPartnerModel>> streamDeliveryPartners() {
    return _firestore.collection('delivery_partners').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => DeliveryPartnerModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Update delivery partner status
  Future<void> setDeliveryPartnerStatus(String partnerId, String status) async {
    await _firestore.collection('delivery_partners').doc(partnerId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream categories
  Stream<List<Map<String, dynamic>>> streamCategories() {
    return _firestore.collection('categories').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Add category
  Future<void> addCategory(String name, {String icon = '', String image = ''}) async {
    await _firestore.collection('categories').add({
      'name': name.trim(),
      'icon': icon.trim(),
      'image': image.trim(),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete category
  Future<void> deleteCategory(String categoryId) async {
    await _firestore.collection('categories').doc(categoryId).delete();
  }

  /// Stream promotional offers
  Stream<List<Map<String, dynamic>>> streamOffers() {
    return _firestore.collection('offers').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Add promotional offer
  Future<void> addOffer({
    required String code,
    required String title,
    required double discountPercent,
    required double minOrderAmount,
  }) async {
    await _firestore.collection('offers').add({
      'code': code.toUpperCase().trim(),
      'title': title.trim(),
      'discountPercent': discountPercent,
      'minOrderAmount': minOrderAmount,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete offer
  Future<void> deleteOffer(String offerId) async {
    await _firestore.collection('offers').doc(offerId).delete();
  }
}

