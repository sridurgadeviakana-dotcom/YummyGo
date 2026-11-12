import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/services/cart_service.dart';
import 'package:yummy_go_application/services/favorite_service.dart';
import 'package:yummy_go_application/views/resturent_menu_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';
import 'package:yummy_go_application/widgets/global_cart_bar.dart';
import 'package:yummy_go_application/widgets/restaurant_conflict_dialog.dart';

class FavoriteFoodsScreen extends StatelessWidget {
  const FavoriteFoodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = FavoriteService();
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'Favorite Foods',
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: favorites.favoriteStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load your favorites: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            );
          }

          final documents = snapshot.data?.docs ?? [];
          if (documents.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      color: AppColors.teal,
                      size: 54,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No favorites yet',
                      style: TextStyle(
                        color: AppColors.deepTeal,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tap the heart on a popular item to save it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final document = documents[index];
              final data = document.data();
              if (data['type'] == 'restaurant') {
                final restaurantId =
                    data['restaurantId']?.toString() ??
                    document.id.replaceFirst('restaurant_', '');
                final restaurantName = data['name']?.toString() ?? 'Restaurant';
                final restaurantImage = data['image']?.toString() ?? '';
                final rating = (data['rating'] as num?)?.toDouble() ?? 0;
                final area = data['area']?.toString() ?? '';
                final cuisine = data['cuisine']?.toString() ?? '';
                final deliveryTime = data['deliveryTime']?.toString() ?? '';

                return Material(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 76,
                        height: 76,
                        child: restaurantImage.isEmpty
                            ? const ColoredBox(
                                color: AppColors.lightTeal,
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  color: AppColors.teal,
                                ),
                              )
                            : Image.network(
                                restaurantImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: AppColors.lightTeal,
                                  child: Icon(
                                    Icons.restaurant_rounded,
                                    color: AppColors.teal,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    title: Text(
                      restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepTeal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (cuisine.isNotEmpty) cuisine,
                        if (area.isNotEmpty) area,
                        if (rating > 0) '${rating.toStringAsFixed(1)} ★',
                        if (deliveryTime.isNotEmpty) deliveryTime,
                      ].join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove from favorites',
                      onPressed: () async {
                        try {
                          await favorites.removeFavorite(document.id);
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Unable to remove favorite: $error',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => RestaurantMenuScreen(
                            restaurantId: restaurantId,
                            restaurantName: restaurantName,
                            rating: rating,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }

              final name = data['name']?.toString() ?? 'Food item';
              final restaurant =
                  data['restaurant']?.toString() ?? 'YummyGo Restaurant';
              final image = data['image']?.toString() ?? '';
              final price = (data['price'] as num?)?.toDouble() ?? 0;
              final rating = (data['rating'] as num?)?.toDouble() ?? 0;

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: image.isEmpty
                            ? const ColoredBox(
                                color: AppColors.lightTeal,
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  color: AppColors.teal,
                                ),
                              )
                            : Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: AppColors.lightTeal,
                                  child: Icon(
                                    Icons.restaurant_rounded,
                                    color: AppColors.teal,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.deepTeal,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            restaurant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Text(
                                '₹${price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppColors.charcoalBlack,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (rating > 0) ...[
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.star_rounded,
                                  size: 15,
                                  color: AppColors.goldenOrange,
                                ),
                                Text(rating.toStringAsFixed(1)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          tooltip: 'Remove from favorites',
                          onPressed: () async {
                            try {
                              await favorites.removeFavorite(document.id);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Unable to remove favorite: $error',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.favorite_rounded,
                            color: AppColors.error,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add to cart',
                          onPressed: () async {
                            final cartService = CartService();
                            final rId = data['restaurantId']?.toString();
                            final rName = restaurant;
                            try {
                              final conflict = await cartService.checkConflict(
                                restaurantId: rId,
                                restaurantName: rName,
                              );
                              if (conflict.hasConflict) {
                                if (!context.mounted) return;
                                final shouldClear =
                                    await showRestaurantConflictDialog(
                                  context,
                                  existingRestaurantName:
                                      conflict.existingRestaurantName,
                                  newRestaurantName: rName,
                                  isGroupOrder: false,
                                );
                                if (shouldClear == true) {
                                  await cartService.clearAndAddToCart(
                                    foodId: document.id,
                                    foodName: name,
                                    image: image,
                                    price: price,
                                    restaurantId: rId,
                                    restaurantName: rName,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$name added to cart'),
                                      ),
                                    );
                                  }
                                }
                                return;
                              }

                              await cartService.addToCart(
                                foodId: document.id,
                                foodName: name,
                                image: image,
                                price: price,
                                restaurantId: rId,
                                restaurantName: rName,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$name added to cart'),
                                  ),
                                );
                              }
                            } catch (error) {
                              if (!context.mounted) return;
                              if (error is RestaurantConflictException) {
                                final shouldClear =
                                    await showRestaurantConflictDialog(
                                  context,
                                  existingRestaurantName:
                                      error.existingRestaurantName,
                                  newRestaurantName: rName,
                                  isGroupOrder: false,
                                );
                                if (shouldClear == true) {
                                  await cartService.clearAndAddToCart(
                                    foodId: document.id,
                                    foodName: name,
                                    image: image,
                                    price: price,
                                    restaurantId: rId,
                                    restaurantName: rName,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$name added to cart'),
                                      ),
                                    );
                                  }
                                }
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Unable to add item: $error'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.add_shopping_cart_rounded,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: const GlobalCartBar(),
    );
  }
}
