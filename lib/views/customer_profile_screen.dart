import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/views/auth/role_selection_screen.dart';
import 'package:yummy_go_application/views/delivery_address_screen.dart';
import 'package:yummy_go_application/views/favorite_foods_screen.dart';
import 'package:yummy_go_application/views/group_ordering_screen.dart';
import 'package:yummy_go_application/views/profile_feature_screens.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.deepTeal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  Future<void> _openPersonalDetails(BuildContext context) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const PersonalDetailsScreen()),
    );
    if (changed == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final name =
        user?.displayName ??
        user?.email?.split('@').first ??
        'YummyGo Customer';

    final email = user?.email ?? 'No email available';

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'My Profile',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PROFILE HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.deepTeal,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.warmIvory,
                    child: Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: AppColors.deepTeal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.white.withOpacity(0.70),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Welcome to YummyGo!',
                          style: TextStyle(color: AppColors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.verified_rounded,
                    color: AppColors.white,
                    size: 25,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            _sectionTitle('My Account'),

            _menuCard(
              context,
              icon: Icons.person_outline_rounded,
              title: 'Personal Details',
              subtitle: 'Manage your profile information',
              color: AppColors.deepTeal,
              onTap: () => _openPersonalDetails(context),
            ),

            _menuCard(
              context,
              icon: Icons.location_on_outlined,
              title: 'Saved Addresses',
              subtitle: 'Manage your delivery addresses',
              color: AppColors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DeliveryAddressScreen(orderType: OrderType.manageOnly),
                ),
              ),
            ),

            const SizedBox(height: 20),

            _sectionTitle('Your Activity'),

            _menuCard(
              context,
              icon: Icons.favorite_rounded,
              title: 'Favorite Foods/Restuarants',
              subtitle: 'View dishes you have saved',
              color: AppColors.error,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FavoriteFoodsScreen(),
                  ),
                );
              },
            ),

            _menuCard(
              context,
              icon: Icons.receipt_long_rounded,
              title: 'My Orders',
              subtitle: 'Active & past delivery orders',
              color: AppColors.deepTeal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const MyOrdersScreen()),
              ),
            ),

            _menuCard(
              context,
              icon: Icons.groups_rounded,
              title: 'Group Orders',
              subtitle: 'Manage your shared orders',
              color: AppColors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const GroupOrderingScreen(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            _sectionTitle('Support & Settings'),

            _menuCard(
              context,
              icon: Icons.headset_mic_outlined,
              title: 'Help & Support',
              subtitle: 'We are here to help you',
              color: AppColors.deepTeal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileHelpScreen(),
                ),
              ),
            ),

            _menuCard(
              context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Manage your preferences',
              color: AppColors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileSettingsScreen(),
                ),
              ),
            ),

            _menuCard(
              context,
              icon: Icons.swap_horiz_rounded,
              title: 'Switch Role / Portal',
              subtitle: 'Switch between Customer, Restaurant, Delivery & Admin',
              color: AppColors.goldenOrange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              ),
            ),

            const SizedBox(height: 25),

            // LOGOUT BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.deepTeal,
                  side: BorderSide(color: AppColors.deepTeal, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                'YummyGo • Made with love',
                style: TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.deepTeal,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title is not available yet.'),
        backgroundColor: AppColors.deepTeal,
      ),
    );
  }

  Widget _menuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: BorderSide(color: AppColors.border),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 7,
          ),
          leading: Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: AppColors.deepTeal,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.teal,
            size: 16,
          ),
          onTap: onTap ?? () => _showMessage(context, title),
        ),
      ),
    );
  }
}
