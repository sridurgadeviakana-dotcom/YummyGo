// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yummy_go_application/models/food_items_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/widgets/customer_home_widgets.dart';

void main() {
  test('restaurant model reads live Firestore document fields', () {
    final restaurant = RestaurantModel.fromMap('restaurant-1', {
      'name': 'Cafe One',
      'branchName': 'Downtown',
      'cuisine': 'Cafe',
      'imageUrl': 'https://example.com/cafe.jpg',
      'rating': 4.7,
      'deliveryTime': '20-30 min',
      'isAvailable': true,
    });

    expect(restaurant.id, 'restaurant-1');
    expect(restaurant.name, 'Cafe One');
    expect(restaurant.branchName, 'Downtown');
    expect(restaurant.area, 'Downtown');
    expect(restaurant.cuisine, 'Cafe');
    expect(restaurant.imageUrl, 'https://example.com/cafe.jpg');
    expect(restaurant.rating, 4.7);
    expect(restaurant.deliveryTime, '20-30 min');
    expect(restaurant.isAvailable, isTrue);
  });

  test('restaurant model accepts common image field names', () {
    final restaurant = RestaurantModel.fromMap('restaurant-2', {
      'name': 'Paradise Biryani',
      'image': 'https://example.com/paradise.jpg',
    });

    expect(restaurant.imageUrl, 'https://example.com/paradise.jpg');
  });

  test('restaurant model reads an explicit delivery area', () {
    final restaurant = RestaurantModel.fromMap('restaurant-area', {
      'name': 'Cafe One',
      'branchName': 'Branch One',
      'area': 'Madhapur',
    });

    expect(restaurant.area, 'Madhapur');
  });

  test('restaurant model uses locality when area is not provided', () {
    final restaurant = RestaurantModel.fromMap('restaurant-locality', {
      'name': 'Cafe One',
      'locality': 'Kukatpally',
    });

    expect(restaurant.area, 'Kukatpally');
  });

  test('restaurant model reads offer information from Firestore', () {
    final restaurant = RestaurantModel.fromMap('restaurant-offer', {
      'name': 'Cafe One',
      'offerTitle': 'Extra ₹30 off',
      'offerDescription': 'On orders above ₹149',
    });

    expect(restaurant.offerTitle, 'Extra ₹30 off');
    expect(restaurant.offerDescription, 'On orders above ₹149');
  });

  test(
    'restaurant availability accepts boolean and string Firestore values',
    () {
      final stringAvailability = RestaurantModel.fromMap('restaurant-3', {
        'name': 'Cafe Two',
        'isAvailable': 'true',
      });
      final inactiveStatus = RestaurantModel.fromMap('restaurant-4', {
        'name': 'Cafe Three',
        'status': 'closed',
      });
      final unavailable = RestaurantModel.fromMap('restaurant-5', {
        'name': 'Cafe Four',
        'isAvailable': false,
      });

      expect(stringAvailability.isAvailable, isTrue);
      expect(inactiveStatus.isAvailable, isFalse);
      expect(unavailable.isAvailable, isFalse);
    },
  );

  test('menu items match restaurant id or restaurant name', () {
    final item = FoodItemModel.fromMap('food_001', {
      'restaurantId': 'paradise_madhapur',
      'restaurant': 'Paradise Biryani',
    });

    expect(
      item.belongsToRestaurant(
        restaurantId: 'paradise_madhapur',
        restaurantName: 'Paradise Biryani',
      ),
      isTrue,
    );
    expect(
      item.belongsToRestaurant(
        restaurantId: 'legacy-id',
        restaurantName: ' paradise biryani ',
      ),
      isTrue,
    );
    expect(
      item.belongsToRestaurant(
        restaurantId: 'pizza_hut_hitech_city',
        restaurantName: 'Pizza Hut',
      ),
      isFalse,
    );
  });

  test('menu item model accepts restaurant name aliases from Firestore', () {
    final item = FoodItemModel.fromMap('food_legacy', {
      'restaurant_id': 'paradise_madhapur',
      'restaurantName': 'Paradise Biryani',
      'name': 'Chicken Biryani',
    });

    expect(item.restaurantId, 'paradise_madhapur');
    expect(item.restaurant, 'Paradise Biryani');
    expect(
      item.belongsToRestaurant(
        restaurantId: 'paradise_madhapur',
        restaurantName: 'Paradise Biryani',
      ),
      isTrue,
    );
  });

  test('menu item model reads menu flags and image aliases', () {
    final item = FoodItemModel.fromMap('food_flags', {
      'name': 'Paneer Biryani',
      'description': 'Biryani with paneer and spices.',
      'imageUrl': 'https://example.com/paneer.jpg',
      'isVeg': true,
      'isEatRight': true,
      'isRepeat': true,
      'isBestSeller': true,
      'isFeatured': true,
    });

    expect(item.description, 'Biryani with paneer and spices.');
    expect(item.image, 'https://example.com/paneer.jpg');
    expect(item.isVeg, isTrue);
    expect(item.isEatRight, isTrue);
    expect(item.isRepeat, isTrue);
    expect(item.isBestSeller, isTrue);
    expect(item.isFeatured, isTrue);
  });

  testWidgets('Home search bar displays its search field', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeSearchBar(
            controller: controller,
            onChanged: (_) {},
            onClear: controller.clear,
          ),
        ),
      ),
    );

    expect(find.text('Search biryani, pizza, restaurants...'), findsOneWidget);

    controller.dispose();
  });
}
