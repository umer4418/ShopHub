/// Stripe Configuration & Credentials
/// Holds publishable key, backend secret key fallback, and payment parameters.
class StripeConfig {
  StripeConfig._();

  /// Stripe Publishable Key (used on client side for tokenization & elements)
  static const String publishableKey =
      'pk_test_51UGajrK1YhEIoCnpHVduQSiRfiEEvILxI9ZJmze0MiuJiFT7F1ifY2jCtCYCQweiJUymsfjJBZV5YDQ3EFsSPWpf00PP4uVnvz';

  /// Stripe Secret Key (used in Supabase Edge Function & local direct fallback)
  static const String secretKey =
      'sk_test_51UGajrK1YhEIoCnp4YKABndcsPt80n1VqUTjdnvGAA3fJ5fuRUdGezKidJi8f1zqtkgX5sbIdR4AXAetPlWWHZvR001xcU0F9x';

  /// Default transaction currency (lowercase ISO)
  static const String defaultCurrency = 'pkr';

  /// Merchant display name shown on Stripe receipts
  static const String merchantName = 'ShopHub';

  /// Standard Stripe test card presets for rapid testing
  static const String testCardNumber = '4242 4242 4242 4242';
  static const String testCardExpiry = '12/34';
  static const String testCardCvc = '123';
  static const String testCardholder = 'Test Customer';
}
