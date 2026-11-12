import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yummy_go_application/models/food_items_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/resturent_services.dart';

/// Provider for RestaurantService instance.
final restaurantServiceProvider = Provider<RestaurantService>((ref) {
  return RestaurantService();
});

/// Stream of all active and approved restaurants.
final restaurantsStreamProvider = StreamProvider<List<RestaurantModel>>((ref) {
  return ref.watch(restaurantServiceProvider).getRestaurants();
});

/// Stream of a single restaurant by ID.
final restaurantDetailsProvider =
    StreamProvider.family<RestaurantModel?, String>((ref, restaurantId) {
  return ref.watch(restaurantServiceProvider).getRestaurant(restaurantId);
});

/// Stream of all food items across the platform.
final allFoodItemsStreamProvider = StreamProvider<List<FoodItemModel>>((ref) {
  return ref.watch(restaurantServiceProvider).getFoodItems();
});

/// Stream of menu items for a specific restaurant.
final restaurantMenuProvider =
    StreamProvider.family<List<FoodItemModel>, String>((ref, restaurantId) {
  return ref.watch(restaurantServiceProvider).getRestaurantMenu(
        restaurantId: restaurantId,
        restaurantName: '',
      );
});

/// Notifier for currently selected cuisine/category filter on customer home screen.
class SelectedCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  set state(String value) => super.state = value;
  void selectCategory(String category) => state = category;
}

/// Currently selected cuisine/category filter on customer home screen.
final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, String>(
  SelectedCategoryNotifier.new,
);

/// Notifier for active restaurant search query text.
class RestaurantSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  set state(String value) => super.state = value;
  void setQuery(String query) => state = query;
  void clear() => state = '';
}

/// Active restaurant search query text.
final restaurantSearchQueryProvider =
    NotifierProvider<RestaurantSearchQueryNotifier, String>(
  RestaurantSearchQueryNotifier.new,
);

/// Computed provider that filters approved restaurants by search query and category.
final filteredRestaurantsProvider = Provider<List<RestaurantModel>>((ref) {
  final restaurants = ref.watch(restaurantsStreamProvider).asData?.value ?? const [];
  final query = ref.watch(restaurantSearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(selectedCategoryProvider).trim();

  return restaurants.where((r) {
    final matchesQuery = query.isEmpty ||
        r.name.toLowerCase().contains(query) ||
        r.cuisine.toLowerCase().contains(query) ||
        r.area.toLowerCase().contains(query);

    final matchesCategory = category.isEmpty ||
        category.toLowerCase() == 'all' ||
        r.cuisine.toLowerCase().contains(category.toLowerCase());

    return matchesQuery && matchesCategory;
  }).toList();
});
