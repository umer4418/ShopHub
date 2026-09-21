import 'package:flutter_test/flutter_test.dart';
import 'package:shophub/main.dart';
import 'package:shophub/state/shop_store.dart';

void main() {
  testWidgets('ShopHub renders home branding', (tester) async {
    final store = ShopStore()..ready = true;
    await tester.pumpWidget(ShopHubApp(store: store));
    await tester.pump();
    expect(find.text('ShopHub'), findsWidgets);
  });
}
