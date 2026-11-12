import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/providers/order_providers.dart';
import 'package:yummy_go_application/services/delivery_tracking_service.dart';

/// Provider for DeliveryTrackingService singleton.
final deliveryTrackingServiceProvider =
    Provider<DeliveryTrackingService>((ref) {
  return DeliveryTrackingService();
});

/// Stream of delivery orders assigned to a partner by Admin awaiting acceptance.
final availableDeliveryOrdersProvider =
    StreamProvider.family<List<OrderModel>, String>((ref, partnerId) {
  return ref
      .watch(orderServiceProvider)
      .streamAvailableDeliveryOrders(partnerId: partnerId);
});

/// Stream of all active and past orders assigned to a partner.
final partnerOrdersProvider =
    StreamProvider.family<List<OrderModel>, String>((ref, partnerId) {
  return ref.watch(orderServiceProvider).streamPartnerOrders(partnerId);
});

/// Stream of live rider GPS tracking document under `orders/{orderId}/tracking/current`.
final liveOrderTrackingDocProvider =
    StreamProvider.family<DocumentSnapshot<Map<String, dynamic>>, String>(
  (ref, orderId) {
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .collection('tracking')
        .doc('current')
        .snapshots();
  },
);

