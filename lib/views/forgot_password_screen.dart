
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/widgets/auth_login_reg_widgets.dart';
import 'package:yummy_go_application/widgets/auth_text_field.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _emailSent = true;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message = 'No account was found for this email.';
          break;

        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Please check your internet connection.';
          break;

        default:
          message = e.message ?? 'Unable to send reset email.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: buildAuthAppBar(
        title: 'Forgot Password',
        onBackPressed: () => Navigator.maybePop(context),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const AuthHeader(
                seamlessWithAppBar: true,
                title: 'Forgot Password?',
                subtitle: 'No worries! Let us help you get back to YummyGo.',
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(25, 10, 25, 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: _emailSent
                      ? _successContent()
                      : _resetForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resetForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),

          const Icon(
            Icons.mark_email_unread_outlined,
            size: 65,
            color: AppColors.teal,
          ),

          const SizedBox(height: 15),

          const Text(
            'Reset Your Password',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.deepTeal,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Enter the email address associated with your account. '
            'We will send you a link to reset your password.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.teal,
              fontSize: 14,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 28),

          AuthTextField(
            controller: _emailController,
            label: 'Email Address',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),

          const SizedBox(height: 28),

          AuthButton(
            text: 'Send Reset Link',
            color: AppColors.deepTeal,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _sendResetLink,
          ),

          const SizedBox(height: 22),

          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.teal,
              ),
              label: const Text(
                'Back to Login',
                style: TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _successContent() {
    return Column(
      children: [
        const SizedBox(height: 25),

        Container(
          height: 95,
          width: 95,
          decoration: BoxDecoration(
            color: AppColors.lime.withOpacity(0.13),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            size: 55,
            color: AppColors.teal,
          ),
        ),

        const SizedBox(height: 25),

        const Text(
          'Check Your Email!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.deepTeal,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'If an account exists for this email, '
          'you will receive a password reset link. '
          'Please check your inbox and spam folder.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.teal,
            fontSize: 14,
            height: 1.6,
          ),
        ),

        const SizedBox(height: 15),

        Text(
          _emailController.text.trim(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 30),

        AuthButton(
          text: 'Back to Login',
          color: AppColors.deepTeal,
          onPressed: () => Navigator.pop(context),
        ),

        const SizedBox(height: 15),

        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _emailSent = false;
                  });
                },
          child: const Text(
            'Try another email',
            style: TextStyle(
              color: AppColors.teal,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
