import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yummy_go_application/models/food_items_model.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/providers/auth_providers.dart';
import 'package:yummy_go_application/providers/order_providers.dart';
import 'package:yummy_go_application/services/restaurant_owner_service.dart';

/// Provider for RestaurantOwnerService instance.
final restaurantOwnerServiceProvider =
    Provider<RestaurantOwnerService>((ref) {
  return RestaurantOwnerService();
});

/// Stream of the restaurant owned by the currently authenticated restaurant owner.
final ownerRestaurantStreamProvider = StreamProvider<RestaurantModel?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(restaurantOwnerServiceProvider).streamOwnerRestaurant();
});

/// Stream of menu items for the owner's restaurant.
final ownerMenuItemsStreamProvider =
    StreamProvider.family<List<FoodItemModel>, String>((ref, restaurantId) {
  return ref.watch(restaurantOwnerServiceProvider).streamMenuItems(restaurantId);
});

/// Stream of orders placed at this restaurant.
final ownerOrdersStreamProvider =
    StreamProvider.family<List<OrderModel>, String>((ref, restaurantId) {
  return ref.watch(orderServiceProvider).streamRestaurantOrders(restaurantId);
});

