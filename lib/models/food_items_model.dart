class FoodItemModel {
  final String id;
  final String name;
  final String restaurantId;
  final String restaurant;
  final String category;
  final String description;
  final String image;
  final String time;
  final String tag;
  final double price;
  final double rating;
  final bool isVeg;
  final bool isEatRight;
  final bool isRepeat;
  final bool isBestSeller;
  final bool isFeatured;

  FoodItemModel({
    required this.id,
    required this.name,
    required this.restaurantId,
    required this.restaurant,
    required this.category,
    required this.description,
    required this.image,
    required this.time,
    required this.tag,
    required this.price,
    required this.rating,
    required this.isVeg,
    required this.isEatRight,
    required this.isRepeat,
    required this.isBestSeller,
    required this.isFeatured,
  });

  factory FoodItemModel.fromMap(String id, Map<String, dynamic> data) {
    return FoodItemModel(
      id: id,
      name: data['name']?.toString() ?? '',
      restaurantId:
          (data['restaurantId'] ?? data['restaurant_id'])?.toString() ?? '',
      restaurant:
          (data['restaurant'] ??
                  data['restaurantName'] ??
                  data['restaurant_name'])
              ?.toString() ??
          '',
      category: data['category']?.toString() ?? 'Other',
      description: (data['description'] ?? data['details'] ?? '')
          .toString()
          .trim(),
      image:
          (data['image'] ?? data['imageUrl'] ?? data['imageURL'])?.toString() ??
          '',
      time: data['time']?.toString() ?? '30-40 min',
      tag: data['tag']?.toString() ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      isVeg: data['isVeg'] == true || data['is_veg'] == true,
      isEatRight: data['isEatRight'] == true || data['eatRight'] == true,
      isRepeat: data['isRepeat'] == true || data['repeatOrder'] == true,
      isBestSeller:
          data['isBestSeller'] == true ||
          data['bestseller'] == true ||
          data['tag']?.toString().toLowerCase().contains('best') == true,
      isFeatured:
          data['isFeatured'] == true ||
          data['featured'] == true ||
          data['tag']?.toString().toLowerCase().contains('popular') == true,
    );
  }

  bool belongsToRestaurant({
    required String restaurantId,
    required String restaurantName,
  }) {
    final normalizedId = this.restaurantId.trim();
    return (normalizedId.isNotEmpty && normalizedId == restaurantId.trim()) ||
        (restaurant.isNotEmpty &&
            restaurant.trim().toLowerCase() ==
                restaurantName.trim().toLowerCase());
  }
}
