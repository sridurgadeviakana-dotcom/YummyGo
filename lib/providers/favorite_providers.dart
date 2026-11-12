import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yummy_go_application/providers/auth_providers.dart';
import 'package:yummy_go_application/services/favorite_service.dart';

/// Provider for FavoriteService instance.
final favoriteServiceProvider = Provider<FavoriteService>((ref) {
  return FavoriteService();
});

/// Stream of favorite items for the authenticated user.
final favoriteStreamProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(favoriteServiceProvider).favoriteStream();
});

/// Set of all saved favorite food and restaurant IDs for fast O(1) checks.
final favoriteItemIdsProvider = Provider<Set<String>>((ref) {
  final snap = ref.watch(favoriteStreamProvider).asData?.value;
  if (snap == null) return const {};

  final ids = <String>{};
  for (final doc in snap.docs) {
    final data = doc.data();
    final foodId = data['foodId']?.toString();
    final restaurantId = data['restaurantId']?.toString();
    if (foodId != null && foodId.isNotEmpty) ids.add(foodId);
    if (restaurantId != null && restaurantId.isNotEmpty) ids.add(restaurantId);
    ids.add(doc.id);
  }
  return ids;
});

/// Family provider checking if an individual item or restaurant is favorited.
final isFavoriteProvider = Provider.family<bool, String>((ref, itemId) {
  final favoriteIds = ref.watch(favoriteItemIdsProvider);
  return favoriteIds.contains(itemId);
});

