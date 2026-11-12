import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/services/order_service.dart';
import 'package:yummy_go_application/views/order_tracking_screen.dart';
import 'package:yummy_go_application/views/profile_feature_screens.dart';

/// Floating Active Orders Banner that shows real-time active delivery status
/// across customer browsing screens, enabling customers to track active deliveries
/// while simultaneously browsing or ordering from other restaurants.
class ActiveOrdersBar extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const ActiveOrdersBar({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(14, 0, 14, 8),
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final orderService = OrderService();

    return StreamBuilder<List<OrderModel>>(
      stream: orderService.streamCustomerActiveOrders(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final activeOrders = snapshot.data!;
        if (activeOrders.isEmpty) {
          return const SizedBox.shrink();
        }

        final isSingle = activeOrders.length == 1;
        final primaryOrder = activeOrders.first;

        Color statusColor;
        Color statusBg;
        IconData statusIcon;

        switch (primaryOrder.orderStatus.toLowerCase()) {
          case 'placed':
            statusColor = AppColors.goldenOrange;
            statusBg = AppColors.lightOrange;
            statusIcon = Icons.hourglass_top_rounded;
            break;
          case 'confirmed':
            statusColor = AppColors.teal;
            statusBg = AppColors.lightTeal;
            statusIcon = Icons.check_circle_rounded;
            break;
          case 'preparing':
            statusColor = AppColors.deepTeal;
            statusBg = AppColors.lightTeal;
            statusIcon = Icons.soup_kitchen_rounded;
            break;
          case 'ready_for_pickup':
            statusColor = Colors.purple.shade700;
            statusBg = Colors.purple.shade50;
            statusIcon = Icons.inventory_2_rounded;
            break;
          case 'out_for_delivery':
          case 'on_the_way':
          case 'picked_up':
            statusColor = AppColors.success;
            statusBg = AppColors.lightLime;
            statusIcon = Icons.delivery_dining_rounded;
            break;
          default:
            statusColor = AppColors.teal;
            statusBg = AppColors.lightTeal;
            statusIcon = Icons.fastfood_rounded;
            break;
        }

        return SafeArea(
          top: false,
          bottom: false,
          child: Container(
            margin: margin,
            child: Material(
              elevation: 4,
              shadowColor: AppColors.deepTeal.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              color: AppColors.white,
              child: InkWell(
                onTap: () {
                  if (isSingle) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(
                          orderId: primaryOrder.id,
                          groupId: primaryOrder.groupId,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyOrdersScreen(),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.teal.withOpacity(0.35),
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      // Animated / pulsing icon badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(statusIcon, color: statusColor, size: 20),
                          ),
                          if (!isSingle)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.goldenOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${activeOrders.length}',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Order information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSingle
                                  ? primaryOrder.restaurantName
                                  : '${activeOrders.length} Active Orders in Progress',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.deepTeal,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSingle
                                  ? '${primaryOrder.statusDisplay} · Tap to Track'
                                  : '${activeOrders.map((o) => o.restaurantName).take(2).join(', ')}${activeOrders.length > 2 ? ' +more' : ''} · Track All',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSingle ? statusColor : AppColors.mutedText,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Action Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.lightTeal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSingle ? 'Track' : 'View All',
                              style: const TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: AppColors.teal,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

