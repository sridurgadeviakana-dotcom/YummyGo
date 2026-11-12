import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/user_role.dart';
import 'package:yummy_go_application/routes/app_routes.dart';
import 'package:yummy_go_application/services/role_service.dart';
import 'package:yummy_go_application/views/admin/admin_dashboard.dart';
import 'package:yummy_go_application/views/auth/login_screen.dart';
import 'package:yummy_go_application/views/auth/signup_screen.dart';
import 'package:yummy_go_application/views/customer/customer_home_screen.dart';
import 'package:yummy_go_application/views/delivery_partner/delivery_dashboard.dart';
import 'package:yummy_go_application/views/restaurant_owner/owner_dashboard.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final RoleService _roleService = RoleService();
  bool _isLoading = false;

  Future<void> _handleRoleSelected(UserRole role) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // User is not logged in yet -> Navigate to Login / Register for this role
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(targetRole: role),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentRole = await _roleService.getCurrentUserRole();

      if (!mounted) return;

      // If user selected Admin, verify admin authorization
      if (role == UserRole.admin) {
        final isAdmin = await _roleService.verifyAdminAccess(user.uid);
        if (!isAdmin && currentRole != UserRole.admin) {
          // If not yet admin, ask user if they want to bootstrap/test as admin
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Admin Access Verification'),
              content: const Text(
                'Your current account is not marked as Admin in Firestore. '
                'Would you like to assign Admin permissions to this account for testing and platform management?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepTeal,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Grant Admin Role'),
                ),
              ],
            ),
          );

          if (proceed == true) {
            await _roleService.setUserRole(uid: user.uid, role: UserRole.admin);
          } else {
            setState(() => _isLoading = false);
            return;
          }
        }
      } else if (currentRole != role) {
        // Switch role for the authenticated user
        await _roleService.setUserRole(uid: user.uid, role: role);
      }

      if (!mounted) return;

      _navigateToDashboard(role);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting role: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard(UserRole role) {
    Widget target;
    switch (role) {
      case UserRole.admin:
        target = const AdminDashboard();
        break;
      case UserRole.restaurantOwner:
        target = const RestaurantOwnerDashboard();
        break;
      case UserRole.deliveryPartner:
        target = const DeliveryDashboardScreen();
        break;
      case UserRole.customer:
      default:
        target = const CustomerHomeScreen();
        break;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => target),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar with Logo & Auth Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.teal,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.teal.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.restaurant_rounded,
                              color: AppColors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YummyGo',
                                style: TextStyle(
                                  color: AppColors.deepTeal,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'FOOD & DELIVERY PORTAL',
                                style: TextStyle(
                                  color: AppColors.mutedText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (user != null)
                        TextButton.icon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            setState(() {});
                          },
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: const Text('Logout'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Welcome Heading
                  const Text(
                    'Welcome to YummyGo',
                    style: TextStyle(
                      color: AppColors.deepTeal,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose how you want to experience the platform. Select your portal to proceed.',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4 Role Cards
                  _buildRoleCard(
                    context: context,
                    role: UserRole.customer,
                    badgeText: 'MOST POPULAR',
                    badgeColor: AppColors.lightTeal,
                    badgeTextColor: AppColors.teal,
                    title: 'Customer / User',
                    tagline: 'Order food, track live delivery, group cart & split bills.',
                    icon: Icons.lunch_dining_rounded,
                    accentColor: AppColors.teal,
                    actionText: 'Browse Restaurants',
                  ),
                  const SizedBox(height: 16),

                  _buildRoleCard(
                    context: context,
                    role: UserRole.restaurantOwner,
                    badgeText: 'PARTNER WITH US',
                    badgeColor: AppColors.lightOrange,
                    badgeTextColor: AppColors.goldenOrange,
                    title: 'Restaurant Owner',
                    tagline: 'Manage live orders, food menus, prices & track restaurant sales.',
                    icon: Icons.storefront_rounded,
                    accentColor: AppColors.goldenOrange,
                    actionText: 'Manage Restaurant',
                  ),
                  const SizedBox(height: 16),

                  _buildRoleCard(
                    context: context,
                    role: UserRole.deliveryPartner,
                    badgeText: 'FLEET & RIDER',
                    badgeColor: AppColors.lightLime,
                    badgeTextColor: AppColors.success,
                    title: 'Delivery Partner',
                    tagline: 'Pick up food, deliver to customers & earn per delivery.',
                    icon: Icons.electric_moped_rounded,
                    accentColor: AppColors.limeGreen,
                    actionText: 'Deliver & Earn',
                  ),
                  const SizedBox(height: 16),

                  _buildRoleCard(
                    context: context,
                    role: UserRole.admin,
                    badgeText: 'MARKETPLACE HQ',
                    badgeColor: AppColors.lightTeal,
                    badgeTextColor: AppColors.deepTeal,
                    title: 'Admin Console',
                    tagline: 'Platform control, restaurant approvals, user & order management.',
                    icon: Icons.admin_panel_settings_rounded,
                    accentColor: AppColors.deepTeal,
                    actionText: 'Access Control Center',
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.25),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.teal),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required UserRole role,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required String title,
    required String tagline,
    required IconData icon,
    required Color accentColor,
    required String actionText,
  }) {
    return InkWell(
      onTap: () => _handleRoleSelected(role),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.deepTeal,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              tagline,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  actionText,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: accentColor,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

