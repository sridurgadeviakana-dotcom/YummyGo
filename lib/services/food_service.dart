import 'package:cloud_firestore/cloud_firestore.dart';

class FoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getFoodsByCategory(
    String category,
  ) {
    return _firestore
        .collection('food_items')
        .where('category', isEqualTo: category)
        .snapshots();
  }
}