import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/cart_service.dart';
import 'package:yummy_go_application/services/favorite_service.dart';
import 'package:yummy_go_application/services/resturent_services.dart';
import 'package:yummy_go_application/views/cart_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';
import 'package:yummy_go_application/widgets/customer_home_widgets.dart';
import 'package:yummy_go_application/widgets/global_cart_bar.dart';
import 'package:yummy_go_application/widgets/restaurant_conflict_dialog.dart';

class CravingOption {
  final String emoji;
  final String title;
  final String imageUrl;
  final List<String> keywords;
  final List<String> excludedKeywords;

  const CravingOption({
    required this.emoji,
    required this.title,
    required this.imageUrl,
    required this.keywords,
    this.excludedKeywords = const [],
  });
}

class CravingResultsScreen extends StatefulWidget {
  final CravingOption craving;

  const CravingResultsScreen({
    super.key,
    required this.craving,
  });

  @override
  State<CravingResultsScreen> createState() => _CravingResultsScreenState();
}

class _CravingResultsScreenState extends State<CravingResultsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CartService _cartService = CartService();
  final FavoriteService _favoriteService = FavoriteService();

  List<FoodItem> _convertFoods(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return documents
        .map((doc) {
          final data = doc.data();
          final isAvail = data['isAvailable'] == null
              ? true
              : (data['isAvailable'] == true ||
                  data['isAvailable'].toString().toLowerCase() == 'true');

          return FoodItem(
            id: doc.id,
            name: data['name']?.toString() ?? '',
            restaurantId:
                (data['restaurantId'] ?? data['restaurant_id'])?.toString() ??
                '',
            restaurant:
                (data['restaurant'] ?? data['restaurantName'])?.toString() ??
                'YummyGo Restaurant',
            price: (data['price'] as num?)?.toInt() ?? 0,
            rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
            time: data['time']?.toString() ?? '25-30 min',
            category: data['category']?.toString() ?? 'Other',
            image:
                (data['image'] ?? data['imageUrl'] ?? data['imageURL'])
                    ?.toString() ??
                '',
            tag: data['tag']?.toString() ?? '',
            description:
                (data['description'] ?? data['details'])?.toString() ?? '',
            cuisine: data['cuisine']?.toString() ?? '',
            isAvailable: isAvail,
          );
        })
        .where((food) => food.name.isNotEmpty && food.isAvailable)
        .toList();
  }

  List<FoodItem> _filterByCraving(List<FoodItem> foods) {
    final kws = widget.craving.keywords.map((k) => k.toLowerCase()).toList();
    final excluded = widget.craving.excludedKeywords.map((k) => k.toLowerCase()).toList();

    return foods.where((food) {
      final nameLower = food.name.toLowerCase();
      final catLower = food.category.toLowerCase();
      final tagLower = food.tag.toLowerCase();
      final cuisineLower = food.cuisine.toLowerCase();
      final descLower = food.description.toLowerCase();

      // Check negative exclusions
      // If any excluded keyword matches the food's name, reject it!
      // (e.g. "classic fries" contains "fries", which is excluded from "Refreshing")
      final isExcluded = excluded.any((ex) {
        final regex = RegExp(r'\b' + RegExp.escape(ex) + r'\b', caseSensitive: false);
        return regex.hasMatch(nameLower);
      });
      if (isExcluded) return false;

      // Primary check on food name, category, tag, and cuisine
      // (Do NOT check food.restaurant to prevent restaurants named "Cafe" or "Shake" matching non-drink items)
      final primaryText = '$nameLower $catLower $tagLower $cuisineLower';

      bool matches = kws.any((kw) {
        if (kw.length <= 4) {
          final regex = RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false);
          return regex.hasMatch(primaryText);
        }
        return primaryText.contains(kw);
      });

      if (matches) return true;

      // Secondary check on description if available
      if (descLower.isNotEmpty) {
        matches = kws.any((kw) {
          if (kw.length <= 4) {
            final regex = RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false);
            return regex.hasMatch(descLower);
          }
          return descLower.contains(kw);
        });
        if (matches) return true;
      }

      return false;
    }).toList();
  }

  Future<void> _addToCart(FoodItem food) async {
    try {
      final conflict = await _cartService.checkConflict(
        restaurantId: food.restaurantId.isEmpty ? null : food.restaurantId,
        restaurantName: food.restaurant,
      );

      if (conflict.hasConflict) {
        if (!mounted) return;
        final shouldClear = await showRestaurantConflictDialog(
          context,
          existingRestaurantName: conflict.existingRestaurantName,
          newRestaurantName: food.restaurant,
          isGroupOrder: false,
        );

        if (shouldClear == true) {
          await _cartService.clearAndAddToCart(
            foodId: food.id,
            foodName: food.name,
            image: food.image,
            price: food.price.toDouble(),
            restaurantId: food.restaurantId.isEmpty ? null : food.restaurantId,
            restaurantName: food.restaurant,
          );
          if (!mounted) return;
          _showAddedSnackBar(food);
        }
        return;
      }

      await _cartService.addToCart(
        foodId: food.id,
        foodName: food.name,
        image: food.image,
        price: food.price.toDouble(),
        restaurantId: food.restaurantId.isEmpty ? null : food.restaurantId,
        restaurantName: food.restaurant,
      );

      if (!mounted) return;
      _showAddedSnackBar(food);
    } catch (e) {
      if (!mounted) return;
      if (e is RestaurantConflictException) {
        final shouldClear = await showRestaurantConflictDialog(
          context,
          existingRestaurantName: e.existingRestaurantName,
          newRestaurantName: food.restaurant,
          isGroupOrder: false,
        );
        if (shouldClear == true) {
          await _cartService.clearAndAddToCart(
            foodId: food.id,
            foodName: food.name,
            image: food.image,
            price: food.price.toDouble(),
            restaurantId: food.restaurantId.isEmpty ? null : food.restaurantId,
            restaurantName: food.restaurant,
          );
          if (!mounted) return;
          _showAddedSnackBar(food);
        }
        return;
      }
      _showMessage(e.toString());
    }
  }

  void _showAddedSnackBar(FoodItem food) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.deepTeal,
          duration: const Duration(seconds: 2),
          width: 320,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${food.name} added!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
                child: const Text(
                  'Check Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _adjustFoodQuantity(FoodItem food, int change) async {
    try {
      if (change > 0) {
        final conflict = await _cartService.checkConflict(
          restaurantId: food.restaurantId.isEmpty ? null : food.restaurantId,
          restaurantName: food.restaurant,
        );

        if (conflict.hasConflict) {
          if (!mounted) return;
          final shouldClear = await showRestaurantConflictDialog(
            context,
            existingRestaurantName: conflict.existingRestaurantName,
            newRestaurantName: food.restaurant,
            isGroupOrder: false,
          );

          if (shouldClear == true) {
            await _cartService.clearAndAdjustQuantity(
              foodId: food.id,
              foodName: food.name,
              image: food.image,
              price: food.price.toDouble(),
              change: change,
              restaurantId: food.restaurantId.isEmpty ? null : food.restaurantId,
              restaurantName: food.restaurant,
            );
          }
          return;
        }
      }

      await _cartService.adjustQuantity(
        foodId: food.id,
        foodName: food.name,
        image: food.image,
        price: food.price.toDouble(),
        change: change,
        restaurantId: food.restaurantId.isEmpty ? null : food.restaurantId,
        restaurantName: food.restaurant,
      );
    } catch (error) {
      if (!mounted) return;
      if (error is RestaurantConflictException) {
        final shouldClear = await showRestaurantConflictDialog(
          context,
          existingRestaurantName: error.existingRestaurantName,
          newRestaurantName: food.restaurant,
          isGroupOrder: false,
        );
        if (shouldClear == true) {
          await _cartService.clearAndAdjustQuantity(
            foodId: food.id,
            foodName: food.name,
            image: food.image,
            price: food.price.toDouble(),
            change: change,
            restaurantId: food.restaurantId.isEmpty ? null : food.restaurantId,
            restaurantName: food.restaurant,
          );
        }
        return;
      }
      _showMessage('Unable to update cart quantity: $error');
    }
  }

  Future<void> _toggleFavoriteFood(FoodItem food) async {
    try {
      await _favoriteService.toggleFavorite(
        foodId: food.id,
        foodData: {
          'name': food.name,
          'restaurant': food.restaurant,
          'category': food.category,
          'image': food.image,
          'price': food.price,
          'rating': food.rating,
          'time': food.time,
          'tag': food.tag,
        },
      );
    } catch (error) {
      _showMessage('Unable to update favorite: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.deepTeal,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cravingTitle = '${widget.craving.emoji} ${widget.craving.title} Food';

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: CommonAppBar(
        backgroundColor: AppColors.white,
        title: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldenOrange.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: Image.network(
                  widget.craving.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(widget.craving.emoji,
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${widget.craving.emoji} ${widget.craving.title} Food',
                style: const TextStyle(
                  color: AppColors.deepTeal,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: StreamBuilder<List<RestaurantModel>>(
        stream: RestaurantService().getRestaurants(),
        builder: (context, restSnap) {
          final approvedRestaurants = (restSnap.data ?? [])
              .where((r) => r.isApproved)
              .toList();
          final approvedIds = approvedRestaurants.map((r) => r.id).toSet();
          final approvedNames = approvedRestaurants
              .map((r) => r.name.trim().toLowerCase())
              .toSet();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('food_items').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load food items: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.error),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allFoods = _convertFoods(snapshot.data?.docs ?? []);
              // Only display food items from approved restaurants with active menus
              final approvedFoods = allFoods.where((food) {
                if (approvedIds.contains(food.restaurantId)) return true;
                if (approvedNames.contains(food.restaurant.trim().toLowerCase())) return true;
                return false;
              }).toList();

              final matchingFoods = _filterByCraving(approvedFoods);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _favoriteService.favoriteStream(),
            builder: (context, favoriteSnapshot) {
              final favoriteDocs = favoriteSnapshot.data?.docs;
              final favoriteIds = <String>{
                if (favoriteDocs != null)
                  for (final doc in favoriteDocs) doc.id,
              };

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _cartService.cartStream(),
                builder: (context, cartSnapshot) {
                  final cartDocs = cartSnapshot.data?.docs;
                  final cartQuantities = <String, int>{
                    if (cartDocs != null)
                      for (final item in cartDocs)
                        item.id:
                            (item.data()['quantity'] as num?)?.toInt() ?? 0,
                  };

                  if (matchingFoods.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.lightOrange,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                widget.craving.emoji,
                                style: const TextStyle(fontSize: 44),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No matching food found 😋',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.deepTeal,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'We could not find any ${widget.craving.title.toLowerCase()} dishes right now. Try exploring another craving!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.mutedText,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.deepTeal,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              child: const Text('Back to Home'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                        child: Row(
                          children: [
                            Text(
                              'Showing ${matchingFoods.length} delicious ${widget.craving.title.toLowerCase()} picks',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: matchingFoods.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 14,
                            mainAxisExtent: 295,
                          ),
                          itemBuilder: (context, index) {
                            final food = matchingFoods[index];
                            final quantity = cartQuantities[food.id] ?? 0;

                            return FoodCard(
                              food: food,
                              isFavorite: favoriteIds.contains(food.id),
                              quantity: quantity,
                              onFavorite: () => _toggleFavoriteFood(food),
                              onAddToCart: () => _addToCart(food),
                              onIncrement: () => _adjustFoodQuantity(food, 1),
                              onDecrement: () => _adjustFoodQuantity(food, -1),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      );
    },
  ),
  bottomNavigationBar: const GlobalCartBar(),
    );
  }
}

