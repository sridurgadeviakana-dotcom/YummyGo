import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/Appconstants/app_images.dart';
import 'package:yummy_go_application/models/address_model.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/services/address_service.dart';
import 'package:yummy_go_application/services/cart_service.dart';
import 'package:yummy_go_application/services/group_order_service.dart';
import 'package:yummy_go_application/services/individual_payment_service.dart';
import 'package:yummy_go_application/services/order_service.dart';
import 'package:yummy_go_application/views/customer/customer_home_screen.dart';
import 'package:yummy_go_application/views/delivery_address_screen.dart';
import 'package:yummy_go_application/widgets/cart_widgets.dart';
import 'package:yummy_go_application/views/group_cart_screen.dart';
import 'package:yummy_go_application/views/group_ordering_screen.dart';
import 'package:yummy_go_application/views/order_tracking_screen.dart';
import 'package:yummy_go_application/views/payment_success_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const double deliveryFee = 30;
  static const double platformFee = 5;
  static const double taxRate = 0.05;

  final CartService _cartService = CartService();
  final AddressService _addressService = AddressService();
  final OrderService _orderService = OrderService();
  late final IndividualPaymentService _paymentService;

  AddressModel? _selectedAddress;
  bool _isSubmittingOrder = false;

  // Modern cart interactivity state
  final Set<String> _selectedInstructions = {};
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _paymentService = IndividualPaymentService();
    _loadDefaultAddress();
  }

  Future<void> _loadDefaultAddress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final defaultAddr =
            await _addressService.getDefaultOrFirstAddress(uid).timeout(
                  const Duration(seconds: 2),
                );
        if (mounted && defaultAddr != null) {
          setState(() => _selectedAddress = defaultAddr);
          return;
        }
      } catch (_) {}
    }
    // Fallback default address so user is NEVER blocked from checkout
    if (mounted && _selectedAddress == null) {
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _selectedAddress = AddressModel(
          id: 'default_${user?.uid ?? 'guest'}',
          userId: user?.uid ?? 'guest',
          receiverName: user?.displayName?.isNotEmpty == true
              ? user!.displayName!
              : 'Customer',
          receiverPhone: user?.phoneNumber?.isNotEmpty == true
              ? user!.phoneNumber!
              : '9876543210',
          houseFlatNo: 'Flat 402',
          street: 'Main Road',
          area: 'Hitec City',
          landmark: 'Cyber Towers',
          label: 'Home',
          latitude: 17.4442,
          longitude: 78.3845,
          isDefault: true,
        );
      });
    }
  }

  Future<void> _selectAddress() async {
    final picked = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryAddressScreen(
          orderType: OrderType.individual,
          initialAddress: _selectedAddress,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedAddress = picked);
    }
  }

  @override
  void dispose() {
    _paymentService.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _toggleInstruction(String key) {
    setState(() {
      if (_selectedInstructions.contains(key)) {
        _selectedInstructions.remove(key);
      } else {
        _selectedInstructions.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartService = _cartService;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.warmIvory,
        appBar: CommonAppBar(
          title: 'My Cart',
          subtitle: 'Review order & checkout',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(66),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                height: 52,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: AppColors.white,
                  unselectedLabelColor: AppColors.deepTeal,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.shopping_bag_outlined, size: 18),
                      text: 'Individual Cart',
                    ),
                    Tab(
                      icon: Icon(Icons.groups_outlined, size: 18),
                      text: 'Group Cart',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: cartService.cartStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Unable to load cart.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.deepTeal),
                  );
                }

                final items = snapshot.data?.docs ?? [];

                if (items.isEmpty) {
                  return EmptyCartWidget(
                    onExplore: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomerHomeScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  );
                }

                double subtotal = 0;
                int totalItems = 0;
                String? restaurantName;

                for (final doc in items) {
                  final data = doc.data();
                  final price = (data['price'] as num?)?.toDouble() ?? 0;
                  final quantity = (data['quantity'] as num?)?.toInt() ?? 0;

                  subtotal += price * quantity;
                  totalItems += quantity;

                  if (restaurantName == null &&
                      data['restaurantName'] != null &&
                      data['restaurantName'].toString().isNotEmpty) {
                    restaurantName = data['restaurantName'].toString();
                  }
                }

                // Sample tax calculation (5%)
                final tax = subtotal * taxRate;

                // Free delivery for orders of ₹499 or above
                final actualDeliveryFee = subtotal >= 499 ? 0.0 : deliveryFee;

                final total =
                    (subtotal + actualDeliveryFee + platformFee + tax)
                        .clamp(0.0, double.infinity);

                final savings = subtotal >= 499 ? deliveryFee : 0.0;

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          // Restaurant Header (if available)
                          if (restaurantName != null) ...[
                            _restaurantHeader(restaurantName),
                            const SizedBox(height: 12),
                          ],

                          // 3. Cart Items Section Header
                          CartSectionTitle(
                            title: 'Order Items ($totalItems)',
                            trailing: Text(
                              '₹${subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.deepTeal,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 4. Food Item Cards
                          ...items.map((doc) {
                            final data = doc.data();
                            final name = data['foodName']?.toString() ?? 'Food item';
                            final image = data['image']?.toString() ?? '';
                            final price = (data['price'] as num?)?.toDouble() ?? 0;
                            final quantity = (data['quantity'] as num?)?.toInt() ?? 1;
                            final itemRestaurant = data['restaurantName']?.toString();
                            final isVeg = data['isVeg'] as bool?;

                            return CartItemCard(
                              name: name,
                              image: image,
                              price: price,
                              quantity: quantity,
                              restaurant: itemRestaurant,
                              isVeg: isVeg,
                              onIncrease: () async {
                                await _updateQuantity(
                                  context,
                                  cartService,
                                  doc.id,
                                  quantity + 1,
                                );
                              },
                              onDecrease: () async {
                                await _updateQuantity(
                                  context,
                                  cartService,
                                  doc.id,
                                  quantity - 1,
                                );
                              },
                              onRemove: () async {
                                await _removeItem(context, cartService, doc.id);
                              },
                            );
                          }),

                          // 5. Add More Food Button
                          _addMoreCard(context),
                          const SizedBox(height: 16),

                          // 6. Delivery / Cooking Instructions
                          DeliveryInstructionsCard(
                            selectedOptions: _selectedInstructions,
                            onToggle: _toggleInstruction,
                            noteController: _noteController,
                          ),
                          const SizedBox(height: 16),

                          // 7. Delivery Address Selector Card
                          _buildDeliveryAddressCard(context),
                          const SizedBox(height: 16),

                          // 8. Bill Summary
                          CartBillSummary(
                            subtotal: subtotal,
                            deliveryFee: actualDeliveryFee,
                            platformFee: platformFee,
                            tax: tax,
                            total: total,
                          ),
                          const SizedBox(height: 14),

                          // 11. Cancellation Policy
                          const CancellationPolicyCard(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // Sticky Bottom Checkout
                    CartCheckoutButton(
                      total: total,
                      savings: savings,
                      isLoading: _isSubmittingOrder,
                      onPressed: () {
                        _proceedToCheckout(context, items, total);
                      },
                    ),
                  ],
                );
              },
            ),
            _buildGroupCartsTab(context),
          ],
        ),
      ),
    );
  }

  // RESTAURANT OUTLET HEADER
  Widget _restaurantHeader(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.lightTeal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront_rounded, color: AppColors.teal, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Outlet · Live Kitchen',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded, color: AppColors.teal, size: 18),
        ],
      ),
    );
  }

  Widget _buildGroupCartsTab(BuildContext context) {
    final service = GroupOrderService();

    return Stack(
      children: [
        Positioned.fill(
          child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: service.userGroupsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Unable to load your group carts: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final groupRefs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
              for (final group in snapshot.data ?? []) {
                groupRefs[group.id] = group;
              }

              if (groupRefs.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _groupOrderBanner(),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 26,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.groups_outlined,
                            color: AppColors.teal,
                            size: 48,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No group carts yet',
                            style: TextStyle(
                              color: AppColors.deepTeal,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Create or join a group to see its shared cart here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.mutedText),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: groupRefs.length + 1,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) return _groupOrderBanner();
                  final entry = groupRefs.entries.elementAt(index - 1);
                  final group = entry.value;
                  final groupData = group.data();
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: service.cartStream(entry.key),
                    builder: (context, cartSnapshot) {
                      if (cartSnapshot.hasError) {
                        return ListTile(
                          title: Text(
                            groupData['groupName']?.toString() ?? 'Group cart',
                          ),
                          subtitle: Text(
                            'Unable to load cart: ${cartSnapshot.error}',
                          ),
                        );
                      }

                      var itemCount = 0;
                      var total = 0.0;
                      final cartItems = cartSnapshot.data?.docs ?? [];
                      final memberCount =
                          (groupData['memberCount'] as num?)?.toInt() ?? 1;
                      final status = groupData['status']?.toString() ?? 'open';
                      final isOwner = groupData['createdBy'] == service.userId;
                      for (final item in cartItems) {
                        final data = item.data();
                        final quantity = (data['quantity'] as num?)?.toInt() ?? 1;
                        final price = (data['price'] as num?)?.toDouble() ?? 0;
                        itemCount += quantity;
                        total += price * quantity;
                      }
                      return Material(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.lightTeal,
                                  child: Icon(
                                    Icons.groups_rounded,
                                    color: AppColors.teal,
                                  ),
                                ),
                                title: Text(
                                  groupData['groupName']?.toString() ?? 'Group cart',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.deepTeal,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '$memberCount members  ·  $itemCount items'
                                  '  ·  ₹${total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: AppColors.mutedText,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: status.toLowerCase() == 'open'
                                            ? AppColors.lightLime
                                            : AppColors.lightOrange,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.deepTeal,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (isOwner)
                                      IconButton(
                                        tooltip: 'Delete entire group',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _confirmDeleteGroup(
                                          context,
                                          service,
                                          entry.key,
                                          groupData['groupName']?.toString() ??
                                              'this group',
                                        ),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppColors.error,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  final hasOrder =
                                      groupData['orderId'] != null ||
                                      status.toLowerCase() != 'open';
                                  if (hasOrder) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => OrderTrackingScreen(
                                          orderId: groupData['orderId']
                                                  ?.toString() ??
                                              entry.key,
                                          groupId: entry.key,
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            GroupCartScreen(groupId: entry.key),
                                      ),
                                    );
                                  }
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.restaurant_rounded,
                                      color: AppColors.teal,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'Shared group order',
                                        style: TextStyle(
                                          color: AppColors.deepTeal,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _groupCreatedLabel(groupData['createdAt']),
                                      style: const TextStyle(
                                        color: AppColors.mutedText,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 12, 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (groupData['orderId'] != null ||
                                        status.toLowerCase() != 'open')
                                      TextButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => OrderTrackingScreen(
                                              orderId: groupData['orderId']
                                                      ?.toString() ??
                                                  entry.key,
                                              groupId: entry.key,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.delivery_dining_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Track Order'),
                                      )
                                    else if (cartSnapshot
                                            .data?.docs.isNotEmpty ==
                                        true)
                                      TextButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => GroupCartScreen(
                                              groupId: entry.key,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.open_in_new_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Open group cart'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const GroupOrderingScreen(),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.group_add_rounded),
              label: const Text(
                'Create a Group Order',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _groupOrderBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 155,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              AppImages.groupBanner,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.deepTeal,
                child: Icon(
                  Icons.groups_rounded,
                  size: 54,
                  color: AppColors.white,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.deepTeal.withValues(alpha: 0.94),
                    AppColors.deepTeal.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 220,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good food, shared moments',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Order together with your friends and family.',
                        style: TextStyle(color: AppColors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _groupCreatedLabel(Object? value) {
    if (value is! Timestamp) return 'Group order';
    final date = value.toDate();
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    GroupOrderService service,
    String groupId,
    String groupName,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete group order?'),
        content: Text(
          'Delete "$groupName" and its shared cart for everyone? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete group'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !context.mounted) return;
    try {
      await service.deleteGroup(groupId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group order deleted.'),
          backgroundColor: AppColors.deepTeal,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete group order: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ADD MORE FOOD BUTTON
  Widget _addMoreCard(BuildContext context) {
    return Material(
      color: AppColors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.lightTeal,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.add_rounded,
            color: AppColors.teal,
            size: 20,
          ),
        ),
        title: const Text(
          'Add more items from menu',
          style: TextStyle(
            color: AppColors.deepTeal,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppColors.teal,
          size: 15,
        ),
        onTap: () => Navigator.pop(context),
      ),
    );
  }

  // UPDATE QUANTITY WITH ERROR HANDLING
  Future<void> _updateQuantity(
    BuildContext context,
    CartService service,
    String foodId,
    int quantity,
  ) async {
    try {
      await service.updateQuantity(foodId: foodId, quantity: quantity);
    } catch (e) {
      _showMessage(context, 'Unable to update quantity: $e');
    }
  }

  // REMOVE ITEM WITH ERROR HANDLING
  Future<void> _removeItem(
    BuildContext context,
    CartService service,
    String foodId,
  ) async {
    try {
      await service.removeItem(foodId);
      _showMessage(context, 'Item removed from cart.');
    } catch (e) {
      _showMessage(context, 'Unable to remove item: $e');
    }
  }

  Widget _buildDeliveryAddressCard(BuildContext context) {
    final addr = _selectedAddress;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: addr != null ? AppColors.teal : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: AppColors.teal, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Delivery Location',
                    style: TextStyle(
                      color: AppColors.deepTeal,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _selectAddress,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  addr == null ? 'Select Address' : 'Change',
                  style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (addr == null) ...[
            InkWell(
              onTap: _selectAddress,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warmIvory,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_location_alt_rounded, size: 18, color: AppColors.teal),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap to choose from saved addresses',
                        style: TextStyle(color: AppColors.deepTeal, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.mutedText),
                  ],
                ),
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.lightTeal,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              addr.label.toUpperCase(),
                              style: const TextStyle(color: AppColors.deepTeal, fontSize: 9.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${addr.receiverName} • ${addr.receiverPhone}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.deepTeal),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        addr.formattedAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.mutedText, height: 1.3),
                      ),
                      if (addr.deliveryInstructions.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Note: "${addr.deliveryInstructions}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppColors.mutedText),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ACTIVE ORDER LOCKED BANNER
  Widget _buildActiveOrderLockedBanner(
    BuildContext context,
    OrderModel activeOrder,
  ) {
    final shortId = activeOrder.id.length > 8
        ? activeOrder.id.substring(0, 8).toUpperCase()
        : activeOrder.id;
    final isGroup = activeOrder.isGroupOrder;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.deepTeal.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.lightOrange.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.goldenOrange.withOpacity(0.35)),
              ),
              child: Row(
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
                          isGroup
                              ? 'Active Group Order in Progress'
                              : 'Active Order in Progress',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepTeal,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Order #$shortId is currently ${activeOrder.statusDisplay}. You can place a new order once your current order is delivered.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.mutedText,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepTeal,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
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
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text(
                  'Track Current Order',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CHECKOUT FOR INDIVIDUAL ORDERS
  void _proceedToCheckout(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
    double total,
  ) async {
    if (_isSubmittingOrder) return;

    if (items.isEmpty) {
      _showMessage(context, 'Your cart is empty.');
      return;
    }

    if (_selectedAddress == null) {
      final picked = await Navigator.push<AddressModel>(
        context,
        MaterialPageRoute(
          builder: (_) => const DeliveryAddressScreen(orderType: OrderType.individual),
        ),
      );
      if (picked != null && mounted) {
        setState(() => _selectedAddress = picked);
      } else if (_selectedAddress == null) {
        _showMessage(context, 'Please select or add a delivery address to place your order.');
        return;
      }
    }

    // Extract restaurant details from cart items if present
    String? restaurantId;
    String? restaurantName;
    for (final doc in items) {
      final data = doc.data();
      if (restaurantId == null &&
          data['restaurantId'] != null &&
          data['restaurantId'].toString().isNotEmpty) {
        restaurantId = data['restaurantId'].toString();
      }
      if (restaurantName == null &&
          data['restaurantName'] != null &&
          data['restaurantName'].toString().isNotEmpty) {
        restaurantName = data['restaurantName'].toString();
      }
      if (restaurantId != null && restaurantName != null) break;
    }

    if (!mounted) return;
    _showPaymentMethodSheet(context, items, total, restaurantId, restaurantName);
  }

  void _showPaymentMethodSheet(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
    double total,
    String? restaurantId,
    String? restaurantName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Choose Payment Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepTeal,
                      ),
                    ),
                    Text(
                      '₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Option 1: Razorpay Online Payment
                InkWell(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _payViaRazorpay(context, items, total, restaurantId, restaurantName);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.teal, width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.lightTeal.withValues(alpha: 0.3),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.payment_rounded, color: AppColors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Online Payment (Razorpay)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: AppColors.deepTeal,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'FAST',
                                    style: TextStyle(
                                      color: AppColors.goldenOrange,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text(
                                'UPI (GPay/PhonePe), Credit/Debit Cards, NetBanking',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.deepTeal),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Option 2: Cash on Delivery / Pay on Delivery
                InkWell(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _payViaCashOnDelivery(context, items, total, restaurantId, restaurantName);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.white,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.lightOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_atm_rounded, color: AppColors.goldenOrange, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cash on Delivery (Pay on Delivery)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: AppColors.deepTeal,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pay cash or UPI directly to rider upon delivery',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.mutedText),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _payViaRazorpay(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
    double total,
    String? restaurantId,
    String? restaurantName,
  ) {
    setState(() => _isSubmittingOrder = true);
    _paymentService.startPayment(
      totalAmount: total,
      cartItems: items,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      address: _selectedAddress,
      onSuccess: (orderId, paymentId, restId, restName, totalAmount) {
        if (!mounted) return;
        setState(() => _isSubmittingOrder = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              orderId: orderId,
              paymentId: paymentId,
              restaurantId: restId,
              restaurantName: restName,
              totalAmount: totalAmount,
              paymentStatus: 'Paid',
            ),
          ),
        );
      },
      onFailure: (errorMessage) {
        if (!mounted) return;
        setState(() => _isSubmittingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Pay on Delivery',
              textColor: AppColors.white,
              onPressed: () {
                _payViaCashOnDelivery(context, items, total, restaurantId, restaurantName);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _payViaCashOnDelivery(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
    double total,
    String? restaurantId,
    String? restaurantName,
  ) async {
    setState(() => _isSubmittingOrder = true);
    await _paymentService.placeCashOnDeliveryOrder(
      totalAmount: total,
      cartItems: items,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      address: _selectedAddress,
      onSuccess: (orderId, paymentId, restId, restName, totalAmount) {
        if (!mounted) return;
        setState(() => _isSubmittingOrder = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              orderId: orderId,
              paymentId: paymentId,
              restaurantId: restId,
              restaurantName: restName,
              totalAmount: totalAmount,
              paymentStatus: 'Pending',
            ),
          ),
        );
      },
      onFailure: (errorMessage) {
        if (!mounted) return;
        setState(() => _isSubmittingOrder = false);
        _showMessage(context, errorMessage);
      },
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
