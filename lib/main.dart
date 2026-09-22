import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'bindings/initial_bindings.dart';
import 'state/shop_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://bbwwtdmwmilvpqmlufgd.supabase.co',
    publishableKey: 'sb_publishable_p6WdHWKYTWgUknPzhV6vsw_zn3oaAX_',
  );

  // Initialize MVC Bindings (Services & Controllers)
  final bindings = await InitialBindings.init();

  // Start application
  runApp(ShopHubApp(bindings: bindings));
}

class ShopHubApp extends StatefulWidget {
  const ShopHubApp({
    super.key,
    this.bindings,
    this.store,
  });

  final InitialBindings? bindings;
  final ShopStore? store;

  @override
  State<ShopHubApp> createState() => _ShopHubAppState();
}

class _ShopHubAppState extends State<ShopHubApp> {
  late final InitialBindings bindings;

  @override
  void initState() {
    super.initState();
    bindings = widget.bindings ?? InitialBindings.sync();
    if (widget.store != null && !widget.store!.ready) {
      widget.store!.init();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'ShopHub',
      debugShowCheckedModeBanner: false,

      // App theme
      theme: AppTheme.light(),

      // Routing configured via app/routes/app_routes.dart & app_pages.dart
      initialRoute: AppRoutes.initial,
      getPages: AppPages.pages,
      routes: AppPages.routes,
      onGenerateRoute: AppPages.onGenerateRoute,
    );
  }
}