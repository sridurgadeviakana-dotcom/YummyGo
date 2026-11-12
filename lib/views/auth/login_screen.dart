import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/user_role.dart';
import 'package:yummy_go_application/services/role_service.dart';
import 'package:yummy_go_application/views/admin/admin_dashboard.dart';
import 'package:yummy_go_application/views/auth/role_selection_screen.dart';
import 'package:yummy_go_application/views/auth/signup_screen.dart';
import 'package:yummy_go_application/views/customer/customer_home_screen.dart';
import 'package:yummy_go_application/views/delivery_partner/delivery_dashboard.dart';
import 'package:yummy_go_application/views/forgot_password_screen.dart';
import 'package:yummy_go_application/views/restaurant_owner/owner_dashboard.dart';
import 'package:yummy_go_application/widgets/auth_login_reg_widgets.dart';
import 'package:yummy_go_application/widgets/auth_text_field.dart';

class LoginScreen extends StatefulWidget {
  final UserRole? targetRole;
  final String? initialEmail;

  const LoginScreen({
    super.key,
    this.targetRole,
    this.initialEmail,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final RoleService _roleService = RoleService();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }

    if (value.length < 6) {
      return 'Password must contain at least 6 characters';
    }

    return null;
  }

  // Firebase Login & Dynamic Role Routing
  Future<void> _loginUser() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception('Authentication failed');

      // Fetch or assign role
      UserRole resolvedRole;
      final profile = await _roleService.getCurrentUserProfile();

      if (widget.targetRole != null) {
        resolvedRole = widget.targetRole!;
        // Update user role in Firestore if target role was selected
        await _roleService.setUserRole(uid: user.uid, role: resolvedRole);
      } else {
        resolvedRole = profile?.role ?? UserRole.customer;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back! Signed in as ${resolvedRole.displayName}.'),
          backgroundColor: Colors.green,
        ),
      );

      _navigateToDashboard(resolvedRole);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-disabled':
          message = 'This account has been disabled.';
          break;

        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Please check your internet connection.';
          break;

        default:
          message = e.message ?? 'Login failed. Please try again.';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => target),
      (route) => false,
    );
  }

  void _handleBackNavigation() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      );
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerRegistrationScreen(
          targetRole: widget.targetRole ?? UserRole.customer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.targetRole;

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: buildAuthAppBar(
        title: 'Login',
        onBackPressed: _handleBackNavigation,
        actionLabel: 'Register',
        onActionPressed: _isLoading ? null : _navigateToRegister,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Swiggy-like Top Header Card
              AuthHeader(
                seamlessWithAppBar: true,
                title: role != null ? '${role.displayName} Portal' : 'Welcome Back',
                subtitle: role != null
                    ? role.tagline
                    : 'Sign in to access your customized dashboard and services',
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(25, 10, 25, 25),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (role != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: role.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: role.color.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(role.icon, color: role.color, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Signing in as: ${role.displayName}',
                                    style: TextStyle(
                                      color: AppColors.deepTeal,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const Text(
                          'Login to your account',
                          style: TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Email field
                        AuthTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),

                        const SizedBox(height: 19),

                        // Password field
                        AuthTextField(
                          controller: _passwordController,
                          label: 'Password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: true,
                          validator: _validatePassword,
                        ),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Common login button
                        AuthButton(
                          text: 'Login',
                          color: role?.color ?? AppColors.deepTeal,
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _loginUser,
                        ),

                        const SizedBox(height: 25),

                        // Registration navigation
                        AuthBottomLink(
                          message: "Don't have an account? ",
                          actionText: 'Register!',
                          onTap: _navigateToRegister,
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
