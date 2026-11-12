import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/services/resturent_services.dart';
import 'package:yummy_go_application/models/food_items_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/payment_service.dart';
import 'package:yummy_go_application/views/customer/customer_home_screen.dart';
import 'package:yummy_go_application/views/group_cart_screen.dart';
import 'package:yummy_go_application/views/group_chat_screen.dart';
import 'package:yummy_go_application/views/group_voting_screen.dart';
import 'package:yummy_go_application/views/order_tracking_screen.dart';
import 'package:yummy_go_application/views/split_bill_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';
import 'package:yummy_go_application/widgets/restaurant_conflict_dialog.dart';

import '../../services/group_order_service.dart';
import 'package:yummy_go_application/providers/providers.dart';

class GroupRoomScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupRoomScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupRoomScreen> createState() => _GroupRoomScreenState();
}

class _GroupRoomScreenState extends ConsumerState<GroupRoomScreen> {
  final GroupOrderService service = GroupOrderService();
  final RestaurantService restaurantService = RestaurantService();
  final ScrollController _scrollController = ScrollController();
  final Map<String, ValueNotifier<int?>> _optimisticQuantities = {};
  final Map<String, int> _quantityBases = {};
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _groupStream;
  late final RazorpayService _razorpayService;
  bool _isPayingShare = false;
  bool _isResettingGroup = false;
  String selectedCategory = 'Biryanis';
  RestaurantModel? selectedRestaurant;

  @override
  void initState() {
    super.initState();
    _groupStream = service.groupStream(widget.groupId);
    _razorpayService = RazorpayService(
      onSuccess: (message) {
        if (!mounted) return;
        setState(() => _isPayingShare = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: AppColors.teal,
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
          ),
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant GroupRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _groupStream = service.groupStream(widget.groupId);
    }
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    _scrollController.dispose();
    for (final quantity in _optimisticQuantities.values) {
      quantity.dispose();
    }
    super.dispose();
  }

  ValueNotifier<int?> _quantityNotifier(String foodId) {
    return _optimisticQuantities.putIfAbsent(
      foodId,
      () => ValueNotifier<int?>(null),
    );
  }

  Map<String, int> _myQuantities(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final quantities = <String, int>{};
    for (final item in snapshot.docs) {
      final data = item.data();
      if (data['addedBy'] != service.userId) continue;
      final foodId = data['foodId']?.toString();
      if (foodId == null || foodId.isEmpty) continue;
      quantities.update(
        foodId,
        (quantity) => quantity + ((data['quantity'] as num?)?.toInt() ?? 1),
        ifAbsent: () => (data['quantity'] as num?)?.toInt() ?? 1,
      );
    }
    return quantities;
  }

  void _reconcileOptimisticQuantities(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final savedQuantities = _myQuantities(snapshot);
    final confirmedFoodIds = _quantityBases.keys
        .where(
          (foodId) =>
              (savedQuantities[foodId] ?? 0) ==
                  _quantityNotifier(foodId).value ||
              (savedQuantities[foodId] ?? 0) != _quantityBases[foodId],
        )
        .toList();
    for (final foodId in confirmedFoodIds) {
      _quantityNotifier(foodId).value = null;
      _quantityBases.remove(foodId);
    }
  }

  final List<Map<String, dynamic>> categories = [
    {
      'name': 'Biryanis',
      'icon': Icons.rice_bowl_rounded,
      'color': const Color(0xFFFFE8D6),
    },
    {
      'name': 'Pizzas',
      'icon': Icons.local_pizza_rounded,
      'color': const Color(0xFFFFE6E2),
    },
    {
      'name': 'Burgers',
      'icon': Icons.lunch_dining_rounded,
      'color': const Color(0xFFFFEFCB),
    },
    {
      'name': 'Pulaos',
      'icon': Icons.restaurant_rounded,
      'color': const Color(0xFFE0F1E8),
    },
  ];

  double getPrice(dynamic price) {
    if (price is num) return price.toDouble();
    return double.tryParse(price.toString()) ?? 0;
  }

  Future<void> addFood({
    required String foodId,
    required String name,
    required String image,
    required double price,
    String? restaurantId,
    String? restaurantName,
  }) async {
    await _changeFoodQuantity(
      foodId: foodId,
      name: name,
      image: image,
      price: price,
      currentQuantity: 0,
      changeBy: 1,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );
  }

  Future<void> _changeFoodQuantity({
    required String foodId,
    required String name,
    required String image,
    required double price,
    required int currentQuantity,
    required int changeBy,
    String? restaurantId,
    String? restaurantName,
  }) async {
    if (changeBy > 0) {
      final conflict = await service.checkGroupConflict(
        groupId: widget.groupId,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
      );

      if (conflict.hasConflict) {
        if (!mounted) return;
        final shouldClear = await showRestaurantConflictDialog(
          context,
          existingRestaurantName: conflict.existingRestaurantName,
          newRestaurantName: restaurantName ?? 'another restaurant',
          isGroupOrder: true,
          actionButtonText: 'Clear Cart & Add',
        );

        if (shouldClear == true) {
          try {
            await service.clearGroupCartAndAddFood(
              groupId: widget.groupId,
              foodId: foodId,
              foodName: name,
              image: image,
              price: price,
              restaurantId: restaurantId,
              restaurantName: restaurantName,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$name added! Group cart reset for ${restaurantName ?? "new restaurant"}.',
                ),
                backgroundColor: AppColors.teal,
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unable to update group cart: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
        return;
      }
    }

    final notifier = _quantityNotifier(foodId);
    final visibleQuantity = notifier.value ?? currentQuantity;
    final nextQuantity = (visibleQuantity + changeBy).clamp(0, 999);
    if (nextQuantity == visibleQuantity) return;
    _quantityBases.putIfAbsent(foodId, () => currentQuantity);
    notifier.value = nextQuantity;

    try {
      await service.adjustFoodQuantity(
        groupId: widget.groupId,
        foodId: foodId,
        foodName: name,
        image: image,
        price: price,
        changeBy: changeBy,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
      );
    } catch (error) {
      if (!mounted) return;
      notifier.value = null;
      _quantityBases.remove(foodId);

      if (error is RestaurantConflictException) {
        final shouldClear = await showRestaurantConflictDialog(
          context,
          existingRestaurantName: error.existingRestaurantName,
          newRestaurantName: restaurantName ?? 'another restaurant',
          isGroupOrder: true,
          actionButtonText: 'Clear Cart & Add',
        );
        if (shouldClear == true) {
          await service.clearGroupCartAndAddFood(
            groupId: widget.groupId,
            foodId: foodId,
            foodName: name,
            image: image,
            price: price,
            restaurantId: restaurantId,
            restaurantName: restaurantName,
          );
        }
        return;
      }

      final isNotMember = error.toString().contains('not a member');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNotMember
              ? 'Please join the group first to add items.'
              : 'Unable to update group cart: $error'),
          backgroundColor: AppColors.error,
          action: isNotMember
              ? SnackBarAction(
                  label: 'Join Now',
                  textColor: AppColors.white,
                  onPressed: () async {
                    try {
                      await service.joinGroupById(widget.groupId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Joined! Tap + to add items now.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (_) {}
                  },
                )
              : null,
        ),
      );
    }
  }

  Future<void> _copyText(String text, String label) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard.'),
          backgroundColor: AppColors.deepTeal,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to copy: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _shareInviteCode({
    required String inviteCode,
    required String groupName,
  }) async {
    final message =
        '🍔 Join my group order "$groupName" on YummyGo!\n\n'
        '⭐ Group Code: $inviteCode\n\n'
        'Open YummyGo, tap "Join a Group", and enter this Code to join us!';
    try {
      await Share.share(message, subject: 'Join my group order on YummyGo');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to share invite: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(groupCartProvider(widget.groupId), (_, next) {
      next.whenData(_reconcileOptimisticQuantities);
    });

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: CommonAppBar(
        backgroundColor: AppColors.deepTeal,
        foregroundColor: AppColors.white,
        title: 'Group Food Order',
        subtitle: 'Order together with friends',
        actions: [
          IconButton(
            tooltip: 'View Group Cart',
            icon: const Icon(Icons.shopping_bag_outlined, color: AppColors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupCartScreen(groupId: widget.groupId),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _groupStream,
          builder: (context, groupSnapshot) {
            if (groupSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.teal));
            }

            if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) {
              return _buildGroupNotFound(context);
            }

            final groupData = groupSnapshot.data?.data() ?? {};
            final memberUids = List<String>.from(groupData['memberUids'] ?? []);
            final isMember = memberUids.contains(service.userId) ||
                groupData['createdBy'] == service.userId;

            // RULE 5 & 6: Only creator and successfully joined members can access.
            if (!isMember) {
              return _buildAccessRestrictedScreen(context, groupData);
            }

            final orderId = groupData['orderId']?.toString();
            final paymentStatus = groupData['paymentStatus']?.toString();
            final status = groupData['status']?.toString();
            final hasActiveOrder = (orderId != null && orderId.isNotEmpty) &&
                (paymentStatus == 'paid' ||
                    status == 'paid' ||
                    status == 'split_created' ||
                    status == 'split_completed' ||
                    groupData['restaurantPayment'] != null);

            // REUSABLE GROUPS:
            // After creator pays and order is confirmed:
            // Lock the group cart and display ONLY group member details,
            // individual split-payment details, and live order status.
            // Allow a new group order only after previous order is delivered.
            if (hasActiveOrder) {
              return _buildLockedGroupOrderView(context, groupData, orderId!);
            }

            return Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    key: PageStorageKey<String>('group-room-${widget.groupId}'),
                    controller: _scrollController,
                    slivers: [
                      // Header
                      SliverToBoxAdapter(child: _buildHeader(groupData)),

                      // Members
                      SliverToBoxAdapter(child: _buildMembers()),

                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
                          child: Text(
                            'Choose a restaurant',
                            style: TextStyle(
                              color: AppColors.deepTeal,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _buildRestaurants(groupData: groupData),
                      ),

                      // Menu title
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedRestaurantName(groupData) == null
                                      ? 'Available Menu Items'
                                      : '${_selectedRestaurantName(groupData)} Menu',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.deepTeal,
                                  ),
                                ),
                              ),
                              if (_selectedRestaurantName(groupData) !=
                                  null) ...[
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: _clearSelectedRestaurant,
                                  child: const Text('All restaurants'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Food list
                      _buildFoodList(groupData: groupData),
                    ],
                  ),
                ),

                // Shared cart bottom section
                _buildBottomCart(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REUSABLE GROUPS & LOCKED CART VIEW
  // ---------------------------------------------------------------------------
  Widget _buildLockedGroupOrderView(
    BuildContext context,
    Map<String, dynamic> groupData,
    String orderId,
  ) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
      builder: (context, orderSnap) {
        final orderData = orderSnap.data?.data() ?? {};
        final orderStatus = (orderData['orderStatus'] ??
                orderData['status'] ??
                groupData['orderStatus'] ??
                groupData['status'] ??
                'confirmed')
            .toString()
            .toLowerCase();
        final isDelivered = orderStatus == 'delivered' || orderStatus == 'completed';
        final stageIndex = _getStageIndex(orderStatus);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .collection('tracking')
              .doc('current')
              .snapshots(),
          builder: (context, trackingSnap) {
            final trackingData = trackingSnap.data?.data();
            final etaMinutes = trackingData?['estimatedMinutes'] ??
                (isDelivered ? 0 : (25 - stageIndex * 5).clamp(5, 30));
            final etaText = isDelivered ? 'Delivered' : '$etaMinutes mins';
            final distanceText = _getDistanceText(stageIndex);

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Group Header (Name, Code, Share/Copy actions)
                  _buildHeader(groupData),

                  // 2. Reusable Group Order Banner & Status
                  _buildReusableGroupBanner(groupData, isDelivered),

                  // 3. Clean 5-Stage Order-Status Timeline
                  _buildLockedTimelineCard(
                    stageIndex: stageIndex,
                    isDelivered: isDelivered,
                  ),

                  // 4. Restaurant Details & Food Items Card
                  _buildLockedRestaurantCard(
                    groupData: groupData,
                    orderData: orderData,
                    orderId: orderId,
                  ),

                  // 5. Payment Status Card
                  _buildLockedPaymentCard(
                    groupData: groupData,
                    orderData: orderData,
                    orderId: orderId,
                  ),

                  // 6. Group Member Details (Full list)
                  _buildLockedMembersCard(groupData: groupData),

                  // 7. Individual Split-Payment Details (Show only if at least 2 members)
                  if ((groupData['members'] as List<dynamic>? ?? []).length >= 2)
                    _buildLockedSplitDetailsCard(
                      groupData: groupData,
                      orderData: orderData,
                    ),

                  // 10. Start New Group Order Button (allowed only after delivered)
                  if (isDelivered)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        icon: _isResettingGroup
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.replay_rounded, size: 22),
                        label: Text(
                          _isResettingGroup
                              ? 'Resetting Group...'
                              : 'Start New Group Order',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: _isResettingGroup
                            ? null
                            : () => _startNewGroupOrder(
                                  groupData['groupName']?.toString() ??
                                      'Group Order',
                                ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // REUSABLE GROUP BANNER (Rule: new order only after delivered)
  Widget _buildReusableGroupBanner(
    Map<String, dynamic> groupData,
    bool isDelivered,
  ) {
    if (isDelivered) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.lightLime,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Delivered Successfully! ðŸŽ‰',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepTeal,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'You can now place another group order with the same members.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightTeal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_clock_rounded, color: AppColors.teal, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Group Cart Locked • Order in Progress',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepTeal,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'A new group order can be started once this order is delivered.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // LIVE STATUS & REAL-TIME ETA CARD (NO MAPS)
  Widget _buildLockedLiveStatusCard({
    required Map<String, dynamic> orderData,
    required Map<String, dynamic>? trackingData,
    required String orderStatus,
    required int stageIndex,
    required String etaText,
    required String distanceText,
    required bool isDelivered,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: isDelivered ? AppColors.lightLime : AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isDelivered
                      ? Icons.check_circle_rounded
                      : Icons.access_time_filled_rounded,
                  color: isDelivered ? AppColors.success : AppColors.teal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDelivered ? 'Delivery Status' : 'Estimated Delivery Time',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      etaText,
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
                  color: _getStatusBadgeBg(orderStatus),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  orderStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _getStatusBadgeColor(orderStatus),
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
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.teal),
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

  // 5-STAGE ORDER TIMELINE CARD (NO MAPS)
  Widget _buildLockedTimelineCard({
    required int stageIndex,
    required bool isDelivered,
  }) {
    final stages = [
      {'title': 'Order Confirmed', 'sub': 'Restaurant accepted group order'},
      {'title': 'Food Ready', 'sub': 'Dishes freshly prepared in kitchen'},
      {'title': 'Delivery Partner Assigned', 'sub': 'Partner arriving at restaurant'},
      {'title': 'Order Picked Up', 'sub': 'Partner heading to group address'},
      {'title': 'Delivered', 'sub': 'Enjoy your group meal!'},
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
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        height: 22,
                        width: 22,
                        decoration: BoxDecoration(
                          color: (i <= stageIndex || isDelivered)
                              ? (i == stageIndex && !isDelivered
                                  ? AppColors.teal
                                  : AppColors.success)
                              : AppColors.border,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: (i <= stageIndex || isDelivered)
                              ? const Icon(Icons.check,
                                  size: 13, color: AppColors.white)
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
                      if (i < stages.length - 1)
                        Expanded(
                          child: Container(
                            width: 2.5,
                            color: (i < stageIndex || isDelivered)
                                ? AppColors.success
                                : AppColors.border,
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
                            stages[i]['title']!,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: (i == stageIndex && !isDelivered)
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: (i <= stageIndex || isDelivered)
                                  ? AppColors.deepTeal
                                  : AppColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stages[i]['sub']!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: (i == stageIndex && !isDelivered)
                                  ? AppColors.deepTeal
                                  : AppColors.mutedText,
                              fontWeight: (i == stageIndex && !isDelivered)
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // RESTAURANT DETAILS & FOOD ITEMS CARD
  Widget _buildLockedRestaurantCard({
    required Map<String, dynamic> groupData,
    required Map<String, dynamic> orderData,
    required String orderId,
  }) {
    final restName = orderData['restaurantName']?.toString() ??
        groupData['restaurantName']?.toString() ??
        'Restaurant';
    final rawItems = orderData['items'] ?? groupData['cartItems'];
    final items = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map) items.add(Map<String, dynamic>.from(it));
      }
    }

    final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ??
        (groupData['restaurantTotal'] as num?)?.toDouble() ??
        0.0;

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
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded,
                        color: AppColors.teal, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        restName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _copyText(orderId, 'Order ID'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '#$orderId',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepTeal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded,
                          size: 12, color: AppColors.teal),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),

          // Items List
          if (items.isEmpty)
            const Text(
              'Items confirmed with restaurant',
              style: TextStyle(fontSize: 12.5, color: AppColors.mutedText),
            )
          else
            ...items.map((item) {
              final name = (item['foodName'] ?? item['name'])?.toString() ?? 'Food item';
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              final price = (item['price'] as num?)?.toDouble() ?? 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.lightTeal,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${qty}x',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepTeal,
                        ),
                      ),
                    ),
                    Text(
                      '₹${(price * qty).toStringAsFixed(0)}',
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

          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),

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
                '₹${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // DELIVERY PARTNER INFORMATION CARD
  Widget _buildLockedPartnerCard({
    required Map<String, dynamic> orderData,
    required Map<String, dynamic>? trackingData,
  }) {
    final partnerName = trackingData?['deliveryPartnerName']?.toString() ??
        orderData['deliveryPartnerName']?.toString() ??
        'Suresh Kumar';
    final partnerPhone = trackingData?['deliveryPartnerPhone']?.toString() ??
        orderData['deliveryPartnerPhone']?.toString() ??
        '+91 98765 43210';
    final isAssigned = (trackingData?['partnerAssigned'] == true) ||
        orderData['deliveryPartnerName'] != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: const BoxDecoration(
              color: AppColors.lightTeal,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.two_wheeler_rounded,
              color: AppColors.teal,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        partnerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepTeal,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAssigned
                            ? AppColors.lightLime
                            : AppColors.lightOrange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isAssigned ? 'Assigned' : 'Searching',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isAssigned
                              ? AppColors.success
                              : AppColors.goldenOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Delivery Partner • $partnerPhone',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Call Partner',
            icon: const Icon(Icons.phone_rounded,
                color: AppColors.deepTeal, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.lightTeal,
              padding: const EdgeInsets.all(10),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: partnerPhone));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Delivery partner phone copied: $partnerPhone'),
                  backgroundColor: AppColors.teal,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // PAYMENT STATUS CARD
  Widget _buildLockedPaymentCard({
    required Map<String, dynamic> groupData,
    required Map<String, dynamic> orderData,
    required String orderId,
  }) {
    final paidByName = groupData['paidByName']?.toString() ??
        orderData['customerName']?.toString() ??
        'Group Host';
    final total = (groupData['restaurantTotal'] as num?)?.toDouble() ??
        (orderData['totalAmount'] as num?)?.toDouble() ??
        0.0;

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
                    'Restaurant Payment Status',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepTeal,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lightLime,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 13, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      'PAID',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _groupStatRow('Paid by', '$paidByName (Host)'),
          const SizedBox(height: 6),
          _groupStatRow('Method', 'Razorpay Online (Test Mode)'),
          const SizedBox(height: 6),
          _groupStatRow('Total Paid', '₹${total.toStringAsFixed(2)}',
              valueColor: AppColors.teal),
          const SizedBox(height: 6),
          _groupStatRow('Order ID', '#$orderId'),
        ],
      ),
    );
  }

  // GROUP MEMBER DETAILS CARD (Full Member List)
  Widget _buildLockedMembersCard({required Map<String, dynamic> groupData}) {
    final createdBy = groupData['createdBy']?.toString();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.membersStream(widget.groupId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = snapshot.data!.docs;

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
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded,
                          color: AppColors.teal, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Group Members (${members.length}/10)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepTeal,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Reusable Group',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...members.map((memberDoc) {
                final data = memberDoc.data();
                final name = (data['name'] ?? 'Member').toString().trim();
                final initial = name.isNotEmpty
                    ? name.substring(0, 1).toUpperCase()
                    : 'M';
                final isCreator = memberDoc.id == createdBy;
                final isCurrent = memberDoc.id == service.userId;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isCreator
                            ? const Color(0xFFFFE8D6)
                            : AppColors.lightTeal,
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isCreator
                                ? AppColors.goldenOrange
                                : AppColors.teal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$name${isCurrent ? ' (You)' : ''}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isCurrent
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: AppColors.deepTeal,
                              ),
                            ),
                            Text(
                              isCreator ? 'Group Creator / Host' : 'Member',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCreator
                              ? AppColors.lightOrange
                              : AppColors.lightLime,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCreator ? 'Host' : 'Active',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isCreator
                                ? AppColors.goldenOrange
                                : AppColors.success,
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

  // INDIVIDUAL SPLIT-PAYMENT DETAILS CARD
  Widget _buildLockedSplitDetailsCard({
    required Map<String, dynamic> groupData,
    required Map<String, dynamic> orderData,
  }) {
    final members = (groupData['members'] as List<dynamic>?) ?? [];
    // Only show split option if there are at least two members in the group
    if (members.length < 2) {
      return const SizedBox.shrink();
    }

    final rawShares = groupData['splitMembers'];
    final shares = <Map<String, dynamic>>[];
    if (rawShares is List) {
      for (final it in rawShares) {
        if (it is Map) shares.add(Map<String, dynamic>.from(it));
      }
    }

    final totalBill = (groupData['restaurantTotal'] as num?)?.toDouble() ??
        (orderData['totalAmount'] as num?)?.toDouble() ??
        0.0;
    final createdBy = groupData['createdBy']?.toString();
    final isCreator = service.userId == createdBy;

    // Find current user's share
    Map<String, dynamic>? myShare;
    for (final s in shares) {
      if (s['userId'] == service.userId) {
        myShare = s;
        break;
      }
    }

    final mySharePaid = myShare != null && myShare['paymentStatus'] == 'paid';
    final myShareAmount = (myShare?['amountDue'] as num?)?.toDouble() ?? 0.0;

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
                  Icon(Icons.call_split_rounded,
                      color: AppColors.teal, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Individual Split-Payment',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepTeal,
                    ),
                  ),
                ],
              ),
              if (shares.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.lightTeal,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${shares.where((s) => s['paymentStatus'] == 'paid').length}/${shares.length} Paid',
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

          // If no split created yet
          if (shares.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightTeal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Total bill of ₹${totalBill.toStringAsFixed(2)} was paid in full by the host.',
                    style: const TextStyle(
                      color: AppColors.deepTeal,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Individual split shares have not been published yet.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 11.5),
                  ),
                  if (isCreator) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.call_split_rounded, size: 16),
                      label: const Text('Create Split Bill Now'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => GroupSplitBillScreen(
                              groupId: widget.groupId,
                              totalamount: totalBill,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            // Current User's Personal Share Card
            if (!isCreator && myShare != null) ...[
              if (mySharePaid)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 12),
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
                            fontSize: 12.5,
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
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.lightOrange,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.goldenOrange.withValues(alpha: 0.4),
                    ),
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
                                  groupId: widget.groupId,
                                  memberUserId: service.userId,
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
            ],

            // Member breakdown list
            ...shares.map((share) {
              final name = share['name']?.toString() ?? 'Member';
              final amount = (share['amountDue'] as num?)?.toDouble() ?? 0.0;
              final isPaid = share['paymentStatus'] == 'paid';
              final isMe = share['userId'] == service.userId;
              final isHost = share['userId'] == createdBy;

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
                        isPaid ? Icons.check : Icons.access_time_rounded,
                        size: 13,
                        color: isPaid
                            ? AppColors.success
                            : AppColors.goldenOrange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$name${isMe ? ' (You)' : ''}${isHost ? ' (Host)' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isMe ? FontWeight.w800 : FontWeight.w600,
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
                    else if (isCreator)
                      TextButton(
                        onPressed: () {
                          final msg =
                              'Hi $name! Please pay your food split share of ₹${amount.toStringAsFixed(0)} for ${groupData['groupName']}.';
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
                      )
                    else
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
        ],
      ),
    );
  }

  // REUSABLE GROUPS: START NEW GROUP ORDER
  Future<void> _startNewGroupOrder(String groupName) async {
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightTeal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.replay_rounded, color: AppColors.teal),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Start New Group Order?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepTeal,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Start a fresh order for "$groupName"?\n\n'
          '• Previous order is safely archived in group history.\n'
          '• All current members remain in this group.\n'
          '• Everyone can immediately choose dishes from any restaurant.',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.charcoalBlack,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Start Order',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldStart == true) {
      setState(() => _isResettingGroup = true);
      try {
        await service.resetGroupForNewOrder(widget.groupId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'New group order started! Add items from any restaurant.'),
            backgroundColor: AppColors.teal,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to reset group: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      } finally {
        if (mounted) setState(() => _isResettingGroup = false);
      }
    }
  }

  // PAY MY SPLIT SHARE (RAZORPAY TEST MODE)
  Future<void> _payMyShare({
    required String groupId,
    required String memberUserId,
    required String memberName,
    required double amount,
  }) async {
    setState(() => _isPayingShare = true);
    await _razorpayService.startSplitPayment(
      groupId: groupId,
      memberUserId: memberUserId,
      memberName: memberName,
      amountInRupees: amount,
    );
  }

  // STAGE & STATUS HELPERS
  int _getStageIndex(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
      case 'confirmed':
        return 0;
      case 'preparing':
      case 'food_ready':
        return 1;
      case 'ready_for_pickup':
      case 'partner_assigned':
        return 2;
      case 'picked_up':
      case 'on_the_way':
      case 'out_for_delivery':
        return 3;
      case 'delivered':
      case 'completed':
        return 4;
      default:
        return 0;
    }
  }

  String _getDistanceText(int stageIndex) {
    switch (stageIndex) {
      case 0:
        return 'Order confirmed with restaurant';
      case 1:
        return 'Food freshly prepared in kitchen';
      case 2:
        return 'Delivery partner assigned';
      case 3:
        return 'Partner on the way with your food';
      case 4:
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

  // ACCESS RESTRICTED SCREEN (RULE 5 & 6)
  Widget _buildAccessRestrictedScreen(BuildContext context, Map<String, dynamic> groupData) {
    final groupName = groupData['groupName']?.toString() ?? 'Group Order';
    final controller = TextEditingController();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.lightOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 56,
                color: AppColors.goldenOrange,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Private Group Order',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.deepTeal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only the creator and successfully joined members can see and access "$groupName".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Join with Group Code',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.deepTeal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ask the group creator to share the 6-character Group Code.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Enter 6-character Group Code (e.g. 7K2X9P)',
                      prefixIcon: Icon(Icons.vpn_key_rounded, size: 18, color: AppColors.teal),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Join This Group', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final input = controller.text.trim();
                        if (input.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter the 6-character Group Code.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        try {
                          await service.joinGroup(input);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Successfully joined! Access unlocked.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Go Back'),
              style: TextButton.styleFrom(foregroundColor: AppColors.deepTeal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupNotFound(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_off_rounded, size: 64, color: AppColors.mutedText),
            const SizedBox(height: 16),
            const Text(
              'Group Order Not Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.deepTeal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This group order does not exist or may have been deleted.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText, fontSize: 13),
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
    );
  }

  // GROUP HEADER

  Widget _buildHeader(Map<String, dynamic> groupData) {
    final inviteCode = groupData['inviteCode']?.toString() ?? '';
    final groupName = groupData['groupName']?.toString() ?? 'Group Order';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.deepTeal,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  groupName,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldenOrange,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => _shareInviteCode(
                  inviteCode: inviteCode,
                  groupName: groupName,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Private group: Only invited friends with this Code can see or enter this order.',
            style: TextStyle(color: AppColors.white.withOpacity(0.70), fontSize: 11.5),
          ),
          const SizedBox(height: 16),

          // Group Code Container (Code Only)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.vpn_key_rounded, color: AppColors.white, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'GROUP CODE: ',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  inviteCode,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy Code',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.copy_rounded, color: AppColors.white, size: 20),
                  onPressed: () => _copyText(inviteCode, 'Group Code'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                  label: const Text(
                    'Group Chat',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupChatScreen(groupId: widget.groupId),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.white.withValues(alpha: 0.12),
                    foregroundColor: AppColors.white,
                    side: BorderSide(
                      color: AppColors.white.withValues(alpha: 0.28),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.how_to_vote_rounded, size: 18),
                  label: const Text(
                    'Voting',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupVotingScreen(groupId: widget.groupId),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // GROUP MEMBERS

  Widget _buildMembers() {
    return StreamBuilder<QuerySnapshot>(
      stream: service.membersStream(widget.groupId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 70,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final members = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: AppColors.teal),
              const SizedBox(width: 8),
              Text(
                'Members (${members.length}/10)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ...members.take(4).map((member) {
                final data = member.data() as Map<String, dynamic>;

                final rawName = data['name'];

                final name = rawName == null ? '' : rawName.toString().trim();

                final initial = name.isNotEmpty
                    ? name.substring(0, 1).toUpperCase()
                    : 'C';

                return Container(
                  margin: const EdgeInsets.only(left: 5),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.lightTeal,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // CATEGORY CARDS

  String? _selectedRestaurantName(Map<String, dynamic> groupData) {
    final name =
        selectedRestaurant?.name ?? groupData['restaurantName']?.toString();
    return name == null || name.isEmpty ? null : name;
  }

  String _selectedCategoryName(Map<String, dynamic> groupData) {
    final savedCategory = groupData['selectedCategory']?.toString();
    return categories.any((category) => category['name'] == savedCategory)
        ? savedCategory!
        : selectedCategory;
  }

  Future<void> _selectRestaurant(RestaurantModel restaurant) async {
    final conflict = await service.checkGroupConflict(
      groupId: widget.groupId,
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
    );

    if (conflict.hasConflict) {
      if (!mounted) return;
      final shouldClear = await showRestaurantConflictDialog(
        context,
        existingRestaurantName: conflict.existingRestaurantName,
        newRestaurantName: restaurant.name,
        isGroupOrder: true,
        actionButtonText: 'Clear & Switch',
      );

      if (shouldClear != true) {
        return; // Keep existing restaurant
      }

      try {
        await service.clearGroupCartAndSelectRestaurant(
          groupId: widget.groupId,
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
        );
        setState(() => selectedRestaurant = restaurant);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group cart cleared. Switched to ${restaurant.name}.'),
            backgroundColor: AppColors.teal,
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to switch restaurant: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => selectedRestaurant = restaurant);
    try {
      await service.selectRestaurant(
        groupId: widget.groupId,
        restaurantId: restaurant.id,
        restaurantName: restaurant.name,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save selected restaurant: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _clearSelectedRestaurant() async {
    setState(() => selectedRestaurant = null);
    try {
      await service.selectRestaurant(
        groupId: widget.groupId,
        restaurantId: '',
        restaurantName: '',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to clear selected restaurant: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _saveSelectedCategory(String category) async {
    try {
      await service.selectCategory(groupId: widget.groupId, category: category);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save selected category: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildRestaurants({required Map<String, dynamic> groupData}) {
    return StreamBuilder<List<RestaurantModel>>(
      stream: restaurantService.getRestaurants(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Unable to load restaurants: ${snapshot.error}',
              style: const TextStyle(color: AppColors.error),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox(
            height: 110,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final restaurants = snapshot.data!;
        if (restaurants.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'No restaurants are available right now.',
              style: TextStyle(color: AppColors.mutedText),
            ),
          );
        }

        return SizedBox(
          height: 148,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: restaurants.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final restaurant = restaurants[index];
              final savedRestaurantId =
                  groupData['restaurantId']?.toString() ?? '';
              final isSelected =
                  (selectedRestaurant?.id ?? savedRestaurantId) ==
                  restaurant.id;
              return SizedBox(
                width: 132,
                child: Material(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(15),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: restaurant.isAvailable
                        ? () => _selectRestaurant(restaurant)
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected ? AppColors.teal : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  restaurant.imageUrl.isEmpty
                                      ? const ColoredBox(
                                          color: AppColors.lightTeal,
                                          child: Icon(
                                            Icons.restaurant_rounded,
                                            color: AppColors.teal,
                                            size: 34,
                                          ),
                                        )
                                      : Image.network(
                                          restaurant.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const ColoredBox(
                                                color: AppColors.lightTeal,
                                                child: Icon(
                                                  Icons.restaurant_rounded,
                                                  color: AppColors.teal,
                                                  size: 34,
                                                ),
                                              ),
                                        ),
                                  if (!restaurant.isAvailable)
                                    ColoredBox(
                                      color: AppColors.deepTeal.withValues(
                                        alpha: 0.6,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Currently unavailable',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restaurant.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.deepTeal,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  restaurant.cuisine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.mutedText,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategories({required Map<String, dynamic> groupData}) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];

          final categoryName = category['name'] as String;
          final isSelected = _selectedCategoryName(groupData) == categoryName;

          return GestureDetector(
            onTap: () {
              setState(() => selectedCategory = categoryName);
              _saveSelectedCategory(categoryName);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 85,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.teal : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? AppColors.teal
                      : AppColors.border,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.teal
                              .withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: category['color'],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      category['icon'],
                      color: AppColors.deepTeal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    category['name'],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : AppColors.deepTeal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // FIRESTORE FOOD LIST

  Widget _buildFoodList({required Map<String, dynamic> groupData}) {
    return StreamBuilder<List<FoodItemModel>>(
      stream: restaurantService.getFoodItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Text(
                'Error loading menu items: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(35),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final foods = snapshot.data ?? [];
        final restaurantId =
            selectedRestaurant?.id ??
            groupData['restaurantId']?.toString() ??
            '';
        final restaurantName =
            selectedRestaurant?.name ??
            groupData['restaurantName']?.toString() ??
            '';
        final hasSelectedRestaurant =
            restaurantId.isNotEmpty && restaurantName.isNotEmpty;
        final filteredFoods = hasSelectedRestaurant
            ? foods.where((food) {
                return food.belongsToRestaurant(
                  restaurantId: restaurantId,
                  restaurantName: restaurantName,
                );
              }).toList()
            : foods;

        if (filteredFoods.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(35),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.restaurant_menu_rounded,
                      size: 45,
                      color: AppColors.teal,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      !hasSelectedRestaurant
                          ? 'No menu items available'
                          : 'No menu items found for $restaurantName',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.deepTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (hasSelectedRestaurant)
                      const Text(
                        'Choose another restaurant to view its menu.',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        return Consumer(
          builder: (context, ref, _) => ref
              .watch(groupCartProvider(widget.groupId))
              .when(
                data: (cartSnapshot) {
                  final myQuantities = _myQuantities(cartSnapshot);

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final food = filteredFoods[index];
                        return ValueListenableBuilder<int?>(
                          valueListenable: _quantityNotifier(food.id),
                          builder: (context, optimisticQuantity, _) =>
                              _buildFoodCard(
                                key: ValueKey(food.id),
                                food: food,
                                quantity:
                                    optimisticQuantity ??
                                    myQuantities[food.id] ??
                                    0,
                              ),
                        );
                      }, childCount: filteredFoods.length),
                    ),
                  );
                },
                error: (error, stackTrace) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Unable to load saved item quantities: $error',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  );
                },
                loading: () {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                },
              ),
        );
      },
    );
  }

  // FOOD CARD

  Widget _buildFoodCard({
    required Key key,
    required FoodItemModel food,
    required int quantity,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECE8E0)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _showFoodDetails(food),
            borderRadius: BorderRadius.circular(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: food.image.isNotEmpty
                  ? Image.network(
                      food.image,
                      width: 105,
                      height: 105,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _foodPlaceholder(),
                    )
                  : _foodPlaceholder(),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _showFoodDetails(food),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepTeal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${food.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildQuantityControl(food: food, quantity: quantity),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityControl({
    required FoodItemModel food,
    required int quantity,
  }) {
    if (quantity == 0) {
      return SizedBox(
        height: 34,
        child: ElevatedButton.icon(
          onPressed: () {
            addFood(
              foodId: food.id,
              name: food.name,
              image: food.image,
              price: food.price,
              restaurantId: food.restaurantId,
              restaurantName: food.restaurant,
            );
          },
          icon: const Icon(Icons.add, size: 17),
          label: const Text('Add'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              _changeFoodQuantity(
                foodId: food.id,
                name: food.name,
                image: food.image,
                price: food.price,
                currentQuantity: quantity,
                changeBy: -1,
                restaurantId: food.restaurantId,
                restaurantName: food.restaurant,
              );
            },
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(
              Icons.remove_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            onPressed: () {
              _changeFoodQuantity(
                foodId: food.id,
                name: food.name,
                image: food.image,
                price: food.price,
                currentQuantity: quantity,
                changeBy: 1,
                restaurantId: food.restaurantId,
                restaurantName: food.restaurant,
              );
            },
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _showFoodDetails(FoodItemModel food) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final cart = ref.watch(groupCartProvider(widget.groupId));
            final quantity = cart.maybeWhen(
              data: (snapshot) => _myQuantities(snapshot)[food.id] ?? 0,
              orElse: () => 0,
            );

            return SingleChildScrollView(
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
                      child: food.image.isEmpty
                          ? _foodPlaceholder()
                          : Image.network(
                              food.image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _foodPlaceholder(),
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
                  if (food.restaurant.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      food.restaurant,
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _detailChip(food.category),
                      if (food.rating > 0)
                        _detailChip('${food.rating.toStringAsFixed(1)} ★'),
                      if (food.time.isNotEmpty) _detailChip(food.time),
                      _detailChip(food.isVeg ? 'Veg' : 'Non-veg'),
                    ],
                  ),
                  if (food.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      food.description,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '₹${food.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<int?>(
                        valueListenable: _quantityNotifier(food.id),
                        builder: (context, optimisticQuantity, _) =>
                            _buildQuantityControl(
                              food: food,
                              quantity: optimisticQuantity ?? quantity,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _detailChip(String label) {
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

  Widget _foodPlaceholder() {
    return Container(
      width: 105,
      height: 105,
      color: AppColors.lightTeal,
      child: const Icon(
        Icons.fastfood_rounded,
        size: 35,
        color: AppColors.teal,
      ),
    );
  }

  // SHARED CART

  Widget _buildBottomCart() {
    return Consumer(
      builder: (context, ref, _) => ref
          .watch(groupCartProvider(widget.groupId))
          .when(
            data: (snapshot) {
              final cartItems = snapshot.docs;

              double total = 0;
              int quantity = 0;

              for (final item in cartItems) {
                final data = item.data();

                final price = getPrice(data['price']);
                final qty = int.tryParse('${data['quantity'] ?? 1}') ?? 1;

                total += price * qty;
                quantity += qty;
              }

              return Container(
                padding: const EdgeInsets.fromLTRB(20, 13, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$quantity items in group cart',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '₹${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepTeal,
                            ),
                          ),
                        ],
                      ),
                    ),

                    ElevatedButton(
                      onPressed: cartItems.isEmpty
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    GroupCartScreen(groupId: widget.groupId),
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 19,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'Group Cart  →',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
            error: (error, stackTrace) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Unable to load group cart: $error',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
    );
  }
}
