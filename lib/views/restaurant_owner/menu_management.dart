import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/food_items_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/restaurant_owner_service.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class MenuManagementScreen extends StatefulWidget {
  final RestaurantModel? restaurant;

  const MenuManagementScreen({super.key, this.restaurant});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final RestaurantOwnerService _service = RestaurantOwnerService();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  void _showAddEditItemDialog({FoodItemModel? existingItem, required RestaurantModel restaurant}) {
    if (!restaurant.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration under review. Adding or editing menu items is allowed only after Admin approval.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final isEditing = existingItem != null;
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existingItem != null ? existingItem.price.toStringAsFixed(0) : '',
    );
    final categoryCtrl = TextEditingController(text: existingItem?.category ?? 'Main Course');
    final descCtrl = TextEditingController(text: existingItem?.description ?? '');
    final imageCtrl = TextEditingController(text: existingItem?.image ?? '');
    bool isVeg = existingItem?.isVeg ?? true;
    bool isBestSeller = existingItem?.isBestSeller ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lightOrange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.goldenOrange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEditing ? 'Edit Food Item' : 'Add New Food Item',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepTeal,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.92,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Item Name *',
                      hintText: 'e.g. Hyderabadi Chicken Biryani',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Price (₹) *',
                            hintText: 'e.g. 250',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: categoryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            hintText: 'e.g. Biryani',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Brief description of ingredients or preparation',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: imageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Image URL',
                      hintText: 'https://...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      const Text('Food Type: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepTeal)),
                      ChoiceChip(
                        label: const Text('Veg'),
                        selected: isVeg,
                        onSelected: (val) => setDialogState(() => isVeg = true),
                        selectedColor: AppColors.lightLime,
                        labelStyle: TextStyle(
                          color: isVeg ? AppColors.success : AppColors.mutedText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Non-Veg'),
                        selected: !isVeg,
                        onSelected: (val) => setDialogState(() => isVeg = false),
                        selectedColor: AppColors.lightOrange,
                        labelStyle: TextStyle(
                          color: !isVeg ? AppColors.error : AppColors.mutedText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.goldenOrange,
                    title: const Text('Mark as Bestseller', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.deepTeal)),
                    value: isBestSeller,
                    onChanged: (val) => setDialogState(() => isBestSeller = val ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.mutedText, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldenOrange,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (!isEditing && !restaurant.isApproved) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Only approved restaurants can add menu items.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) return;
                final price = double.tryParse(priceCtrl.text) ?? 0.0;

                try {
                  if (isEditing) {
                    await _service.updateFoodItem(existingItem.id, {
                      'name': nameCtrl.text.trim(),
                      'price': price,
                      'category': categoryCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'image': imageCtrl.text.trim(),
                      'imageUrl': imageCtrl.text.trim(),
                      'isVeg': isVeg,
                      'isBestSeller': isBestSeller,
                    });
                  } else {
                    await _service.addFoodItem(
                      restaurantId: restaurant.id,
                      restaurantName: restaurant.name,
                      name: nameCtrl.text.trim(),
                      category: categoryCtrl.text.trim(),
                      price: price,
                      isVeg: isVeg,
                      description: descCtrl.text.trim(),
                      image: imageCtrl.text.trim(),
                      isBestSeller: isBestSeller,
                    );
                  }

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? 'Item updated!' : 'Item added to menu!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'Save Changes' : 'Add Item', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RestaurantModel?>(
      stream: widget.restaurant != null
          ? Stream.value(widget.restaurant)
          : _service.streamOwnerRestaurant(),
      builder: (context, restSnap) {
        final restaurant = restSnap.data ?? widget.restaurant;

        if (restaurant == null) {
          return const Scaffold(
            backgroundColor: AppColors.warmIvory,
            appBar: CommonAppBar(title: 'Menu Management'),
            body: Center(
              child: Text('Please register a restaurant first to manage menu.'),
            ),
          );
        }

        final bool isApproved = restaurant.isApproved;

        return Scaffold(
          backgroundColor: AppColors.warmIvory,
          appBar: const CommonAppBar(
            title: 'Menu Management',
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: isApproved ? AppColors.goldenOrange : AppColors.mutedText,
            foregroundColor: AppColors.white,
            icon: Icon(isApproved ? Icons.add_rounded : Icons.lock_outline_rounded),
            label: const Text('Add Food Item'),
            onPressed: () {
              if (!isApproved) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Only approved restaurants can add menu items.'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              _showAddEditItemDialog(restaurant: restaurant);
            },
          ),
          body: Column(
            children: [
              if (!isApproved)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lightOrange,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.goldenOrange.withOpacity(0.6)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pending_actions_rounded, color: AppColors.goldenOrange, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REGISTRATION UNDER ADMIN REVIEW',
                              style: TextStyle(
                                color: AppColors.goldenOrange,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Your registration has been submitted to Admin. Only after Admin approves the registration will you be allowed to add, edit, or manage menu items. Your restaurant will become visible to customers after approval.',
                              style: TextStyle(
                                color: AppColors.deepTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search food item...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.goldenOrange),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
              ),

              // Menu Items Stream
              Expanded(
                child: StreamBuilder<List<FoodItemModel>>(
                  stream: _service.streamMenuItems(
                    restaurant.id,
                    restaurantName: restaurant.name,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.goldenOrange));
                    }

                    final items = snapshot.data ?? [];
                    final filtered = items.where((it) {
                      if (_searchQuery.isNotEmpty && !it.name.toLowerCase().contains(_searchQuery)) {
                        return false;
                      }
                      if (_selectedCategory != 'All' && it.category != _selectedCategory) {
                        return false;
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 54, color: AppColors.mutedText),
                            const SizedBox(height: 12),
                            const Text('No food items on menu yet', style: TextStyle(color: AppColors.mutedText)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldenOrange),
                              onPressed: () => _showAddEditItemDialog(restaurant: restaurant),
                              child: const Text('Add Your First Item', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _buildMenuItemCard(item, restaurant);
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

  Widget _buildMenuItemCard(FoodItemModel item, RestaurantModel restaurant) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.lightOrange,
              borderRadius: BorderRadius.circular(14),
              image: item.image.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(item.image),
                      fit: BoxFit.cover,
                      onError: (_, _) {},
                    )
                  : null,
            ),
            child: item.image.isEmpty
                ? const Icon(Icons.fastfood_rounded, color: AppColors.goldenOrange, size: 30)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 11,
                      color: item.isVeg ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepTeal,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.category} • ₹${item.price.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.goldenOrange,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: restaurant.isApproved ? AppColors.teal : AppColors.mutedText,
                  size: 20,
                ),
                onPressed: restaurant.isApproved
                    ? () => _showAddEditItemDialog(existingItem: item, restaurant: restaurant)
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Registration under review. Editing items is unlocked after Admin approval.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      },
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: restaurant.isApproved ? AppColors.error : AppColors.mutedText,
                  size: 20,
                ),
                onPressed: restaurant.isApproved
                    ? () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Item'),
                            content: Text('Delete ${item.name} from menu?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _service.deleteFoodItem(item.id, restaurantId: restaurant.id);
                        }
                      }
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Registration under review. Deleting items is unlocked after Admin approval.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
