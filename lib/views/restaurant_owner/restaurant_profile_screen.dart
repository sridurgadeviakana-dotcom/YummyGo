import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/restaurant_owner_service.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class RestaurantProfileScreen extends StatefulWidget {
  final RestaurantModel? restaurant;

  const RestaurantProfileScreen({super.key, this.restaurant});

  @override
  State<RestaurantProfileScreen> createState() =>
      _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState extends State<RestaurantProfileScreen> {
  final RestaurantOwnerService _service = RestaurantOwnerService();

  late TextEditingController _nameController;
  late TextEditingController _branchController;
  late TextEditingController _areaController;
  late TextEditingController _cuisineController;
  late TextEditingController _deliveryTimeController;
  late TextEditingController _imageController;
  late TextEditingController _hoursController;
  late TextEditingController _phoneController;

  bool _isAvailable = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final r = widget.restaurant;
    _nameController = TextEditingController(text: r?.name ?? '');
    _branchController = TextEditingController(text: r?.branchName ?? '');
    _areaController = TextEditingController(text: r?.area ?? '');
    _cuisineController = TextEditingController(text: r?.cuisine ?? '');
    _deliveryTimeController =
        TextEditingController(text: r?.deliveryTime ?? '30-40 min');
    _imageController = TextEditingController(text: r?.imageUrl ?? '');
    _hoursController = TextEditingController(text: '9:00 AM - 11:00 PM');
    _phoneController = TextEditingController();
    _isAvailable = r?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _branchController.dispose();
    _areaController.dispose();
    _cuisineController.dispose();
    _deliveryTimeController.dispose();
    _imageController.dispose();
    _hoursController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges(String restaurantId) async {
    setState(() => _isLoading = true);

    try {
      await _service.updateRestaurant(restaurantId, {
        'name': _nameController.text.trim(),
        'branchName': _branchController.text.trim(),
        'area': _areaController.text.trim(),
        'cuisine': _cuisineController.text.trim(),
        'deliveryTime': _deliveryTimeController.text.trim(),
        'imageUrl': _imageController.text.trim(),
        'openingHours': _hoursController.text.trim(),
        'phone': _phoneController.text.trim(),
        'isAvailable': _isAvailable,
        'isActive': _isAvailable,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restaurant profile updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RestaurantModel?>(
      stream: widget.restaurant != null
          ? Stream.value(widget.restaurant)
          : _service.streamOwnerRestaurant(),
      builder: (context, snapshot) {
        final restaurant = snapshot.data ?? widget.restaurant;

        if (restaurant == null) {
          return const Scaffold(
            backgroundColor: AppColors.warmIvory,
            appBar: CommonAppBar(title: 'Restaurant Profile'),
            body: Center(
              child: Text(
                'No restaurant registered yet.',
                style: TextStyle(color: AppColors.mutedText),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.warmIvory,
          appBar: const CommonAppBar(
            title: 'Restaurant Profile',
            subtitle: 'Manage store details & hours',
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Restaurant Header Hero Card
                _buildHeaderCard(restaurant),
                const SizedBox(height: 16),

                // 2. Open / Closed Status Card
                _buildStatusCard(restaurant),
                const SizedBox(height: 16),

                // 3. Basic Information Section
                _buildSectionCard(
                  title: 'Basic Information',
                  icon: Icons.storefront_rounded,
                  iconColor: AppColors.teal,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Restaurant Name *',
                        prefixIcon: Icon(Icons.business_rounded, color: AppColors.teal),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _branchController,
                      decoration: const InputDecoration(
                        labelText: 'Branch Name',
                        prefixIcon: Icon(Icons.location_city_rounded, color: AppColors.teal),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _cuisineController,
                      decoration: const InputDecoration(
                        labelText: 'Cuisine (e.g. Biryani, Pizzas, Desserts)',
                        prefixIcon: Icon(Icons.restaurant_menu_rounded, color: AppColors.teal),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Location & Contact Section
                _buildSectionCard(
                  title: 'Location & Contact',
                  icon: Icons.pin_drop_rounded,
                  iconColor: AppColors.goldenOrange,
                  children: [
                    TextField(
                      controller: _areaController,
                      decoration: const InputDecoration(
                        labelText: 'Area / Neighborhood *',
                        prefixIcon: Icon(Icons.map_rounded, color: AppColors.goldenOrange),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone Number',
                        prefixIcon: Icon(Icons.phone_rounded, color: AppColors.goldenOrange),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 5. Operational Hours & Delivery Time
                _buildSectionCard(
                  title: 'Operations & Timing',
                  icon: Icons.access_time_filled_rounded,
                  iconColor: AppColors.deepTeal,
                  children: [
                    TextField(
                      controller: _hoursController,
                      decoration: const InputDecoration(
                        labelText: 'Operating Hours (e.g. 9:00 AM - 11:00 PM)',
                        prefixIcon: Icon(Icons.schedule_rounded, color: AppColors.deepTeal),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _deliveryTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Estimated Prep & Delivery Time',
                        prefixIcon: Icon(Icons.delivery_dining_rounded, color: AppColors.deepTeal),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 6. Branding & Media Section
                _buildSectionCard(
                  title: 'Store Branding',
                  icon: Icons.image_rounded,
                  iconColor: AppColors.teal,
                  children: [
                    TextField(
                      controller: _imageController,
                      decoration: const InputDecoration(
                        labelText: 'Cover Image URL',
                        prefixIcon: Icon(Icons.link_rounded, color: AppColors.teal),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 7. Save Changes Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepTeal,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    icon: _isLoading
                        ? const SizedBox.shrink()
                        : const Icon(Icons.check_circle_rounded),
                    label: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Save Profile Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                    onPressed: _isLoading ? null : () => _saveChanges(restaurant.id),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(RestaurantModel restaurant) {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : restaurant.name;
    final branch = _branchController.text.trim().isNotEmpty
        ? _branchController.text.trim()
        : restaurant.branchName;
    final cuisine = _cuisineController.text.trim().isNotEmpty
        ? _cuisineController.text.trim()
        : restaurant.cuisine;
    final imageUrl = _imageController.text.trim().isNotEmpty
        ? _imageController.text.trim()
        : restaurant.imageUrl;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepTeal.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderBanner(),
                    )
                  else
                    _buildPlaceholderBanner(),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.charcoalBlack.withOpacity(0.15),
                          AppColors.charcoalBlack.withOpacity(0.65),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
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
                                  color: AppColors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (branch.isNotEmpty)
                                Text(
                                  branch,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.lightIvory,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.charcoalBlack.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: AppColors.goldenOrange, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                restaurant.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (cuisine.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cuisine,
                      style: const TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: restaurant.isApproved ? AppColors.lightLime : AppColors.lightOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    restaurant.isApproved ? 'VERIFIED STORE' : 'PENDING APPROVAL',
                    style: TextStyle(
                      color: restaurant.isApproved ? AppColors.success : AppColors.goldenOrange,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderBanner() {
    return Container(
      color: AppColors.deepTeal,
      child: const Center(
        child: Icon(Icons.storefront_rounded, color: AppColors.white, size: 48),
      ),
    );
  }

  Widget _buildStatusCard(RestaurantModel restaurant) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isAvailable ? AppColors.teal.withOpacity(0.3) : AppColors.border,
          width: _isAvailable ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isAvailable
                  ? AppColors.lightLime
                  : AppColors.charcoalBlack.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isAvailable ? Icons.store_rounded : Icons.lock_clock_rounded,
              color: _isAvailable ? AppColors.success : AppColors.charcoalBlack,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accepting Orders',
                  style: TextStyle(
                    color: AppColors.deepTeal,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isAvailable
                      ? 'Store is Open & Accepting Orders'
                      : 'Store is Closed (Ordering Disabled)',
                  style: TextStyle(
                    color: _isAvailable ? AppColors.success : AppColors.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAvailable,
            activeColor: AppColors.teal,
            inactiveTrackColor: AppColors.border,
            onChanged: (val) {
              setState(() => _isAvailable = val);
              _service.updateRestaurant(restaurant.id, {
                'isAvailable': val,
                'isActive': val,
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.deepTeal,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
