import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_text_field.dart';
import '../theme/colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const route = AppRoutes.login;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authCtrl = Get.find<AuthController>();
    final err = await authCtrl.login(
      _email.text.trim(),
      _password.text,
    );

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _error = err;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = false);

    if (authCtrl.currentUser?.isAdmin == true) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.adminDashboard,
        (_) => false,
      );
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (_) => false,
      );
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authCtrl = Get.find<AuthController>();
    final err = await authCtrl.loginWithGoogle();

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _error = err;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = false);

    if (authCtrl.currentUser != null) {
      if (authCtrl.currentUser!.isAdmin) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.adminDashboard,
          (_) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Welcome back',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text(
                  'Use customer@shophub.com / user123 or admin@shophub.com / admin123',
                  style: TextStyle(color: ShopColors.muted),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _email,
                  labelText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _password,
                  labelText: 'Password',
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.length < 4) ? 'Enter your password' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 18),
                AppButton(
                  text: 'Login',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleLogin,
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: ShopColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Continue with Google',
                  isOutlined: true,
                  icon: Icons.g_mobiledata,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleGoogleLogin,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.register,
                  ),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
