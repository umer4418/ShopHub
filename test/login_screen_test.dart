import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shophub/app/routes/app_routes.dart';
import 'package:shophub/controllers/auth_controller.dart';
import 'package:shophub/core/widgets/app_button.dart';
import 'package:shophub/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginScreen UI & Behavior', () {
    late AuthController authCtrl;

    setUp(() {
      Get.reset();
      authCtrl = AuthController()..init();
      Get.put(authCtrl);
    });

    Widget createLoginApp() {
      return GetMaterialApp(
        initialRoute: AppRoutes.login,
        getPages: [
          GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
          GetPage(name: AppRoutes.home, page: () => const Scaffold(body: Text('Home Screen'))),
          GetPage(name: AppRoutes.register, page: () => const Scaffold(body: Text('Register Screen'))),
        ],
      );
    }

    testWidgets('renders 1-line ShopHub heading and Welcome back to ShopHub subtitle', (tester) async {
      await tester.pumpWidget(createLoginApp());
      await tester.pumpAndSettle();

      // Heading and subtitle exist
      expect(find.text('ShopHub'), findsOneWidget);
      expect(find.text('Welcome back to ShopHub'), findsOneWidget);

      // Old demo credentials instruction text is removed
      expect(find.textContaining('Use customer@shophub.com'), findsNothing);
      expect(find.textContaining('admin@shophub.com'), findsNothing);

      // Both buttons exist
      expect(find.widgetWithText(AppButton, 'Login'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Continue with Google'), findsOneWidget);

      // Forgot Password button exists
      expect(find.text('Forgot Password?'), findsOneWidget);
    });

    testWidgets('tapping Forgot Password opens reset dialog', (tester) async {
      await tester.pumpWidget(createLoginApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel to dismiss
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Reset Password'), findsNothing);
    });

    testWidgets('loading state is isolated to clicked button', (tester) async {
      final completer = Completer<String?>();
      final slowAuth = _SlowMockAuthController(completer)..init();
      Get.reset();
      Get.put<AuthController>(slowAuth);

      await tester.pumpWidget(createLoginApp());
      await tester.pumpAndSettle();

      // Fill in valid email and password
      await tester.enterText(find.byType(TextField).at(0), 'customer@shophub.com');
      await tester.enterText(find.byType(TextField).at(1), 'user123');

      // Tap Login button
      await tester.tap(find.widgetWithText(AppButton, 'Login'));
      await tester.pump(); // Advance frame while async operation is pending

      // Check AppButton widget properties while login is in flight
      final loginBtn = tester.widget<AppButton>(find.byWidgetPredicate(
        (w) => w is AppButton && w.text == 'Login',
      ));
      final googleBtn = tester.widget<AppButton>(find.byWidgetPredicate(
        (w) => w is AppButton && w.text == 'Continue with Google',
      ));

      // Login button should be loading, but Google button should NOT be loading
      expect(loginBtn.isLoading, isTrue);
      expect(googleBtn.isLoading, isFalse);

      // Complete the login call and settle
      completer.complete(null);
      await tester.pumpAndSettle();
    });
  });
}

class _SlowMockAuthController extends AuthController {
  final Completer<String?> _completer;

  _SlowMockAuthController(this._completer);

  @override
  Future<String?> login(String email, String password) {
    return _completer.future;
  }
}

