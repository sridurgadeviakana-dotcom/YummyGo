import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/admin_service.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class RestaurantManagementScreen extends StatefulWidget {
  final int initialTabIndex;

  const RestaurantManagementScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<RestaurantManagementScreen> createState() =>
      _RestaurantManagementScreenState();
}

class _RestaurantManagementScreenState
    extends State<RestaurantManagementScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddRestaurantDialog() {
    final nameCtrl = TextEditingController();
    final branchCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final cuisineCtrl = TextEditingController();
    final deliveryTimeCtrl = TextEditingController(text: '30-40 min');
    final imageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Restaurant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Restaurant Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: branchCtrl,
                decoration: const InputDecoration(labelText: 'Branch Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: areaCtrl,
                decoration: const InputDecoration(labelText: 'Area / Location *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cuisineCtrl,
                decoration: const InputDecoration(labelText: 'Cuisine (e.g. Biryani, North Indian)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deliveryTimeCtrl,
                decoration: const InputDecoration(labelText: 'Delivery Time'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imageCtrl,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || areaCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and Area are required')),
                );
                return;
              }

              await _adminService.addRestaurant({
                'name': nameCtrl.text.trim(),
                'branchName': branchCtrl.text.trim(),
                'area': areaCtrl.text.trim(),
                'cuisine': cuisineCtrl.text.trim().isEmpty ? 'Multi-Cuisine' : cuisineCtrl.text.trim(),
                'deliveryTime': deliveryTimeCtrl.text.trim(),
                'imageUrl': imageCtrl.text.trim(),
                'rating': 4.5,
                'isAvailable': true,
                'isActive': true,
                'status': 'active',
              });

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Restaurant added successfully!')),
                );
              }
            },
            child: const Text('Add Restaurant'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: CommonAppBar(
        title: 'Restaurant Management',
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.deepTeal,
          indicatorColor: AppColors.teal,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Pending'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.deepTeal,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add Restaurant'),
        onPressed: _showAddRestaurantDialog,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search restaurants by name or area...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.teal),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<RestaurantModel>>(
              stream: _adminService.streamAllRestaurants(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading restaurants: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.teal));
                }

                final allList = snapshot.data ?? [];
                final filtered = allList.where((r) {
                  if (_searchQuery.isEmpty) return true;
                  return r.name.toLowerCase().contains(_searchQuery) ||
                      r.area.toLowerCase().contains(_searchQuery) ||
                      r.cuisine.toLowerCase().contains(_searchQuery);
                }).toList();

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('food_items').snapshots(),
                  builder: (context, foodSnap) {
                    final foodDocs = foodSnap.data?.docs ?? [];
                    final Map<String, int> menuCounts = {};
                    for (final doc in foodDocs) {
                      final d = doc.data();
                      final isAvail = d['isAvailable'] == null
                          ? true
                          : (d['isAvailable'] == true ||
                              d['isAvailable'].toString().toLowerCase() == 'true');
                      if (isAvail) {
                        final rId = (d['restaurantId'] ?? d['restaurant_id'])?.toString() ?? '';
                        final rName = (d['restaurant'] ?? d['restaurantName'])?.toString().trim().toLowerCase() ?? '';
                        if (rId.isNotEmpty) menuCounts[rId] = (menuCounts[rId] ?? 0) + 1;
                        if (rName.isNotEmpty) menuCounts[rName] = (menuCounts[rName] ?? 0) + 1;
                      }
                    }

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRestaurantList(filtered, menuCounts: menuCounts),
                        _buildRestaurantList(
                          filtered.where((r) => r.isApproved && r.isAvailable).toList(),
                          menuCounts: menuCounts,
                        ),
                        _buildRestaurantList(
                          filtered.where((r) => r.status.toLowerCase() == 'pending').toList(),
                          isPendingTab: true,
                          menuCounts: menuCounts,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantList(
    List<RestaurantModel> list, {
    bool isPendingTab = false,
    required Map<String, int> menuCounts,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 54, color: AppColors.mutedText.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text(
              'No restaurants found in this category',
              style: TextStyle(color: AppColors.mutedText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final restaurant = list[index];
        final menuCount = menuCounts[restaurant.id] ??
            menuCounts[restaurant.name.trim().toLowerCase()] ??
            0;
        return _buildRestaurantCard(
          restaurant,
          isPendingTab: isPendingTab,
          menuCount: menuCount,
        );
      },
    );
  }

  Widget _buildRestaurantCard(
    RestaurantModel restaurant, {
    bool isPendingTab = false,
    required int menuCount,
  }) {
    final bool isApproved = restaurant.isApproved;
    final bool hasMenu = menuCount > 0;
    final bool isVisibleToCustomer = isApproved && hasMenu;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isVisibleToCustomer
              ? AppColors.teal.withOpacity(0.4)
              : AppColors.border,
          width: isVisibleToCustomer ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(14),
                  image: restaurant.imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(restaurant.imageUrl),
                          fit: BoxFit.cover,
                          onError: (_, _) {},
                        )
                      : null,
                ),
                child: restaurant.imageUrl.isEmpty
                    ? const Icon(Icons.restaurant_rounded, color: AppColors.teal, size: 28)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepTeal,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${restaurant.cuisine} • ${restaurant.area}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.goldenOrange, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              restaurant.rating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.restaurant_menu_rounded, color: AppColors.mutedText, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '$menuCount menu items',
                              style: TextStyle(
                                color: hasMenu ? AppColors.teal : AppColors.error,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isApproved ? AppColors.lightLime : AppColors.lightOrange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isApproved ? 'APPROVED' : 'PENDING',
                      style: TextStyle(
                        color: isApproved ? AppColors.success : AppColors.error,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Customer Visibility Banner / Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isVisibleToCustomer
                  ? AppColors.lightLime.withOpacity(0.5)
                  : AppColors.lightOrange.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVisibleToCustomer ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  size: 13,
                  color: isVisibleToCustomer ? AppColors.success : AppColors.goldenOrange,
                ),
                const SizedBox(width: 6),
                Text(
                  isVisibleToCustomer
                      ? 'Visible to Customers ($menuCount dishes available)'
                      : (!isApproved
                          ? 'Hidden from Customers: Pending Admin Approval'
                          : 'Hidden from Customers: Add menu items to become visible'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isVisibleToCustomer ? AppColors.success : AppColors.goldenOrange,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              // APPROVE / ACTIVATE OR DEACTIVATE
              if (!isApproved)
                ElevatedButton.icon(
                  onPressed: () => _adminService.setRestaurantStatus(restaurant.id, 'active'),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _adminService.setRestaurantStatus(restaurant.id, 'inactive'),
                  icon: const Icon(Icons.pause_circle_outline_rounded, size: 15),
                  label: const Text('Deactivate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                ),

              // 3. DELETE
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Restaurant'),
                      content: Text('Are you sure you want to delete ${restaurant.name}?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete', style: TextStyle(color: AppColors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _adminService.deleteRestaurant(restaurant.id);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
