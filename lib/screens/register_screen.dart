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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
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
                const SizedBox(height: 20),
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
                  text: 'Create account',
                  onPressed: () {
                    if (!_form.currentState!.validate()) return;
                    final err = Get.find<AuthController>().register(
                          name: _name.text.trim(),
                          email: _email.text,
                          password: _password.text,
                          phone: _phone.text.trim(),
                        );
                    if (err != null) {
                      setState(() => _error = err);
                      return;
                    }
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.home,
                      (_) => false,
                    );
                  },
                ),
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
