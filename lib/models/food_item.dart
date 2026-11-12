class FoodItem {
  final String id;
  final String name;
  final String restaurant;
  final String category;
  final String image;
  final double price;
  final double originalPrice;
  final double rating;
  final int deliveryMinutes;
  final bool isVeg;
  final String offer;
  final bool isAvailable;

  const FoodItem({
    required this.id,
    required this.name,
    required this.restaurant,
    required this.category,
    required this.image,
    required this.price,
    required this.originalPrice,
    required this.rating,
    required this.deliveryMinutes,
    required this.isVeg,
    required this.offer,
    required this.isAvailable,
  });

  factory FoodItem.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FoodItem(
      id: id,
      name: data['name'] ?? '',
      restaurant: data['restaurant'] ?? '',
      category: data['category'] ?? '',
      image: data['image'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      originalPrice:
          (data['originalPrice'] as num?)?.toDouble() ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      deliveryMinutes:
          (data['deliveryMinutes'] as num?)?.toInt() ?? 30,
      isVeg: data['isVeg'] ?? false,
      offer: data['offer'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
    );
  }
}