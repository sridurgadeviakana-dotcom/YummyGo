import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yummy_go_application/models/app_user_model.dart';
import 'package:yummy_go_application/models/delivery_partner_model.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/providers/order_providers.dart';
import 'package:yummy_go_application/services/admin_service.dart';

/// Provider for AdminService instance.
final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService();
});

/// Stream of all users on the platform for Admin management.
final adminUsersStreamProvider = StreamProvider<List<AppUserModel>>((ref) {
  return ref.watch(adminServiceProvider).streamUsers();
});

/// Stream of all restaurants (active, approved, and pending).
final adminAllRestaurantsProvider =
    StreamProvider<List<RestaurantModel>>((ref) {
  return ref.watch(adminServiceProvider).streamAllRestaurants();
});

/// Stream of all registered delivery partners.
final adminDeliveryPartnersProvider =
    StreamProvider<List<DeliveryPartnerModel>>((ref) {
  return ref.watch(adminServiceProvider).streamDeliveryPartners();
});

/// Stream of categories managed by Admin.
final adminCategoriesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminServiceProvider).streamCategories();
});

/// Stream of promotional offers and coupons.
final adminOffersProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminServiceProvider).streamOffers();
});

/// Stream of all orders across the entire platform.
final adminAllOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(orderServiceProvider).streamAllOrders();
});

