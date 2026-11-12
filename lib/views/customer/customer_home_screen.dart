import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/Appconstants/app_images.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/address_service.dart';
import 'package:yummy_go_application/services/cart_service.dart';
import 'package:yummy_go_application/services/favorite_service.dart';
import 'package:yummy_go_application/services/location_service.dart';
import 'package:yummy_go_application/services/recommendation_service.dart';
import 'package:yummy_go_application/services/resturent_services.dart';
import 'package:yummy_go_application/views/cart_screen.dart';
import 'package:yummy_go_application/views/customer_profile_screen.dart';
import 'package:yummy_go_application/views/favorite_foods_screen.dart';
import 'package:yummy_go_application/views/craving_results_screen.dart';
import 'package:yummy_go_application/views/location_picker_screen.dart';
import 'package:yummy_go_application/views/resturent_menu_screen.dart';

import '../../widgets/active_orders_bar.dart';
import '../../widgets/customer_home_widgets.dart';
import '../../widgets/global_cart_bar.dart';
import '../../widgets/restaurant_conflict_dialog.dart';
import '../../widgets/spin_for_food_dialog.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RestaurantService _restaurantService = RestaurantService();
  final LocationService _locationService = LocationService();
  late final Stream<List<RestaurantModel>> _restaurantsStream;
  final CartService _cartService = CartService();
  final FavoriteService _favoriteService = FavoriteService();
  final RecommendationService _recommendationService = RecommendationService();

  int _selectedNav = 0;
  String? _selectedLocation;
  String _primaryArea = 'Locating...';
  String _secondaryArea = 'Finding nearby restaurants';
  double _userLatitude = 17.4442;
  double _userLongitude = 78.3845;
  bool _locationLoading = true;
  Set<String> _selectedRestaurantIds = {};
  Set<String> _selectedRestaurantNames = {};
  List<RestaurantModel> _cachedRestaurants = [];

  @override
  void initState() {
    super.initState();
    _restaurantsStream = _restaurantService.getRestaurants();
    _initializeCurrentLocation();
  }

  Future<void> _initializeCurrentLocation() async {
    try {
      Position? position;
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            position = await Geolocator.getLastKnownPosition();
            position ??= await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Location service GPS error: $e');
      }

      String? detectedAddress;
      String? primary;
      String? secondary;
      double? lat;
      double? lng;

      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
        try {
          final placemarks = await Geocoding().placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          ).timeout(const Duration(seconds: 2));
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            primary = place.subLocality?.isNotEmpty == true
                ? place.subLocality!
                : (place.locality?.isNotEmpty == true
                    ? place.locality!
                    : (place.name?.isNotEmpty == true
                        ? place.name!
                        : 'Current Location'));
            final secParts = [
              if (place.name != null && place.name != primary) place.name,
              place.locality,
              place.administrativeArea,
              place.postalCode,
            ].whereType<String>().where((p) => p.trim().isNotEmpty);
            secondary = secParts.toSet().join(', ');
            detectedAddress = '$primary, $secondary';
          }
        } catch (e) {
          debugPrint('Reverse geocoding error: $e');
        }
      }

      // If GPS address failed or is empty, try user's saved addresses
      if (detectedAddress == null || detectedAddress.trim().isEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final saved = await AddressService()
                .getDefaultOrFirstAddress(user.uid)
                .timeout(const Duration(seconds: 2));
            if (saved != null && saved.formattedAddress.isNotEmpty) {
              detectedAddress = saved.formattedAddress;
              primary = saved.landmark.isNotEmpty
                  ? saved.landmark
                  : (saved.label.isNotEmpty ? saved.label : 'Saved Address');
              secondary = saved.formattedAddress;
              lat = saved.latitude;
              lng = saved.longitude;
            }
          } catch (e) {
            debugPrint('Saved address error: $e');
          }
        }
      }

      // Final reliable fallback so location is ALWAYS displayed immediately
      primary ??= 'Hitec City';
      secondary ??= 'Cyberabad, Hyderabad 500081';
      detectedAddress ??= '$primary, $secondary';
      lat ??= 17.4442;
      lng ??= 78.3845;

      if (!mounted) return;
      setState(() {
        _userLatitude = lat!;
        _userLongitude = lng!;
        _primaryArea = primary!;
        _secondaryArea = secondary!;
        _selectedLocation = detectedAddress;
        _locationLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _primaryArea = 'Hitec City';
          _secondaryArea = 'Cyberabad, Hyderabad';
          _selectedLocation = 'Hitec City, Hyderabad';
          _userLatitude = 17.4442;
          _userLongitude = 78.3845;
          _locationLoading = false;
        });
      }
    } finally {
      if (mounted && _locationLoading) {
        setState(() => _locationLoading = false);
      }
    }
  }

  String _normalizeLocationText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceAll('hytech', 'hitec')
        .replaceAll('hitech', 'hitec');
  }

  // Fetch food items from Firestore.
  Stream<QuerySnapshot<Map<String, dynamic>>> get _foodStream {
    return _firestore.collection('food_items').snapshots();
  }

  // Convert Firestore food documents into FoodItem objects.
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
            isPopular: _isPopularFoodData(data),
            cuisine: data['cuisine']?.toString() ?? '',
            isAvailable: isAvail,
          );
        })
        .where((food) => food.name.isNotEmpty)
        .toList();
  }

  static const List<CravingOption> _cravings = [
    CravingOption(
      emoji: '🌶️',
      title: 'Spicy',
      imageUrl: AppImages.cravingSpicy,
      keywords: [
        'spicy',
        'chilli',
        'chili',
        'masala',
        'pepper',
        'tandoori',
        'schezwan',
        'tikka',
        'peri peri',
        'curry',
        'mirchi',
        'fiery',
        'vindaloo',
      ],
      excludedKeywords: ['ice cream', 'dessert', 'sweet', 'shake', 'cake', 'brownie'],
    ),
    CravingOption(
      emoji: '🍚',
      title: 'Biryani',
      imageUrl: AppImages.cravingBiryani,
      keywords: [
        'biryani',
        'biriyani',
        'dum',
        'pulao',
        'mandi',
        'khichdi',
      ],
      excludedKeywords: ['price', 'licorice'],
    ),
    CravingOption(
      emoji: '🍗',
      title: 'Crispy',
      imageUrl: AppImages.cravingCrispy,
      keywords: [
        'crispy',
        'fried',
        'crunchy',
        'nugget',
        'nuggets',
        'wings',
        'popcorn',
        'strips',
        'fries',
        'french fries',
        'pakora',
        'samosa',
        'cutlet',
        'roast',
        'tempura',
        'vada',
        'bajji',
        '65',
      ],
    ),
    CravingOption(
      emoji: '🍕',
      title: 'Cheesy',
      imageUrl: AppImages.cravingCheesy,
      keywords: [
        'cheese',
        'cheesy',
        'pizza',
        'pasta',
        'mozzarella',
        'lasagna',
        'garlic bread',
        'macaroni',
        'quesadilla',
        'parmesan',
        'cheddar',
      ],
    ),
    CravingOption(
      emoji: '🥗',
      title: 'Healthy',
      imageUrl: AppImages.cravingHealthy,
      keywords: [
        'salad',
        'healthy',
        'soup',
        'diet',
        'fresh',
        'sprouts',
        'boiled',
        'oats',
        'quinoa',
        'veggie bowl',
        'fruit bowl',
        'steamed',
        'keto',
      ],
      excludedKeywords: ['deep fried', 'heavy cheese'],
    ),
    CravingOption(
      emoji: '🍫',
      title: 'Sweet',
      imageUrl: AppImages.cravingSweet,
      keywords: [
        'sweet',
        'dessert',
        'desserts',
        'ice cream',
        'chocolate',
        'cake',
        'pastry',
        'brownie',
        'halwa',
        'gulab jamun',
        'rasgulla',
        'waffle',
        'pancake',
        'sundae',
        'donut',
        'kheer',
        'pudding',
        'laddu',
        'barfi',
      ],
      excludedKeywords: ['spicy', 'chilli', 'curry'],
    ),
    CravingOption(
      emoji: '🥤',
      title: 'Refreshing',
      imageUrl: AppImages.cravingRefreshing,
      keywords: [
        'refreshing',
        'juice',
        'beverage',
        'beverages',
        'smoothie',
        'smoothies',
        'shake',
        'milkshake',
        'mojito',
        'soda',
        'lassi',
        'cooler',
        'lemonade',
        'mocktail',
        'cold coffee',
        'iced tea',
        'drink',
        'drinks',
        'chai',
        'tea',
        'coffee',
        'latte',
        'frappe',
        'slush',
        'falooda',
        'boba',
        'coconut water',
        'crush',
      ],
      excludedKeywords: [
        'fries',
        'fry',
        'burger',
        'pizza',
        'biryani',
        'curry',
        'roti',
        'naan',
        'noodles',
        'rice',
        'sandwich',
        'roll',
        'wrap',
        'nugget',
        'wings',
        'samosa',
        'pakora',
        'tikka',
        'kebab',
        'momos',
        'manchurian',
        'dosa',
        'idli',
        'meal',
        'thali',
      ],
    ),
    CravingOption(
      emoji: '🍔',
      title: 'Fast Food',
      imageUrl: AppImages.cravingFastFood,
      keywords: [
        'burger',
        'burgers',
        'fast food',
        'fries',
        'french fries',
        'roll',
        'rolls',
        'sandwich',
        'sandwiches',
        'wrap',
        'wraps',
        'nuggets',
        'frankie',
        'snack',
        'hot dog',
        'taco',
        'nachos',
        'wedges',
        'potato bites',
      ],
    ),
  ];

  List<FoodItem> _popularFoods(List<FoodItem> foods) {
    final matches = foods.where((food) => food.isPopular).toList();
    matches.sort(
      (first, second) => second.rating.compareTo(first.rating),
    );
    return matches;
  }

  List<FoodItem> _searchFoods(List<FoodItem> foods, String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    final matches = foods.where((food) {
      final combined =
          '${food.name} ${food.restaurant} ${food.category} ${food.cuisine} ${food.tag} ${food.description}'
              .toLowerCase();
      return combined.contains(q);
    }).toList();

    matches.sort((a, b) => b.rating.compareTo(a.rating));
    return matches;
  }

  List<RestaurantModel> _searchRestaurants(
    List<RestaurantModel> restaurants,
    String query,
  ) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    final matches = restaurants.where((restaurant) {
      if (!restaurant.isApproved) return false;
      final combined =
          '${restaurant.name} ${restaurant.cuisine} ${restaurant.area} ${restaurant.branchName} ${restaurant.address}'
              .toLowerCase();
      return combined.contains(q);
    }).toList();

    // Sort matching restaurants by nearest distance from customer's current GPS location
    matches.sort((a, b) {
      final distA = a.getDistanceInKm(_userLatitude, _userLongitude);
      final distB = b.getDistanceInKm(_userLatitude, _userLongitude);
      return distA.compareTo(distB);
    });
    return matches;
  }

  Widget _buildCravingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.goldenOrange.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('😋', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 8),
              const Text(
                'What are you craving?',
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 122,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _cravings.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final craving = _cravings[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CravingResultsScreen(craving: craving),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 72,
                          width: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.goldenOrange.withOpacity(0.35),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.deepTeal.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.network(
                              craving.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.lightOrange,
                                child: Center(
                                  child: Text(
                                    craving.emoji,
                                    style: const TextStyle(fontSize: 30),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              craving.emoji,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 80,
                      child: Text(
                        craving.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpinForFoodBanner(List<FoodItem> foods) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.deepTeal,
            AppColors.teal,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepTeal.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.teal.withOpacity(0.8),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Text('🎲', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Can't Decide What to Eat?",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Spin and let YummyGo pick for you!',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => SpinForFoodDialog.show(
              context,
              foods: foods,
              onAddToCart: (food) => _addToCart(food),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Spin 🎲',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isPopularFoodData(Map<String, dynamic> data) {
    bool isEnabled(dynamic value) =>
        value == true || value?.toString().toLowerCase() == 'true';

    final tag = data['tag']?.toString().toLowerCase() ?? '';
    return isEnabled(data['isPopular']) ||
        isEnabled(data['isFeatured']) ||
        isEnabled(data['featured']) ||
        isEnabled(data['isBestSeller']) ||
        isEnabled(data['bestseller']) ||
        tag.contains('popular') ||
        tag.contains('best');
  }

  // Open selected restaurant menu.
  void _openRestaurant(
    String restaurantId,
    String restaurantName,
    double rating,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantMenuScreen(
          restaurantId: restaurantId,
          restaurantName: restaurantName,
          rating: rating,
        ),
      ),
    );
  }

  Future<void> _showPopularFoodDetails(FoodItem food) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: Image.network(
                    food.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AppColors.lightTeal,
                      child: Icon(
                        Icons.restaurant_rounded,
                        color: AppColors.teal,
                        size: 56,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                food.name,
                style: const TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                food.restaurant,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _foodDetailChip(food.category),
                  if (food.rating > 0)
                    _foodDetailChip('${food.rating.toStringAsFixed(1)} ★'),
                  _foodDetailChip(food.time),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                food.description.trim().isNotEmpty
                    ? food.description.trim()
                    : 'A popular ${food.category.toLowerCase()} dish from ${food.restaurant}.',
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
                      '₹${food.price}',
                      style: const TextStyle(
                        color: AppColors.charcoalBlack,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _addToCart(food);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.deepTeal,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: const Text('Add to cart'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _foodDetailChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.lightTeal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.deepTeal,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _chooseDeliveryLocation() async {
    try {
      final selected = await Navigator.push<DeliveryLocationSelection>(
        context,
        MaterialPageRoute<DeliveryLocationSelection>(
          builder: (_) =>
              LocationPickerScreen(selectedAddress: _selectedLocation),
        ),
      );

      if (selected != null && mounted) {
        setState(() {
          _locationLoading = false;
          if (selected.address.isNotEmpty) {
            _selectedLocation = selected.address;
            final parts = selected.address.split(',');
            _primaryArea = selected.area.isNotEmpty ? selected.area : parts.first.trim();
            _secondaryArea = parts.length > 1
                ? parts.sublist(1).join(',').trim()
                : 'Hyderabad, Telangana';

            // Resolve coordinates for nearby calculations
            for (final entry in RestaurantModel.knownAreaCoords.entries) {
              if (selected.area.toLowerCase().contains(entry.key) ||
                  selected.address.toLowerCase().contains(entry.key)) {
                _userLatitude = entry.value[0];
                _userLongitude = entry.value[1];
                break;
              }
            }
          }
          _selectedRestaurantIds = selected.restaurantIds;
          _selectedRestaurantNames = selected.restaurantNames;
        });
      }
    } catch (error) {
      _showMessage('Unable to load delivery locations: $error');
    }
  }

  // Add food to individual cart.
  Future<void> _addToCart(FoodItem food) async {
    // Check if restaurant is closed
    final rName = food.restaurant.trim().toLowerCase();
    final rId = food.restaurantId.trim();
    final matchedRestaurant = _cachedRestaurants.where(
      (r) => (rId.isNotEmpty && r.id == rId) || (rName.isNotEmpty && r.name.trim().toLowerCase() == rName),
    ).firstOrNull;
    if (matchedRestaurant != null && !matchedRestaurant.isAvailable) {
      _showMessage('Sorry, ${food.restaurant} is currently closed. Ordering is disabled.');
      return;
    }

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

  // Bottom navigation.
  void _handleNavigation(int index) {
    setState(() => _selectedNav = index);

    switch (index) {
      case 0:
        break;

      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FavoriteFoodsScreen()),
        );
        break;

      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CartScreen()),
        );
        break;

      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        break;
    }
  }

  // Show individual cart.
  void _showCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return StreamBuilder(
          stream: _cartService.cartStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Unable to load cart. Please try again.'),
              );
            }

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final documents = snapshot.data!.docs;

            int subtotal = 0;

            for (final doc in documents) {
              final data = doc.data();
              final price = (data['price'] as num?)?.toInt() ?? 0;
              final quantity = (data['quantity'] as num?)?.toInt() ?? 1;

              subtotal += price * quantity;
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Cart',
                      style: TextStyle(
                        color: AppColors.deepTeal,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (documents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 25),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                color: AppColors.teal,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text('Your cart is empty.'),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: documents.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: AppColors.border),
                          itemBuilder: (context, index) {
                            final doc = documents[index];
                            final data = doc.data();

                            final name = data['foodName']?.toString() ?? '';
                            final price = (data['price'] as num?)?.toInt() ?? 0;
                            final quantity =
                                (data['quantity'] as num?)?.toInt() ?? 1;

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                name,
                                style: const TextStyle(
                                  color: AppColors.deepTeal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '₹$price × $quantity = ₹${price * quantity}',
                              ),
                              trailing: IconButton(
                                onPressed: () async {
                                  try {
                                    await _cartService.removeItem(doc.id);
                                  } catch (e) {
                                    _showMessage(e.toString());
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.error,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (documents.isNotEmpty) ...[
                      const Divider(color: AppColors.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal',
                            style: TextStyle(
                              color: AppColors.deepTeal,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '₹$subtotal',
                            style: const TextStyle(
                              color: AppColors.deepTeal,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _showMessage(
                              'Checkout screen will be connected next.',
                            );
                          },
                          child: const Text('Proceed to Checkout'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Restaurant Card used in both All Restaurants and Search Results
  Widget _buildRestaurantCard(
    RestaurantModel restaurant,
    bool isFavorite,
  ) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: AppColors.deepTeal.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openRestaurant(
          restaurant.id,
          restaurant.name,
          restaurant.rating,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 126,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RestaurantImage(
                    imageUrl: restaurant.imageUrl,
                    restaurantName: restaurant.name,
                    height: 126,
                    width: double.infinity,
                  ),
                  if (!restaurant.isAvailable)
                    Positioned.fill(
                      child: Container(
                        color: AppColors.charcoalBlack.withOpacity(0.65),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.charcoalBlack,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.white.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_clock_rounded, color: AppColors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'CLOSED',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10.5,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x22000000),
                          Colors.transparent,
                          Color(0x99000000),
                        ],
                        stops: [0, 0.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: AppColors.white.withValues(
                        alpha: 0.94,
                      ),
                      shape: const CircleBorder(),
                      child: IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 34,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: isFavorite
                            ? 'Remove restaurant from favorites'
                            : 'Add restaurant to favorites',
                        onPressed: () async {
                          try {
                            await _favoriteService
                                .toggleRestaurantFavorite(
                                  restaurant,
                                );
                          } catch (error) {
                            _showMessage(
                              'Unable to update favorite: $error',
                            );
                          }
                        },
                        icon: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFavorite
                              ? AppColors.error
                              : AppColors.deepTeal,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  if (restaurant.offerTitle.isNotEmpty)
                    Positioned(
                      left: 7,
                      bottom: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.deepTeal,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          restaurant.offerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 7,
                    bottom: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        restaurant.getDistanceText(_userLatitude, _userLongitude).isNotEmpty
                            ? '${restaurant.getDistanceText(_userLatitude, _userLongitude)} · ${restaurant.deliveryTime}'
                            : restaurant.deliveryTime,
                        style: const TextStyle(
                          color: AppColors.deepTeal,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepTeal,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.teal,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          restaurant.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (restaurant.getDistanceText(_userLatitude, _userLongitude).isNotEmpty) ...[
                          const Text(
                            ' · ',
                            style: TextStyle(
                              color: AppColors.mutedText,
                            ),
                          ),
                          Text(
                            restaurant.getDistanceText(_userLatitude, _userLongitude),
                            style: const TextStyle(
                              color: AppColors.teal,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        if (restaurant.area.isNotEmpty) ...[
                          const Text(
                            ' · ',
                            style: TextStyle(
                              color: AppColors.mutedText,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              restaurant.area,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      restaurant.cuisine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 10,
                      ),
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

  // Load available restaurants from Firestore (only approved restaurants with available menus).
  Widget _buildAllRestaurants(
    List<FoodItem> allFoods,
    List<RestaurantModel> allRestaurants,
    Set<String> favoriteRestaurantIds,
  ) {
    // Collect restaurant IDs and names that have at least one available food item
    final approvedRestaurantIdsWithMenu = allFoods
        .where((f) => f.isAvailable && f.restaurantId.isNotEmpty)
        .map((f) => f.restaurantId)
        .toSet();

    final approvedRestaurantNamesWithMenu = allFoods
        .where((f) => f.isAvailable && f.restaurant.isNotEmpty)
        .map((f) => f.restaurant.trim().toLowerCase())
        .toSet();

    // ONLY approved restaurants with available menus are visible to customers!
    final approvedRestaurants = allRestaurants.where((restaurant) {
      if (!restaurant.isApproved) return false;
      final hasMenu = approvedRestaurantIdsWithMenu.contains(restaurant.id) ||
          approvedRestaurantNamesWithMenu.contains(restaurant.name.trim().toLowerCase());
      return hasMenu;
    }).toList();

    // Dynamically sort nearby restaurants by proximity from user location (closest first)
    approvedRestaurants.sort((a, b) {
      final distA = a.getDistanceInKm(_userLatitude, _userLongitude);
      final distB = b.getDistanceInKm(_userLatitude, _userLongitude);
      return distA.compareTo(distB);
    });

    if (approvedRestaurants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(25),
        child: Center(
          child: Text(
            'No restaurants with menus available near $_primaryArea yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: approvedRestaurants.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 224,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final restaurant = approvedRestaurants[index];
        final isFavorite = favoriteRestaurantIds.contains(restaurant.id);
        return _buildRestaurantCard(restaurant, isFavorite);
      },
    );
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

  Widget _buildSmartPicksSection({
    required List<FoodItem> allFoods,
    required Set<String> favoriteIds,
    required Map<String, int> cartQuantities,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    final subtitle = RecommendationService.getTimeSlotSubtitle();

    return FutureBuilder<List<FoodItem>>(
      future: _recommendationService.getSmartPicks(
        userId: user?.uid,
        candidateFoods: allFoods,
        limit: 10,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 90,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final picks = snapshot.data ?? [];
        final query = _searchController.text.trim().toLowerCase();

        final filteredPicks = query.isEmpty
            ? picks
            : picks.where((food) {
                return food.name.toLowerCase().contains(query) ||
                    food.restaurant.toLowerCase().contains(query) ||
                    food.category.toLowerCase().contains(query) ||
                    food.cuisine.toLowerCase().contains(query);
              }).toList();

        if (filteredPicks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.limeGreen.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.deepTeal,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Smart Picks for You',
                        style: TextStyle(
                          color: AppColors.deepTeal,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  TimeSlotAnimatedSubtitle(
                    text: subtitle,
                    slot: RecommendationService.getTimeSlot(),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 295,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: filteredPicks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final food = filteredPicks[index];
                  final quantity = cartQuantities[food.id] ?? 0;

                  return SizedBox(
                    width: 220,
                    child: FoodCard(
                      food: food,
                      onTap: () => _showPopularFoodDetails(food),
                      isFavorite: favoriteIds.contains(food.id),
                      quantity: quantity,
                      onFavorite: () => _toggleFavoriteFood(food),
                      onAddToCart: () => _addToCart(food),
                      onIncrement: () => _adjustFoodQuantity(food, 1),
                      onDecrement: () => _adjustFoodQuantity(food, -1),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      body: SafeArea(
        child: StreamBuilder<List<RestaurantModel>>(
          stream: _restaurantsStream,
          builder: (context, restaurantSnapshot) {
            final allRestaurants = restaurantSnapshot.data ?? _cachedRestaurants;
            if (restaurantSnapshot.hasData && restaurantSnapshot.data != null) {
              _cachedRestaurants = restaurantSnapshot.data!;
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _foodStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Unable to load food items: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final foods = _convertFoods(snapshot.data?.docs ?? []);
                final popularFoods = _popularFoods(foods);
                final searchQuery = _searchController.text.trim();
                final isSearching = searchQuery.isNotEmpty;
                final searchFoods =
                    isSearching ? _searchFoods(foods, searchQuery) : <FoodItem>[];
                final searchRestaurants =
                    isSearching ? _searchRestaurants(allRestaurants, searchQuery) : <RestaurantModel>[];

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _favoriteService.favoriteStream(),
                  builder: (context, favoriteSnapshot) {
                    final favoriteDocs = favoriteSnapshot.data?.docs;
                    final favoriteIds = <String>{
                      if (favoriteDocs != null)
                        for (final doc in favoriteDocs) doc.id,
                    };
                    final favoriteRestaurantIds = <String>{
                      if (favoriteDocs != null)
                        for (final favorite in favoriteDocs)
                          if (favorite.data()['type'] == 'restaurant')
                            favorite.data()['restaurantId']?.toString() ??
                                favorite.id.replaceFirst('restaurant_', ''),
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

                        return CustomScrollView(
                          slivers: [
                            // Swiggy-style Live Delivery Location SliverAppBar
                            SliverAppBar(
                              pinned: false,
                              floating: true,
                              elevation: 0,
                              scrolledUnderElevation: 0,
                              backgroundColor: AppColors.warmIvory,
                              automaticallyImplyLeading: false,
                          toolbarHeight: 74,
                          titleSpacing: 16,
                          title: InkWell(
                            onTap: _chooseDeliveryLocation,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppColors.lightTeal,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.location_on_rounded,
                                      color: AppColors.teal,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _locationLoading
                                                    ? 'Locating...'
                                                    : _primaryArea,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.deepTeal,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: AppColors.deepTeal,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _locationLoading
                                              ? 'Detecting current address...'
                                              : _secondaryArea,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.mutedText,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfileScreen(),
                                  ),
                                );
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.white,
                                foregroundColor: AppColors.deepTeal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                              ),
                              icon: const Icon(Icons.person_outline_rounded, size: 22),
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),

                        // Search.
                        SliverToBoxAdapter(
                          child: HomeSearchBar(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            onClear: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                        ),

                        if (isSearching) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.search_rounded,
                                          color: AppColors.teal, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Results for "$searchQuery"',
                                        style: const TextStyle(
                                          color: AppColors.deepTeal,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${searchRestaurants.length + searchFoods.length} found',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (searchRestaurants.isEmpty && searchFoods.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 48),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: const BoxDecoration(
                                          color: AppColors.lightOrange,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.search_off_rounded,
                                          size: 40,
                                          color: AppColors.goldenOrange,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No results found for "$searchQuery" 🔍',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.deepTeal,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'We couldn\'t find any restaurants or dishes matching your search.\nTry searching for biryani, pizza, burger, Chinese, or check your spelling.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.mutedText,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            if (searchRestaurants.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.storefront_rounded,
                                          color: AppColors.teal, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Restaurants (${searchRestaurants.length})',
                                        style: const TextStyle(
                                          color: AppColors.deepTeal,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Text(
                                        'Closest first',
                                        style: TextStyle(
                                          color: AppColors.mutedText,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                sliver: SliverGrid(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final restaurant = searchRestaurants[index];
                                      final isFavorite = favoriteRestaurantIds.contains(restaurant.id);
                                      return _buildRestaurantCard(restaurant, isFavorite);
                                    },
                                    childCount: searchRestaurants.length,
                                  ),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 220,
                                    mainAxisExtent: 224,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                  ),
                                ),
                              ),
                            ],
                            if (searchFoods.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.restaurant_menu_rounded,
                                          color: AppColors.teal, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Dishes & Food Items (${searchFoods.length})',
                                        style: const TextStyle(
                                          color: AppColors.deepTeal,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                sliver: SliverGrid(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final food = searchFoods[index];
                                    final quantity =
                                        cartQuantities[food.id] ?? 0;
                                    return FoodCard(
                                      food: food,
                                      onTap: () =>
                                          _showPopularFoodDetails(food),
                                      isFavorite:
                                          favoriteIds.contains(food.id),
                                      quantity: quantity,
                                      onFavorite: () =>
                                          _toggleFavoriteFood(food),
                                      onAddToCart: () => _addToCart(food),
                                      onIncrement: () =>
                                          _adjustFoodQuantity(food, 1),
                                      onDecrement: () =>
                                          _adjustFoodQuantity(food, -1),
                                    );
                                  }, childCount: searchFoods.length),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 260,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 14,
                                    mainAxisExtent: 295,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ] else ...[
                          // Promo banner.
                          SliverToBoxAdapter(
                            child: HomePromoBanner(
                              onTap: () {
                                _showMessage(
                                    'Connect your offers screen here.');
                              },
                            ),
                          ),

                          // 😋 Restored Cravings Section!
                          SliverToBoxAdapter(
                            child: _buildCravingSection(),
                          ),

                          // ✨ Smart Picks for You section
                          SliverToBoxAdapter(
                            child: _buildSmartPicksSection(
                              allFoods: foods,
                              favoriteIds: favoriteIds,
                              cartQuantities: cartQuantities,
                            ),
                          ),

                          // 🎲 Spin for Food Banner
                          SliverToBoxAdapter(
                            child: _buildSpinForFoodBanner(foods),
                          ),

                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 16, 20, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    ' Top Restaurants To Explore',
                                    style: TextStyle(
                                      color: AppColors.deepTeal,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.near_me_rounded,
                                        size: 15,
                                        color: AppColors.teal,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Delivering to $_primaryArea',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.mutedText,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _buildAllRestaurants(
                              foods,
                              allRestaurants,
                              favoriteRestaurantIds,
                            ),
                          ),

                          SliverToBoxAdapter(
                            child: HomeSectionHeader(
                              title: 'Popular items',
                              subtitle: 'Most loved dishes picked for you',
                              onViewAll: () {},
                            ),
                          ),

                          if (popularFoods.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(25),
                                child: Center(
                                  child: Text(
                                    'No popular items found right now.',
                                    style:
                                        TextStyle(color: AppColors.mutedText),
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final food = popularFoods[index];
                                  final quantity =
                                      cartQuantities[food.id] ?? 0;
                                  return FoodCard(
                                    food: food,
                                    onTap: () =>
                                        _showPopularFoodDetails(food),
                                    isFavorite:
                                        favoriteIds.contains(food.id),
                                    quantity: quantity,
                                    onFavorite: () =>
                                        _toggleFavoriteFood(food),
                                    onAddToCart: () => _addToCart(food),
                                    onIncrement: () =>
                                        _adjustFoodQuantity(food, 1),
                                    onDecrement: () =>
                                        _adjustFoodQuantity(food, -1),
                                  );
                                }, childCount: popularFoods.length),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 260,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 14,
                                  mainAxisExtent: 295,
                                ),
                              ),
                            ),
                        ],

                        // Footer.
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Center(
                      child: Text(
                        '♥ Made with love by YummyGo',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 11,
                        ),
                      ),
                    ),
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
),

      // Floating "🎲 Spin for Food" button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => SpinForFoodDialog.show(context),
        backgroundColor: AppColors.teal,
        foregroundColor: AppColors.white,
        elevation: 4,
        icon: const Text('🎲', style: TextStyle(fontSize: 18)),
        label: const Text(
          'Spin for Food',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Bottom navigation with Active Orders Bar & Global Cart Bar
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ActiveOrdersBar(),
          const GlobalCartBar(),
          HomeBottomNavigation(
            selectedIndex: _selectedNav,
            cartCount: 0,
            onSelected: _handleNavigation,
          ),
        ],
      ),
    );
  }
}
