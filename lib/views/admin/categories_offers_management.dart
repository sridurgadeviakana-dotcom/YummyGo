import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/services/admin_service.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class CategoriesOffersManagementScreen extends StatefulWidget {
  final int initialIndex;

  const CategoriesOffersManagementScreen({super.key, this.initialIndex = 0});

  @override
  State<CategoriesOffersManagementScreen> createState() =>
      _CategoriesOffersManagementScreenState();
}

class _CategoriesOffersManagementScreenState
    extends State<CategoriesOffersManagementScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Food Category'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Category Name (e.g. Biryani, Pizza, Desserts)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await _adminService.addCategory(nameCtrl.text.trim());
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddOfferDialog() {
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '20');
    final minAmountCtrl = TextEditingController(text: '199');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Promotional Offer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Coupon Code (e.g. YUMMY50) *'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Offer Description / Title *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: discountCtrl,
                decoration: const InputDecoration(labelText: 'Discount % (e.g. 20)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minAmountCtrl,
                decoration: const InputDecoration(labelText: 'Min Order Value (₹)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
            ),
            onPressed: () async {
              if (codeCtrl.text.trim().isEmpty || titleCtrl.text.trim().isEmpty) return;
              final disc = double.tryParse(discountCtrl.text) ?? 10.0;
              final minAmt = double.tryParse(minAmountCtrl.text) ?? 100.0;

              await _adminService.addOffer(
                code: codeCtrl.text.trim(),
                title: titleCtrl.text.trim(),
                discountPercent: disc,
                minOrderAmount: minAmt,
              );
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Create Offer'),
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
        title: 'Categories & Offers',
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.deepTeal,
          indicatorColor: AppColors.teal,
          tabs: const [
            Tab(text: 'Food Categories', icon: Icon(Icons.category_rounded)),
            Tab(text: 'Platform Offers', icon: Icon(Icons.local_offer_rounded)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.deepTeal,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(_tabController.index == 0 ? 'New Category' : 'New Offer'),
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddCategoryDialog();
          } else {
            _showAddOfferDialog();
          }
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Categories Stream
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _adminService.streamCategories(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.teal));
              }
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.category_outlined, size: 54, color: AppColors.mutedText),
                      const SizedBox(height: 12),
                      const Text('No categories created yet'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _showAddCategoryDialog,
                        child: const Text('Add First Category'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final cat = list[index];
                  return Card(
                    color: AppColors.white,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.lightTeal,
                        child: Icon(Icons.restaurant_menu_rounded, color: AppColors.teal),
                      ),
                      title: Text(
                        cat['name']?.toString() ?? 'Category',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.deepTeal),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                        onPressed: () => _adminService.deleteCategory(cat['id']),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Offers Stream
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _adminService.streamOffers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.teal));
              }
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_offer_outlined, size: 54, color: AppColors.mutedText),
                      const SizedBox(height: 12),
                      const Text('No offers active right now'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _showAddOfferDialog,
                        child: const Text('Create First Offer'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final off = list[index];
                  return Card(
                    color: AppColors.white,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.lightOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.discount_rounded, color: AppColors.goldenOrange),
                      ),
                      title: Text(
                        off['code']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.deepTeal),
                      ),
                      subtitle: Text(
                        '${off['title']} • ${off['discountPercent']}% OFF (Min ₹${off['minOrderAmount']})',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                        onPressed: () => _adminService.deleteOffer(off['id']),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

