import 'package:flutter_test/flutter_test.dart';
import 'package:yummy_go_application/models/app_user_model.dart';
import 'package:yummy_go_application/models/delivery_partner_model.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/models/user_role.dart';

void main() {
  group('UserRole & Authorization tests', () {
    test('UserRole parses strings properly', () {
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('administrator'), UserRole.admin);
      expect(UserRole.fromString('restaurant_owner'), UserRole.restaurantOwner);
      expect(UserRole.fromString('owner'), UserRole.restaurantOwner);
      expect(UserRole.fromString('delivery_partner'), UserRole.deliveryPartner);
      expect(UserRole.fromString('rider'), UserRole.deliveryPartner);
      expect(UserRole.fromString('customer'), UserRole.customer);
      expect(UserRole.fromString(null), UserRole.customer);
      expect(UserRole.fromString('unknown_role'), UserRole.customer);
    });

    test('UserRole properties are defined for all roles', () {
      for (final role in UserRole.values) {
        expect(role.displayName.isNotEmpty, isTrue);
        expect(role.tagline.isNotEmpty, isTrue);
        expect(role.id.isNotEmpty, isTrue);
      }
    });

    test('AppUserModel maps from and to Firestore data', () {
      final user = AppUserModel.fromMap('user123', {
        'name': 'Devi',
        'email': 'devi@example.com',
        'role': 'restaurant_owner',
        'phone': '9876543210',
        'status': 'active',
      });

      expect(user.uid, 'user123');
      expect(user.name, 'Devi');
      expect(user.email, 'devi@example.com');
      expect(user.role, UserRole.restaurantOwner);
      expect(user.phone, '9876543210');
      expect(user.status, 'active');

      final map = user.toMap();
      expect(map['role'], 'restaurant_owner');
      expect(map['email'], 'devi@example.com');
    });
  });

  group('Order & Fleet Model tests', () {
    test('OrderModel maps Firestore document with items', () {
      final order = OrderModel.fromMap('order-999', {
        'userId': 'user-1',
        'customerName': 'John Doe',
        'restaurantId': 'rest-1',
        'restaurantName': 'Spice Garden',
        'totalAmount': 450.0,
        'orderStatus': 'preparing',
        'items': [
          {'id': 'item-1', 'name': 'Biryani', 'quantity': 2, 'price': 200.0, 'isVeg': false},
          {'id': 'item-2', 'name': 'Coke', 'quantity': 1, 'price': 50.0, 'isVeg': true},
        ],
      });

      expect(order.id, 'order-999');
      expect(order.customerName, 'John Doe');
      expect(order.totalAmount, 450.0);
      expect(order.items.length, 2);
      expect(order.orderStatus, 'preparing');
      expect(order.statusDisplay, 'Cooking in Kitchen');
    });

    test('DeliveryPartnerModel maps availability and earnings', () {
      final partner = DeliveryPartnerModel.fromMap('rider-1', {
        'userId': 'rider-1',
        'name': 'Rider Ram',
        'vehicleType': 'EV',
        'vehicleNumber': 'TS09 EV 1234',
        'isAvailable': true,
        'rating': 4.9,
        'totalDeliveries': 12,
        'earnings': 600.0,
      });

      expect(partner.name, 'Rider Ram');
      expect(partner.vehicleType, 'EV');
      expect(partner.isAvailable, isTrue);
      expect(partner.totalDeliveries, 12);
      expect(partner.earnings, 600.0);
    });
  });
}
