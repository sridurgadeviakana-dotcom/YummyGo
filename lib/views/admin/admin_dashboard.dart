import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/routes/app_routes.dart';
import 'package:yummy_go_application/views/admin/categories_offers_management.dart';
import 'package:yummy_go_application/views/admin/restaurant_management.dart';
import 'package:yummy_go_application/views/auth/role_selection_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _AdminTopBar(),
                  const SizedBox(height: 22),
                  const _AdminWelcomeCard(),
                  const SizedBox(height: 24),
                  const _SectionHeading(
                    title: 'Marketplace pulse',
                    subtitle: 'Real-time metrics from Firebase Firestore',
                  ),
                  const SizedBox(height: 14),
                  const _LiveAdminMetricGrid(),
                  const SizedBox(height: 26),
                  const _SectionHeading(
                    title: 'Control Center',
                    subtitle: 'Manage every workflow of the YummyGo ecosystem',
                  ),
                  const SizedBox(height: 14),
                  const _AdminControlCenter(),
                  const SizedBox(height: 26),
                  const _SectionHeading(
                    title: 'Recent Platform Orders',
                    subtitle: 'Live order tracking across all restaurants',
                  ),
                  const SizedBox(height: 14),
                  const _RecentOrdersFeed(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.deepTeal,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.space_dashboard_rounded,
            color: AppColors.white,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YummyGo HQ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'MARKETPLACE ADMIN',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
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

class _AdminWelcomeCard extends StatelessWidget {
  const _AdminWelcomeCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        double totalVolume = 0.0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final amt = (data['totalAmount'] as num?)?.toDouble() ??
                (data['total'] as num?)?.toDouble() ??
                0.0;
            totalVolume += amt;
          }
        }
        final commission = totalVolume * 0.15; // 15% platform commission

        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.deepTeal, AppColors.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              Positioned(
                right: -15,
                top: -20,
                child: Icon(
                  Icons.storefront_rounded,
                  size: 130,
                  color: AppColors.white.withOpacity(0.08),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'PLATFORM REVENUE & VOLUME',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '₹${totalVolume.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total Gross Marketplace Volume • Platform Commission: ₹${commission.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.lightTeal,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({required this.title, required this.subtitle});

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

class _LiveAdminMetricGrid extends StatelessWidget {
  const _LiveAdminMetricGrid();

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('restaurants').snapshots(),
      builder: (context, restSnap) {
        final restCount = restSnap.data?.docs.length ?? 0;
        final pendingReview = restSnap.data?.docs.where((d) {
              final data = d.data() as Map<String, dynamic>?;
              final status = data?['status']?.toString().toLowerCase();
              return status == 'pending';
            }).length ??
            0;

        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('orders').snapshots(),
          builder: (context, orderSnap) {
            final orderCount = orderSnap.data?.docs.length ?? 0;

            return StreamBuilder<QuerySnapshot>(
              stream: db.collection('users').snapshots(),
              builder: (context, userSnap) {
                final userCount = userSnap.data?.docs.length ?? 0;

                final metrics = [
                  _AdminMetric(
                    'Restaurants',
                    '$restCount',
                    Icons.storefront_outlined,
                    AppColors.teal,
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminRestaurants),
                  ),
                  _AdminMetric(
                    'Total Orders',
                    '$orderCount',
                    Icons.receipt_long_outlined,
                    AppColors.goldenOrange,
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminOrders),
                  ),
                  _AdminMetric(
                    'Users & Fleet',
                    '$userCount',
                    Icons.people_alt_outlined,
                    AppColors.deepTeal,
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminOwners),
                  ),
                  _AdminMetric(
                    'Needs Review',
                    '$pendingReview',
                    Icons.fact_check_outlined,
                    AppColors.success,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RestaurantManagementScreen(initialTabIndex: 2),
                      ),
                    ),
                  ),
                ];

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 520 ? 4 : 2;
                    final width = (constraints.maxWidth - (columns - 1) * 11) / columns - 0.5;
                    return Wrap(
                      spacing: 11,
                      runSpacing: 11,
                      children: metrics.map((m) => SizedBox(width: width, child: m)).toList(),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AdminMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const _AdminMetric(
    this.label,
    this.value,
    this.icon,
    this.accent, {
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminControlCenter extends StatelessWidget {
  const _AdminControlCenter();

  @override
  Widget build(BuildContext context) {
    final controls = [
      _AdminControlData(
        'Restaurants',
        'Listings & approvals',
        Icons.store_mall_directory_outlined,
        AppColors.lightTeal,
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminRestaurants),
      ),
      _AdminControlData(
        'Owners & Users',
        'Account credentials',
        Icons.groups_2_outlined,
        AppColors.lightOrange,
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminOwners),
      ),
      _AdminControlData(
        'All Orders',
        'Marketplace flow',
        Icons.inventory_2_outlined,
        AppColors.lightTeal,
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminOrders),
      ),
    
      // _AdminControlData(
      //   'Delivery Fleet',
      //   'Partner operations',
      //   Icons.delivery_dining_rounded,
      //   AppColors.lightLime,
      //   onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminDelivery),
      // ),
      // _AdminControlData(
      //   'Food Categories',
      //   'Manage item tags',
      //   Icons.restaurant_menu_rounded,
      //   AppColors.lightLime,
      //   onTap: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (_) => const CategoriesOffersManagementScreen(initialIndex: 0),
      //       ),
      //     );
      //   },
      // ),
      // _AdminControlData(
      //   'Coupons & Offers',
      //   'Platform discounts',
      //   Icons.local_offer_outlined,
      //   AppColors.lightOrange,
      //   onTap: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (_) => const CategoriesOffersManagementScreen(initialIndex: 1),
      //       ),
      //     );
      //   },
      // ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 11) / columns;
        return Wrap(
          spacing: 11,
          runSpacing: 11,
          children: controls
              .map(
                (c) => SizedBox(
                  width: width,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: c.onTap,
                    child: _AdminControlCard(c),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AdminControlData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final VoidCallback onTap;

  const _AdminControlData(
    this.title,
    this.subtitle,
    this.icon,
    this.background, {
    required this.onTap,
  });
}

class _AdminControlCard extends StatelessWidget {
  final _AdminControlData data;

  const _AdminControlCard(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(data.icon, color: AppColors.deepTeal, size: 20),
          ),
          const SizedBox(height: 11),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.title,
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.deepTeal,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersFeed extends StatelessWidget {
  const _RecentOrdersFeed();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.teal));
        }

        final docs = [...?snapshot.data?.docs];
        docs.sort((a, b) {
          final first = a.data()['createdAt'];
          final second = b.data()['createdAt'];
          final firstDate = first is Timestamp ? first.toDate() : DateTime(0);
          final secondDate = second is Timestamp ? second.toDate() : DateTime(0);
          return secondDate.compareTo(firstDate);
        });

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'No orders placed on platform yet.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
            ),
          );
        }

        final recentDocs = docs.take(5).toList();

        return Column(
          children: recentDocs.map((doc) {
            final order = OrderModel.fromFirestore(doc);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.lightTeal,
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.teal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.restaurantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.deepTeal,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${order.customerName} • ₹${order.totalAmount.toStringAsFixed(0)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightLime,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      order.statusDisplay,
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
