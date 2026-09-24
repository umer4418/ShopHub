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
  bool _isLoggingIn = false;
  bool _isGoogleLoggingIn = false;

  bool get _isLoading => _isLoggingIn || _isGoogleLoggingIn;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _isLoggingIn = true;
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
        _isLoggingIn = false;
      });
      return;
    }

    setState(() => _isLoggingIn = false);

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
      _isGoogleLoggingIn = true;
      _error = null;
    });

    final authCtrl = Get.find<AuthController>();
    final err = await authCtrl.loginWithGoogle();

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _error = err;
        _isGoogleLoggingIn = false;
      });
      return;
    }

    setState(() => _isGoogleLoggingIn = false);

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

  void _handleForgotPassword() {
    final resetEmailCtrl = TextEditingController(text: _email.text.trim());
    final formKey = GlobalKey<FormState>();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: ShopColors.primary),
              SizedBox(width: 8),
              Text(
                'Reset Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your registered ShopHub email address and we will send you a password recovery link.',
                  style: TextStyle(fontSize: 13, color: ShopColors.muted),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: resetEmailCtrl,
                  labelText: 'Email Address',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ShopColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSending
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSending = true);
                      final email = resetEmailCtrl.text.trim();
                      final authCtrl = Get.find<AuthController>();
                      final err = await authCtrl.sendPasswordResetEmail(email);

                      if (!ctx.mounted || !mounted) return;
                      Navigator.pop(ctx);

                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(err),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Password reset link sent to $email. Please check your inbox.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
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
                const Text(
                  'ShopHub',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Welcome back to ShopHub',
                  style: TextStyle(
                    fontSize: 15,
                    color: ShopColors.muted,
                  ),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _handleForgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: ShopColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 10),
                AppButton(
                  text: 'Login',
                  isLoading: _isLoggingIn,
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
                  isLoading: _isGoogleLoggingIn,
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
