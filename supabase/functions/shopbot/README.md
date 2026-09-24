# ShopBot Supabase Edge Function

AI customer support chatbot for the ShopHub marketplace powered by Google Gemini AI and live Supabase order tracking.

## Features
- **Strict Domain Guardrail**: Only answers customer questions about ShopHub app, orders, delivery times, processing times, and product stock. Politely declines any off-topic queries with:
  > *"I am here to assist you regarding the ShopHub app only. How can I help you with your ShopHub shopping, orders, or account today?"*
- **Live Supabase Order & Stock Context**: Queries live orders from `orders` table and product stock from `products` table and injects them as grounding into Gemini.
- **Trained with Gemini AI**: Fully trained on password reset, account management, shipping times, processing times, payment methods (COD & Stripe), and 7-day return policy.
- **Model Fallback**: Automatically tries `gemini-flash-latest`, falling back to `gemini-flash-lite-latest` or `gemini-3.6-flash` if temporary Google 503 capacity spikes occur.

## Deployment to Supabase

To deploy this function to your live Supabase project:

```bash
# 1. Login to Supabase CLI (if not already logged in)
npx supabase login

# 2. Link your project
npx supabase link --project-ref bbwwtdmwmilvpqmlufgd

# 3. Configure Gemini Secrets
npx supabase secrets set GEMINI_API_KEY=AIzaSyCDIEz5yERvB7ip2Iicdy0d8sZUFZN-vNE GEMINI_MODEL=gemini-flash-latest GEMINI_URL=https://generativelanguage.googleapis.com/v1beta/models

# 4. Deploy the shopbot function
npx supabase functions deploy shopbot --no-verify-jwt
```

## Testing Locally

```bash
npx supabase functions serve shopbot --no-verify-jwt
```
