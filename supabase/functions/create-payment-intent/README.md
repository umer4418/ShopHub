# Supabase Edge Function: `create-payment-intent`

This Edge Function handles Stripe payment intent creation securely on the backend for ShopHub.

## How It Works
1. Receives order details (`amount`, `currency`, `customerName`, `customerEmail`, `orderId`) from the Flutter app.
2. Uses the Stripe secret key (`STRIPE_SECRET_KEY`) to create a Stripe `PaymentIntent`.
3. Returns the `clientSecret` and `paymentIntentId` to the client app to complete the payment.

---

## How to Deploy via Supabase CLI

### 1. Install & Login to Supabase CLI
```bash
# Login to your Supabase account
supabase login
```

### 2. Link your Project
```bash
supabase link --project-ref bbwwtdmwmilvpqmlufgd
```

### 3. Set your Stripe Secret Key
```bash
supabase secrets set STRIPE_SECRET_KEY=sk_test_51UGajrK1YhEIoCnp4YKABndcsPt80n1VqUTjdnvGAA3fJ5fuRUdGezKidJi8f1zqtkgX5sbIdR4AXAetPlWWHZvR001xcU0F9x
```

### 4. Deploy the Function
```bash
supabase functions deploy create-payment-intent --no-verify-jwt
```

> **Note:** The ShopHub Flutter app includes an intelligent automatic fallback mechanism. If the Edge Function has not been deployed yet, the app will gracefully process test payments via Stripe API so you can test immediately without any errors.
