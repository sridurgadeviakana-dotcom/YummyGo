import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/providers/auth_providers.dart';
import 'package:yummy_go_application/services/order_service.dart';

/// Provider for OrderService instance.
final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService();
});

/// Stream of all customer orders (active and past).
final customerOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const []);
  }
  return ref.watch(orderServiceProvider).streamCustomerOrders(user.uid);
});

/// Stream of currently active customer orders (Confirmed, Preparing, On the way).
final customerActiveOrdersStreamProvider =
    StreamProvider<List<OrderModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const []);
  }
  return ref.watch(orderServiceProvider).streamCustomerActiveOrders(user.uid);
});

/// Stream of completed/delivered customer orders.
final customerDeliveredOrdersStreamProvider =
    StreamProvider<List<OrderModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const []);
  }
  return ref.watch(orderServiceProvider).streamCustomerDeliveredOrders(user.uid);
});

/// Stream of the single most recent active order for the customer (null if none).
final activeOrderProvider = StreamProvider<OrderModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(null);
  }
  return ref.watch(orderServiceProvider).streamUserActiveOrder(user.uid);
});

/// Stream of an individual order document by ID.
final orderStreamProvider =
    StreamProvider.family<OrderModel?, String>((ref, orderId) {
  return ref.watch(orderServiceProvider).streamOrder(orderId);
});

