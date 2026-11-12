import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/food_items_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/cart_service.dart';
import 'package:yummy_go_application/services/resturent_services.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';
import 'package:yummy_go_application/widgets/global_cart_bar.dart';
import 'package:yummy_go_application/widgets/restaurant_conflict_dialog.dart';

class RestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.charcoalBlack.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  RestaurantImage(
                    imageUrl: restaurant.imageUrl,
                    restaurantName: restaurant.name,
                    height: 160,
                    width: double.infinity,
                  ),
                  if (!restaurant.isAvailable)
                    Positioned.fill(
                      child: Container(
                        color: AppColors.charcoalBlack.withOpacity(0.65),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.charcoalBlack,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.white.withOpacity(0.4),
                                width: 1.2,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_clock_rounded, color: AppColors.white, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'CLOSED',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${restaurant.cuisine} • ${restaurant.branchName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: AppColors.goldenOrange,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(restaurant.rating.toStringAsFixed(1)),
                      const Spacer(),
                      const Icon(Icons.access_time, size: 17),
                      const SizedBox(width: 4),
                      Text(restaurant.deliveryTime),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantImage extends StatelessWidget {
  final String imageUrl;
  final String restaurantName;
  final double width;
  final double height;
  final BoxFit fit;

  const RestaurantImage({
    super.key,
    required this.imageUrl,
    required this.restaurantName,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  static const String _paradiseFallbackUrl =
      'https://images.unsplash.com/photo-1589302168068-964664d93dc0'
      '?w=900&auto=format&fit=crop';

  @override
  Widget build(BuildContext context) {
    final primaryUrl = imageUrl.trim();
    final fallbackUrl = restaurantName.toLowerCase().contains('paradise')
        ? _paradiseFallbackUrl
        : '';
    final oldBrokenParadiseUrl = primaryUrl.contains(
      'photo-1563379091339-03246963d96c',
    );
    final displayUrl = primaryUrl.isNotEmpty && !oldBrokenParadiseUrl
        ? primaryUrl
        : fallbackUrl;

    if (displayUrl.isEmpty) return _placeholder();

    return Image.network(
      displayUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        if (fallbackUrl.isNotEmpty && displayUrl != fallbackUrl) {
          return Image.network(
            fallbackUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _placeholder(),
          );
        }
        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.lightTeal,
      child: const Center(
        child: Icon(Icons.restaurant, color: AppColors.teal, size: 36),
      ),
    );
  }
}

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectLocation() {
    final location = _controller.text.trim();

    if (location.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter your location')));
      return;
    }

    Navigator.pop(context, location);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: 'Select Location'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Enter area, street or city',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectLocation,
                child: const Text('Confirm Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Restaurant cards, location selection, image handling, and menu UI.
class RestaurantMenuScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final double rating;

  const RestaurantMenuScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.rating,
  });

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  final RestaurantService _service = RestaurantService();
  final CartService _cartService = CartService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  bool _isRestaurantClosed = false;

  static const Color _pageColor = AppColors.warmIvory;
  static const Color _cardColor = AppColors.white;
  static const Color _inkColor = AppColors.charcoalBlack;
  static const Color _accentColor = AppColors.teal;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addToCart(BuildContext context, FoodItemModel food) async {
    if (_isRestaurantClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This restaurant is currently closed. Ordering is disabled.'),
          backgroundColor: AppColors.charcoalBlack,
        ),
      );
      return;
    }
    try {
      final conflict = await _cartService.checkConflict(
        restaurantId: widget.restaurantId,
        restaurantName: widget.restaurantName,
      );

      if (conflict.hasConflict) {
        if (!context.mounted) return;
        final shouldClear = await showRestaurantConflictDialog(
          context,
          existingRestaurantName: conflict.existingRestaurantName,
          newRestaurantName: widget.restaurantName,
          isGroupOrder: false,
        );

        if (shouldClear == true) {
          await _cartService.clearAndAddToCart(
            foodId: food.id,
            foodName: food.name,
            image: food.image,
            price: food.price,
            restaurantId: widget.restaurantId,
            restaurantName: widget.restaurantName,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${food.name} added to cart')),
            );
          }
        }
        return;
      }

      await _cartService.addToCart(
        foodId: food.id,
        foodName: food.name,
        image: food.image,
        price: food.price,
        restaurantId: widget.restaurantId,
        restaurantName: widget.restaurantName,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
      }
    } catch (e) {
      if (!context.mounted) return;
      if (e is RestaurantConflictException) {
        final shouldClear = await showRestaurantConflictDialog(
          context,
          existingRestaurantName: e.existingRestaurantName,
          newRestaurantName: widget.restaurantName,
          isGroupOrder: false,
        );
        if (shouldClear == true) {
          await _cartService.clearAndAddToCart(
            foodId: food.id,
            foodName: food.name,
            image: food.image,
            price: food.price,
            restaurantId: widget.restaurantId,
            restaurantName: widget.restaurantName,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${food.name} added to cart')),
            );
          }
        }
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to add item: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RestaurantModel?>(
      stream: _service.getRestaurant(widget.restaurantId),
      builder: (context, restaurantSnapshot) {
        if (restaurantSnapshot.hasError) {
          return Scaffold(
            backgroundColor: _pageColor,
            appBar: CommonAppBar(
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
              title: widget.restaurantName,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load restaurant details: '
                  '${restaurantSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final restaurant = restaurantSnapshot.data;
        _isRestaurantClosed = restaurant != null && !restaurant.isAvailable;
        final restaurantName = restaurant?.name ?? widget.restaurantName;
        final restaurantRating = restaurant?.rating ?? widget.rating;
        final hasRestaurantImage = restaurant?.imageUrl.isNotEmpty == true;

        return Scaffold(
          backgroundColor: _pageColor,
          appBar: CommonAppBar(
            backgroundColor: AppColors.deepTeal,
            foregroundColor: AppColors.white,
            centerTitle: true,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: _cardColor,
                  radius: 18,
                  child: hasRestaurantImage ||
                          restaurantName.toLowerCase().contains('paradise')
                      ? ClipOval(
                          child: RestaurantImage(
                            imageUrl: restaurant?.imageUrl ?? '',
                            restaurantName: restaurantName,
                            width: 36,
                            height: 36,
                          ),
                        )
                      : Text(
                          restaurantName.isEmpty
                              ? 'Y'
                              : restaurantName[0].toUpperCase(),
                          style: const TextStyle(
                            color: _accentColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    restaurantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Restaurant options',
                onPressed: () {},
                icon: const Icon(Icons.more_vert, color: AppColors.white),
              ),
            ],
          ),
          body: StreamBuilder<List<FoodItemModel>>(
            stream: _service.getRestaurantMenu(
              restaurantId: widget.restaurantId,
              restaurantName: restaurantName,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Unable to load this menu: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _accentColor),
                );
              }

              final allFoods = snapshot.data ?? [];
              final query = _searchController.text.trim().toLowerCase();
              final foods = allFoods.where((food) {
                final matchesSearch =
                    query.isEmpty ||
                    food.name.toLowerCase().contains(query) ||
                    food.category.toLowerCase().contains(query);
                final matchesFilter = switch (_selectedFilter) {
                  'Veg' => food.isVeg,
                  'Non-veg' => !food.isVeg,
                  'EatRight' => food.isEatRight,
                  '4.0+' => food.rating >= 4,
                  'Bestseller' => food.isBestSeller || food.isFeatured,
                  _ => true,
                };
                return matchesSearch && matchesFilter;
              }).toList();
              final topPicks = [...allFoods]
                ..sort((a, b) => b.rating.compareTo(a.rating));
              final repeatFoods = allFoods
                  .where((food) => food.isRepeat)
                  .toList();

              if (allFoods.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No menu items found for $restaurantName yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return StreamBuilder(
                stream: _cartService.cartStream(),
                builder: (context, cartSnapshot) {
                  if (cartSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Unable to load item quantities: '
                          '${cartSnapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    );
                  }

                  final quantities = {
                    for (final item in cartSnapshot.data?.docs ?? [])
                      item.id: (item.data()['quantity'] as num?)?.toInt() ?? 0,
                  };

                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (_isRestaurantClosed)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: AppColors.charcoalBlack,
                          child: const Row(
                            children: [
                              Icon(Icons.lock_clock_rounded, color: AppColors.white, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'This restaurant is currently CLOSED. Ordering is disabled.',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        color: AppColors.deepTeal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_fire_department,
                                    color: _accentColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      restaurant?.cuisine.isNotEmpty == true
                                          ? 'Best in ${restaurant!.cuisine}'
                                          : 'Popular in ${allFoods.first.category}',
                                      style: const TextStyle(
                                        color: _inkColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.verified,
                                    color: AppColors.teal,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'YummyGo',
                                    style: TextStyle(
                                      color: AppColors.teal,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          restaurantName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _inkColor,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${restaurant?.deliveryTime ?? allFoods.first.time}'
                                          '${restaurant?.branchName.isNotEmpty == true ? '  |  ${restaurant!.branchName}' : ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.mutedText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          restaurantRating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        const Icon(
                                          Icons.star,
                                          color: AppColors.white,
                                          size: 13,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1),
                              ),
                              Text(
                                '${allFoods.length} menu items available',
                                style: const TextStyle(
                                  color: _inkColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (restaurant?.offerTitle.isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightOrange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        restaurant!.offerTitle,
                                        style: const TextStyle(
                                          color: _inkColor,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      if (restaurant
                                          .offerDescription
                                          .isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 3,
                                          ),
                                          child: Text(
                                            restaurant.offerDescription,
                                            style: const TextStyle(
                                              color: _inkColor,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search for dishes',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                            filled: true,
                            fillColor: _cardColor,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          scrollDirection: Axis.horizontal,
                          children: [
                            _filterChip('Veg', Icons.circle, AppColors.success),
                            _filterChip(
                              'Non-veg',
                              Icons.circle,
                              AppColors.error,
                            ),
                            _filterChip(
                              'EatRight',
                              Icons.eco,
                              AppColors.limeGreen,
                            ),
                            _filterChip('4.0+', Icons.star, _accentColor),
                            _filterChip(
                              'Bestseller',
                              Icons.local_fire_department,
                              _accentColor,
                            ),
                          ],
                        ),
                      ),
                      if (repeatFoods.isNotEmpty) ...[
                        _sectionTitle('Want to repeat?'),
                        SizedBox(
                          height: 148,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: repeatFoods.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) => _repeatFoodCard(
                              context,
                              repeatFoods[index],
                              quantities[repeatFoods[index].id] ?? 0,
                            ),
                          ),
                        ),
                      ],
                      _sectionTitle('Top Picks'),
                      SizedBox(
                        height: 218,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: topPicks.take(6).length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final food = topPicks[index];
                            return _topPickCard(
                              context,
                              food,
                              quantities[food.id] ?? 0,
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Items at ₹${foods.isEmpty ? 0 : foods.map((food) => food.price).reduce((a, b) => a < b ? a : b).toStringAsFixed(0)} (${foods.length})',
                                style: const TextStyle(
                                  color: _inkColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down),
                          ],
                        ),
                      ),
                      if (foods.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No dishes match your search or filters.',
                            ),
                          ),
                        )
                      else
                        ...foods.map(
                          (food) => _menuItemCard(
                            context,
                            food,
                            quantities[food.id] ?? 0,
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              );
            },
          ),
          bottomNavigationBar: const GlobalCartBar(),
        );
      },
    );
  }

  Widget _filterChip(String label, IconData icon, Color iconColor) {
    final selected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(icon, size: 15, color: iconColor),
        label: Text(label),
        backgroundColor: _cardColor,
        selectedColor: AppColors.lightTeal,
        side: BorderSide(color: selected ? _accentColor : AppColors.border),
        onSelected: (value) {
          setState(() => _selectedFilter = value ? label : 'All');
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: _inkColor,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _repeatFoodCard(
    BuildContext context,
    FoodItemModel food,
    int quantity,
  ) {
    return InkWell(
      onTap: () => _showFoodDetails(context, food),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 245,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 78,
                height: 92,
                child: _foodImage(food.image),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    food.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _inkColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '₹${food.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: _inkColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _quantityControl(context, food, quantity, compact: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topPickCard(BuildContext context, FoodItemModel food, int quantity) {
    return InkWell(
      onTap: () => _showFoodDetails(context, food),
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 240,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _foodImage(food.image),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.charcoalBlack.withValues(alpha: 0.8),
                    ],
                    stops: const [0.35, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '₹${food.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        _quantityControl(
                          context,
                          food,
                          quantity,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItemCard(BuildContext context, FoodItemModel food, int quantity) {
    return InkWell(
      onTap: () => _showFoodDetails(context, food),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 112,
                height: 112,
                child: _foodImage(food.image),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.circle,
                    size: 14,
                    color: food.isVeg ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    food.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _inkColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    food.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '₹${food.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: _inkColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (food.rating > 0) ...[
                        const Icon(Icons.star, color: _accentColor, size: 15),
                        Text(
                          food.rating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _quantityControl(context, food, quantity),
          ],
        ),
      ),
    );
  }

  Future<void> _showFoodDetails(
    BuildContext context,
    FoodItemModel food,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 210,
                      child: _foodImage(food.image),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              food.name,
                              style: const TextStyle(
                                color: AppColors.charcoalBlack,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.circle,
                            size: 14,
                            color: food.isVeg
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _detailPill(food.category),
                          if (food.rating > 0)
                            _detailPill(
                              '${food.rating.toStringAsFixed(1)} ★',
                              icon: Icons.star,
                            ),
                          _detailPill(
                            food.isVeg ? 'Veg' : 'Non-veg',
                            icon: Icons.circle,
                          ),
                          _detailPill(food.time, icon: Icons.schedule),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        food.description.isNotEmpty
                            ? food.description
                            : '${food.category} • ${food.time} preparation',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '₹${food.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.charcoalBlack,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          StreamBuilder(
                            stream: _cartService.cartStream(),
                            builder: (context, cartSnapshot) {
                              if (cartSnapshot.hasError) {
                                return const Text(
                                  'Unable to load quantity',
                                  style: TextStyle(color: AppColors.error),
                                );
                              }
                              final item = cartSnapshot.data?.docs
                                  .where((doc) => doc.id == food.id)
                                  .firstOrNull;
                              final quantity =
                                  (item?.data()['quantity'] as num?)?.toInt() ??
                                  0;
                              return _quantityControl(context, food, quantity);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailPill(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lightTeal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.teal),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              color: AppColors.deepTeal,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quantityControl(
    BuildContext context,
    FoodItemModel food,
    int quantity, {
    bool compact = false,
  }) {
    if (_isRestaurantClosed) {
      return Container(
        height: compact ? 30 : 34,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: AppColors.charcoalBlack.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.charcoalBlack.withOpacity(0.2)),
        ),
        child: const Center(
          child: Text(
            'CLOSED',
            style: TextStyle(
              color: AppColors.charcoalBlack,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.8,
            ),
          ),
        ),
      );
    }

    if (quantity <= 0) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepTeal,
          side: const BorderSide(color: AppColors.deepTeal),
          minimumSize: Size.zero,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 10,
            vertical: compact ? 5 : 7,
          ),
        ),
        onPressed: () => _addToCart(context, food),
        child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w800)),
      );
    }

    return Container(
      height: compact ? 32 : 36,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.teal),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _quantityAction(
            icon: Icons.remove,
            tooltip: 'Decrease ${food.name} quantity',
            onPressed: () => _changeQuantity(context, food, -1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: AppColors.deepTeal,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _quantityAction(
            icon: Icons.add,
            tooltip: 'Increase ${food.name} quantity',
            onPressed: () => _changeQuantity(context, food, 1),
          ),
        ],
      ),
    );
  }

  Widget _quantityAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(icon, size: 18, color: AppColors.deepTeal),
    );
  }

  Future<void> _changeQuantity(
    BuildContext context,
    FoodItemModel food,
    int change,
  ) async {
    if (_isRestaurantClosed && change > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This restaurant is currently closed. Ordering is disabled.'),
          backgroundColor: AppColors.charcoalBlack,
        ),
      );
      return;
    }
    try {
      if (change > 0) {
        final conflict = await _cartService.checkConflict(
          restaurantId: widget.restaurantId,
          restaurantName: widget.restaurantName,
        );

        if (conflict.hasConflict) {
          if (!context.mounted) return;
          final shouldClear = await showRestaurantConflictDialog(
            context,
            existingRestaurantName: conflict.existingRestaurantName,
            newRestaurantName: widget.restaurantName,
            isGroupOrder: false,
          );

          if (shouldClear == true) {
            await _cartService.clearAndAdjustQuantity(
              foodId: food.id,
              foodName: food.name,
              image: food.image,
              price: food.price,
              change: change,
              restaurantId: widget.restaurantId,
              restaurantName: widget.restaurantName,
            );
          }
          return;
        }
      }

      await _cartService.adjustQuantity(
        foodId: food.id,
        foodName: food.name,
        image: food.image,
        price: food.price,
        change: change,
        restaurantId: widget.restaurantId,
        restaurantName: widget.restaurantName,
      );
    } catch (error) {
      if (!context.mounted) return;
      if (error is RestaurantConflictException) {
        final shouldClear = await showRestaurantConflictDialog(
          context,
          existingRestaurantName: error.existingRestaurantName,
          newRestaurantName: widget.restaurantName,
          isGroupOrder: false,
        );
        if (shouldClear == true) {
          await _cartService.clearAndAdjustQuantity(
            foodId: food.id,
            foodName: food.name,
            image: food.image,
            price: food.price,
            change: change,
            restaurantId: widget.restaurantId,
            restaurantName: widget.restaurantName,
          );
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update ${food.name}: $error')),
      );
    }
  }

  Widget _foodImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        color: AppColors.lightTeal,
        child: const Center(
          child: Icon(Icons.fastfood, color: AppColors.teal, size: 40),
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.lightTeal,
          child: const Center(
            child: Icon(Icons.fastfood, color: AppColors.teal, size: 40),
          ),
        );
      },
    );
  }
}
