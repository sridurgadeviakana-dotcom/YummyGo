import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/address_model.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/services/address_service.dart';
import 'package:yummy_go_application/services/group_order_service.dart';
import 'package:yummy_go_application/services/order_service.dart';
import 'package:yummy_go_application/services/payment_service.dart';
import 'package:yummy_go_application/views/delivery_address_screen.dart';
import 'package:yummy_go_application/views/group_order_status.dart';
import 'package:yummy_go_application/views/order_tracking_screen.dart';
import 'package:yummy_go_application/views/payment_success_screen.dart';
import 'package:yummy_go_application/views/split_bill_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class GroupCartScreen extends StatefulWidget {
  final String groupId;

  const GroupCartScreen({super.key, required this.groupId});

  @override
  State<GroupCartScreen> createState() => _GroupCartScreenState();
}

class _GroupCartScreenState extends State<GroupCartScreen> {
  final GroupOrderService _service = GroupOrderService();
  final AddressService _addressService = AddressService();
  final OrderService _orderService = OrderService();
  late final RazorpayService _razorpayService;
  String? _paymentStatus;
  AddressModel? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _loadInitialAddress();
    _razorpayService = RazorpayService(
      onSuccess: (message) {
        if (!mounted) return;
        setState(() => _paymentStatus = message);
      },
      onFailure: (message) {
        if (!mounted) return;
        setState(() => _paymentStatus = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onGroupPaymentSuccess: (orderId, paymentId, totalAmount) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              orderId: orderId,
              paymentId: paymentId,
              restaurantName: 'YummyGo Restaurant',
              totalAmount: totalAmount,
              paymentStatus: 'Paid',
              groupId: widget.groupId,
              onSplitBill: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupSplitBillScreen(
                      groupId: widget.groupId,
                      totalamount: totalAmount,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  Future<void> _loadInitialAddress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final defaultAddr = await _addressService.getDefaultOrFirstAddress(uid);
      if (mounted && defaultAddr != null && _selectedAddress == null) {
        setState(() => _selectedAddress = defaultAddr);
      }
    }
  }

  Future<void> _selectGroupAddress(Map<String, dynamic> groupData) async {
    final picked = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryAddressScreen(
          orderType: OrderType.group,
          groupId: widget.groupId,
          initialAddress: _selectedAddress,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedAddress = picked);
      await FirebaseFirestore.instance.collection('group_orders').doc(widget.groupId).set({
        'deliveryAddress': picked.formattedAddress,
        'receiverDetails': picked.toMap(),
        'deliveryLatitude': picked.latitude,
        'deliveryLongitude': picked.longitude,
        'customerLatitude': picked.latitude,
        'customerLongitude': picked.longitude,
        'deliveryInstructions': picked.deliveryInstructions,
      }, SetOptions(merge: true));
    }
  }

  Widget _buildGroupDeliveryAddressCard(BuildContext context, Map<String, dynamic> groupData) {
    AddressModel? addr = _selectedAddress;
    if (addr == null && groupData['receiverDetails'] is Map) {
      addr = AddressModel.fromMap('saved', Map<String, dynamic>.from(groupData['receiverDetails'] as Map));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: addr != null ? AppColors.teal : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on_rounded, color: AppColors.teal, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Group Delivery Address',
                    style: TextStyle(
                      color: AppColors.deepTeal,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _selectGroupAddress(groupData),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  addr == null ? 'Select Address' : 'Change',
                  style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (addr == null) ...[
            InkWell(
              onTap: () => _selectGroupAddress(groupData),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warmIvory,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_location_alt_rounded, size: 16, color: AppColors.teal),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap to choose from saved addresses',
                        style: TextStyle(color: AppColors.deepTeal, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.mutedText),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text(
              '${addr.label.toUpperCase()} • ${addr.receiverName} (${addr.receiverPhone})',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.deepTeal),
            ),
            const SizedBox(height: 2),
            Text(
              addr.formattedAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _changeQuantity(String itemId, int quantity) async {
    try {
      await _service.updateQuantity(
        groupId: widget.groupId,
        itemId: itemId,
        quantity: quantity,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update group cart: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildGroupNotFound(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_off_rounded, size: 54, color: AppColors.mutedText),
            const SizedBox(height: 14),
            const Text(
              'Group Not Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.deepTeal,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This group order no longer exists or the link is invalid.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessRestrictedScreen(BuildContext context, Map<String, dynamic> groupData) {
    final groupName = groupData['groupName']?.toString() ?? 'Group Order';

    return Center(
      child: Padding(
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
              'Private Group Cart',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.deepTeal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only the creator and joined members can view or checkout the cart for "$groupName". Join using the Group Code.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Return to Safety'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: CommonAppBar(
        title: 'Group Cart',
        subtitle: 'Shared Order',
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lightTeal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.groups_rounded, size: 14, color: AppColors.teal),
                SizedBox(width: 4),
                Text(
                  'SHARED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),
          ),
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _service.groupStream(widget.groupId),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.teal));
          }

          if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) {
            return _buildGroupNotFound(context);
          }

          final groupData = groupSnapshot.data?.data() ?? {};
          final memberUids = List<String>.from(groupData['memberUids'] ?? []);
          final isMember = memberUids.contains(_service.userId) ||
              groupData['createdBy'] == _service.userId;

          // RULE 5 & 6: Only the creator and successfully joined members can see and access this group.
          // Other users cannot see or enter it.
          if (!isMember) {
            return _buildAccessRestrictedScreen(context, groupData);
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _service.cartStream(widget.groupId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Unable to load group cart: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.teal));
              }

              final items = snapshot.data?.docs ?? [];
              if (items.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 52,
                          color: AppColors.teal,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Your group cart is empty',
                          style: TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Add items from the group menu to see them here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                );
              }

              var total = 0.0;
              var count = 0;
              for (final item in items) {
                final data = item.data();
                final quantity = (data['quantity'] as num?)?.toInt() ?? 1;
                final price = (data['price'] as num?)?.toDouble() ?? 0;
                count += quantity;
                total += price * quantity;
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final data = item.data();
                        final name = data['foodName']?.toString() ?? 'Food item';
                        final image = data['image']?.toString() ?? '';
                        final price = (data['price'] as num?)?.toDouble() ?? 0;
                        final quantity = (data['quantity'] as num?)?.toInt() ?? 1;
                        final memberName =
                            data['memberName']?.toString() ?? 'Group member';

                        return Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 76,
                                  height: 76,
                                  child: image.isEmpty
                                      ? const ColoredBox(
                                          color: AppColors.lightTeal,
                                          child: Icon(
                                            Icons.fastfood_rounded,
                                            color: AppColors.teal,
                                          ),
                                        )
                                      : Image.network(
                                          image,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const ColoredBox(
                                                color: AppColors.lightTeal,
                                                child: Icon(
                                                  Icons.fastfood_rounded,
                                                  color: AppColors.teal,
                                                ),
                                              ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.deepTeal,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Added by $memberName',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.mutedText,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${(price * quantity).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: AppColors.deepTeal,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.lightTeal,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          _changeQuantity(item.id, quantity - 1),
                                      icon: const Icon(
                                        Icons.remove_rounded,
                                        color: AppColors.deepTeal,
                                        size: 18,
                                      ),
                                    ),
                                    Text(
                                      '$quantity',
                                      style: const TextStyle(
                                        color: AppColors.deepTeal,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          _changeQuantity(item.id, quantity + 1),
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        color: AppColors.deepTeal,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.deepTeal.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$count items in group cart',
                                  style: const TextStyle(
                                    color: AppColors.mutedText,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppColors.deepTeal,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lightTeal,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.science_outlined,
                                  color: AppColors.deepTeal,
                                  size: 19,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Razorpay test mode — no real money will be charged.',
                                    style: TextStyle(
                                      color: AppColors.deepTeal,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_paymentStatus != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _paymentStatus!,
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          _buildCartCheckoutActions(context, groupData, total),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCartCheckoutActions(
    BuildContext context,
    Map<String, dynamic> groupData,
    double total,
  ) {
    final payment = groupData['restaurantPayment'] as Map?;
    final payerId =
        payment?['paidBy']?.toString() ?? groupData['paidBy']?.toString();
    final isPaid = groupData['paymentStatus'] == 'paid' || payerId != null;
    final splitCreated = groupData['split'] != null;

    if (isPaid) {
      final effectiveOrderId =
          groupData['orderId']?.toString() ?? widget.groupId;
      final split = groupData['split'] as Map<String, dynamic>?;
      final rawShares = groupData['splitMembers'];
      final shares = rawShares is List
          ? rawShares.whereType<Map>().map((share) {
              final amount = (share['amountDue'] as num?)?.toDouble() ?? 0;
              return SplitMember(
                userId: share['userId']?.toString(),
                name: share['name']?.toString() ?? 'Group member',
                amount: amount,
                isPaid: share['paymentStatus'] == 'paid',
              );
            }).toList()
          : <SplitMember>[];
      final savedTotal = (split?['total'] as num?)?.toDouble() ?? total;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => OrderTrackingScreen(
                  orderId: effectiveOrderId,
                  groupId: widget.groupId,
                ),
              ),
            ),
            icon: const Icon(Icons.delivery_dining_rounded),
            label: const Text('Track Live Order & Details'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (payerId == _service.userId && !splitCreated)
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => GroupSplitBillScreen(
                    groupId: widget.groupId,
                    totalamount: total,
                  ),
                ),
              ),
              icon: const Icon(Icons.call_split_rounded),
              label: const Text('Create Split Bill'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: const BorderSide(color: AppColors.teal),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          if (splitCreated)
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => GroupSplitScreen(
                    orderName:
                        groupData['groupName']?.toString() ?? 'Group order',
                    orderId: widget.groupId,
                    totalAmount: savedTotal,
                    orderStatus: 'Split created',
                    members: shares,
                  ),
                ),
              ),
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('View Split Payment Status'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: const BorderSide(color: AppColors.teal),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
        ],
      );
    }

    return StreamBuilder<OrderModel?>(
      stream: _orderService.streamUserActiveOrder(_service.userId),
      builder: (context, activeSnap) {
        final activeOrder = activeSnap.data;
        if (activeOrder != null) {
          final shortId = activeOrder.id.length > 8
              ? activeOrder.id.substring(0, 8).toUpperCase()
              : activeOrder.id;
          final isGroupOrder = activeOrder.isGroupOrder;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.goldenOrange.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_clock_rounded,
                      color: AppColors.goldenOrange,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGroupOrder
                                ? 'Active Group Order in Progress'
                                : 'Active Order in Progress',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepTeal,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'You have an ongoing order (#$shortId • ${activeOrder.statusDisplay}). You cannot place a new group order until your current order is delivered.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedText,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepTeal,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(
                          orderId: activeOrder.id,
                          groupId: activeOrder.groupId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.navigation_rounded, size: 16),
                  label: const Text(
                    'Track Active Order',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGroupDeliveryAddressCard(context, groupData),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                // Pre-check for any active order before opening Razorpay
                final existingActive = await _orderService.getActiveUserOrder(_service.userId);
                if (existingActive != null) {
                  if (mounted) {
                    final shortId = existingActive.id.length > 8
                        ? existingActive.id.substring(0, 8).toUpperCase()
                        : existingActive.id;
                    final type = existingActive.isGroupOrder ? 'group' : 'individual';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'You have an active $type order in progress (#$shortId • ${existingActive.statusDisplay}). You can place a group order once your current order is delivered.',
                        ),
                        backgroundColor: AppColors.goldenOrange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  return;
                }

                AddressModel? addr = _selectedAddress;
                if (addr == null && groupData['receiverDetails'] is Map) {
                  addr = AddressModel.fromMap(
                    'saved',
                    Map<String, dynamic>.from(groupData['receiverDetails'] as Map),
                  );
                }

                if (addr == null) {
                  final picked = await Navigator.push<AddressModel>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeliveryAddressScreen(
                        orderType: OrderType.group,
                        groupId: widget.groupId,
                        initialAddress: _selectedAddress,
                      ),
                    ),
                  );
                  if (picked == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select or add a delivery address for the group order.'),
                        ),
                      );
                    }
                    return;
                  }
                  addr = picked;
                  setState(() => _selectedAddress = picked);
                  await FirebaseFirestore.instance
                      .collection('group_orders')
                      .doc(widget.groupId)
                      .set({
                    'deliveryAddress': picked.formattedAddress,
                    'receiverDetails': picked.toMap(),
                    'deliveryLatitude': picked.latitude,
                    'deliveryLongitude': picked.longitude,
                    'customerLatitude': picked.latitude,
                    'customerLongitude': picked.longitude,
                    'deliveryInstructions': picked.deliveryInstructions,
                  }, SetOptions(merge: true));
                }

                await _razorpayService.startPayment(
                  groupId: widget.groupId,
                  amountInRupees: total,
                  address: addr,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Pay Group Order (Test)'),
            ),
          ],
        );
      },
    );
  }
}
