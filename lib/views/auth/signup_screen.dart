import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/user_role.dart';
import 'package:yummy_go_application/services/auth_service.dart';
import 'package:yummy_go_application/views/auth/login_screen.dart';
import 'package:yummy_go_application/views/auth/role_selection_screen.dart';
import 'package:yummy_go_application/widgets/auth_login_reg_widgets.dart';
import 'package:yummy_go_application/widgets/auth_text_field.dart';

class CustomerRegistrationScreen extends StatefulWidget {
  final UserRole targetRole;

  const CustomerRegistrationScreen({
    super.key,
    this.targetRole = UserRole.customer,
  });

  @override
  State<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState
    extends State<CustomerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Additional controllers for partner roles
  final _restaurantNameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  String _selectedVehicle = 'Bike';

  final AuthService _authService = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _restaurantNameController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }

    final email = value.trim();
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    if (value.length < 6) {
      return 'Password must contain at least 6 characters';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  Future<void> _registerUser() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Show registration loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: AppColors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.teal),
                  SizedBox(width: 16),
                  Text(
                    'Creating account...',
                    style: TextStyle(
                      color: AppColors.deepTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final extraData = <String, dynamic>{};
      if (widget.targetRole == UserRole.deliveryPartner) {
        extraData['vehicleType'] = _selectedVehicle;
        extraData['vehicleNumber'] = _vehicleNumberController.text.trim();
      } else if (widget.targetRole == UserRole.restaurantOwner) {
        extraData['restaurantName'] = _restaurantNameController.text.trim();
      }

      final registeredEmail = _emailController.text.trim();

      await _authService.registerWithRole(
        name: _nameController.text.trim(),
        email: registeredEmail,
        password: _passwordController.text,
        role: widget.targetRole,
        phone: _phoneController.text.trim(),
        extraData: extraData,
      );

      // Sign out so the user explicitly logs in on the Login screen
      await _authService.signOut();

      if (!mounted) return;

      // Close loading dialog on success
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account registered successfully as ${widget.targetRole.displayName}! Please log in.',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      _navigateToLogin(registeredEmail);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // Close loading dialog on failure
      Navigator.of(context, rootNavigator: true).pop();

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered. Please log in.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Please choose a stronger password.';
          break;
        case 'operation-not-allowed':
          message = 'Email/Password authentication is not enabled.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
        default:
          message = e.message ?? 'Registration failed. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog on failure
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration error: $e'),
          backgroundColor: AppColors.error,
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

  void _navigateToLogin(String email) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          targetRole: widget.targetRole,
          initialEmail: email,
        ),
      ),
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

  void _switchToLoginScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(targetRole: widget.targetRole),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.targetRole;

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: buildAuthAppBar(
        title: 'Register',
        onBackPressed: _handleBackNavigation,
        actionLabel: 'Login',
        onActionPressed: _isLoading ? null : _switchToLoginScreen,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              AuthHeader(
                seamlessWithAppBar: true,
                title: 'Join as ${role.displayName}',
                subtitle: role.tagline,
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
                        const Text(
                          'Create your account',
                          style: TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Name field
                        AuthTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          prefixIcon: Icons.person_outline_rounded,
                          validator: _validateName,
                        ),
                        const SizedBox(height: 16),

                        // Email field
                        AuthTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 16),

                        // Phone field
                        AuthTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        // Conditional role fields
                        if (role == UserRole.restaurantOwner) ...[
                          AuthTextField(
                            controller: _restaurantNameController,
                            label: 'Restaurant Name',
                            prefixIcon: Icons.storefront_rounded,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter restaurant name'
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (role == UserRole.deliveryPartner) ...[
                          DropdownButtonFormField<String>(
                            value: _selectedVehicle,
                            decoration: InputDecoration(
                              labelText: 'Vehicle Type',
                              prefixIcon: const Icon(Icons.two_wheeler_rounded, color: AppColors.teal),
                              filled: true,
                              fillColor: AppColors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Bike', child: Text('Motorcycle / Bike')),
                              DropdownMenuItem(value: 'Scooter', child: Text('Scooter')),
                              DropdownMenuItem(value: 'EV', child: Text('Electric Vehicle (EV)')),
                              DropdownMenuItem(value: 'Bicycle', child: Text('Bicycle')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedVehicle = v);
                            },
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _vehicleNumberController,
                            label: 'Vehicle Number (e.g. AP09 AB 1234)',
                            prefixIcon: Icons.pin_outlined,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Password field
                        AuthTextField(
                          controller: _passwordController,
                          label: 'Password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: true,
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 16),

                        // Confirm password field
                        AuthTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: true,
                          validator: _validateConfirmPassword,
                        ),
                        const SizedBox(height: 24),

                        // Register button
                        AuthButton(
                          text: 'Register as ${role.displayName}',
                          color: role.color,
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _registerUser,
                        ),
                        const SizedBox(height: 22),

                        // Login link
                        AuthBottomLink(
                          message: 'Already have an account? ',
                          actionText: 'Login here!',
                          onTap: _switchToLoginScreen,
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
