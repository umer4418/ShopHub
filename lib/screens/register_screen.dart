import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const route = AppRoutes.register;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _isAdmin = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authCtrl = Get.find<AuthController>();
    final err = await authCtrl.register(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      phone: _phone.text.trim(),
      isAdmin: _isAdmin,
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

    if (_isAdmin) {
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
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Join ShopHub',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                const Text(
                  'Register as',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Customer / Client'),
                        icon: Icon(Icons.person_outline),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Admin'),
                        icon: Icon(Icons.admin_panel_settings_outlined),
                      ),
                    ],
                    selected: {_isAdmin},
                    onSelectionChanged: (newSelection) {
                      setState(() => _isAdmin = newSelection.first);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _name,
                  labelText: 'Full name',
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _email,
                  labelText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _phone,
                  labelText: 'Phone number',
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Enter a valid phone'
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _password,
                  labelText: 'Password',
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.length < 4) ? 'Min 4 characters' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 18),
                AppButton(
                  text: _isAdmin ? 'Create Admin Account' : 'Create Account',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleRegister,
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
                          color: Colors.grey,
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
                    AppRoutes.login,
                  ),
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
