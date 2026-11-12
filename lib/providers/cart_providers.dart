import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yummy_go_application/providers/auth_providers.dart';
import 'package:yummy_go_application/services/cart_service.dart';

/// Provider for CartService instance.
final cartServiceProvider = Provider<CartService>((ref) {
  return CartService();
});

/// Stream of individual user's cart snapshot from Firestore.
final cartStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  // Re-subscribe when authentication state changes
  ref.watch(authStateChangesProvider);
  return ref.watch(cartServiceProvider).cartStream();
});

/// List of cart document snapshots.
final cartItemsProvider =
    Provider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return ref.watch(cartStreamProvider).asData?.value?.docs ?? const [];
});

/// Total number of food units in the customer's cart.
final cartItemCountProvider = Provider<int>((ref) {
  final docs = ref.watch(cartItemsProvider);
  int count = 0;
  for (final doc in docs) {
    count += ((doc.data()['quantity'] as num?)?.toInt() ?? 1);
  }
  return count;
});

/// Total cart amount in rupees.
final cartTotalAmountProvider = Provider<double>((ref) {
  final docs = ref.watch(cartItemsProvider);
  double total = 0.0;
  for (final doc in docs) {
    final price = (doc.data()['price'] as num?)?.toDouble() ?? 0.0;
    final qty = (doc.data()['quantity'] as num?)?.toInt() ?? 1;
    total += price * qty;
  }
  return total;
});

/// Existing restaurant information from the customer's current cart (if any).
final cartRestaurantInfoProvider = Provider<({String? id, String? name})>((ref) {
  final docs = ref.watch(cartItemsProvider);
  for (final doc in docs) {
    final data = doc.data();
    final rId = data['restaurantId']?.toString();
    final rName = data['restaurantName']?.toString();
    if ((rId != null && rId.isNotEmpty) || (rName != null && rName.isNotEmpty)) {
      return (id: rId, name: rName);
    }
  }
  return (id: null, name: null);
});

