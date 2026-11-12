import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/services/recommendation_service.dart';
import 'package:yummy_go_application/views/group_ordering_screen.dart';

class FoodItem {
  final String id;
  final String name;
  final String restaurantId;
  final String restaurant;
  final int price;
  final double rating;
  final String time;
  final String category;
  final String image;
  final String tag;
  final String description;
  final bool isPopular;
  final String cuisine;
  final bool isAvailable;
  final double recommendationScore;

  const FoodItem({
    required this.id,
    required this.name,
    required this.restaurantId,
    required this.restaurant,
    required this.price,
    required this.rating,
    required this.time,
    required this.category,
    required this.image,
    required this.tag,
    this.description = '',
    this.isPopular = false,
    this.cuisine = '',
    this.isAvailable = true,
    this.recommendationScore = 0.0,
  });

  FoodItem copyWith({
    String? id,
    String? name,
    String? restaurantId,
    String? restaurant,
    int? price,
    double? rating,
    String? time,
    String? category,
    String? image,
    String? tag,
    String? description,
    bool? isPopular,
    String? cuisine,
    bool? isAvailable,
    double? recommendationScore,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurant: restaurant ?? this.restaurant,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      time: time ?? this.time,
      category: category ?? this.category,
      image: image ?? this.image,
      tag: tag ?? this.tag,
      description: description ?? this.description,
      isPopular: isPopular ?? this.isPopular,
      cuisine: cuisine ?? this.cuisine,
      isAvailable: isAvailable ?? this.isAvailable,
      recommendationScore: recommendationScore ?? this.recommendationScore,
    );
  }
}

class HomeHeader extends StatelessWidget {
  final VoidCallback onLocationTap;
  final VoidCallback onProfileTap;
  final String locationLabel;

  const HomeHeader({
    super.key,
    required this.onLocationTap,
    required this.onProfileTap,
    this.locationLabel = 'Your Location',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.lightTeal,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.room_service_rounded,
              color: AppColors.teal,
              size: 29,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR LOCATION',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: onLocationTap,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          locationLabel == 'Your Location'
                              ? 'Choose your delivery area'
                              : locationLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.teal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onProfileTap,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.deepTeal,
            ),
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class HomeSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search biryani, pizza, restaurants...',
          hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.teal),
          suffixIcon: IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: AppColors.deepTeal),
          ),
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class HomePromoBanner extends StatelessWidget {
  final VoidCallback onTap;

  const HomePromoBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: AppColors.lightOrange,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 242,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/yummygo.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: AppColors.lightTeal),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0, 0.36, 0.66, 1],
                      colors: [
                        AppColors.lightTeal,
                        AppColors.lightTeal.withValues(alpha: 0.90),
                        AppColors.teal.withValues(alpha: 0.50),
                        AppColors.deepTeal.withValues(alpha: 0.40),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.teal,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'YUMMYGO SPECIAL',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.groups_rounded,
                            color: AppColors.deepTeal,
                            size: 25,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Group Ordering',
                        style: TextStyle(
                          color: AppColors.deepTeal,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const SizedBox(
                        width: 255,
                        child: Text(
                          'Your friends. Your favourite food. One group order!',
                          style: TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GroupOrderingScreen(),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text(
                            'Start Group Order',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Center(
                        child: Text(
                          'Invite friends • Add food together • Enjoy together',
                          style: TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeCategorySection extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const HomeCategorySection({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const List<IconData> _icons = [
    Icons.grid_view_rounded,
    Icons.rice_bowl_rounded,
    Icons.local_pizza_rounded,
    Icons.lunch_dining_rounded,
    Icons.restaurant_rounded,
    Icons.icecream_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 26, 20, 15),
          child: Text(
            'What are you craving?',
            style: TextStyle(
              color: AppColors.deepTeal,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(
          height: 94,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (context, index) {
              final selected = selectedIndex == index;

              return GestureDetector(
                onTap: () => onSelected(index),
                child: SizedBox(
                  width: 65,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.teal : AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? AppColors.teal : AppColors.border,
                          ),
                        ),
                        child: Icon(
                          _icons[index % _icons.length],
                          color: selected
                              ? AppColors.white
                              : AppColors.deepTeal,
                          size: 27,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        categories[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? AppColors.teal
                              : AppColors.charcoalBlack,
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onViewAll;

  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.deepTeal,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onViewAll,
            child: const Text(
              'View all',
              style: TextStyle(
                color: AppColors.teal,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FoodCard extends StatelessWidget {
  final FoodItem food;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onAddToCart;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback? onTap;

  const FoodCard({
    super.key,
    required this.food,
    required this.isFavorite,
    required this.onFavorite,
    required this.onAddToCart,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepTeal.withOpacity(0.045),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
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
                  Positioned(
                    top: 9,
                    left: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        food.tag,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      onPressed: onFavorite,
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite
                            ? Colors.redAccent
                            : AppColors.deepTeal,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.goldenOrange,
                            size: 15,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            food.rating.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      food.restaurant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '₹${food.price}',
                            style: const TextStyle(
                              color: AppColors.charcoalBlack,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (quantity == 0)
                          IconButton.filled(
                            onPressed: onAddToCart,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              foregroundColor: AppColors.white,
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.add_rounded),
                          )
                        else
                          Container(
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.teal,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: onDecrement,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 34,
                                    height: 34,
                                  ),
                                  padding: EdgeInsets.zero,
                                  color: AppColors.white,
                                  icon: const Icon(
                                    Icons.remove_rounded,
                                    size: 18,
                                  ),
                                ),
                                Text(
                                  '$quantity',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                IconButton(
                                  onPressed: onIncrement,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 34,
                                    height: 34,
                                  ),
                                  padding: EdgeInsets.zero,
                                  color: AppColors.white,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: AppColors.teal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          food.time,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final int cartCount;
  final ValueChanged<int> onSelected;

  const HomeBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.cartCount,
    required this.onSelected,
  });

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.favorite_border_rounded, 'Favourites'),
    (Icons.shopping_bag_outlined, 'Cart'),
    (Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = selectedIndex == index;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelected(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            item.$1,
                            size: 24,
                            color: selected
                                ? AppColors.teal
                                : AppColors.mutedText,
                          ),
                          if (index == 2 && cartCount > 0)
                            Positioned(
                              right: -9,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.goldenOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$cartCount',
                                  style: const TextStyle(
                                    color: AppColors.charcoalBlack,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: selected
                              ? AppColors.teal
                              : AppColors.mutedText,
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

const Color appMaroon = AppColors.teal;
const Color appDarkMaroon = AppColors.goldenOrange;
const Color appPeach = AppColors.lightTeal;
const Color appCardPeach = AppColors.lightIvory;
const Color appGreen = AppColors.success;
const Color appText = AppColors.charcoalBlack;

// LOCATION HEADER

class LocationHeader extends StatelessWidget {
  final VoidCallback onMenuTap;

  const LocationHeader({super.key, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: appDarkMaroon,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 15),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.white, size: 21),
          const SizedBox(width: 8),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RMZ Futura ›',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Deloitte Dr, Hi-Tech City, Hyderabad, Telangana...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          GestureDetector(
            onTap: onMenuTap,
            child: Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: appDarkMaroon,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.menu, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// TOP SERVICE TABS

class TopServiceTabs extends StatelessWidget {
  final String selectedService;
  final ValueChanged<String> onSelected;

  const TopServiceTabs({
    super.key,
    required this.selectedService,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'name': 'Food', 'emoji': '🍔'},
      {'name': 'Instamart', 'emoji': '🛒'},
      {'name': 'Dineout', 'emoji': '🍲'},
      {'name': 'Scenes', 'emoji': '🎡'},
    ];

    return Container(
      color: appDarkMaroon,
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 0),
      child: Row(
        children: tabs.map((tab) {
          final name = tab['name']!;
          final selected = selectedService == name;

          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(name),
              child: Container(
                height: 76,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: selected ? appMaroon : const Color(0xFF521126),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                    bottom: Radius.circular(8),
                  ),
                  border: Border.all(
                    color: selected ? Colors.white54 : Colors.white12,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(tab['emoji']!, style: const TextStyle(fontSize: 27)),
                    const SizedBox(height: 5),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// FOOD CATEGORY TABS

class FoodCategoryTabs extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const FoodCategoryTabs({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'name': 'All', 'icon': '☷'},
      {'name': 'Store', 'icon': '♟'},
      {'name': 'Offers', 'icon': '◆'},
      {'name': 'Bolt', 'icon': 'ϟ'},
      {'name': 'Gourmet', 'icon': '♜'},
    ];

    return Container(
      color: appMaroon,
      child: Row(
        children: categories.map((category) {
          final name = category['name']!;
          final selected = selectedCategory == name;

          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(name),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${category['icon']} ${name.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// MAIN OFFER BANNER

class OfferBanner extends StatelessWidget {
  final String title;
  final String subtitle;

  const OfferBanner({
    super.key,
    this.title = '80% OFF',
    this.subtitle = 'UP TO ₹160',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 125,
      color: appMaroon,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            left: 12,
            child: Text('🥟', style: TextStyle(fontSize: 55)),
          ),
          const Positioned(
            right: 12,
            child: Text('🥨', style: TextStyle(fontSize: 55)),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFFFC342),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(2, 3),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: appDarkMaroon,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '⏱ Ends In   00:20:40',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// BOLT PROMOTIONAL BANNER

class BoltPromoBanner extends StatelessWidget {
  final VoidCallback onOrderTap;

  const BoltPromoBanner({super.key, required this.onOrderTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF64132C),
        borderRadius: BorderRadius.circular(15),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -5,
            top: 0,
            bottom: 0,
            child: Image.network(
              'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600',
              width: 190,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.fastfood,
                  size: 90,
                  color: Colors.white70,
                );
              },
            ),
          ),

          Positioned(
            left: 15,
            top: 20,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bolt⚡ Food In 15 Mins!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Fresh, hot & crisp\ndelights for you.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onOrderTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'ORDER NOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// FILTER CHIPS

class HomeFilterChips extends StatelessWidget {
  final bool minimumOffer;
  final bool fastDelivery;
  final VoidCallback onOfferTap;
  final VoidCallback onDeliveryTap;

  const HomeFilterChips({
    super.key,
    required this.minimumOffer,
    required this.fastDelivery,
    required this.onOfferTap,
    required this.onDeliveryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1D2B3),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onOfferTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: minimumOffer ? const Color(0xFFFFCBA4) : appCardPeach,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
                  'MIN Rs. 100 OFF',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onDeliveryTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: fastDelivery
                      ? const Color(0xFFFFCBA4)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
                  'FAST DELIVERY',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to slide the multi-color gradient across text smoothly
class _SlidingGradientTransform extends GradientTransform {
  final double percent;

  const _SlidingGradientTransform(this.percent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (percent * 2.0 - 1.0),
      0.0,
      0.0,
    );
  }
}

/// Animated colorful time-based text and badge for Smart Picks
class TimeSlotAnimatedSubtitle extends StatefulWidget {
  final String text;
  final TimeOfDaySlot slot;

  const TimeSlotAnimatedSubtitle({
    super.key,
    required this.text,
    required this.slot,
  });

  @override
  State<TimeSlotAnimatedSubtitle> createState() =>
      _TimeSlotAnimatedSubtitleState();
}

class _TimeSlotAnimatedSubtitleState extends State<TimeSlotAnimatedSubtitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _getGradientColors(TimeOfDaySlot slot) {
    switch (slot) {
      case TimeOfDaySlot.morning:
        return const [
          Color(0xFFE65100), // Deep Amber
          Color(0xFFFF9800), // Vibrant Orange
          Color(0xFF009688), // Fresh Teal
          Color(0xFFFFB300), // Sunshine Yellow
          Color(0xFFE65100), // Loop back
        ];
      case TimeOfDaySlot.afternoon:
        return const [
          Color(0xFFD84315), // Fiery Saffron
          Color(0xFFFF5722), // Vibrant Coral
          Color(0xFFFFA000), // Golden Amber
          Color(0xFFE91E63), // Sunset Pink
          Color(0xFFD84315), // Loop back
        ];
      case TimeOfDaySlot.evening:
        return const [
          Color(0xFF8E24AA), // Sunset Violet
          Color(0xFFFF4081), // Neon Pink
          Color(0xFFFF6E40), // Sunset Orange
          Color(0xFF7C4DFF), // Electric Violet
          Color(0xFF8E24AA), // Loop back
        ];
      case TimeOfDaySlot.night:
        return const [
          Color(0xFF3949AB), // Royal Indigo
          Color(0xFF7C4DFF), // Vivid Violet
          Color(0xFF00B0FF), // Neon Cyan
          Color(0xFFFF4081), // Neon Pink
          Color(0xFF3949AB), // Loop back
        ];
    }
  }

  String _getBadgeLabel(TimeOfDaySlot slot) {
    switch (slot) {
      case TimeOfDaySlot.morning:
        return '☀️ Morning Fresh';
      case TimeOfDaySlot.afternoon:
        return '🍛 Lunch Specials';
      case TimeOfDaySlot.evening:
        return '🌆 Evening Bites';
      case TimeOfDaySlot.night:
        return '🌙 Late Night Cravings';
    }
  }

  Color _getBadgeColor(TimeOfDaySlot slot) {
    switch (slot) {
      case TimeOfDaySlot.morning:
        return const Color(0xFFFF8F00);
      case TimeOfDaySlot.afternoon:
        return const Color(0xFFFF5722);
      case TimeOfDaySlot.evening:
        return const Color(0xFFD81B60);
      case TimeOfDaySlot.night:
        return const Color(0xFF651FFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getGradientColors(widget.slot);
    final badgeColor = _getBadgeColor(widget.slot);
    final badgeLabel = _getBadgeLabel(widget.slot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
        // Badge row with animated pulsing glow
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final pulse =
                0.97 + 0.03 * math.sin(_controller.value * 2 * math.pi);
            final glowOpacity =
                0.20 + 0.15 * math.sin(_controller.value * 2 * math.pi);

            return Transform.scale(
              scale: pulse,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      badgeColor.withOpacity(0.18),
                      badgeColor.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: badgeColor.withOpacity(glowOpacity + 0.25),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withOpacity(glowOpacity * 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        // Colorful Animated Shimmer Text with Sparkle
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                  transform: _SlidingGradientTransform(_controller.value),
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: child,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final sparkleScale =
                      0.85 + 0.25 * math.cos(_controller.value * 2 * math.pi);
                  return Transform.scale(
                    scale: sparkleScale,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: badgeColor,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
