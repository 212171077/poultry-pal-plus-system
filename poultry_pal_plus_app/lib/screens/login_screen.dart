import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:poultry_pal_plus_app/screens/register_screen.dart';
import 'package:poultry_pal_plus_app/service/poultry_pal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _rememberMe = false;
  final PoultryPalService _service = PoultryPalService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _obscurePassword = true; // <-- Password visibility toggle
  double _opacity = 0.0;
  double _scale = 1.0;

  late final AnimationController _fadeController = AnimationController(
    duration: const Duration(milliseconds: 800),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() => _opacity = 1.0);
      _fadeController.forward();
    });
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) {
      // If form is invalid, do not proceed
      return;
    }

    final context = this.context;
    String email = emailController.text.trim();
    String password = passwordController.text;


    setState(() {
      isLoading = true;
      _scale = 0.95;
    });

    _showLoadingDialog();

    try {
      await _service.login(email, password);

     // Save credentials if Remember Me is checked
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

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      // Success check animation
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            Dialog(
              backgroundColor: Colors.transparent,
              child: SizedBox(
                width: 150,
                height: 150,
                child: Lottie.asset(
                  'assets/lottie/success_check.json',
                  repeat: false,
                  onLoaded: (composition) async {
                    await Future.delayed(composition.duration);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ),
      );

      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (context, animation,
              secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
                parent: animation, curve: Curves.easeInOut);
            return FadeTransition(opacity: curved, child: child);
          },
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text('Invalid username or password',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          _scale = 1.0;
        });
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _fadeController,
              curve: Curves.easeInOutBack,
            ),
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: SizedBox(
                width: 200,
                height: 200,
                child: Lottie.asset(
                  'assets/lottie/loading_animation.json',
                  repeat: true,
                ),
              ),
            ),
          ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon,
      {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black87),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      prefixIcon: Icon(icon, color: Colors.brown),
      suffixIcon: suffixIcon,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 800),
        opacity: _opacity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: AnimatedScale(
                scale: _scale,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                              color: Colors.grey[300]!, width: 1),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12,
                                blurRadius: 12,
                                offset: Offset(0, 5)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Hero(
                              tag: 'avatarHero',
                              child: Container(
                                width: 88,
                                height: 88,
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.brown,
                                  shape: BoxShape.circle,
                                ),
                                child: const CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white,
                                  backgroundImage: AssetImage(
                                      'assets/login.png'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Login to your account',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ).animate().fadeIn(duration: 600.ms).moveY(
                                begin: 30),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: emailController,
                              decoration: _inputDecoration(
                                  'Email', Icons.email_outlined),
                              keyboardType: TextInputType.emailAddress,
                              autovalidateMode: AutovalidateMode
                                  .onUserInteraction,
                              validator: (value) {
                                if (value == null || value
                                    .trim()
                                    .isEmpty) {
                                  return 'Please enter your email';
                                }
                                return null;
                              },
                            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passwordController,
                              obscureText: _obscurePassword,
                              decoration: _inputDecoration(
                                'Password',
                                Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.brown,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              autovalidateMode: AutovalidateMode
                                  .onUserInteraction,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                            const SizedBox(height: 10),

                            // ✅ Remember Me Checkbox
                            CheckboxListTile(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                              activeColor: theme.primaryColor,
                              title: const Text("Remember Me"),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ).animate().fadeIn(delay: 350.ms),

                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 50, vertical: 15),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              child: const Text('Login',
                                  style: TextStyle(color: Colors.white)),
                            ).animate().scale(delay: 400.ms),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () {},
                              child: const Text('Forgot Password?'),
                            ).animate().fadeIn(delay: 600.ms),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => const RegisterScreen()));
                              },
                              child: const Text(
                                  "Don't have an account? Register"),
                            ).animate().fadeIn(delay: 700.ms),
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
    );
  }
}
