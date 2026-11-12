import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/services/cart_service.dart';
import 'package:yummy_go_application/views/cart_screen.dart';
import 'package:yummy_go_application/widgets/customer_home_widgets.dart';
import 'package:yummy_go_application/widgets/restaurant_conflict_dialog.dart';

/// Interactive "Spin for Food" Dialog with a spinning animation,
/// random meal selection from Firestore, and [Order Now] / [Spin Again] actions.
class SpinForFoodDialog extends StatefulWidget {
  final List<FoodItem>? initialFoods;
  final ValueChanged<FoodItem>? onAddToCart;

  const SpinForFoodDialog({
    super.key,
    this.initialFoods,
    this.onAddToCart,
  });

  static Future<void> show(
    BuildContext context, {
    List<FoodItem>? foods,
    ValueChanged<FoodItem>? onAddToCart,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => SpinForFoodDialog(
        initialFoods: foods,
        onAddToCart: onAddToCart,
      ),
    );
  }

  @override
  State<SpinForFoodDialog> createState() => _SpinForFoodDialogState();
}

class _SpinForFoodDialogState extends State<SpinForFoodDialog>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CartService _cartService = CartService();

  late final AnimationController _spinController;
  late final AnimationController _revealController;
  late final Animation<double> _scaleAnimation;

  List<FoodItem> _availableFoods = [];
  FoodItem? _selectedFood;
  FoodItem? _previewFood;
  bool _isLoading = true;
  bool _isSpinning = false;
  Timer? _cyclingTimer;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutBack,
    );

    _initFoodsAndSpin();
  }

  @override
  void dispose() {
    _cyclingTimer?.cancel();
    _spinController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _initFoodsAndSpin() async {
    List<FoodItem> foods = [];

    if (widget.initialFoods != null && widget.initialFoods!.isNotEmpty) {
      foods = widget.initialFoods!
          .where((food) => food.name.isNotEmpty && food.isAvailable)
          .toList();
    }

    if (foods.isEmpty) {
      try {
        final snapshot = await _firestore.collection('food_items').get();
        foods = snapshot.docs
            .map((doc) {
              final data = doc.data();
              final isAvail = data['isAvailable'] == null
                  ? true
                  : (data['isAvailable'] == true ||
                      data['isAvailable'].toString().toLowerCase() == 'true');

              return FoodItem(
                id: doc.id,
                name: data['name']?.toString() ?? '',
                restaurantId: (data['restaurantId'] ?? data['restaurant_id'])
                        ?.toString() ??
                    '',
                restaurant: (data['restaurant'] ?? data['restaurantName'])
                        ?.toString() ??
                    'YummyGo Restaurant',
                price: (data['price'] as num?)?.toInt() ?? 0,
                rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
                time: data['time']?.toString() ?? '25-30 min',
                category: data['category']?.toString() ?? 'Other',
                image: (data['image'] ?? data['imageUrl'] ?? data['imageURL'])
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
      } catch (_) {
        foods = [];
      }
    }

    if (!mounted) return;

    setState(() {
      _availableFoods = foods;
      _isLoading = false;
    });

    if (_availableFoods.isNotEmpty) {
      _spin();
    }
  }

  void _spin() {
    if (_availableFoods.isEmpty || _isSpinning) return;

    setState(() {
      _isSpinning = true;
      _selectedFood = null;
    });

    // Reset controllers
    _spinController.reset();
    _revealController.reset();
    _spinController.forward();

    // Fast-cycle dishes visually while spinning
    _cyclingTimer?.cancel();
    int cycleCount = 0;
    _cyclingTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      cycleCount++;
      setState(() {
        _previewFood =
            _availableFoods[_random.nextInt(_availableFoods.length)];
      });
    });

    // Pick random food (distinct from current if possible)
    int targetIndex = _random.nextInt(_availableFoods.length);
    if (_availableFoods.length > 1 &&
        _selectedFood != null &&
        _availableFoods[targetIndex].id == _selectedFood!.id) {
      targetIndex = (targetIndex + 1) % _availableFoods.length;
    }
    final pickedFood = _availableFoods[targetIndex];

    // Conclude spin after 1.8 seconds
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      _cyclingTimer?.cancel();
      setState(() {
        _isSpinning = false;
        _selectedFood = pickedFood;
        _previewFood = null;
      });
      _revealController.forward(from: 0.0);
    });
  }

  Future<void> _orderNow(FoodItem food) async {
    if (widget.onAddToCart != null) {
      Navigator.pop(context);
      widget.onAddToCart!(food);
      return;
    }

    final rId = food.restaurantId.isEmpty ? null : food.restaurantId;
    final rName = food.restaurant;
    try {
      final conflict = await _cartService.checkConflict(
        restaurantId: rId,
        restaurantName: rName,
      );

      if (conflict.hasConflict) {
        if (!mounted) return;
        final shouldClear = await showRestaurantConflictDialog(
          context,
          existingRestaurantName: conflict.existingRestaurantName,
          newRestaurantName: rName,
          isGroupOrder: false,
        );

        if (shouldClear == true) {
          await _cartService.clearAndAddToCart(
            foodId: food.id,
            foodName: food.name,
            image: food.image,
            price: food.price.toDouble(),
            restaurantId: rId,
            restaurantName: rName,
          );
          if (!mounted) return;
          Navigator.pop(context);
          _showAddedSnackBar(food);
        }
        return;
      }

      await _cartService.addToCart(
        foodId: food.id,
        foodName: food.name,
        image: food.image,
        price: food.price.toDouble(),
        restaurantId: rId,
        restaurantName: rName,
      );

      if (!mounted) return;
      Navigator.pop(context);
      _showAddedSnackBar(food);
    } catch (e) {
      if (!mounted) return;
      if (e is RestaurantConflictException) {
        final shouldClear = await showRestaurantConflictDialog(
          context,
          existingRestaurantName: e.existingRestaurantName,
          newRestaurantName: rName,
          isGroupOrder: false,
        );
        if (shouldClear == true) {
          await _cartService.clearAndAddToCart(
            foodId: food.id,
            foodName: food.name,
            image: food.image,
            price: food.price.toDouble(),
            restaurantId: rId,
            restaurantName: rName,
          );
          if (!mounted) return;
          Navigator.pop(context);
          _showAddedSnackBar(food);
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add item: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${food.name} added to cart!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepTeal.withOpacity(0.18),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.warmIvory,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🎲', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              const Text(
                'Spin for Food',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepTeal,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.mutedText),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }

    if (_availableFoods.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.lightOrange,
                shape: BoxShape.circle,
              ),
              child: const Text('😋', style: TextStyle(fontSize: 40)),
            ),
            const SizedBox(height: 18),
            const Text(
              'No food available right now 😋',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.deepTeal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check back soon or browse restaurants when menu items are added.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.mutedText),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepTeal,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        if (_isSpinning) ...[
          _buildSpinningView(),
        ] else if (_selectedFood != null) ...[
          ScaleTransition(
            scale: _scaleAnimation,
            child: _buildFoodPickView(_selectedFood!),
          ),
        ] else ...[
          _buildIdleView(),
        ],
      ],
    );
  }

  Widget _buildIdleView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          height: 110,
          width: 110,
          decoration: BoxDecoration(
            color: AppColors.lightTeal,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.teal, width: 2),
          ),
          child: const Center(
            child: Text('🎲', style: TextStyle(fontSize: 50)),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          "Can't decide what to eat?",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.deepTeal,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Let YummyGo pick a random delicious dish for you!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.mutedText),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _spin,
            icon: const Icon(Icons.casino_rounded, size: 20),
            label: const Text('Spin for Food! 🎲'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpinningView() {
    final preview = _previewFood;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated Roulette Wheel / Dice
        RotationTransition(
          turns: _spinController,
          child: Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  AppColors.teal,
                  AppColors.deepTeal,
                  AppColors.limeGreen,
                  AppColors.lightLime,
                  AppColors.teal,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withOpacity(0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                height: 104,
                width: 104,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🎲', style: TextStyle(fontSize: 46)),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Spinning your meal...',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.deepTeal,
          ),
        ),
        const SizedBox(height: 8),

        // Ticker showing cycling food names
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warmIvory,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            preview != null ? '🍽️ ${preview.name}' : 'Finding delicious food...',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.teal,
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildFoodPickView(FoodItem food) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Winner Announcement Header
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lightTeal,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.teal.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🎉', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text(
                    'Your Food Pick!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.deepTeal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Food Card
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepTeal.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Food Image with tag
              Stack(
                children: [
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: Image.network(
                      food.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.lightTeal,
                        child: const Icon(
                          Icons.restaurant_rounded,
                          size: 48,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                  ),
                  if (food.category.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.deepTeal.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          food.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.goldenOrange),
                          const SizedBox(width: 3),
                          Text(
                            food.rating > 0
                                ? food.rating.toStringAsFixed(1)
                                : '4.5',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepTeal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded,
                            size: 14, color: AppColors.mutedText),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            food.restaurant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '₹${food.price}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Action Buttons: [ Order Now ] and [ Spin Again ]
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _spin,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Spin Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  side: const BorderSide(color: AppColors.teal, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _orderNow(food),
                icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                label: const Text('Order Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

