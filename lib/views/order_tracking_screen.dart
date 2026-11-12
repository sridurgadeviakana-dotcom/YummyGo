import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/services/group_order_service.dart';
import 'package:yummy_go_application/services/payment_service.dart';
import 'package:yummy_go_application/views/customer/customer_home_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';
import 'package:yummy_go_application/widgets/delivery_osm_map.dart';

/// Live Order Tracking Screen with Clean Order-Status Timeline,
/// Restaurant Details, Delivery Partner Information, Payment Status,
/// and Estimated Delivery Time using Real-Time Firestore Updates.
class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String? groupId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.groupId,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GroupOrderService _groupOrderService = GroupOrderService();
  late final RazorpayService _razorpayService;
  bool _isPayingShare = false;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService(
      onSuccess: (message) {
        if (!mounted) return;
        setState(() => _isPayingShare = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onFailure: (message) {
        if (!mounted) return;
        setState(() => _isPayingShare = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onSplitPaymentSuccess: (paymentId, amountPaid) {
        if (!mounted) return;
        setState(() => _isPayingShare = false);
      },
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  void _payMyShare({
    required String groupId,
    required String memberUserId,
    required String memberName,
    required double amount,
  }) {
    if (_isPayingShare) return;
    setState(() => _isPayingShare = true);

    _razorpayService.startSplitPayment(
      groupId: groupId,
      memberUserId: memberUserId,
      memberName: memberName,
      amountInRupees: amount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('orders').doc(widget.orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.warmIvory,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            ),
          );
        }

        // Fallback: If orderId is not found directly, check if it's a groupId
        if (orderSnapshot.hasError ||
            !orderSnapshot.hasData ||
            !orderSnapshot.data!.exists) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('group_orders')
                .doc(widget.orderId)
                .snapshots(),
            builder: (context, groupSnap) {
              if (groupSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: AppColors.warmIvory,
                  body: Center(
                    child: CircularProgressIndicator(color: AppColors.teal),
                  ),
                );
              }

              final linkedOrderId =
                  groupSnap.data?.data()?['orderId']?.toString();
              if (linkedOrderId != null &&
                  linkedOrderId.isNotEmpty &&
                  linkedOrderId != widget.orderId) {
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _firestore
                      .collection('orders')
                      .doc(linkedOrderId)
                      .snapshots(),
                  builder: (context, linkedOrderSnap) {
                    if (linkedOrderSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                        backgroundColor: AppColors.warmIvory,
                        body: Center(
                          child:
                              CircularProgressIndicator(color: AppColors.teal),
                        ),
                      );
                    }
                    if (linkedOrderSnap.hasData &&
                        linkedOrderSnap.data!.exists) {
                      final orderData = linkedOrderSnap.data!.data() ?? {};
                      final order =
                          OrderModel.fromMap(linkedOrderId, orderData);
                      return _buildAuthorizedTrackingView(
                        context,
                        orderId: linkedOrderId,
                        order: order,
                        orderData: orderData,
                        effectiveGroupId: widget.orderId,
                      );
                    }
                    return _buildOrderNotFound(context);
                  },
                );
              }

              return _buildOrderNotFound(context);
            },
          );
        }

        final orderData = orderSnapshot.data!.data() ?? {};
        final order = OrderModel.fromMap(widget.orderId, orderData);

        final effectiveGroupId = widget.groupId ??
            orderData['groupId']?.toString() ??
            (orderData['orderType'] == 'group' ? widget.orderId : null);

        return _buildAuthorizedTrackingView(
          context,
          orderId: widget.orderId,
          order: order,
          orderData: orderData,
          effectiveGroupId: effectiveGroupId,
        );
      },
    );
  }

  Widget _buildAuthorizedTrackingView(
    BuildContext context, {
    required String orderId,
    required OrderModel order,
    required Map<String, dynamic> orderData,
    required String? effectiveGroupId,
  }) {
    if (effectiveGroupId != null) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _groupOrderService.groupStream(effectiveGroupId),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.warmIvory,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.teal),
              ),
            );
          }

          final groupData = groupSnapshot.data?.data() ?? {};
          final currentUid = FirebaseAuth.instance.currentUser?.uid;

          // Authorization: Creator or member in memberUids
          final groupCreator = groupData['createdBy']?.toString() ??
              orderData['customerId']?.toString() ??
              order.userId;
          final memberUids = List<String>.from(groupData['memberUids'] ??
              orderData['memberUids'] ??
              []);

          final isAuthorized = currentUid == groupCreator ||
              (currentUid != null && memberUids.contains(currentUid));

          if (!isAuthorized) {
            return _buildUnauthorizedScreen(context);
          }

          return _buildMainTrackingScaffold(
            context,
            orderId: orderId,
            order: order,
            orderData: orderData,
            effectiveGroupId: effectiveGroupId,
            groupData: groupData,
          );
        },
      );
    }

    return _buildMainTrackingScaffold(
      context,
      orderId: orderId,
      order: order,
      orderData: orderData,
      effectiveGroupId: null,
      groupData: null,
    );
  }

  Widget _buildMainTrackingScaffold(
    BuildContext context, {
    required String orderId,
    required OrderModel order,
    required Map<String, dynamic> orderData,
    required String? effectiveGroupId,
    Map<String, dynamic>? groupData,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('orders')
          .doc(orderId)
          .collection('tracking')
          .doc('current')
          .snapshots(),
      builder: (context, trackingSnapshot) {
        final trackingData = trackingSnapshot.data?.data();
        final stageIndex = _getStageIndex(order.orderStatus);
        final etaText = _getEtaText(stageIndex);
        final distanceText = _getDistanceText(stageIndex);

        return Scaffold(
          backgroundColor: AppColors.warmIvory,
          appBar: CommonAppBar(
            backgroundColor: AppColors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      effectiveGroupId != null
                          ? 'Group Order Tracking'
                          : 'Track Order',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepTeal,
                      ),
                    ),
                    if (effectiveGroupId != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.lightTeal,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'GROUP',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '${order.restaurantName} • #${order.id}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.home_outlined, color: AppColors.teal),
                tooltip: 'Home',
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CustomerHomeScreen()),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Estimated Delivery Time & Live Status Banner (Hidden for Group Orders)
                if (effectiveGroupId == null)
                  _buildLiveEtaBanner(order, trackingData, stageIndex, etaText, distanceText),

                // 2. Interactive Map Routes (Hidden for Group Orders)
                if (effectiveGroupId == null)
                  DeliveryOsmMap(
                    order: order,
                    trackingData: trackingData,
                    stageIndex: stageIndex,
                    etaText: etaText,
                    distanceText: distanceText,
                    height: 250,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  ),

                if (effectiveGroupId != null)
                  const SizedBox(height: 8),

                // 3. 5-Stage Order Status Timeline
                _buildTimelineSection(order),

                // 4. Restaurant Details & Food Items
                _buildOrderDetailsContainer(order, orderData),

                // 5. Payment Status Card
                _buildPaymentStatusCard(order, orderData),

                // 6. Group Order Payment Section (if group order)
                if (effectiveGroupId != null)
                  _buildGroupPaymentSection(effectiveGroupId, order),
              ],
            ),
          ),
        );
      },
    );
  }

  // 1. ESTIMATED DELIVERY TIME & LIVE STATUS BANNER (Real-time Firestore)
  Widget _buildLiveEtaBanner(
    OrderModel order,
    Map<String, dynamic>? trackingData,
    int stageIndex,
    String etaText,
    String distanceText,
  ) {
    final liveMinutes = trackingData?['estimatedMinutes'];
    final displayEta = liveMinutes != null ? '$liveMinutes mins' : etaText;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.access_time_filled_rounded,
                  color: AppColors.teal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimated Delivery Time',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayEta,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepTeal,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusBadgeBg(order.orderStatus),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.statusDisplay,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _getStatusBadgeColor(order.orderStatus),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warmIvory,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.teal),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    distanceText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. DELIVERY PARTNER INFORMATION CARD (Real-time updates)
  Widget _buildDeliveryPartnerCard(
    OrderModel order,
    Map<String, dynamic>? trackingData,
  ) {
    final partnerName = trackingData?['deliveryPartnerName']?.toString() ??
        order.deliveryPartnerName;
    if (partnerName == null || partnerName.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final partnerPhone = trackingData?['deliveryPartnerPhone']?.toString() ??
        order.deliveryPartnerPhone ??
        '';
    final isAssigned = (trackingData?['partnerAssigned'] == true) ||
        order.deliveryPartnerName != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoalBlack.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
     
    );
  }

  // 3. PAYMENT STATUS CARD
  Widget _buildPaymentStatusCard(
    OrderModel order,
    Map<String, dynamic> data,
  ) {
    final paymentMethod = (data['paymentMethod'] ?? order.paymentMethod).toString().toUpperCase();
    final paymentStatus = (data['paymentStatus'] ?? order.paymentStatus).toString().toUpperCase();
    final paymentId = (data['paymentId'] ?? data['restaurantPayment']?['paymentId'])?.toString();
    final isPaid = paymentStatus.toLowerCase() == 'paid';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.payment_rounded, color: AppColors.teal, size: 19),
                  SizedBox(width: 8),
                  Text(
                    'Payment Status',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepTeal,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid ? AppColors.lightLime : AppColors.lightOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPaid ? Icons.check_circle_rounded : Icons.access_time_rounded,
                      size: 13,
                      color: isPaid ? AppColors.success : AppColors.goldenOrange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPaid ? 'PAID' : paymentStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isPaid ? AppColors.success : AppColors.goldenOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _groupStatRow('Payment Method', paymentMethod.contains('RAZOR') ? 'Razorpay Online' : paymentMethod),
          const SizedBox(height: 6),
          _groupStatRow('Total Amount', '₹${order.totalAmount.toStringAsFixed(2)}', valueColor: AppColors.teal),
          if (paymentId != null && paymentId.isNotEmpty) ...[
            const SizedBox(height: 6),
            _groupStatRow('Payment ID', paymentId),
          ],
        ],
      ),
    );
  }

  // 4. GROUP ORDER PAYMENT STATUS & MEMBER SPLIT (Requirements 6, 7, 8, 9)
  Widget _buildGroupPaymentSection(String groupId, OrderModel order) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _groupOrderService.groupStream(groupId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final groupData = snapshot.data!.data() ?? {};
        final members = (groupData['members'] as List<dynamic>?) ?? [];
        if (members.length < 2) {
          return const SizedBox.shrink();
        }

        final totalBill =
            (groupData['split']?['total'] as num?)?.toDouble() ??
            (groupData['restaurantTotal'] as num?)?.toDouble() ??
            order.totalAmount;

        final rawShares = groupData['splitMembers'];
        final shares = <Map<String, dynamic>>[];
        if (rawShares is List) {
          for (final it in rawShares) {
            if (it is Map) shares.add(Map<String, dynamic>.from(it));
          }
        }

        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final creatorUid = groupData['paidBy']?.toString() ??
            groupData['createdBy']?.toString() ??
            order.userId;
        final isCreator = currentUid == creatorUid;

        final paidCount =
            shares.where((s) => s['paymentStatus'] == 'paid').length;
        final pendingCount = shares.length - paidCount;
        final isAllPaid = (shares.isNotEmpty && pendingCount == 0) ||
            groupData['status'] == 'split_completed';

        double collectedAmount = 0.0;
        for (final s in shares) {
          if (s['paymentStatus'] == 'paid') {
            collectedAmount += (s['amountDue'] as num?)?.toDouble() ?? 0.0;
          }
        }

        // Current member's personal share
        Map<String, dynamic>? myShare;
        for (final s in shares) {
          if (s['userId'] == currentUid) {
            myShare = s;
            break;
          }
        }
        final bool myShareIsPaid =
            myShare != null && myShare['paymentStatus'] == 'paid';
        final double myShareAmount =
            (myShare?['amountDue'] as num?)?.toDouble() ?? 0.0;

        final payerName = groupData['paidByName']?.toString() ??
            groupData['customerName']?.toString() ??
            'Group Host';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.groups_rounded,
                          size: 20, color: AppColors.teal),
                      SizedBox(width: 8),
                      Text(
                        'Group Split Payment',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepTeal,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAllPaid
                          ? AppColors.lightLime
                          : AppColors.lightOrange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAllPaid)
                          const Icon(Icons.check_circle_rounded,
                              size: 13, color: AppColors.success)
                        else
                          const Icon(Icons.access_time_rounded,
                              size: 13, color: AppColors.goldenOrange),
                        const SizedBox(width: 4),
                        Text(
                          isAllPaid
                              ? 'Split Completed'
                              : '$pendingCount Pending',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isAllPaid
                                ? AppColors.success
                                : AppColors.goldenOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Summary Stats Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warmIvory,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _groupStatRow('Restaurant Bill',
                        '₹${totalBill.toStringAsFixed(2)}'),
                    const SizedBox(height: 5),
                    _groupStatRow(
                      'Payer ($payerName)',
                      'Paid full amount ✓',
                      valueColor: AppColors.success,
                    ),
                    const SizedBox(height: 5),
                    _groupStatRow(
                      'Reimbursed by Members',
                      '₹${collectedAmount.toStringAsFixed(2)} / ₹${totalBill.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalBill > 0
                            ? (collectedAmount / totalBill).clamp(0.0, 1.0)
                            : 0.0,
                        minHeight: 5,
                        backgroundColor: AppColors.border,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(AppColors.teal),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Requirement 9: Show Split Completed Banner
              if (isAllPaid) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.lightLime,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.limeGreen.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.celebration_rounded,
                          color: AppColors.success, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '🎉 Split Completed! All members have paid their share.',
                          style: TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Requirement 7: Creator must NOT see Pay Now after paying full amount
              if (isCreator) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.lightTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded,
                          color: AppColors.teal, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAllPaid
                              ? 'You have received full reimbursement from all members.'
                              : 'You paid the restaurant bill of ₹${totalBill.toStringAsFixed(0)}. Members will pay their pending shares to you.',
                          style: const TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Requirement 8: Members can pay ONLY their own pending share
              if (!isCreator && myShare != null) ...[
                if (myShareIsPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.lightLime,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your share of ₹${myShareAmount.toStringAsFixed(0)} is Paid! Thank you.',
                            style: const TextStyle(
                              color: AppColors.deepTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightOrange,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.goldenOrange.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Your Pending Share',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepTeal,
                              ),
                            ),
                            Text(
                              '₹${myShareAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.deepTeal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _isPayingShare
                              ? null
                              : () => _payMyShare(
                                    groupId: groupId,
                                    memberUserId: currentUid ?? '',
                                    memberName: myShare?['name']?.toString() ??
                                        'Member',
                                    amount: myShareAmount,
                                  ),
                          icon: _isPayingShare
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Icon(Icons.payment_rounded, size: 18),
                          label: Text(
                            _isPayingShare
                                ? 'Processing...'
                                : 'Pay My Share (₹${myShareAmount.toStringAsFixed(0)})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
              ],

              // Member Shares List
              const Text(
                'Member Split Shares',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepTeal,
                ),
              ),
              const SizedBox(height: 8),

              if (shares.isEmpty)
                const Text(
                  'No split bill created yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                )
              else
                ...shares.map((share) {
                  final name = share['name']?.toString() ?? 'Member';
                  final amount =
                      (share['amountDue'] as num?)?.toDouble() ?? 0.0;
                  final isPaid = share['paymentStatus'] == 'paid';
                  final isCurrentMember = share['userId'] == currentUid;
                  final isShareCreator = share['userId'] == creatorUid;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: isPaid
                              ? AppColors.lightLime
                              : AppColors.lightOrange,
                          child: Icon(
                            isPaid
                                ? Icons.check
                                : Icons.access_time_rounded,
                            size: 13,
                            color: isPaid
                                ? AppColors.success
                                : AppColors.goldenOrange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$name${isCurrentMember ? ' (You)' : ''}${isShareCreator ? ' (Host)' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrentMember
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: AppColors.deepTeal,
                            ),
                          ),
                        ),
                        Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepTeal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.lightLime,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Paid',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          )
                        else if (isCreator && !isAllPaid) ...[
                          TextButton(
                            onPressed: () {
                              final msg =
                                  'Hi $name! Please pay your food split share of ₹${amount.toStringAsFixed(0)} for ${order.restaurantName}.';
                              Clipboard.setData(ClipboardData(text: msg));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Reminder copied for $name!'),
                                  backgroundColor: AppColors.teal,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Remind',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.goldenOrange,
                              ),
                            ),
                          ),
                        ] else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.lightOrange,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Pending',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.goldenOrange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _groupStatRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.deepTeal,
          ),
        ),
      ],
    );
  }

  // 3-STAGE TIMELINE SECTION
  Widget _buildTimelineSection(OrderModel order) {
    final currentStage = _getStageIndex(order.orderStatus);

    final stages = [
      {'title': 'Order Placed', 'sub': 'Restaurant has accepted your order'},
      {'title': 'Ready for Pickup', 'sub': 'Dishes ready & partner assigned'},
      {'title': 'Delivered', 'sub': 'Enjoy your delicious meal!'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline_rounded, color: AppColors.teal, size: 20),
              SizedBox(width: 8),
              Text(
                'Live Order Timeline',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < stages.length; i++) ...[
            _timelineItem(
              title: stages[i]['title']!,
              subtitle: stages[i]['sub']!,
              isCompleted: i <= currentStage,
              isCurrent: i == currentStage,
              isLast: i == stages.length - 1,
            ),
          ],
        ],
      ),
    );
  }

  Widget _timelineItem({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    Color dotColor;
    if (isCompleted) {
      dotColor = isCurrent ? AppColors.teal : AppColors.success;
    } else {
      dotColor = AppColors.border;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                height: 22,
                width: 22,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.teal.withValues(alpha: 0.35),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 13, color: AppColors.white)
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.5,
                    color: isCompleted ? AppColors.success : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          isCurrent ? FontWeight.w900 : FontWeight.w700,
                      color: isCompleted
                          ? AppColors.deepTeal
                          : AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isCurrent
                          ? AppColors.deepTeal
                          : AppColors.mutedText,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6. ORDER DETAILS CONTAINER (Requirement 1)
  Widget _buildOrderDetailsContainer(
      OrderModel order, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepTeal,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${order.items.length} items',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Clear Order ID row (accessible & copyable)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order ID',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: order.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order ID copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '#${order.id}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepTeal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, size: 13, color: AppColors.teal),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          // Items list
          ...order.items.map((it) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: it.isVeg
                            ? AppColors.success
                            : AppColors.error,
                        width: 1.4,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: it.isVeg
                              ? AppColors.success
                              : AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${it.quantity}x ${it.name}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepTeal,
                      ),
                    ),
                  ),
                  Text(
                    '₹${(it.price * it.quantity).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepTeal,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          // Bill Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepTeal,
                ),
              ),
              Text(
                '₹${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Payment details
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warmIvory,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.credit_card_rounded,
                    size: 16, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payment: ${order.paymentMethod.toUpperCase()} • ${order.paymentStatus.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepTeal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.lightLime,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'Paid',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // STAGE HELPERS
  int _getStageIndex(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
      case 'confirmed':
        return 0;
      case 'ready_for_pickup':
      case 'preparing':
      case 'picked_up':
      case 'on_the_way':
      case 'out_for_delivery':
        return 1;
      case 'delivered':
      case 'completed':
        return 2;
      default:
        return 0;
    }
  }

  String _getEtaText(int stageIndex) {
    switch (stageIndex) {
      case 0:
        return '20-25 mins';
      case 1:
        return '10-15 mins';
      case 2:
        return 'Delivered';
      default:
        return '20-25 mins';
    }
  }

  String _getDistanceText(int stageIndex) {
    switch (stageIndex) {
      case 0:
        return 'Order confirmed with restaurant';
      case 1:
        return 'Ready for pickup & delivery in progress';
      case 2:
        return 'Order Delivered';
      default:
        return 'Order in progress';
    }
  }

  Color _getStatusBadgeBg(String status) {
    final s = status.toLowerCase();
    if (s == 'delivered' || s == 'completed') return AppColors.lightLime;
    if (s == 'cancelled') return AppColors.error.withValues(alpha: 0.12);
    return AppColors.lightOrange;
  }

  Color _getStatusBadgeColor(String status) {
    final s = status.toLowerCase();
    if (s == 'delivered' || s == 'completed') return AppColors.success;
    if (s == 'cancelled') return AppColors.error;
    return AppColors.goldenOrange;
  }

  // ACCESS RESTRICTED SCREEN
  Widget _buildUnauthorizedScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'Access Restricted',
        backgroundColor: AppColors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  size: 40,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Group Order Access Restricted',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepTeal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Only the group creator and authorized members can view this order.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepTeal,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ORDER NOT FOUND SCREEN
  Widget _buildOrderNotFound(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(title: 'Track Order'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 64, color: AppColors.mutedText),
              const SizedBox(height: 16),
              const Text(
                'Order details could not be found.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepTeal,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please check if the order was placed or ask the group creator.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.mutedText),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepTeal,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
