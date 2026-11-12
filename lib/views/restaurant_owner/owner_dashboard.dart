import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/food_items_model.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/order_service.dart';
import 'package:yummy_go_application/services/restaurant_owner_service.dart';
import 'package:yummy_go_application/views/auth/role_selection_screen.dart';
import 'package:yummy_go_application/views/restaurant_owner/menu_management.dart';
import 'package:yummy_go_application/views/restaurant_owner/restaurant_orders_screen.dart';
import 'package:yummy_go_application/views/restaurant_owner/restaurant_profile_screen.dart';

class RestaurantOwnerDashboard extends StatefulWidget {
  const RestaurantOwnerDashboard({super.key});

  @override
  State<RestaurantOwnerDashboard> createState() =>
      _RestaurantOwnerDashboardState();
}

class _RestaurantOwnerDashboardState extends State<RestaurantOwnerDashboard> {
  final RestaurantOwnerService _ownerService = RestaurantOwnerService();
  final OrderService _orderService = OrderService();
  final Set<String> _knownOrderIds = {};
  bool _isInitialLoad = true;
  StreamSubscription<List<OrderModel>>? _ordersSubscription;
  String? _subscribedRestaurantId;

  void _setupOrderListener(RestaurantModel restaurant) {
    if (_subscribedRestaurantId == restaurant.id) return;
    _subscribedRestaurantId = restaurant.id;
    _ordersSubscription?.cancel();

    _ordersSubscription = _orderService
        .streamRestaurantOrders(restaurant.id, restaurantName: restaurant.name)
        .listen((orders) {
      if (!mounted) return;
      final incoming = orders
          .where((o) => o.orderStatus == 'placed' || o.orderStatus == 'confirmed')
          .toList();

      if (_isInitialLoad) {
        _isInitialLoad = false;
        for (final o in orders) {
          _knownOrderIds.add(o.id);
        }
        return;
      }

      for (final order in incoming) {
        if (!_knownOrderIds.contains(order.id)) {
          _knownOrderIds.add(order.id);
          _showNewOrderAlert(order, restaurant);
        }
      }
    });
  }

  void _showNewOrderAlert(OrderModel order, RestaurantModel restaurant) {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    } catch (_) {}

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 7),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.goldenOrange,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.goldenOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You got an order! Please check',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${order.customerName} • ${order.items.length} items • ₹${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'CHECK',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RestaurantOrdersScreen(restaurant: restaurant),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      body: SafeArea(
        child: StreamBuilder<RestaurantModel?>(
          stream: _ownerService.streamOwnerRestaurant(),
          builder: (context, snapshot) {
            final restaurant = snapshot.data;
            if (restaurant != null) {
              _setupOrderListener(restaurant);
            }

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 17, 20, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const _OwnerTopBar(),
                      const SizedBox(height: 22),
                      _RestaurantIdentityCard(restaurant: restaurant),
                      const SizedBox(height: 17),
                      if (restaurant != null) ...[
                        if (!restaurant.isApproved) ...[
                          _RegistrationPendingBanner(restaurant: restaurant),
                        ],
                        _LiveSalesSnapshotCard(restaurant: restaurant),
                        const SizedBox(height: 25),
                        const _OwnerSectionTitle(
                          title: 'Your Workspace',
                          subtitle: 'Live tools to manage your restaurant operations',
                        ),
                        const SizedBox(height: 13),
                        _OwnerActionGrid(restaurant: restaurant),
                        const SizedBox(height: 25),
                        const _OwnerSectionTitle(
                          title: 'Live Order Queue',
                          subtitle: 'Stay on top of orders cooking in your kitchen',
                        ),
                        const SizedBox(height: 13),
                        _OrderQueuePreview(restaurant: restaurant),
                      ] else ...[
                        _RestaurantRegistrationBanner(),
                      ],
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OwnerTopBar extends StatelessWidget {
  const _OwnerTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.lightOrange,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.restaurant_rounded,
            color: AppColors.goldenOrange,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YummyGo Partner',
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'RESTAURANT OWNER',
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Switch Role / Portal',
          icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.deepTeal),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
            );
          },
        ),
        IconButton(
          tooltip: 'Logout',
          icon: const Icon(Icons.logout_rounded, color: AppColors.error),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                (r) => false,
              );
            }
          },
        ),
      ],
    );
  }
}

class _RestaurantIdentityCard extends StatelessWidget {
  final RestaurantModel? restaurant;

  const _RestaurantIdentityCard({this.restaurant});

  @override
  Widget build(BuildContext context) {
    final hasRestaurant = restaurant != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.goldenOrange, AppColors.lightOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.deepTeal,
              size: 31,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasRestaurant ? restaurant!.name : 'Set Up Your Restaurant',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepTeal,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  hasRestaurant
                      ? '${restaurant!.cuisine} • ${restaurant!.area.isNotEmpty ? restaurant!.area : "Live on YummyGo"}'
                      : 'Complete your restaurant profile to receive orders',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: !hasRestaurant
                  ? AppColors.lightOrange
                  : (!restaurant!.isApproved
                      ? AppColors.lightOrange
                      : (restaurant!.isAvailable ? AppColors.lightLime : AppColors.lightOrange)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              !hasRestaurant
                  ? 'SETUP'
                  : (!restaurant!.isApproved
                      ? 'PENDING REVIEW'
                      : (restaurant!.isAvailable ? 'OPEN' : 'CLOSED')),
              style: TextStyle(
                color: !hasRestaurant
                    ? AppColors.goldenOrange
                    : (!restaurant!.isApproved
                        ? AppColors.goldenOrange
                        : (restaurant!.isAvailable ? AppColors.success : AppColors.goldenOrange)),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationPendingBanner extends StatelessWidget {
  final RestaurantModel restaurant;

  const _RegistrationPendingBanner({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightOrange.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.goldenOrange.withOpacity(0.4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.pending_actions_rounded, color: AppColors.goldenOrange, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration Submitted for Admin Review',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.deepTeal,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Your restaurant registration is currently under Admin review. Only after Admin approves your registration can you add, edit, or manage menu items. Your restaurant will become visible to customers once approved.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveSalesSnapshotCard extends StatelessWidget {
  final RestaurantModel restaurant;

  const _LiveSalesSnapshotCard({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();
    final ownerService = RestaurantOwnerService();

    return StreamBuilder<List<OrderModel>>(
      stream: orderService.streamRestaurantOrders(
        restaurant.id,
        restaurantName: restaurant.name,
      ),
      builder: (context, orderSnap) {
        final orders = orderSnap.data ?? [];
        double totalSales = 0.0;
        int readyOrdersCount = 0;
        int newOrdersCount = 0;

        for (final o in orders) {
          if (o.orderStatus != 'cancelled') {
            totalSales += o.totalAmount;
          }
          if (o.orderStatus == 'ready_for_pickup') {
            readyOrdersCount++;
          }
          if (o.orderStatus == 'placed' || o.orderStatus == 'confirmed') {
            newOrdersCount++;
          }
        }

        return StreamBuilder<List<FoodItemModel>>(
          stream: ownerService.streamMenuItems(restaurant.id, restaurantName: restaurant.name),
          builder: (context, menuSnap) {
            final menuCount = menuSnap.data?.length ?? 0;

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 19, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.deepTeal,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TODAY AT A GLANCE',
                          style: TextStyle(
                            color: AppColors.darkBannerSubtext,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.insights_rounded,
                        color: AppColors.darkBannerAccent,
                        size: 21,
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    '₹${totalSales.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Total Sales Volume (Live)',
                    style: TextStyle(color: AppColors.darkBannerSubtext, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Container(height: 1, color: AppColors.white.withOpacity(0.16)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _SalesMiniStat(
                          icon: Icons.receipt_long_outlined,
                          label: 'Total',
                          value: '${orders.length}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SalesMiniStat(
                          icon: Icons.notifications_active_outlined,
                          label: 'New Orders',
                          value: '$newOrdersCount',
                          highlight: newOrdersCount > 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SalesMiniStat(
                          icon: Icons.inventory_2_outlined,
                          label: 'Ready',
                          value: '$readyOrdersCount',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SalesMiniStat(
                          icon: Icons.restaurant_menu_outlined,
                          label: 'Menu',
                          value: '$menuCount',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SalesMiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _SalesMiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: highlight ? AppColors.darkBannerAccent : AppColors.teal,
          size: 16,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: highlight ? AppColors.darkBannerAccent : AppColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.darkBannerSubtext,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnerSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _OwnerSectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
        ),
      ],
    );
  }
}

class _OwnerActionGrid extends StatelessWidget {
  final RestaurantModel restaurant;

  const _OwnerActionGrid({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _OwnerAction(
        title: 'Manage Orders',
        subtitle: 'Review & prepare',
        icon: Icons.receipt_long_rounded,
        background: AppColors.lightTeal,
        accent: AppColors.teal,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RestaurantOrdersScreen(restaurant: restaurant),
            ),
          );
        },
      ),
      _OwnerAction(
        title: 'Food menu',
        subtitle: restaurant.isApproved ? 'Items & prices' : 'Pending review',
        icon: Icons.menu_book_rounded,
        background: AppColors.lightOrange,
        accent: AppColors.goldenOrange,
        onTap: () {
          if (!restaurant.isApproved) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Row(
                  children: [
                    Icon(Icons.lock_clock_rounded, color: AppColors.goldenOrange),
                    SizedBox(width: 8),
                    Text('Approval Required'),
                  ],
                ),
                content: Text(
                  'Your registration for "${restaurant.name}" has been submitted to Admin for review. Only after Admin approves your registration can you add, edit, or manage menu items.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MenuManagementScreen(restaurant: restaurant),
            ),
          );
        },
      ),
      _OwnerAction(
        title: 'Restaurant Profile',
        subtitle: 'Hours & details',
        icon: Icons.storefront_rounded,
        background: AppColors.lightLime,
        accent: AppColors.success,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RestaurantProfileScreen(restaurant: restaurant),
            ),
          );
        },
      ),
      // _OwnerAction(
      //   title: 'Switch Role',
      //   subtitle: 'Customer / Partner / Admin',
      //   icon: Icons.swap_horiz_rounded,
      //   background: AppColors.lightTeal,
      //   accent: AppColors.deepTeal,
      //   onTap: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (_) => const RoleSelectionScreen(),
      //       ),
      //     );
      //   },
      // ),
      // _OwnerAction(
      //   title: 'Add New Food',
      //   subtitle: 'Upload to menu',
      //   icon: Icons.add_circle_outline_rounded,
      //   background: AppColors.lightTeal,
      //   accent: AppColors.deepTeal,
      //   onTap: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (_) => MenuManagementScreen(restaurant: restaurant),
      //       ),
      //     );
      //   },
      // ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 11) / columns;
        return Wrap(
          spacing: 11,
          runSpacing: 11,
          children: actions
              .map((a) => SizedBox(width: width, child: a))
              .toList(),
        );
      },
    );
  }
}

class _OwnerAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color accent;
  final VoidCallback onTap;

  const _OwnerAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.deepTeal,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderQueuePreview extends StatelessWidget {
  final RestaurantModel restaurant;

  const _OrderQueuePreview({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();

    return StreamBuilder<List<OrderModel>>(
      stream: orderService.streamRestaurantOrders(
        restaurant.id,
        restaurantName: restaurant.name,
      ),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? [];
        final newOrders = orders
            .where((o) => o.orderStatus == 'placed' || o.orderStatus == 'confirmed')
            .toList();
        final preparingOrders = orders
            .where((o) => o.orderStatus == 'preparing')
            .toList();
        final readyOrders = orders
            .where((o) => o.orderStatus == 'ready_for_pickup')
            .toList();
        final activeOrders = [...newOrders, ...preparingOrders, ...readyOrders];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(21),
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
                      const Text(
                        'Active Kitchen Queue',
                        style: TextStyle(
                          color: AppColors.deepTeal,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (activeOrders.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: newOrders.isNotEmpty
                                ? AppColors.lightOrange
                                : AppColors.lightTeal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${activeOrders.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: newOrders.isNotEmpty
                                  ? AppColors.goldenOrange
                                  : AppColors.teal,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RestaurantOrdersScreen(restaurant: restaurant),
                        ),
                      );
                    },
                    child: const Text('View All',
                        style: TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // VIBRANT ALERT BANNER WHEN ORDERS ARRIVE: "You got an order! Please check"
              if (newOrders.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lightOrange,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.goldenOrange, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldenOrange.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.goldenOrange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: AppColors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'You got an order! Please check',
                                  style: TextStyle(
                                    color: AppColors.deepTeal,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14.5,
                                  ),
                                ),
                                Text(
                                  '${newOrders.length} incoming order${newOrders.length > 1 ? "s" : ""} waiting for kitchen response',
                                  style: const TextStyle(
                                    color: AppColors.mutedText,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.goldenOrange,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.receipt_long_rounded, size: 17),
                          label: const Text(
                            'Check Orders & Start Cooking',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RestaurantOrdersScreen(restaurant: restaurant),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              if (activeOrders.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.warmIvory,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No orders pending. Kitchen is clear and ready!',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: activeOrders.take(5).map((order) {
                    final isNew = order.orderStatus == 'placed' ||
                        order.orderStatus == 'confirmed';
                    final isCooking = order.orderStatus == 'preparing';

                    Color badgeBg;
                    Color badgeColor;
                    String badgeText;
                    if (isNew) {
                      badgeBg = AppColors.goldenOrange;
                      badgeColor = AppColors.white;
                      badgeText = 'NEW • CHECK';
                    } else if (isCooking) {
                      badgeBg = AppColors.teal;
                      badgeColor = AppColors.white;
                      badgeText = 'COOKING';
                    } else {
                      badgeBg = AppColors.lightLime;
                      badgeColor = AppColors.success;
                      badgeText = 'READY';
                    }

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RestaurantOrdersScreen(restaurant: restaurant),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isNew
                              ? AppColors.lightOrange
                              : AppColors.warmIvory,
                          borderRadius: BorderRadius.circular(14),
                          border: isNew
                              ? Border.all(
                                  color: AppColors.goldenOrange
                                      .withValues(alpha: 0.4))
                              : null,
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
                                      Text(
                                        order.customerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.deepTeal,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '#${order.id}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.mutedText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${order.items.length} item(s): ${order.items.map((it) => "${it.quantity}x ${it.name}").join(", ")}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.mutedText),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₹${order.totalAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: AppColors.deepTeal,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isNew)
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await orderService.updateOrderStatus(
                                          order.id, 'preparing');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Order #${order.id} accepted & preparing in kitchen!'),
                                            backgroundColor: AppColors.goldenOrange,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.goldenOrange,
                                      foregroundColor: AppColors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.soup_kitchen_rounded,
                                        size: 14),
                                    label: const Text(
                                      'Accept & Prepare',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  )
                                else if (isCooking)
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await orderService.updateOrderStatus(
                                          order.id, 'ready_for_pickup');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Order #${order.id} marked ready for pickup!'),
                                            backgroundColor: AppColors.teal,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.deepTeal,
                                      foregroundColor: AppColors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.check_circle_rounded,
                                        size: 14),
                                    label: const Text(
                                      'Mark Ready for Pickup',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  )
                                else
                                  const Text(
                                    'Waiting for rider pickup',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.teal,
                                        fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RestaurantRegistrationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.add_business_rounded, size: 52, color: AppColors.goldenOrange),
          const SizedBox(height: 14),
          const Text(
            'Register Your Restaurant',
            style: TextStyle(
              color: AppColors.deepTeal,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Link or create your restaurant profile on YummyGo to start adding food items and receiving customer orders.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldenOrange,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Restaurant Profile', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _showRegisterRestaurantDialog(context),
          ),
        ],
      ),
    );
  }

  void _showRegisterRestaurantDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final branchCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final cuisineCtrl = TextEditingController();
    final deliveryTimeCtrl = TextEditingController(text: '30-40 min');
    final service = RestaurantOwnerService();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Restaurant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Restaurant Name *')),
              const SizedBox(height: 12),
              TextField(controller: branchCtrl, decoration: const InputDecoration(labelText: 'Branch Name')),
              const SizedBox(height: 12),
              TextField(controller: areaCtrl, decoration: const InputDecoration(labelText: 'Area / Location *')),
              const SizedBox(height: 12),
              TextField(controller: cuisineCtrl, decoration: const InputDecoration(labelText: 'Cuisine (e.g. Biryani, Pizzas)')),
              const SizedBox(height: 12),
              TextField(controller: deliveryTimeCtrl, decoration: const InputDecoration(labelText: 'Delivery Time')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldenOrange,
              foregroundColor: AppColors.white,
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || areaCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in Restaurant Name and Area'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              // Show loading dialog
              showDialog(
                context: ctx,
                barrierDismissible: false,
                builder: (_) => const PopScope(
                  canPop: false,
                  child: Center(
                    child: Card(
                      color: AppColors.white,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.teal),
                            SizedBox(width: 16),
                            Text(
                              'Registering restaurant...',
                              style: TextStyle(
                                color: AppColors.deepTeal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );

              try {
                await service.registerRestaurant(
                  name: nameCtrl.text.trim(),
                  branchName: branchCtrl.text.trim(),
                  area: areaCtrl.text.trim(),
                  cuisine: cuisineCtrl.text.trim().isEmpty ? 'Multi-Cuisine' : cuisineCtrl.text.trim(),
                  deliveryTime: deliveryTimeCtrl.text.trim(),
                );

                // Close loading dialog
                if (ctx.mounted) {
                  Navigator.of(ctx, rootNavigator: true).pop();
                }
                // Close registration dialog
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Restaurant registration submitted for review!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                // Ensure loading dialog is closed on failure
                if (ctx.mounted) {
                  Navigator.of(ctx, rootNavigator: true).pop();
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Registration failed: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Register Now'),
          ),
        ],
      ),
    );
  }
}
