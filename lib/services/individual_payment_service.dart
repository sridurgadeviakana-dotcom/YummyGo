import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/address_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/cart_service.dart';
import 'package:yummy_go_application/services/order_service.dart';

/// Service managing individual customer payments via Razorpay (Test Mode).
/// Operates without requiring the paid Firebase Blaze plan or Cloudflare Workers.
/// Never exposes the Razorpay Key Secret in Flutter.
class IndividualPaymentService {
  late final Razorpay _razorpay;
  final CartService _cartService = CartService();

  // Test Mode Key ID (Public key safe to use in client apps)
  static const String testKeyId = 'rzp_test_TvgNMtZA7IeoDe';

  // Active payment state
  bool _isCheckoutActive = false;
  bool _isOrderCreating = false;
  double? _activeAmount;
  String? _activeRestaurantId;
  String? _activeRestaurantName;
  List<Map<String, dynamic>>? _activeItems;
  AddressModel? _activeAddress;

  // Callbacks
  Function(String orderId, String paymentId, String restaurantId, String restaurantName, double totalAmount)? _onSuccess;
  Function(String errorMessage)? _onFailure;

  IndividualPaymentService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// Start Razorpay payment for an individual customer order.
  Future<void> startPayment({
    required double totalAmount,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems,
    String? restaurantId,
    String? restaurantName,
    AddressModel? address,
    required Function(String orderId, String paymentId, String restaurantId, String restaurantName, double totalAmount) onSuccess,
    required Function(String errorMessage) onFailure,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onFailure('Please log in to proceed with payment.');
      return;
    }

    if (_isOrderCreating) {
      return;
    }

    if (totalAmount <= 0 || cartItems.isEmpty) {
      onFailure('Your cart is empty or the amount is invalid.');
      return;
    }

    _isCheckoutActive = true;
    _isOrderCreating = false;
    _activeAmount = totalAmount;
    _activeRestaurantId = restaurantId ?? '';
    _activeRestaurantName = restaurantName ?? 'YummyGo Restaurant';
    _activeAddress = address;
    _onSuccess = onSuccess;
    _onFailure = onFailure;

    // Convert cart documents to order items
    _activeItems = cartItems.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': (data['foodName'] ?? data['name'])?.toString() ?? 'Food Item',
        'quantity': (data['quantity'] as num?)?.toInt() ?? 1,
        'price': (data['price'] as num?)?.toDouble() ?? 0.0,
        'image': data['image']?.toString() ?? '',
        'isVeg': data['isVeg'] == true,
      };
    }).toList();

    final prefill = <String, String>{};
    prefill['email'] = (user.email != null && user.email!.isNotEmpty)
        ? user.email!
        : 'customer@yummygo.com';
    prefill['contact'] = (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
        ? user.phoneNumber!
        : (address?.receiverPhone.isNotEmpty == true
            ? address!.receiverPhone
            : '9876543210');

    final options = {
      'key': testKeyId,
      'amount': (totalAmount * 100).round(), // Razorpay expects amount in paise
      'name': 'YummyGo',
      'description': 'Order from ${_activeRestaurantName!}',
      'prefill': prefill,
      'theme': {
        'color': AppColors.razorpayThemeHex,
      },
      'modal': {
        'confirm_close': true,
      },
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _clearState();
      onFailure('Failed to open Razorpay: $e');
    }
  }

  /// Place order using Cash on Delivery / Pay on Delivery (Direct without Razorpay)
  Future<void> placeCashOnDeliveryOrder({
    required double totalAmount,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> cartItems,
    String? restaurantId,
    String? restaurantName,
    AddressModel? address,
    required Function(String orderId, String paymentId, String restaurantId, String restaurantName, double totalAmount) onSuccess,
    required Function(String errorMessage) onFailure,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onFailure('Please log in to proceed with order.');
      return;
    }

    if (totalAmount <= 0 || cartItems.isEmpty) {
      onFailure('Your cart is empty or the amount is invalid.');
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final orderRef = firestore.collection('orders').doc();
      final orderId = orderRef.id;

      final customerName = address?.receiverName.isNotEmpty == true
          ? address!.receiverName
          : (user.displayName ?? 'Customer');
      final customerPhone = address?.receiverPhone.isNotEmpty == true
          ? address!.receiverPhone
          : (user.phoneNumber ?? '');
      final formattedAddress = address?.formattedAddress.isNotEmpty == true
          ? address!.formattedAddress
          : 'Standard Delivery Address';

      final items = cartItems.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': (data['foodName'] ?? data['name'])?.toString() ?? 'Food Item',
          'quantity': (data['quantity'] as num?)?.toInt() ?? 1,
          'price': (data['price'] as num?)?.toDouble() ?? 0.0,
          'image': data['image']?.toString() ?? '',
          'isVeg': data['isVeg'] == true,
        };
      }).toList();

      final restCoords = RestaurantModel.findCoordinatesForText(restaurantName ?? '');
      final restLat = restCoords?[0] ?? 17.4483;
      final restLng = restCoords?[1] ?? 78.3915;

      final orderData = {
        'id': orderId,
        'customerId': user.uid,
        'userId': user.uid,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'deliveryAddress': formattedAddress,
        'address': formattedAddress,
        'receiverDetails': address?.toMap(),
        'deliveryLatitude': address?.latitude ?? 17.4442,
        'deliveryLongitude': address?.longitude ?? 78.3845,
        'customerLatitude': address?.latitude ?? 17.4442,
        'customerLongitude': address?.longitude ?? 78.3845,
        'restaurantLatitude': restLat,
        'restaurantLongitude': restLng,
        'deliveryInstructions': address?.deliveryInstructions ?? '',
        'restaurantId': restaurantId ?? '',
        'restaurantName': restaurantName ?? 'YummyGo Restaurant',
        'items': items,
        'totalAmount': totalAmount,
        'total': totalAmount,
        'amount': totalAmount,
        'paymentMethod': 'Cash on Delivery',
        'paymentStatus': 'Pending',
        'orderStatus': 'placed',
        'status': 'placed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await orderRef.set(orderData);

      // Pre-initialize tracking doc with customer drop-off coordinates and restaurant coordinates for map routes
      try {
        await firestore
            .collection('orders')
            .doc(orderId)
            .collection('tracking')
            .doc('current')
            .set({
          'customerLatitude': address?.latitude ?? 17.4442,
          'customerLongitude': address?.longitude ?? 78.3845,
          'customerAddress': formattedAddress,
          'restaurantLatitude': restLat,
          'restaurantLongitude': restLng,
          'orderStatus': 'placed',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      // Mirror to user's private orders subcollection for profile view
      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('orders')
            .doc(orderId)
            .set(orderData);
      } catch (_) {}

      // Clear customer's individual cart
      await _cartService.clearCart();

      final restId = restaurantId ?? '';
      final restName = restaurantName ?? 'YummyGo Restaurant';
      final paymentId = 'COD_${orderId.length > 6 ? orderId.substring(0, 6) : orderId}';

      onSuccess(orderId, paymentId, restId, restName, totalAmount);
    } catch (e) {
      onFailure('Failed to place Cash on Delivery order: $e');
    }
  }

  /// Handles successful Razorpay payment.
  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Prevent duplicate handling
    if (_isOrderCreating) return;
    _isOrderCreating = true;

    final user = FirebaseAuth.instance.currentUser;
    final paymentId = response.paymentId ?? '';
    final razorpayOrderId = response.orderId ??
        'rzp_order_${DateTime.now().millisecondsSinceEpoch}';

    if (user == null || paymentId.isEmpty) {
      _onFailure?.call('Payment succeeded, but user session was lost.');
      _clearState();
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // Check if order with this paymentId already exists (Idempotency)
      final existing = await firestore
          .collection('orders')
          .where('paymentId', isEqualTo: paymentId)
          .limit(1)
          .get();

      String orderId;

      if (existing.docs.isNotEmpty) {
        orderId = existing.docs.first.id;
      } else {
        // Create new order in Firestore
        final orderRef = firestore.collection('orders').doc();
        orderId = orderRef.id;

        final customerName = _activeAddress?.receiverName.isNotEmpty == true
            ? _activeAddress!.receiverName
            : (user.displayName ?? 'Customer');
        final customerPhone = _activeAddress?.receiverPhone.isNotEmpty == true
            ? _activeAddress!.receiverPhone
            : (user.phoneNumber ?? '');
        final formattedAddress = _activeAddress?.formattedAddress.isNotEmpty == true
            ? _activeAddress!.formattedAddress
            : 'Standard Delivery Address';

        final restCoords = RestaurantModel.findCoordinatesForText(_activeRestaurantName ?? '');
        final restLat = restCoords?[0] ?? 17.4483;
        final restLng = restCoords?[1] ?? 78.3915;

        final orderData = {
          'id': orderId,
          'customerId': user.uid,
          'userId': user.uid,
          'customerName': customerName,
          'customerPhone': customerPhone,
          'deliveryAddress': formattedAddress,
          'address': formattedAddress,
          'receiverDetails': _activeAddress?.toMap(),
          'deliveryLatitude': _activeAddress?.latitude ?? 17.4442,
          'deliveryLongitude': _activeAddress?.longitude ?? 78.3845,
          'customerLatitude': _activeAddress?.latitude ?? 17.4442,
          'customerLongitude': _activeAddress?.longitude ?? 78.3845,
          'restaurantLatitude': restLat,
          'restaurantLongitude': restLng,
          'deliveryInstructions': _activeAddress?.deliveryInstructions ?? '',
          'restaurantId': _activeRestaurantId ?? '',
          'restaurantName': _activeRestaurantName ?? 'YummyGo Restaurant',
          'items': _activeItems ?? [],
          'totalAmount': _activeAmount ?? 0.0,
          'total': _activeAmount ?? 0.0,
          'amount': _activeAmount ?? 0.0,
          'paymentMethod': 'razorpay',
          'paymentStatus': 'paid',
          'paymentId': paymentId,
          'razorpayOrderId': razorpayOrderId,
          'orderStatus': 'confirmed',
          'status': 'confirmed',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await orderRef.set(orderData);

        // Pre-initialize tracking doc with customer drop-off coordinates and restaurant coordinates for map routes
        try {
          await firestore
              .collection('orders')
              .doc(orderId)
              .collection('tracking')
              .doc('current')
              .set({
            'customerLatitude': _activeAddress?.latitude ?? 17.4442,
            'customerLongitude': _activeAddress?.longitude ?? 78.3845,
            'customerAddress': formattedAddress,
            'restaurantLatitude': restLat,
            'restaurantLongitude': restLng,
            'orderStatus': 'confirmed',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}

        // Mirror to user's private orders subcollection for profile view
        try {
          await firestore
              .collection('users')
              .doc(user.uid)
              .collection('orders')
              .doc(orderId)
              .set(orderData);
        } catch (_) {}
      }

      // Clear customer's individual cart so they can immediately place another order
      await _cartService.clearCart();

      final restId = _activeRestaurantId ?? '';
      final restName = _activeRestaurantName ?? 'YummyGo Restaurant';
      final total = _activeAmount ?? 0.0;

      _onSuccess?.call(orderId, paymentId, restId, restName, total);
    } catch (e) {
      _onFailure?.call('Payment verified, but saving order failed: $e');
    } finally {
      _clearState();
    }
  }

  /// Handles failed or cancelled Razorpay payment.
  void _handlePaymentError(PaymentFailureResponse response) {
    _clearState();

    String message;
    switch (response.code) {
      case Razorpay.PAYMENT_CANCELLED:
        message = 'Payment was cancelled. You can try again whenever ready.';
        break;
      case Razorpay.NETWORK_ERROR:
        message = 'Network error encountered during payment. Please check your internet.';
        break;
      case Razorpay.INVALID_OPTIONS:
        message = 'Invalid payment options. Please retry.';
        break;
      default:
        message = response.message ?? 'Payment failed. Please try again.';
        break;
    }

    _onFailure?.call(message);
  }

  /// Handles external wallet redirection.
  void _handleExternalWallet(ExternalWalletResponse response) {
    _clearState();
    _onFailure?.call(
      'Wallet ${response.walletName ?? 'selected'} redirection initiated. Please complete the transaction.',
    );
  }

  void _clearState() {
    _isCheckoutActive = false;
    _isOrderCreating = false;
    _activeAmount = null;
    _activeRestaurantId = null;
    _activeRestaurantName = null;
    _activeItems = null;
    _activeAddress = null;
  }

  /// Clean up Razorpay instance.
  void dispose() {
    _razorpay.clear();
  }
}
