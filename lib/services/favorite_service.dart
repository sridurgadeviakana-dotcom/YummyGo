import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yummy_go_application/models/returent_model.dart';

class FavoriteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _favoritesRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Please log in to manage favorite items.');
    }

    return _firestore.collection('users').doc(user.uid).collection('favorites');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> favoriteStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestore.collection('users').doc(user.uid).collection('favorites').snapshots();
  }

  Future<void> toggleFavorite({
    required String foodId,
    required Map<String, dynamic> foodData,
  }) async {
    final favoriteRef = _favoritesRef.doc(foodId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(favoriteRef);
      if (snapshot.exists) {
        transaction.delete(favoriteRef);
        return;
      }

      transaction.set(favoriteRef, {
        ...foodData,
        'foodId': foodId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> toggleRestaurantFavorite(RestaurantModel restaurant) async {
    final favoriteId = 'restaurant_${restaurant.id}';
    final favoriteRef = _favoritesRef.doc(favoriteId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(favoriteRef);
      if (snapshot.exists) {
        transaction.delete(favoriteRef);
        return;
      }

      transaction.set(favoriteRef, {
        'type': 'restaurant',
        'restaurantId': restaurant.id,
        'name': restaurant.name,
        'branchName': restaurant.branchName,
        'area': restaurant.area,
        'cuisine': restaurant.cuisine,
        'image': restaurant.imageUrl,
        'rating': restaurant.rating,
        'deliveryTime': restaurant.deliveryTime,
        'savedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> removeFavorite(String foodId) {
    return _favoritesRef.doc(foodId).delete();
  }
}
