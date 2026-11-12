import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/services/order_service.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final OrderService _orderService = OrderService();
  String _selectedStatusFilter = 'all';

  final List<Map<String, String>> _statusFilters = [
    {'label': 'All Orders', 'value': 'all'},
    {'label': 'Ready for Pickup', 'value': 'ready_for_pickup'},
    {'label': 'Delivered', 'value': 'delivered'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'Marketplace Orders',
      ),
      body: Column(
        children: [
          // Horizontal status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _statusFilters.map((f) {
                final isSelected = _selectedStatusFilter == f['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f['label']!),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedStatusFilter = f['value']!);
                    },
                    selectedColor: AppColors.deepTeal,
                    backgroundColor: AppColors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.deepTeal,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),

          // Live Orders Stream
          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              stream: _orderService.streamAllOrders(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading orders: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.teal));
                }

                final orders = snapshot.data ?? [];
                final filtered = orders.where((order) {
                  if (_selectedStatusFilter == 'all') return true;
                  final s = order.orderStatus.toLowerCase();
                  if (_selectedStatusFilter == 'ready_for_pickup') {
                    return s == 'ready_for_pickup' || s == 'ready' || s == 'placed' || s == 'confirmed' || s == 'preparing';
                  }
                  if (_selectedStatusFilter == 'delivered') {
                    return s == 'delivered' || s == 'completed';
                  }
                  return s == _selectedStatusFilter.toLowerCase();
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 58,
                          color: AppColors.mutedText.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No orders in this status',
                          style: TextStyle(color: AppColors.mutedText, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    return _buildOrderCard(order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    Color statusColor;
    String statusDisplay;
    switch (order.orderStatus.toLowerCase()) {
      case 'preparing':
        statusColor = AppColors.teal;
        statusDisplay = 'PREPARING';
        break;
      case 'ready_for_pickup':
      case 'ready':
        statusColor = AppColors.goldenOrange;
        statusDisplay = 'READY';
        break;
      case 'on_the_way':
      case 'out_for_delivery':
      case 'picked_up':
        statusColor = AppColors.deepTeal;
        statusDisplay = 'OUT FOR DELIVERY';
        break;
      case 'delivered':
      case 'completed':
        statusColor = AppColors.success;
        statusDisplay = 'DELIVERED';
        break;
      default:
        statusColor = AppColors.mutedText;
        statusDisplay = order.statusDisplay.toUpperCase();
    }

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
          // Order ID and Status Badge
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
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusDisplay,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Restaurant & Customer
          Text(
            order.restaurantName,
            style: const TextStyle(
              color: AppColors.deepTeal,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Customer: ${order.customerName} ${order.customerPhone.isNotEmpty ? '(${order.customerPhone})' : ''}',
            style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
          if (order.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Delivery Address: ${order.deliveryAddress}',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),

          // Items Preview
          if (order.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warmIvory,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: order.items.map((it) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${it.quantity}x ${it.name}',
                            style: const TextStyle(
                              color: AppColors.deepTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '₹${(it.price * it.quantity).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 12,
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

          // Total & Payment method
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Amount', style: TextStyle(color: AppColors.mutedText, fontSize: 11)),
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.deepTeal,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Text(
                '${order.paymentMethod} • ${order.paymentStatus.toUpperCase()}',
                style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),

          if (order.deliveryPartnerName != null && order.deliveryPartnerName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.delivery_dining_rounded, size: 16, color: AppColors.limeGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rider: ${order.deliveryPartnerName} (${order.deliveryAccepted ? "Accepted" : "Awaiting Acceptance"})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepTeal,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Ready for pickup assignment banner
          if (order.orderStatus.toLowerCase() == 'ready_for_pickup') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.lightOrange,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.goldenOrange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, size: 16, color: AppColors.goldenOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.deliveryPartnerName != null && order.deliveryPartnerName!.isNotEmpty
                          ? 'Assigned to ${order.deliveryPartnerName} • Ready for pickup'
                          : 'Food is Ready! Assign a delivery partner below.',
                      style: const TextStyle(
                        color: AppColors.deepTeal,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),

          // Actions
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (order.isDelivered) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lightLime,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                      SizedBox(width: 6),
                      Text(
                        'Delivered (Completed)',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                if (order.orderStatus.toLowerCase() == 'ready_for_pickup' ||
                    order.deliveryPartnerId == null ||
                    order.deliveryPartnerId!.isEmpty) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepTeal,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: Text(
                      order.deliveryPartnerName != null && order.deliveryPartnerName!.isNotEmpty
                          ? 'Reassign Rider'
                          : 'Assign Rider',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showAssignPartnerDialog(order),
                  ),
                ],
                if (_selectedStatusFilter != 'ready_for_pickup')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepTeal,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Update Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _showUpdateStatusDialog(order),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showAssignPartnerDialog(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightLime,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, color: AppColors.deepTeal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign Delivery Partner',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.deepTeal),
                        ),
                        Text(
                          'Order #${order.id} • ${order.restaurantName}',
                          style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Available Fleet Delivery Partners:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.deepTeal),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('delivery_partners').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.teal));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_rounded, size: 48, color: AppColors.mutedText.withOpacity(0.5)),
                            const SizedBox(height: 8),
                            const Text('No registered delivery partners found.', style: TextStyle(color: AppColors.mutedText)),
                          ],
                        ),
                      );
                    }

                    // Sort: online/available partners first
                    final partners = docs.map((d) {
                      final m = Map<String, dynamic>.from(d.data());
                      m['docId'] = d.id;
                      return m;
                    }).toList();

                    partners.sort((a, b) {
                      final aAvail = (a['isAvailable'] == true || a['isOnline'] == true) ? 1 : 0;
                      final bAvail = (b['isAvailable'] == true || b['isOnline'] == true) ? 1 : 0;
                      return bAvail.compareTo(aAvail);
                    });

                    return ListView.separated(
                      itemCount: partners.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final p = partners[idx];
                        final pid = p['userId']?.toString() ?? p['id']?.toString() ?? p['docId'];
                        final name = p['name']?.toString() ?? 'Delivery Partner';
                        final phone = p['phone']?.toString() ?? '';
                        final isAvail = p['isAvailable'] == true || p['isOnline'] == true;
                        final vehicle = p['vehicleType']?.toString() ?? 'Bike';
                        final rating = (p['rating'] as num?)?.toDouble() ?? 5.0;
                        final isCurrentlyAssigned = order.deliveryPartnerId == pid;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrentlyAssigned ? AppColors.lightLime : AppColors.warmIvory,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurrentlyAssigned ? AppColors.success : AppColors.border,
                              width: isCurrentlyAssigned ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isAvail ? AppColors.lightLime : AppColors.border,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: isAvail ? AppColors.success : AppColors.mutedText,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.deepTeal),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isAvail ? AppColors.lightLime : AppColors.border,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isAvail ? 'ONLINE' : 'OFFLINE',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: isAvail ? AppColors.success : AppColors.mutedText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$vehicle • ★ ${rating.toStringAsFixed(1)}${phone.isNotEmpty ? " • $phone" : ""}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: !isAvail
                                      ? AppColors.border
                                      : (isCurrentlyAssigned ? AppColors.success : AppColors.deepTeal),
                                  foregroundColor: !isAvail ? AppColors.mutedText : AppColors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: !isAvail ? 0 : 2,
                                ),
                                onPressed: !isAvail
                                    ? null
                                    : () async {
                                        await _orderService.assignDeliveryPartner(
                                          orderId: order.id,
                                          partnerId: pid,
                                          partnerName: name,
                                          partnerPhone: phone,
                                        );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Assigned $name to Order #${order.id}!'),
                                              backgroundColor: AppColors.teal,
                                            ),
                                          );
                                        }
                                      },
                                child: Text(
                                  !isAvail
                                      ? 'Offline'
                                      : (isCurrentlyAssigned ? 'Assigned' : 'Assign'),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUpdateStatusDialog(OrderModel order) {
    if (order.isDelivered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order is already delivered and cannot be modified.'),
          backgroundColor: AppColors.deepTeal,
        ),
      );
      return;
    }

    const statuses = [
      {'label': 'Ready for Pickup', 'value': 'ready_for_pickup'},
      {'label': 'Delivered', 'value': 'delivered'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Update Order Status'),
        children: statuses.map((s) {
          final isCurrent = order.orderStatus.toLowerCase() == s['value'] ||
              (s['value'] == 'out_for_delivery' &&
                  (order.orderStatus.toLowerCase() == 'on_the_way' ||
                      order.orderStatus.toLowerCase() == 'picked_up'));
          return SimpleDialogOption(
            onPressed: () async {
              await _orderService.updateOrderStatus(order.id, s['value']!);
              if (mounted) Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s['label']!,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? AppColors.teal : AppColors.deepTeal,
                  ),
                ),
                if (isCurrent)
                  const Icon(Icons.check_rounded, color: AppColors.teal, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
