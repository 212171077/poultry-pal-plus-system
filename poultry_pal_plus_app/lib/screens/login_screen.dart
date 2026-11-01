import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:local_auth/local_auth.dart';
import 'package:poultry_pal_plus_app/screens/forgot_password_screen.dart';
import 'package:poultry_pal_plus_app/screens/register_screen.dart';
import 'package:poultry_pal_plus_app/service/poultry_pal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _rememberMe = false;
  final PoultryPalService _service = PoultryPalService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _obscurePassword = true;
  bool _isBiometricAvailable = false;
  String? _inlineError;

  double _opacity = 0.0;

  late final AnimationController _gradientController;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _opacity = 1.0);
    });

    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (mounted) {
        setState(() => _isBiometricAvailable = canCheck && isSupported);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _gradientController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    final ctx = context;
    final email = emailController.text.trim();
    final password = passwordController.text;

    setState(() => isLoading = true);

    try {
      await _service.login(email, password);

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', email);
        await prefs.setString('saved_password', password);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }

      if (!ctx.mounted) return;

      // Success animation
      await showDialog(
        context: ctx,
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
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ),
        ),
      );

      if (!ctx.mounted) return;
      Navigator.of(ctx).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity:
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              child: child,
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
            () => _inlineError = 'Invalid email or password. Please try again.');
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loginWithBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email');
    final password = prefs.getString('saved_password');
    final remember = prefs.getBool('remember_me') ?? false;

    if (!remember || email == null || password == null) {
      if (mounted) {
        setState(() =>
            _inlineError = 'Log in with email first, then enable Remember Me.');
      }
      return;
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to log in to Poultry Pal Plus',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (authenticated) {
        emailController.text = email;
        passwordController.text = password;
        _login();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError = 'Biometric authentication failed.');
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon,
      {Widget? suffixIcon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight),
      filled: true,
      fillColor: isDark
          ? AppColors.surfaceVariantDark
          : AppColors.surfaceVariantLight,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
            color: AppColors.adaptivePrimary(context), width: 1.5),
      ),
      prefixIcon:
          Icon(icon, color: AppColors.adaptivePrimary(context)),
      suffixIcon: suffixIcon,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = AppColors.adaptivePrimary(context);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, child) {
          final t = _gradientController.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Color.lerp(const Color(0xFF121A12),
                            const Color(0xFF1A2B1A), t)!,
                        Color.lerp(const Color(0xFF1B251B),
                            const Color(0xFF0D1A0D), t)!,
                      ]
                    : [
                        Color.lerp(const Color(0xFFFFF8F0),
                            const Color(0xFFFFF0E0), t)!,
                        Color.lerp(const Color(0xFFF4EDE5),
                            const Color(0xFFEADDD0), t)!,
                      ],
              ),
            ),
            child: child,
          );
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 800),
          opacity: _opacity,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          margin:
                              const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface
                                .withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.6),
                                width: 1),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: isDark ? 0.35 : 0.10),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Column(
                            children: [
                              // ── 1. Hero logo ──
                              Hero(
                                tag: 'appLogoHero',
                                child: Container(
                                  width: 88,
                                  height: 88,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primary
                                            .withValues(alpha: 0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor:
                                        theme.colorScheme.surface,
                                    backgroundImage:
                                        const AssetImage('assets/icon.png'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Welcome back!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                              ).animate().fadeIn(duration: 600.ms).moveY(
                                  begin: 20),
                              const SizedBox(height: 4),
                              Text(
                                'Login to your account',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ).animate().fadeIn(
                                  duration: 600.ms, delay: 100.ms),
                              const SizedBox(height: 24),

                              // ── Email field ──
                              TextFormField(
                                controller: emailController,
                                decoration: _inputDecoration(
                                    'Email', Icons.email_outlined),
                                keyboardType: TextInputType.emailAddress,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  return null;
                                },
                              ).animate().fadeIn(
                                  duration: 500.ms, delay: 200.ms),
                              const SizedBox(height: 14),

                              // ── 4. Password field with show/hide ──
                              TextFormField(
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                decoration: _inputDecoration(
                                  'Password',
                                  Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: primary,
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword =
                                            !_obscurePassword),
                                  ),
                                ),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ).animate().fadeIn(
                                  duration: 500.ms, delay: 300.ms),
                              const SizedBox(height: 6),

                              // Remember Me
                              CheckboxListTile(
                                value: _rememberMe,
                                onChanged: (v) => setState(
                                    () => _rememberMe = v ?? false),
                                activeColor: primary,
                                title: const Text('Remember Me'),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ).animate().fadeIn(delay: 350.ms),

                              // ── 7. Inline error message ──
                              if (_inlineError != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
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

                              // ── 5. Login button with loading state ──
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    disabledBackgroundColor:
                                        primary.withValues(alpha: 0.6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    elevation: 2,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          'Login',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600),
                                        ),
                                ),
                              ).animate().scale(delay: 400.ms),

                              // ── 8. Biometric login ──
                              if (_isBiometricAvailable) ...[
                                const SizedBox(height: 12),
                                Row(children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Text('or',
                                        style: TextStyle(
                                            color: isDark
                                                ? AppColors
                                                    .textSecondaryDark
                                                : AppColors
                                                    .textSecondaryLight,
                                            fontSize: 13)),
                                  ),
                                  const Expanded(child: Divider()),
                                ]),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _loginWithBiometrics,
                                  icon: const Icon(Icons.fingerprint,
                                      size: 22),
                                  label:
                                      const Text('Use Biometrics'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primary,
                                    side: BorderSide(
                                        color: primary, width: 1.5),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                  ),
                                ).animate().fadeIn(delay: 450.ms),
                              ],

                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const ForgotPasswordScreen()));
                                    },
                                    child: const Text('Forgot Password?'),
                                  ).animate().fadeIn(delay: 620.ms),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const RegisterScreen()));
                                    },
                                    child: const Text('Register'),
                                  ).animate().fadeIn(delay: 650.ms),
                                ],
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
        ),
      ),
    );
  }
}
