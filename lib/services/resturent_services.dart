import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yummy_go_application/models/food_items_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';

class RestaurantService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<RestaurantModel>> getRestaurants() {
    return _db.collection('restaurants').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => RestaurantModel.fromFirestore(doc))
          .where((r) => r.isApproved)
          .toList();
    }).handleError((error) {
      return <RestaurantModel>[];
    });
  }

  Stream<RestaurantModel?> getRestaurant(String restaurantId) {
    return _db
        .collection('restaurants')
        .doc(restaurantId)
        .snapshots()
        .map((doc) => doc.exists ? RestaurantModel.fromFirestore(doc) : null)
        .handleError((error) => null);
  }

  Stream<List<FoodItemModel>> getFoodItems() {
    return _db.collection('food_items').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return FoodItemModel.fromMap(doc.id, doc.data());
      }).toList();
    }).handleError((error) {
      return <FoodItemModel>[];
    });
  }

  Stream<List<FoodItemModel>> getRestaurantMenu({
    required String restaurantId,
    required String restaurantName,
  }) {
    return _db.collection('food_items').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => FoodItemModel.fromMap(doc.id, doc.data()))
          .where(
            (food) => food.belongsToRestaurant(
              restaurantId: restaurantId,
              restaurantName: restaurantName,
            ),
          )
          .toList();
    }).handleError((error) {
      return <FoodItemModel>[];
    });
  }
}
