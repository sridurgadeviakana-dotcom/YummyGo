import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/delivery_partner_model.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/services/delivery_tracking_service.dart';
import 'package:yummy_go_application/services/map_navigation_service.dart';
import 'package:yummy_go_application/services/order_service.dart';
import 'package:yummy_go_application/widgets/delivery_osm_map.dart';
import 'package:yummy_go_application/views/auth/role_selection_screen.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() =>
      _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  late TabController _tabController;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<DeliveryPartnerModel?> _streamPartnerProfile() {
    final uid = _user?.uid;
    if (uid == null) return Stream.value(null);

    return FirebaseFirestore.instance
        .collection('delivery_partners')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return DeliveryPartnerModel.fromFirestore(doc);
      }
      return DeliveryPartnerModel(
        id: uid,
        userId: uid,
        name: _user?.displayName ?? 'Rider',
        email: _user?.email ?? '',
      );
    });
  }

  Future<void> _toggleOnlineStatus(bool currentStatus) async {
    final uid = _user?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('delivery_partners').doc(uid).set({
      'isAvailable': !currentStatus,
      'isOnline': !currentStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _navigateToDestination(OrderModel order, Map<String, dynamic>? trackingData) {
    final isPickup = order.orderStatus == 'ready_for_pickup';
    final targetAddress = isPickup
        ? order.restaurantName
        : (order.deliveryAddress.isNotEmpty ? order.deliveryAddress : order.customerName);
    final targetLat = isPickup
        ? (trackingData?['restaurantLatitude'] as num?)?.toDouble()
        : (trackingData?['customerLatitude'] as num?)?.toDouble();
    final targetLng = isPickup
        ? (trackingData?['restaurantLongitude'] as num?)?.toDouble()
        : (trackingData?['customerLongitude'] as num?)?.toDouble();

    MapNavigationService.openGoogleMapsDirections(
      address: targetAddress,
      latitude: targetLat,
      longitude: targetLng,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.navigation_rounded, color: AppColors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Opening Google Maps directions to $targetAddress...',
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.teal,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateToDeliveryAddress(OrderModel order, [Map<String, dynamic>? trackingData]) {
    final targetAddress = order.deliveryAddress.isNotEmpty
        ? order.deliveryAddress
        : order.customerName;
    final targetLat = (trackingData?['customerLatitude'] as num?)?.toDouble() ??
        ((order.deliveryLatitude != null && order.deliveryLatitude != 0.0) ? order.deliveryLatitude : null);
    final targetLng = (trackingData?['customerLongitude'] as num?)?.toDouble() ??
        ((order.deliveryLongitude != null && order.deliveryLongitude != 0.0) ? order.deliveryLongitude : null);

    MapNavigationService.openGoogleMapsDirections(
      address: targetAddress,
      latitude: targetLat,
      longitude: targetLng,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.navigation_rounded, color: AppColors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Opening Google Maps directions to $targetAddress...',
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.teal,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openLocationMap({
    required bool isRestaurant,
    required OrderModel order,
    required Map<String, dynamic>? trackingData,
  }) {
    final targetName = isRestaurant
        ? order.restaurantName
        : (order.deliveryAddress.isNotEmpty ? order.deliveryAddress : order.customerName);

    final targetLat = isRestaurant
        ? (trackingData?['restaurantLatitude'] as num?)?.toDouble()
        : (trackingData?['customerLatitude'] as num?)?.toDouble() ?? order.deliveryLatitude;

    final targetLng = isRestaurant
        ? (trackingData?['restaurantLongitude'] as num?)?.toDouble()
        : (trackingData?['customerLongitude'] as num?)?.toDouble() ?? order.deliveryLongitude;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.warmIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isRestaurant ? AppColors.lightOrange : AppColors.lightTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isRestaurant ? Icons.storefront_rounded : Icons.location_on_rounded,
                      color: isRestaurant ? AppColors.goldenOrange : AppColors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRestaurant ? 'RESTAURANT LOCATION' : 'CUSTOMER DROP-OFF LOCATION',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.mutedText,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          targetName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.deepTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Option 1: Turn-by-turn navigation via Google Maps
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text(
                    'Navigate with Google Maps',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    MapNavigationService.openGoogleMapsDirections(
                      address: targetName,
                      latitude: targetLat,
                      longitude: targetLng,
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Option 2: Interactive In-App OpenStreetMap View
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.deepTeal, width: 1.5),
                    foregroundColor: AppColors.deepTeal,
                    backgroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text(
                    'Open Interactive OSM Map',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeliveryOsmFullScreenScreen(
                          order: order,
                          isDeliveryPartner: true,
                          initialTrackingData: trackingData,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      body: SafeArea(
        child: StreamBuilder<DeliveryPartnerModel?>(
          stream: _streamPartnerProfile(),
          builder: (context, profileSnap) {
            final partner = profileSnap.data ??
                DeliveryPartnerModel(
                  id: _user?.uid ?? 'partner',
                  userId: _user?.uid ?? 'partner',
                  name: _user?.displayName ?? 'Delivery Partner',
                );

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(context),
                          const SizedBox(height: 18),
                          _buildProfileCard(partner),
                          const SizedBox(height: 16),
                          _buildEarningsSummary(partner),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        controller: _tabController,
                        labelColor: AppColors.deepTeal,
                        indicatorColor: AppColors.limeGreen,
                        tabs: const [
                          Tab(text: 'Active Delivery'),
                          Tab(text: 'Available (New)'),
                          Tab(text: 'History'),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveDeliveryTab(partner),
                  _buildAvailableOrdersTab(partner),
                  _buildDeliveryHistoryTab(partner),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.lightLime,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.electric_moped_rounded, color: AppColors.limeGreen),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YummyGo Fleet',
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'DELIVERY PARTNER DASHBOARD',
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

  Widget _buildProfileCard(DeliveryPartnerModel partner) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.lightLime,
            child: const Icon(Icons.person_rounded, color: AppColors.deepTeal, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.name,
                  style: const TextStyle(
                    color: AppColors.deepTeal,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${partner.vehicleType} • ★ ${partner.rating.toStringAsFixed(1)}',
                  style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          // Online status switch
          Column(
            children: [
              Text(
                partner.isAvailable ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  color: partner.isAvailable ? AppColors.success : AppColors.mutedText,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Switch(
                value: partner.isAvailable,
                activeColor: AppColors.limeGreen,
                onChanged: (val) => _toggleOnlineStatus(partner.isAvailable),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsSummary(DeliveryPartnerModel partner) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.deepTeal,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total Earnings', '₹${partner.earnings.toStringAsFixed(0)}'),
          Container(width: 1, height: 40, color: AppColors.white.withOpacity(0.24)),
          _buildSummaryItem('Completed Trips', '${partner.totalDeliveries}'),
          Container(width: 1, height: 40, color: AppColors.white.withOpacity(0.24)),
          _buildSummaryItem('Per Delivery Pay', '₹50'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: AppColors.lightTeal, fontSize: 10)),
      ],
    );
  }

  Widget _buildActiveDeliveryTab(DeliveryPartnerModel partner) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.streamPartnerOrders(partner.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.limeGreen));
        }

        final orders = snapshot.data ?? [];
        final pendingAcceptance = orders
            .where((o) =>
                !o.deliveryAccepted &&
                (o.orderStatus == 'ready_for_pickup' || o.orderStatus == 'preparing'))
            .toList();

        final active = orders
            .where((o) =>
                o.deliveryAccepted &&
                (o.orderStatus == 'on_the_way' ||
                    o.orderStatus == 'out_for_delivery' ||
                    o.orderStatus == 'picked_up' ||
                    o.orderStatus == 'ready_for_pickup'))
            .toList();

        if (active.isEmpty) {
          // When no active delivery, ensure tracking is stopped
          if (DeliveryTrackingService().isTracking) {
            DeliveryTrackingService().stopTracking();
          }

          if (pendingAcceptance.isNotEmpty) {
            final assignedOrder = pendingAcceptance.first;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.goldenOrange, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldenOrange.withOpacity(0.12),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.lightOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars_rounded, color: AppColors.goldenOrange, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'ASSIGNED TO YOU BY ADMIN',
                                style: TextStyle(
                                  color: AppColors.goldenOrange,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'Payout: ₹50',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.success),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Pickup: ${assignedOrder.restaurantName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.deepTeal),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lightTeal.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: AppColors.teal, size: 18),
                              const SizedBox(width: 6),
                              const Text(
                                'DELIVERY DROP-OFF LOCATION',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.teal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            assignedOrder.deliveryAddress.isNotEmpty
                                ? assignedOrder.deliveryAddress
                                : 'Deliver to: ${assignedOrder.customerName}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepTeal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 38,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.teal,
                                side: const BorderSide(color: AppColors.teal),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.navigation_rounded, size: 16),
                              label: const Text(
                                'Directions in Google Maps',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                              onPressed: () => _navigateToDeliveryAddress(assignedOrder),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${assignedOrder.items.length} items • Total: ₹${assignedOrder.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepTeal),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepTeal,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Accept Delivery Order', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          await _orderService.acceptDeliveryOrder(
                            orderId: assignedOrder.id,
                            partnerId: partner.userId,
                            partnerName: partner.name,
                            partnerPhone: partner.phone,
                          );
                          await DeliveryTrackingService().startTracking(
                            orderId: assignedOrder.id,
                            partnerId: partner.userId,
                            partnerName: partner.name,
                            partnerPhone: partner.phone,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order accepted! Navigate to ${assignedOrder.restaurantName} for pickup.'),
                                backgroundColor: AppColors.teal,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_bike_rounded, size: 58, color: AppColors.mutedText.withOpacity(0.5)),
                const SizedBox(height: 12),
                const Text('No active deliveries right now', style: TextStyle(color: AppColors.mutedText)),
                const SizedBox(height: 8),
                const Text(
                  'Switch to "Available (New)" tab to accept delivery orders.',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final order = active.first;

        // Auto-resume continuous GPS location streaming if not currently active
        if (!DeliveryTrackingService().isTracking ||
            DeliveryTrackingService().currentOrderId != order.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DeliveryTrackingService().startTracking(
              orderId: order.id,
              partnerId: partner.userId,
              partnerName: partner.name,
              partnerPhone: partner.phone,
            );
          });
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(order.id)
              .collection('tracking')
              .doc('current')
              .snapshots(),
          builder: (context, trackSnap) {
            final trackingData = trackSnap.data?.data();
            final isPickup = order.orderStatus == 'ready_for_pickup';

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Delivery Order Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (order.isGroupOrder) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.lightTeal,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.groups_rounded, color: AppColors.teal, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  order.groupName != null && order.groupName!.isNotEmpty
                                      ? 'GROUP ORDER: ${order.groupName}'
                                      : 'CURRENT GROUP ORDER',
                                  style: const TextStyle(
                                    color: AppColors.deepTeal,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isPickup
                                    ? AppColors.lightOrange
                                    : AppColors.lightLime,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPickup
                                        ? Icons.storefront_rounded
                                        : Icons.directions_bike_rounded,
                                    size: 12,
                                    color: isPickup
                                        ? AppColors.goldenOrange
                                        : AppColors.success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isPickup
                                        ? 'STAGE 1: PICK UP FOOD'
                                        : 'STAGE 2: DELIVERING TO CUSTOMER',
                                    style: TextStyle(
                                      color: isPickup
                                          ? AppColors.goldenOrange
                                          : AppColors.success,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'Payout: ₹50',
                              style: TextStyle(
                                color: AppColors.deepTeal,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Pickup location
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.storefront_rounded, color: AppColors.goldenOrange, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('PICKUP RESTAURANT', style: TextStyle(fontSize: 10, color: AppColors.mutedText, fontWeight: FontWeight.bold)),
                                  Text(
                                    order.restaurantName,
                                    style: const TextStyle(color: AppColors.deepTeal, fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isPickup) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.teal),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.directions_rounded, size: 18, color: AppColors.teal),
                              label: const Text(
                                'View Route to Restaurant (Google Maps)',
                                style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: () => _navigateToDestination(order, trackingData),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Delivery location (Customer drop-off address)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.lightTeal.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_rounded, color: AppColors.teal, size: 24),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'CUSTOMER DROP-OFF ADDRESS',
                                          style: TextStyle(fontSize: 10, color: AppColors.teal, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          order.customerName,
                                          style: const TextStyle(color: AppColors.deepTeal, fontSize: 15, fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          order.deliveryAddress.isNotEmpty
                                              ? order.deliveryAddress
                                              : 'Customer delivery location',
                                          style: const TextStyle(color: AppColors.charcoalBlack, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                                        ),
                                        if (order.deliveryLatitude != null &&
                                            order.deliveryLongitude != null &&
                                            order.deliveryLatitude != 0.0 &&
                                            order.deliveryLongitude != 0.0) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            'GPS: ${order.deliveryLatitude!.toStringAsFixed(4)}, ${order.deliveryLongitude!.toStringAsFixed(4)}',
                                            style: const TextStyle(color: AppColors.mutedText, fontSize: 10.5),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Dedicated Google Maps Navigation Button to Delivery Address - Always Visible
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.teal,
                                    foregroundColor: AppColors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 2,
                                  ),
                                  icon: const Icon(Icons.navigation_rounded, size: 19),
                                  label: const Text(
                                    'Navigate to Delivery Address (Google Maps)',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                  ),
                                  onPressed: () => _navigateToDeliveryAddress(order, trackingData),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Items list
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warmIvory,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Items To Deliver:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.deepTeal)),
                              const SizedBox(height: 4),
                              ...order.items.map((it) => Text('• ${it.quantity}x ${it.name}', style: const TextStyle(fontSize: 12))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Picked Up / Complete delivery button
                        if (isPickup)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.deepTeal,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.shopping_bag_rounded),
                              label: const Text('Picked Up Food • Start Journey', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                await _orderService.markPickedUp(order.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Order picked up! Status updated to On The Way. Live GPS shared with customer.'),
                                      backgroundColor: AppColors.teal,
                                      duration: const Duration(seconds: 4),
                                      action: SnackBarAction(
                                        label: 'Open Maps',
                                        textColor: AppColors.white,
                                        onPressed: () {
                                          _navigateToDestination(order, trackingData);
                                        },
                                      ),
                                    ),
                                  );
                                  // Automatically launch Google Maps directions directly to the customer's delivery address
                                  _navigateToDestination(order, trackingData);
                                }
                              },
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text('Confirm Delivery Completed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                _showCustomerNameVerificationDialog(context, order, partner);
                              },
                            ),
                          ),
                      ],
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

  void _showCustomerNameVerificationDialog(
    BuildContext context,
    OrderModel order,
    DeliveryPartnerModel partner,
  ) {
    final nameController = TextEditingController();
    String? validationError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightLime,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hand-off Verification',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.deepTeal),
                        ),
                        Text(
                          'Verify customer before completing',
                          style: TextStyle(fontSize: 11, color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warmIvory,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXPECTED RECIPIENT',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.mutedText, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.customerName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.deepTeal),
                          ),
                          if (order.deliveryAddress.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              order.deliveryAddress,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.mutedText),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter or confirm recipient name:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.deepTeal),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Customer name (e.g. ${order.customerName})',
                        errorText: validationError,
                        filled: true,
                        fillColor: AppColors.white,
                        prefixIcon: const Icon(Icons.person_rounded, color: AppColors.teal, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.teal, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick-fill button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.teal),
                        label: Text('Use "${order.customerName}"', style: const TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          setDialogState(() {
                            nameController.text = order.customerName;
                            validationError = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mutedText,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Complete Delivery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final entered = nameController.text.trim();
                    if (entered.isEmpty) {
                      setDialogState(() {
                        validationError = 'Please enter or confirm customer name';
                      });
                      return;
                    }

                    Navigator.pop(dialogCtx);

                    // 1. Stop continuous live GPS tracking
                    await DeliveryTrackingService().stopTracking();

                    // 2. Complete delivery in Firestore
                    await _orderService.completeDelivery(
                      order.id,
                      partner.userId,
                      customerVerifiedName: entered,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Delivery completed for $entered! ₹50 credited to your earnings.'),
                              ),
                            ],
                          ),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAvailableOrdersTab(DeliveryPartnerModel partner) {
    if (!partner.isAvailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.charcoalBlack.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: AppColors.charcoalBlack,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You are currently OFFLINE',
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Turn on your online status at the top to receive new orders and delivery assignments.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.power_settings_new_rounded),
                label: const Text(
                  'Go Online Now',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _toggleOnlineStatus(false),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.streamAvailableDeliveryOrders(partnerId: partner.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.limeGreen));
        }

        final availableOrders = snapshot.data ?? [];

        if (availableOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.mutedText.withOpacity(0.5)),
                const SizedBox(height: 12),
                const Text('No pending delivery requests', style: TextStyle(color: AppColors.mutedText)),
                const SizedBox(height: 6),
                const Text('New orders will appear here automatically when food is ready.', style: TextStyle(color: AppColors.mutedText, fontSize: 11)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: availableOrders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = availableOrders[index];
            final isAssignedToMe = order.deliveryPartnerId == partner.userId && !order.deliveryAccepted;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isAssignedToMe ? AppColors.goldenOrange : AppColors.border,
                  width: isAssignedToMe ? 2 : 1,
                ),
                boxShadow: isAssignedToMe
                    ? [
                        BoxShadow(
                          color: AppColors.goldenOrange.withOpacity(0.12),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAssignedToMe) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lightOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, color: AppColors.goldenOrange, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'ASSIGNED TO YOU BY ADMIN',
                            style: TextStyle(
                              color: AppColors.goldenOrange,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pickup from: ${order.restaurantName}',
                        style: const TextStyle(
                          color: AppColors.deepTeal,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.lightLime,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '+ ₹50 Payout',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.teal.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppColors.teal, size: 17),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.deliveryAddress.isNotEmpty
                                    ? order.deliveryAddress
                                    : 'Customer Location',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.deepTeal,
                                ),
                              ),
                              Text(
                                'Recipient: ${order.customerName}',
                                style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.teal,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          icon: const Icon(Icons.navigation_rounded, size: 14),
                          label: const Text('Directions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _navigateToDeliveryAddress(order),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${order.items.length} items • Total Value: ₹${order.totalAmount.toStringAsFixed(0)} (${order.paymentStatus.toUpperCase()})',
                    style: const TextStyle(color: AppColors.deepTeal, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAssignedToMe ? AppColors.goldenOrange : AppColors.deepTeal,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.sports_motorsports_rounded, size: 18),
                      label: const Text(
                        'Accept Assigned Order',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () async {
                        await _orderService.acceptDeliveryOrder(
                          orderId: order.id,
                          partnerId: partner.userId,
                          partnerName: partner.name,
                          partnerPhone: partner.phone,
                        );

                        // Automatically start continuous live GPS location tracking in Firestore
                        await DeliveryTrackingService().startTracking(
                          orderId: order.id,
                          partnerId: partner.userId,
                          partnerName: partner.name,
                          partnerPhone: partner.phone,
                        );

                        _tabController.animateTo(0);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Order accepted! Navigate to ${order.restaurantName} for pickup.'),
                              backgroundColor: AppColors.teal,
                            ),
                          );
                        }
                      },
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

  Widget _buildDeliveryHistoryTab(DeliveryPartnerModel partner) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.streamPartnerOrders(partner.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.limeGreen));
        }

        final orders = snapshot.data ?? [];
        final completed = orders.where((o) => o.orderStatus == 'delivered').toList();

        if (completed.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 54, color: AppColors.mutedText.withOpacity(0.5)),
                const SizedBox(height: 12),
                const Text('No completed deliveries yet', style: TextStyle(color: AppColors.mutedText)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: completed.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final order = completed[index];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.lightLime,
                    child: const Icon(Icons.check_rounded, color: AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.restaurantName,
                          style: const TextStyle(color: AppColors.deepTeal, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Delivered to ${order.customerName}',
                          style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '+ ₹50.00',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
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
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.warmIvory,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
