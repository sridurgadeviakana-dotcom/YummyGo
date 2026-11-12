import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/address_model.dart';
import 'package:yummy_go_application/services/group_order_service.dart';
import 'package:yummy_go_application/services/order_service.dart';

/// Razorpay Payment Service for Group Orders and Split Bill Shares (Test Mode).
/// Operates without Cloudflare Workers or Firebase Blaze plans.
/// Never exposes the Razorpay Key Secret.
class RazorpayService {
  late final Razorpay _razorpay;
  final GroupOrderService _groupOrderService = GroupOrderService();

  // Test Mode Key ID (Public key safe to use in client apps)
  static const String testKeyId = 'rzp_test_TvgNMtZA7IeoDe';

  final Function(String message) onSuccess;
  final Function(String message) onFailure;

  // Optional navigation callbacks
  void Function(String orderId, String paymentId, double totalAmount)?
      onGroupPaymentSuccess;
  void Function(String paymentId, double amountPaid)? onSplitPaymentSuccess;

  // Active transaction state
  bool _isProcessing = false;
  String? _activePaymentType; // 'group' or 'split'
  String? _activeGroupId;
  String? _activeMemberUserId;
  String? _activeMemberName;
  double? _activeAmount;
  AddressModel? _activeAddress;

  RazorpayService({
    required this.onSuccess,
    required this.onFailure,
    this.onGroupPaymentSuccess,
    this.onSplitPaymentSuccess,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// Step 1: Start Razorpay payment for the entire Group Order at the restaurant
  Future<void> startPayment({
    required String groupId,
    required double amountInRupees,
    String? restaurantId,
    String? restaurantName,
    AddressModel? address,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        onFailure('Please login before starting checkout.');
        return;
      }

      if (groupId.trim().isEmpty ||
          !amountInRupees.isFinite ||
          amountInRupees <= 0) {
        onFailure('Invalid payment amount.');
        return;
      }

      // STRICT ACTIVE ORDER GATING:
      // Block group order payment if user has any active order (individual or group)
      final activeOrder = await OrderService().getActiveUserOrder(user.uid);
      if (activeOrder != null) {
        final shortId = activeOrder.id.length > 8
            ? activeOrder.id.substring(0, 8).toUpperCase()
            : activeOrder.id;
        final type = activeOrder.isGroupOrder ? 'group' : 'individual';
        onFailure(
          'You have an active $type order in progress (#$shortId • ${activeOrder.statusDisplay}). You can place a new order once your current order is delivered.',
        );
        return;
      }

      _isProcessing = false;
      _activePaymentType = 'group';
      _activeGroupId = groupId;
      _activeAmount = amountInRupees;
      _activeAddress = address;

      final prefill = <String, String>{};
      if (user.email != null && user.email!.isNotEmpty) {
        prefill['email'] = user.email!;
      }
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        prefill['contact'] = user.phoneNumber!;
      }

      final options = {
        'key': testKeyId,
        'amount': (amountInRupees * 100).round(), // In paise
        'currency': 'INR',
        'name': 'YummyGo',
        'description': 'Group Food Order (Test Mode)',
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

      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay group start error: $e');
      _clearActivePayment();
      onFailure('Unable to start payment: $e');
    }
  }

  /// Step 2: Start Razorpay payment for an individual member's split share
  Future<void> startSplitPayment({
    required String groupId,
    required String memberUserId,
    required String memberName,
    required double amountInRupees,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        onFailure('Please login to pay your share.');
        return;
      }

      if (groupId.trim().isEmpty ||
          !amountInRupees.isFinite ||
          amountInRupees <= 0) {
        onFailure('Invalid split share amount.');
        return;
      }

      _isProcessing = false;
      _activePaymentType = 'split';
      _activeGroupId = groupId;
      _activeMemberUserId = memberUserId;
      _activeMemberName = memberName;
      _activeAmount = amountInRupees;

      final prefill = <String, String>{};
      if (user.email != null && user.email!.isNotEmpty) {
        prefill['email'] = user.email!;
      }
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        prefill['contact'] = user.phoneNumber!;
      }

      final options = {
        'key': testKeyId,
        'amount': (amountInRupees * 100).round(),
        'currency': 'INR',
        'name': 'YummyGo Split Bill',
        'description': 'Share for $memberName',
        'prefill': prefill,
        'theme': {
          'color': '#008F83', // YummyGo Teal
        },
        'modal': {
          'confirm_close': true,
        },
        'external': {
          'wallets': ['paytm'],
        },
      };

      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay split start error: $e');
      _clearActivePayment();
      onFailure('Unable to start split payment: $e');
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final paymentId = response.paymentId ?? '';
    final groupId = _activeGroupId;
    final amount = _activeAmount ?? 0.0;
    final paymentType = _activePaymentType;

    if (paymentId.isEmpty || groupId == null) {
      onFailure('Payment response was incomplete. No payment recorded.');
      _clearActivePayment();
      return;
    }

    try {
      if (paymentType == 'group') {
        // Record group restaurant payment directly in Firestore
        final orderId = await _groupOrderService.recordRestaurantPayment(
          groupId: groupId,
          paymentId: paymentId,
          totalAmount: amount,
          address: _activeAddress,
        );

        onSuccess('Group payment of ₹${amount.toStringAsFixed(2)} completed successfully!');
        onGroupPaymentSuccess?.call(orderId, paymentId, amount);
      } else if (paymentType == 'split') {
        // Record individual member's share payment in Firestore
        final memberUserId = _activeMemberUserId ?? '';
        final memberName = _activeMemberName ?? 'Member';

        await _groupOrderService.paySplitShare(
          groupId: groupId,
          memberUserId: memberUserId,
          paymentId: paymentId,
          amount: amount,
        );

        onSuccess('$memberName\'s share of ₹${amount.toStringAsFixed(2)} paid successfully!');
        onSplitPaymentSuccess?.call(paymentId, amount);
      }
    } catch (e) {
      debugPrint('Payment verification and recording error: $e');
      onFailure('Payment was completed, but saving to Firestore failed: $e');
    } finally {
      _clearActivePayment();
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _clearActivePayment();

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

    onFailure(message);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    onFailure(
      'Wallet ${response.walletName ?? 'selected'} redirection initiated. Please complete the transaction.',
    );
  }

  void _clearActivePayment() {
    _isProcessing = false;
    _activePaymentType = null;
    _activeGroupId = null;
    _activeMemberUserId = null;
    _activeMemberName = null;
    _activeAmount = null;
    _activeAddress = null;
  }

  void dispose() {
    _razorpay.clear();
  }
}
