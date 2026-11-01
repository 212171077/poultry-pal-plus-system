import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  bool _isLoading = false;
  String? _inlineError;
  String _passwordValue = '';

  late final AnimationController _gradientController;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _passwordController.addListener(() {
      setState(() => _passwordValue = _passwordController.text);
    });
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _farmNameController.dispose();
    super.dispose();
  }

  // ── 3. Password strength logic ──────────────────────────────────
  int _passwordStrength(String p) {
    if (p.isEmpty) return 0;
    int score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(p)) score++;
    return score; // 0–5
  }

  String _strengthLabel(int s) {
    if (s <= 1) return 'Weak';
    if (s <= 3) return 'Medium';
    return 'Strong';
  }

  Color _strengthColor(int s) {
    if (s <= 1) return AppColors.error;
    if (s <= 3) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = AppColors.adaptivePrimary(context);
    final strength = _passwordStrength(_passwordValue);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, child) {
          final t = _gradientController.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: isDark
                    ? [
                        Color.lerp(const Color(0xFF121A12),
                            const Color(0xFF1C2A1C), t)!,
                        Color.lerp(const Color(0xFF1B251B),
                            const Color(0xFF0E180E), t)!,
                      ]
                    : [
                        Color.lerp(const Color(0xFFFFF8F0),
                            const Color(0xFFF8EEE0), t)!,
                        Color.lerp(const Color(0xFFF0E8DC),
                            const Color(0xFFE8D5C0), t)!,
                      ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface
                            .withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.6),
                            width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.35 : 0.10),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Hero logo
                          Hero(
                            tag: 'register-avatar',
                            child: Container(
                              width: 88,
                              height: 88,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        primary.withValues(alpha: 0.30),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const CircleAvatar(
                                radius: 40,
                                backgroundImage:
                                    AssetImage('assets/register.png'),
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
                              color: primary,
                            ),
                          ).animate().fadeIn(duration: 500.ms).moveY(
                              begin: 20),
                          const SizedBox(height: 4),
                          Text(
                            'Join Poultry Pal Plus today',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ).animate().fadeIn(
                              duration: 500.ms, delay: 100.ms),
                          const SizedBox(height: 20),

                          // Form fields
                          _buildField(
                            controller: _farmNameController,
                            label: 'Farm Name',
                            icon: Icons.agriculture_outlined,
                            delay: 150,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Please enter your farm name'
                                : null,
                          ),
                          _buildField(
                            controller: _nameController,
                            label: 'Your Name',
                            icon: Icons.person_outline,
                            delay: 200,
                            validator: (v) {
                              if (v == null || v.isEmpty) { return 'Please enter your name'; }
                              if (v.length < 2 || v.length > 50) { return 'Name must be 2–50 characters'; }
                              return null;
                            },
                          ),
                          _buildField(
                            controller: _surnameController,
                            label: 'Your Surname',
                            icon: Icons.person,
                            delay: 230,
                            validator: (v) {
                              if (v == null || v.isEmpty) { return 'Please enter your surname'; }
                              if (v.length < 2 || v.length > 50) { return 'Surname must be 2–50 characters'; }
                              return null;
                            },
                          ),
                          _buildField(
                            controller: _emailController,
                            label: 'Your Email',
                            icon: Icons.email_outlined,
                            delay: 260,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) { return 'Please enter your email'; }
                              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) { return 'Enter a valid email'; }
                              if (v.length > 50) { return 'Email must not exceed 50 characters'; }
                              return null;
                            },
                          ),
                          _buildField(
                            controller: _phoneNumberController,
                            label: 'Phone Number',
                            icon: Icons.phone,
                            delay: 290,
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.isEmpty) { return 'Please enter your phone number'; }
                              if (v.length > 15) { return 'Phone number too long'; }
                              if (!RegExp(r'^[0-9]+$').hasMatch(v)) { return 'Only digits allowed'; }
                              return null;
                            },
                          ),

                          // ── 4. Password with show/hide + 3. strength indicator ──
                          _buildField(
                            controller: _passwordController,
                            label: 'Your Password',
                            icon: Icons.lock_outline,
                            delay: 320,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: primary,
                              ),
                              onPressed: () => setState(() =>
                                  _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) { return 'Please enter your password'; }
                              if (v.length < 6 || v.length > 120) { return 'Password must be 6–120 characters'; }
                              return null;
                            },
                          ),

                          // ── 3. Password strength bar ──
                          if (_passwordValue.isNotEmpty)
                            _PasswordStrengthBar(
                              strength: strength,
                              label: _strengthLabel(strength),
                              color: _strengthColor(strength),
                            ).animate().fadeIn(duration: 300.ms),

                          // ── 4. Confirm password with show/hide ──
                          _buildField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Your Password',
                            icon: Icons.lock,
                            delay: 350,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: primary,
                              ),
                              onPressed: () => setState(() =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword),
                            ),
                            validator: (v) {
                              if (v != _passwordController.text) { return 'Passwords do not match'; }
                              return null;
                            },
                          ),

                          // ── 7. Inline error ──
                          if (_inlineError != null)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.error
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.error
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.error, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _inlineError!,
                                      style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .shakeX(duration: 400.ms),

                          const SizedBox(height: 20),

                          // ── 5. Register button with loading state ──
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                disabledBackgroundColor:
                                    primary.withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20)),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Create Account',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ).animate().scale(delay: 380.ms),

                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            ),
                            child: const Text(
                              'Already have an account? Login',
                              style: TextStyle(fontSize: 14),
                            ),
                          ).animate().fadeIn(delay: 420.ms),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required int delay,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    required String? Function(String?) validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.adaptivePrimary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: TextStyle(
            fontSize: 15,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight),
        decoration: InputDecoration(
          prefixIcon:
              Icon(icon, color: primary),
          suffixIcon: suffixIcon,
          labelText: label,
          labelStyle: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: isDark
              ? AppColors.surfaceVariantDark
              : AppColors.surfaceVariantLight,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.error, width: 1.5),
          ),
        ),
        validator: validator,
      ),
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: delay));
  }

  void _register() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final MessageResponse result = await _service.signup(
        name: _nameController.text,
        surname: _surnameController.text,
        email: _emailController.text,
        phoneNumber: _phoneNumberController.text,
        password: _passwordController.text,
        farmName: _farmNameController.text,
      );

      if (!mounted) return;

      if (result.success) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            child: SizedBox(
              width: 150,
              height: 150,
              child: Lottie.asset(
                'assets/lottie/success_check.json',
                repeat: false,
                onLoaded: (composition) async {
                  await Future.delayed(composition.duration);
                  if (mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ),
        );

        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Awaiting approval'),
            content: const Text(
                'Your account was created and is awaiting approval by the administrator. '
                'We emailed you a welcome message and will email you again once a decision is made.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        // ── 7. Inline error instead of SnackBar ──
        setState(() => _inlineError = result.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError =
            'Registration failed. Please check your details and try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ──────────────────────────────────────────────────────────────────
// 3. Password Strength Bar Widget
// ──────────────────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final int strength; // 0–5
  final String label;
  final Color color;

  const _PasswordStrengthBar({
    required this.strength,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (strength / 5.0).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: fraction),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 12),
              const SizedBox(width: 4),
              Text(
                'Password strength: $label',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
