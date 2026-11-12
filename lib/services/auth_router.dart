import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yummy_go_application/models/user_role.dart';
import 'package:yummy_go_application/services/role_service.dart';
import 'package:yummy_go_application/views/admin/admin_dashboard.dart';
import 'package:yummy_go_application/views/auth/role_selection_screen.dart';
import 'package:yummy_go_application/views/customer/customer_home_screen.dart';
import 'package:yummy_go_application/views/delivery_partner/delivery_dashboard.dart';
import 'package:yummy_go_application/views/restaurant_owner/owner_dashboard.dart';
import 'package:yummy_go_application/views/splash_screen.dart';

class AuthRouter extends StatefulWidget {
  const AuthRouter({super.key});

  @override
  State<AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends State<AuthRouter> {
  final RoleService _roleService = RoleService();
  late Future<Widget> _nextScreen;

  @override
  void initState() {
    super.initState();
    _nextScreen = _decideNextScreen();
  }

  Future<Widget> _decideNextScreen() async {
    // Keep splash screen visible for at least 1.5 seconds for branding animation
    await Future.delayed(const Duration(milliseconds: 1500));

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final profile = await _roleService.getCurrentUserProfile();
        final role = profile?.role ?? UserRole.customer;

        switch (role) {
          case UserRole.admin:
            return const AdminDashboard();
          case UserRole.restaurantOwner:
            return const RestaurantOwnerDashboard();
          case UserRole.deliveryPartner:
            return const DeliveryDashboardScreen();
          case UserRole.customer:
          default:
            return const CustomerHomeScreen();
        }
      } catch (e) {
        // Fallback to customer home if offline or unexpected
        return const CustomerHomeScreen();
      }
    }

    // If not logged in, show modern Role Selection Entry Screen
    return const RoleSelectionScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _nextScreen,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen(onGetStarted: () {});
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Something went wrong. Please restart the app.'),
            ),
          );
        }

        return snapshot.data ?? const RoleSelectionScreen();
      },
    );
  }
}
