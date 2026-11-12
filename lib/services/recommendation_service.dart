import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/widgets/customer_home_widgets.dart';

/// Configurable weights for recommendation scoring (Total = 100).
class RecommendationWeights {
  final double preferredCuisineWeight;
  final double previousOrderWeight;
  final double favoriteRestaurantWeight;
  final double timeOfDayWeight;

  const RecommendationWeights({
    this.preferredCuisineWeight = 30.0,
    this.previousOrderWeight = 30.0,
    this.favoriteRestaurantWeight = 20.0,
    this.timeOfDayWeight = 20.0,
  });
}

/// Time of day categories for context-aware food discovery.
enum TimeOfDaySlot { morning, afternoon, evening, night }

/// Cached user context to avoid repeated Firestore reads on screen rebuilds.
class _UserRecommendationContext {
  final String userId;
  final Set<String> preferredCuisines;
  final Set<String> favoriteRestaurantIds;
  final Set<String> favoriteRestaurantNames;
  final Set<String> orderedItemIds;
  final Set<String> orderedItemNames;
  final Set<String> orderedCategories;
  final Set<String> orderedRestaurantIds;
  final Set<String> orderedRestaurantNames;
  final DateTime cachedAt;

  const _UserRecommendationContext({
    required this.userId,
    required this.preferredCuisines,
    required this.favoriteRestaurantIds,
    required this.favoriteRestaurantNames,
    required this.orderedItemIds,
    required this.orderedItemNames,
    required this.orderedCategories,
    required this.orderedRestaurantIds,
    required this.orderedRestaurantNames,
    required this.cachedAt,
  });

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > const Duration(minutes: 3);
}

/// Rule-based recommendation engine for YummyGo Smart Picks.
class RecommendationService {
  final FirebaseFirestore _firestore;
  final RecommendationWeights weights;

  // In-memory cache for user recommendation context
  _UserRecommendationContext? _cachedContext;

  RecommendationService({
    FirebaseFirestore? firestore,
    this.weights = const RecommendationWeights(),
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Determines the current time-of-day slot based on device hour.
  static TimeOfDaySlot getTimeSlot([DateTime? now]) {
    final current = now ?? DateTime.now();
    final hour = current.hour;

    if (hour >= 5 && hour < 12) {
      return TimeOfDaySlot.morning;
    } else if (hour >= 12 && hour < 17) {
      return TimeOfDaySlot.afternoon;
    } else if (hour >= 17 && hour < 21) {
      return TimeOfDaySlot.evening;
    } else {
      return TimeOfDaySlot.night;
    }
  }

  /// Human-readable title/subtitle for the current time-of-day slot.
  static String getTimeSlotSubtitle([DateTime? now]) {
    final slot = getTimeSlot(now);
    switch (slot) {
      case TimeOfDaySlot.morning:
        return 'Curated breakfast & morning bites picked for you';
      case TimeOfDaySlot.afternoon:
        return 'Handpicked lunch & midday cravings for your taste';
      case TimeOfDaySlot.evening:
        return 'Evening snacks & quick treats tailored for you';
      case TimeOfDaySlot.night:
        return 'Late night dinners & comfort food just for you';
    }
  }

  /// Keywords associated with each time-of-day slot for dish and category matching.
  static const Map<TimeOfDaySlot, List<String>> _timeSlotKeywords = {
    TimeOfDaySlot.morning: [
      'breakfast',
      'idli',
      'dosa',
      'poha',
      'sandwich',
      'upma',
      'vada',
      'tea',
      'coffee',
      'paratha',
      'bakery',
      'south indian',
      'toast',
      'omelette',
    ],
    TimeOfDaySlot.afternoon: [
      'meals',
      'biryani',
      'rice',
      'thali',
      'lunch',
      'curry',
      'roti',
      'north indian',
      'south indian',
      'pulao',
      'dal',
      'paneer',
      'chicken',
      'fish',
    ],
    TimeOfDaySlot.evening: [
      'snacks',
      'pizza',
      'burger',
      'rolls',
      'fries',
      'chaat',
      'sandwich',
      'fast food',
      'beverages',
      'tea',
      'coffee',
      'shake',
      'momos',
      'samosa',
      'sides',
      'wrap',
    ],
    TimeOfDaySlot.night: [
      'biryani',
      'pizza',
      'chinese',
      'fast food',
      'dinner',
      'burger',
      'noodles',
      'fried rice',
      'rolls',
      'curry',
      'dessert',
      'ice cream',
      'kebab',
    ],
  };

  /// Invalidate cache when user updates favorites, places an order, or logs out.
  void clearCache() {
    _cachedContext = null;
  }

  /// Fetch user profile preferences, favorite restaurants, and past order history.
  Future<_UserRecommendationContext> _loadUserContext(String? userId) async {
    if (userId == null || userId.trim().isEmpty) {
      return _UserRecommendationContext(
        userId: '',
        preferredCuisines: {},
        favoriteRestaurantIds: {},
        favoriteRestaurantNames: {},
        orderedItemIds: {},
        orderedItemNames: {},
        orderedCategories: {},
        orderedRestaurantIds: {},
        orderedRestaurantNames: {},
        cachedAt: DateTime.now(),
      );
    }

    if (_cachedContext != null &&
        _cachedContext!.userId == userId &&
        !_cachedContext!.isExpired) {
      return _cachedContext!;
    }

    final preferredCuisines = <String>{};
    final favoriteRestaurantIds = <String>{};
    final favoriteRestaurantNames = <String>{};
    final orderedItemIds = <String>{};
    final orderedItemNames = <String>{};
    final orderedCategories = <String>{};
    final orderedRestaurantIds = <String>{};
    final orderedRestaurantNames = <String>{};

    try {
      // 1. Read user document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};

        // Preferred cuisine (string or list)
        final pref = data['preferredCuisine'];
        if (pref is String && pref.trim().isNotEmpty) {
          preferredCuisines.add(pref.trim().toLowerCase());
        }
        final prefs = data['preferredCuisines'];
        if (prefs is List) {
          for (final item in prefs) {
            if (item != null && item.toString().trim().isNotEmpty) {
              preferredCuisines.add(item.toString().trim().toLowerCase());
            }
          }
        }

        // Favorite restaurants in user document
        final favs = data['favoriteRestaurants'];
        if (favs is List) {
          for (final f in favs) {
            if (f != null && f.toString().trim().isNotEmpty) {
              favoriteRestaurantIds.add(f.toString().trim().toLowerCase());
            }
          }
        }
      }

      // 2. Read favorites subcollection for restaurant favorites
      final favSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();

      for (final doc in favSnapshot.docs) {
        final d = doc.data();
        final type = d['type']?.toString();
        final restId = (d['restaurantId'] ?? d['restaurant_id'])?.toString();
        final restName = (d['name'] ?? d['restaurantName'])?.toString();

        if (type == 'restaurant' || restId != null) {
          if (restId != null && restId.isNotEmpty) {
            favoriteRestaurantIds.add(restId.trim().toLowerCase());
          }
          final docRestId = doc.id.replaceFirst('restaurant_', '');
          favoriteRestaurantIds.add(docRestId.trim().toLowerCase());
          if (restName != null && restName.isNotEmpty) {
            favoriteRestaurantNames.add(restName.trim().toLowerCase());
          }
        }
      }

      // 3. Read previous orders (limit to recent 25 orders to preserve Spark plan quotas)
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .limit(25)
          .get();

      for (final doc in ordersSnapshot.docs) {
        final order = OrderModel.fromFirestore(doc);
        if (order.restaurantId.isNotEmpty) {
          orderedRestaurantIds.add(order.restaurantId.trim().toLowerCase());
        }
        if (order.restaurantName.isNotEmpty) {
          orderedRestaurantNames.add(order.restaurantName.trim().toLowerCase());
        }

        for (final item in order.items) {
          if (item.id.isNotEmpty) {
            orderedItemIds.add(item.id.trim().toLowerCase());
          }
          if (item.name.isNotEmpty) {
            final nameLower = item.name.trim().toLowerCase();
            orderedItemNames.add(nameLower);

            // Extract category hints from item names (e.g. Biryani, Pizza, Burger, Dosa)
            for (final cat in ['biryani', 'pizza', 'burger', 'dosa', 'meals', 'thali', 'sandwich', 'noodles', 'fries', 'rolls', 'curry']) {
              if (nameLower.contains(cat)) {
                orderedCategories.add(cat);
              }
            }
          }
        }
      }
    } catch (_) {
      // Gracefully continue with available data if any read encounters an issue
    }

    final context = _UserRecommendationContext(
      userId: userId,
      preferredCuisines: preferredCuisines,
      favoriteRestaurantIds: favoriteRestaurantIds,
      favoriteRestaurantNames: favoriteRestaurantNames,
      orderedItemIds: orderedItemIds,
      orderedItemNames: orderedItemNames,
      orderedCategories: orderedCategories,
      orderedRestaurantIds: orderedRestaurantIds,
      orderedRestaurantNames: orderedRestaurantNames,
      cachedAt: DateTime.now(),
    );

    _cachedContext = context;
    return context;
  }

  /// Computes personalized Smart Picks recommendations.
  ///
  /// [candidateFoods]: Optional list of available food items (e.g. from an existing stream).
  /// If omitted or empty, food items will be fetched from the `food_items` collection.
  /// [restaurants]: Optional list of restaurants to map cuisines and verify availability.
  /// [currentTime]: Optional custom time for testing or deterministic calculations.
  /// [limit]: Maximum number of recommended items to return.
  Future<List<FoodItem>> getSmartPicks({
    required String? userId,
    List<FoodItem>? candidateFoods,
    List<RestaurantModel>? restaurants,
    DateTime? currentTime,
    int limit = 10,
  }) async {
    // 1. Obtain user context
    final userContext = await _loadUserContext(userId);

    // 2. Obtain candidate food items
    List<FoodItem> items = candidateFoods ?? [];
    if (items.isEmpty) {
      try {
        final snapshot = await _firestore.collection('food_items').get();
        items = snapshot.docs.map((doc) {
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
            isPopular: data['isPopular'] == true ||
                data['isFeatured'] == true ||
                data['isBestSeller'] == true,
            cuisine: data['cuisine']?.toString() ?? '',
            isAvailable: isAvail,
          );
        }).toList();
      } catch (_) {
        return [];
      }
    }

    if (items.isEmpty) return [];

    // Filter out unavailable food items
    final availableItems = items.where((item) => item.isAvailable).toList();
    if (availableItems.isEmpty) return [];

    // Map restaurants for cuisine lookup and availability
    final restaurantMap = <String, RestaurantModel>{};
    if (restaurants != null) {
      for (final r in restaurants) {
        restaurantMap[r.id.toLowerCase()] = r;
        restaurantMap[r.name.trim().toLowerCase()] = r;
      }
    }

    // Filter out items belonging to restaurants explicitly marked unavailable
    final validItems = availableItems.where((item) {
      final rById = restaurantMap[item.restaurantId.toLowerCase()];
      if (rById != null && !rById.isAvailable) return false;
      final rByName = restaurantMap[item.restaurant.trim().toLowerCase()];
      if (rByName != null && !rByName.isAvailable) return false;
      return true;
    }).toList();

    if (validItems.isEmpty) return [];

    // 3. Calculate recommendation score for each item
    final timeSlot = getTimeSlot(currentTime);
    final timeKeywords = _timeSlotKeywords[timeSlot] ?? const [];

    final scoredItems = <FoodItem>[];

    for (final item in validItems) {
      final score = _calculateScore(
        item: item,
        userContext: userContext,
        restaurantMap: restaurantMap,
        timeKeywords: timeKeywords,
      );

      scoredItems.add(item.copyWith(recommendationScore: score));
    }

    // 4. Sort items by score descending with smart tie-breakers
    scoredItems.sort((a, b) {
      // Primary: Recommendation score descending
      final scoreComparison =
          b.recommendationScore.compareTo(a.recommendationScore);
      if (scoreComparison != 0) return scoreComparison;

      // Secondary: Popularity flag
      final aPop = a.isPopular ? 1 : 0;
      final bPop = b.isPopular ? 1 : 0;
      if (aPop != bPop) return bPop.compareTo(aPop);

      // Tertiary: Highest rating
      final ratingComparison = b.rating.compareTo(a.rating);
      if (ratingComparison != 0) return ratingComparison;

      // Quaternary: Lowest price
      return a.price.compareTo(b.price);
    });

    return scoredItems.take(limit).toList();
  }

  /// Calculates a single item's recommendation score out of 100.
  double _calculateScore({
    required FoodItem item,
    required _UserRecommendationContext userContext,
    required Map<String, RestaurantModel> restaurantMap,
    required List<String> timeKeywords,
  }) {
    double totalScore = 0.0;

    final itemNameLower = item.name.trim().toLowerCase();
    final itemCategoryLower = item.category.trim().toLowerCase();
    final itemCuisineLower = item.cuisine.trim().toLowerCase();
    final restIdLower = item.restaurantId.trim().toLowerCase();
    final restNameLower = item.restaurant.trim().toLowerCase();

    // Determine effective cuisine (from item or restaurant)
    String effectiveCuisine = itemCuisineLower;
    if (effectiveCuisine.isEmpty) {
      final rest = restaurantMap[restIdLower] ?? restaurantMap[restNameLower];
      if (rest != null && rest.cuisine.isNotEmpty) {
        effectiveCuisine = rest.cuisine.trim().toLowerCase();
      }
    }

    // -------------------------------------------------------------
    // Factor 1: Preferred Cuisine Match (Max: 30)
    // -------------------------------------------------------------
    if (userContext.preferredCuisines.isNotEmpty) {
      bool cuisineMatches = false;
      for (final pref in userContext.preferredCuisines) {
        if (effectiveCuisine.contains(pref) ||
            pref.contains(effectiveCuisine) ||
            itemCategoryLower.contains(pref) ||
            itemNameLower.contains(pref)) {
          cuisineMatches = true;
          break;
        }
      }

      if (cuisineMatches) {
        totalScore += weights.preferredCuisineWeight;
      }
    }

    // -------------------------------------------------------------
    // Factor 2: Previous Orders Match (Max: 30)
    // -------------------------------------------------------------
    double orderScore = 0.0;

    // Direct food item match (user previously ordered this exact dish)
    final itemIdLower = item.id.trim().toLowerCase();
    final previouslyOrderedItem =
        userContext.orderedItemIds.contains(itemIdLower) ||
        userContext.orderedItemNames.contains(itemNameLower);

    if (previouslyOrderedItem) {
      orderScore = weights.previousOrderWeight;
    } else {
      // Category or cuisine match from past orders
      bool categoryMatched = false;
      for (final cat in userContext.orderedCategories) {
        if (itemCategoryLower.contains(cat) ||
            itemNameLower.contains(cat) ||
            effectiveCuisine.contains(cat)) {
          categoryMatched = true;
          break;
        }
      }

      if (categoryMatched) {
        orderScore = weights.previousOrderWeight * 0.85; // 25.5 pts
      } else if (userContext.orderedRestaurantIds.contains(restIdLower) ||
          userContext.orderedRestaurantNames.contains(restNameLower)) {
        // Previously ordered from this same restaurant
        orderScore = weights.previousOrderWeight * 0.60; // 18 pts
      }
    }

    totalScore += orderScore.clamp(0.0, weights.previousOrderWeight);

    // -------------------------------------------------------------
    // Factor 3: Favorite Restaurant Match (Max: 20)
    // -------------------------------------------------------------
    final isFavoriteRestaurant =
        userContext.favoriteRestaurantIds.contains(restIdLower) ||
        userContext.favoriteRestaurantNames.contains(restNameLower);

    if (isFavoriteRestaurant) {
      totalScore += weights.favoriteRestaurantWeight;
    }

    // -------------------------------------------------------------
    // Factor 4: Time of Day Match (Max: 20)
    // -------------------------------------------------------------
    bool timeMatches = false;
    final itemDescLower = item.description.trim().toLowerCase();

    for (final keyword in timeKeywords) {
      if (itemCategoryLower.contains(keyword) ||
          itemNameLower.contains(keyword) ||
          effectiveCuisine.contains(keyword) ||
          itemDescLower.contains(keyword)) {
        timeMatches = true;
        break;
      }
    }

    if (timeMatches) {
      totalScore += weights.timeOfDayWeight;
    }

    // Return total score (capped at 100.0)
    return totalScore.clamp(0.0, 100.0);
  }
}

