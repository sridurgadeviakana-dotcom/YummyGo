import 'package:flutter_test/flutter_test.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/recommendation_service.dart';
import 'package:yummy_go_application/widgets/customer_home_widgets.dart';

void main() {
  group('RecommendationService TimeOfDay tests', () {
    test('identifies morning slot correctly (05:00 - 11:59)', () {
      final morning = DateTime(2026, 11, 6, 8, 30);
      expect(RecommendationService.getTimeSlot(morning), TimeOfDaySlot.morning);
      expect(
        RecommendationService.getTimeSlotSubtitle(morning),
        contains('breakfast'),
      );
    });

    test('identifies afternoon slot correctly (12:00 - 16:59)', () {
      final afternoon = DateTime(2026, 11, 6, 13, 15);
      expect(
        RecommendationService.getTimeSlot(afternoon),
        TimeOfDaySlot.afternoon,
      );
      expect(
        RecommendationService.getTimeSlotSubtitle(afternoon),
        contains('lunch'),
      );
    });

    test('identifies evening slot correctly (17:00 - 20:59)', () {
      final evening = DateTime(2026, 11, 6, 18, 45);
      expect(RecommendationService.getTimeSlot(evening), TimeOfDaySlot.evening);
      expect(
        RecommendationService.getTimeSlotSubtitle(evening),
        contains('Evening snacks'),
      );
    });

    test('identifies night slot correctly (21:00 - 04:59)', () {
      final night = DateTime(2026, 11, 6, 22, 10);
      final earlyHours = DateTime(2026, 11, 6, 2, 30);
      expect(RecommendationService.getTimeSlot(night), TimeOfDaySlot.night);
      expect(
        RecommendationService.getTimeSlot(earlyHours),
        TimeOfDaySlot.night,
      );
      expect(
        RecommendationService.getTimeSlotSubtitle(night),
        contains('Late night'),
      );
    });
  });

  group('Recommendation Scoring tests', () {
    final biryaniItem = FoodItem(
      id: 'food-biryani',
      name: 'Chicken Dum Biryani',
      restaurantId: 'rest-paradise',
      restaurant: 'Paradise Biryani',
      price: 350,
      rating: 4.8,
      time: '30 min',
      category: 'Biryani',
      image: 'https://example.com/biryani.jpg',
      tag: 'Bestseller',
      cuisine: 'Biryani',
      isPopular: true,
      isAvailable: true,
    );

    final dosaItem = FoodItem(
      id: 'food-dosa',
      name: 'Masala Dosa',
      restaurantId: 'rest-chutneys',
      restaurant: 'Chutneys',
      price: 120,
      rating: 4.6,
      time: '15 min',
      category: 'Breakfast',
      image: 'https://example.com/dosa.jpg',
      tag: 'Popular',
      cuisine: 'South Indian',
      isPopular: true,
      isAvailable: true,
    );

    final pizzaItem = FoodItem(
      id: 'food-pizza',
      name: 'Farmhouse Pizza',
      restaurantId: 'rest-pizza-hut',
      restaurant: 'Pizza Hut',
      price: 399,
      rating: 4.3,
      time: '25 min',
      category: 'Pizzas',
      image: 'https://example.com/pizza.jpg',
      tag: '',
      cuisine: 'Pizza',
      isPopular: false,
      isAvailable: true,
    );

    final unavailableItem = FoodItem(
      id: 'food-unavailable',
      name: 'Mutton Biryani',
      restaurantId: 'rest-paradise',
      restaurant: 'Paradise Biryani',
      price: 499,
      rating: 4.9,
      time: '30 min',
      category: 'Biryani',
      image: 'https://example.com/mutton.jpg',
      tag: '',
      cuisine: 'Biryani',
      isPopular: false,
      isAvailable: false,
    );

    final service = RecommendationService();

    test('cold start: returns available items for new user with no history', () async {
      final morningTime = DateTime(2026, 11, 6, 8, 30);
      final picks = await service.getSmartPicks(
        userId: null,
        candidateFoods: [biryaniItem, dosaItem, pizzaItem, unavailableItem],
        currentTime: morningTime,
      );

      // Unavailable items must be filtered out
      expect(picks.any((item) => item.id == 'food-unavailable'), isFalse);
      expect(picks.isNotEmpty, isTrue);

      // In the morning, Masala Dosa matches the morning slot keywords (+20)
      expect(picks.first.id, 'food-dosa');
      expect(picks.first.recommendationScore, 20.0);
    });

    test('afternoon recommendations prioritize biryani and lunch items', () async {
      final afternoonTime = DateTime(2026, 11, 6, 13, 0);
      final picks = await service.getSmartPicks(
        userId: null,
        candidateFoods: [biryaniItem, dosaItem, pizzaItem],
        currentTime: afternoonTime,
      );

      // In afternoon, Biryani matches afternoon keywords ('biryani') (+20)
      expect(picks.first.id, 'food-biryani');
      expect(picks.first.recommendationScore, 20.0);
    });

    test('filters out items from unavailable restaurants', () async {
      final closedRestaurant = RestaurantModel(
        id: 'rest-closed',
        name: 'Closed Kitchen',
        branchName: 'Main',
        cuisine: 'Indian',
        imageUrl: '',
        rating: 4.0,
        deliveryTime: '30 min',
        isAvailable: false,
      );

      final closedItem = FoodItem(
        id: 'food-closed',
        name: 'Dal Makhani',
        restaurantId: 'rest-closed',
        restaurant: 'Closed Kitchen',
        price: 200,
        rating: 4.5,
        time: '20 min',
        category: 'Meals',
        image: '',
        tag: '',
        cuisine: 'Indian',
        isAvailable: true,
      );

      final picks = await service.getSmartPicks(
        userId: null,
        candidateFoods: [biryaniItem, closedItem],
        restaurants: [closedRestaurant],
      );

      expect(picks.any((item) => item.id == 'food-closed'), isFalse);
    });

    test('custom weights are honored', () {
      const customWeights = RecommendationWeights(
        preferredCuisineWeight: 40.0,
        previousOrderWeight: 25.0,
        favoriteRestaurantWeight: 20.0,
        timeOfDayWeight: 15.0,
      );

      final customService = RecommendationService(weights: customWeights);
      expect(customService.weights.preferredCuisineWeight, 40.0);
      expect(customService.weights.previousOrderWeight, 25.0);
      expect(customService.weights.favoriteRestaurantWeight, 20.0);
      expect(customService.weights.timeOfDayWeight, 15.0);
    });

    test('empty candidate food list returns empty list gracefully', () async {
      final picks = await service.getSmartPicks(
        userId: 'any_user',
        candidateFoods: [],
      );
      expect(picks, isEmpty);
    });
  });
}

