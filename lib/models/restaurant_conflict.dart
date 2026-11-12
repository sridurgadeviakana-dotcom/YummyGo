class CartConflictResult {
  final bool hasConflict;
  final String existingRestaurantId;
  final String existingRestaurantName;
  final int itemCount;

  const CartConflictResult({
    required this.hasConflict,
    this.existingRestaurantId = '',
    this.existingRestaurantName = '',
    this.itemCount = 0,
  });
}

class RestaurantConflictException implements Exception {
  final String existingRestaurantName;
  final String newRestaurantName;

  const RestaurantConflictException({
    required this.existingRestaurantName,
    required this.newRestaurantName,
  });

  @override
  String toString() =>
      'Your cart already contains items from $existingRestaurantName. '
      'Clear the cart to add items from $newRestaurantName.';
}

