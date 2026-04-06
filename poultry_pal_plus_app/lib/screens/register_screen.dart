import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:lottie/lottie.dart';
import 'package:poultry_pal_plus_app/models/message_response.dart';
import 'package:poultry_pal_plus_app/screens/login_screen.dart';
import 'package:poultry_pal_plus_app/service/poultry_pal_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _farmNameController = TextEditingController();
  final PoultryPalService _service = PoultryPalService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _fadeAnimation2;
  late final Animation<double> _fadeAnimation3;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
    _fadeAnimation2 = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.5, 0.75, curve: Curves.easeIn),
    );
    _fadeAnimation3 = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _farmNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          Hero(
                            tag: 'register-avatar',
                            child: Container(
                              width: 88,
                              height: 88,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.adaptivePrimary(context),
                                shape: BoxShape.circle,
                              ),
                              child: const CircleAvatar(
                                radius: 40,
                                backgroundImage: AssetImage('assets/register.png'),
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Create your account',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.adaptivePrimary(context),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextFormField(
                            controller: _farmNameController,
                            labelText: 'Farm Name',
                            icon: Icons.agriculture_outlined,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Please enter your farm name'
                                : null,
                          ),
                          _buildTextFormField(
                            controller: _nameController,
                            labelText: 'Your Name',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter your name';
                              if (value.length < 2 || value.length > 50) return 'Name must be between 2 and 50 characters';
                              return null;
                            },
                          ),
                          _buildTextFormField(
                            controller: _surnameController,
                            labelText: 'Your Surname',
                            icon: Icons.person,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter your surname';
                              if (value.length < 2 || value.length > 50) return 'Surname must be between 2 and 50 characters';
                              return null;
                            },
                          ),
                          _buildTextFormField(
                            controller: _emailController,
                            labelText: 'Your Email',
                            icon: Icons.email_outlined,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter your email';
                              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Enter a valid email';
                              if (value.length > 50) return 'Email must not exceed 50 characters';
                              return null;
                            },
                          ),
                          _buildTextFormField(
                            controller: _phoneNumberController,
                            labelText: 'Phone Number',
                            icon: Icons.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter your phone number';
                              if (value.length > 15) return 'Phone number too long';
                              if (!RegExp(r'^[0-9]+$').hasMatch(value)) return 'Only digits allowed';
                              return null;
                            },
                          ),
                          _buildTextFormField(
                            controller: _passwordController,
                            labelText: 'Your Password',
                            obscureText: _obscurePassword,
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter your password';
                              if (value.length < 6 || value.length > 120) return 'Password must be 6-120 characters';
                              return null;
                            },
                          ),
                          _buildTextFormField(
                            controller: _confirmPasswordController,
                            labelText: 'Confirm Your Password',
                            obscureText: _obscureConfirmPassword,
                            icon: Icons.lock,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                            validator: (value) {
                              if (value != _passwordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Register button with animation
                          FadeTransition(
                            opacity: _fadeAnimation2,
                            child: ElevatedButton(
                              onPressed: _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.adaptivePrimary(context),
                                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Register',
                                style: TextStyle(
                                    color: AppColors.surfaceLight,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Navigate to Login
                          FadeTransition(
                            opacity: _fadeAnimation3,
                            child: TextButton(
                              child: const Text(
                                'Already have an account? Login',
                                style: TextStyle(fontSize: 14),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (context) => const LoginScreen()),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    bool obscureText = false,
    IconData? icon,
    Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(fontSize: 16, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, color: AppColors.adaptivePrimary(context)) : null,
          suffixIcon: suffixIcon,
          labelText: labelText,
          labelStyle: TextStyle(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.adaptivePrimary(context), width: 1.5),
          ),
        ),
        validator: validator,
      ),
    );
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      // Show loading animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ScaleTransition(
          scale: _fadeAnimation,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: SizedBox(
              width: 200,
              height: 200,
              child: Lottie.asset('assets/lottie/loading_animation.json', repeat: true),
            ),
          ),
        ),
      );



      MessageResponse result = await _service.signup(
        name: _nameController.text,
        surname: _surnameController.text,
        email: _emailController.text,
        phoneNumber: _phoneNumberController.text,
        password: _passwordController.text,
        farmName: _farmNameController.text,
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (result.success) {
        // Show success animation
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ScaleTransition(
            scale: _fadeAnimation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: SizedBox(
                width: 200,
                height: 200,
                child: Lottie.asset('assets/lottie/success_check.json', repeat: false),
              ),
            ),
          ),
        );


        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).pop(); // Close success dialog
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        final snackBar = SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: AppColors.surfaceLight),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.message,
                  style: const TextStyle(color: AppColors.surfaceLight),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    }
  }
}
