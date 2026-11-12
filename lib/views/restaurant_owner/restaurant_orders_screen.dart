import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/order_service.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class RestaurantOrdersScreen extends StatefulWidget {
  final RestaurantModel restaurant;

  const RestaurantOrdersScreen({super.key, required this.restaurant});

  @override
  State<RestaurantOrdersScreen> createState() => _RestaurantOrdersScreenState();
}

class _RestaurantOrdersScreenState extends State<RestaurantOrdersScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: CommonAppBar(
        title: 'Incoming Orders',
        subtitle: widget.restaurant.name,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.deepTeal,
          indicatorColor: AppColors.goldenOrange,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Incoming'),
            Tab(text: 'Preparing'),
            Tab(text: 'Ready for Pickup'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _orderService.streamRestaurantOrders(
          widget.restaurant.id,
          restaurantName: widget.restaurant.name,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.goldenOrange));
          }

          final orders = snapshot.data ?? [];

          final newOrders = orders.where((o) => o.orderStatus == 'placed' || o.orderStatus == 'confirmed').toList();
          final preparingOrders = orders.where((o) => o.orderStatus == 'preparing').toList();
          final readyOrders = orders.where((o) =>
              o.orderStatus == 'ready_for_pickup' ||
              o.orderStatus == 'on_the_way' ||
              o.orderStatus == 'out_for_delivery' ||
              o.orderStatus == 'picked_up').toList();
          final completedOrders = orders.where((o) => o.orderStatus == 'delivered' || o.orderStatus == 'cancelled').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOrdersList(newOrders, 'new'),
              _buildOrdersList(preparingOrders, 'preparing'),
              _buildOrdersList(readyOrders, 'ready'),
              _buildOrdersList(completedOrders, 'completed'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrdersList(List<OrderModel> list, String stage) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.soup_kitchen_outlined, size: 54, color: AppColors.mutedText.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              stage == 'new'
                  ? 'No incoming orders right now'
                  : 'No orders in this stage',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (stage == 'new')
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.lightOrange,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.goldenOrange, width: 1.5),
            ),
            child: Row(
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
                const SizedBox(width: 12),
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
                        '${list.length} incoming order${list.length > 1 ? "s" : ""} waiting for kitchen response',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ...list.map((order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRestaurantOrderCard(order, stage),
            )),
      ],
    );
  }

  Widget _buildRestaurantOrderCard(OrderModel order, String stage) {
    return Container(
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
                child: Text(
                  'ORDER #${order.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightOrange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  order.statusDisplay,
                  style: const TextStyle(
                    color: AppColors.goldenOrange,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Customer: ${order.customerName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.deepTeal,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          if (order.customerPhone.isNotEmpty)
            Text(
              'Phone: ${order.customerPhone}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          const SizedBox(height: 10),

          // Items
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warmIvory,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: order.items.map((it) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: it.isVeg ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${it.quantity}x ${it.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.deepTeal,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${(it.price * it.quantity).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.deepTeal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ₹${order.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (order.deliveryPartnerName != null && order.deliveryPartnerName!.isNotEmpty)
                Text(
                  'Rider: ${order.deliveryPartnerName}',
                  style: const TextStyle(color: AppColors.limeGreen, fontWeight: FontWeight.bold, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Stage-specific actions
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (stage == 'new') ...[
                ElevatedButton.icon(
                  onPressed: () async {
                    await _orderService.updateOrderStatus(order.id, 'preparing');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order accepted! Kitchen started preparing.'),
                          backgroundColor: AppColors.goldenOrange,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldenOrange,
                    foregroundColor: AppColors.white,
                  ),
                  icon: const Icon(Icons.soup_kitchen_rounded, size: 16),
                  label: const Text('Accept & Prepare'),
                ),
              ] else if (stage == 'preparing') ...[
                ElevatedButton.icon(
                  onPressed: () async {
                    await _orderService.updateOrderStatus(order.id, 'ready_for_pickup');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Food prepared! Order marked Ready for Pickup.'),
                          backgroundColor: AppColors.teal,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepTeal,
                    foregroundColor: AppColors.white,
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Mark Ready for Pickup'),
                ),
              ] else if (stage == 'ready') ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (order.orderStatus == 'ready_for_pickup') ...[
                      if (order.deliveryPartnerName != null && order.deliveryPartnerName!.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delivery_dining_rounded, size: 16, color: AppColors.teal),
                            const SizedBox(width: 4),
                            Text(
                              'Rider: ${order.deliveryPartnerName} (${order.deliveryAccepted ? 'En Route' : 'Assigned'})',
                              style: const TextStyle(color: AppColors.deepTeal, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        )
                      else
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, size: 14, color: AppColors.goldenOrange),
                            SizedBox(width: 4),
                            Text(
                              'Ready • Awaiting Admin to assign Rider',
                              style: TextStyle(color: AppColors.goldenOrange, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                    ] else if (order.orderStatus == 'on_the_way' ||
                        order.orderStatus == 'out_for_delivery' ||
                        order.orderStatus == 'picked_up') ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            'Picked Up by ${order.deliveryPartnerName ?? 'Rider'} • On The Way',
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        order.statusDisplay,
                        style: const TextStyle(color: AppColors.mutedText, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ] else ...[
                Text(
                  'Order ${order.orderStatus}',
                  style: TextStyle(
                    color: order.orderStatus == 'delivered' ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

