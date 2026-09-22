// Supabase Edge Function: create-payment-intent
// Creates a Stripe PaymentIntent for ShopHub e-commerce orders.
// Runtime: Deno / Supabase Edge Functions

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req: Request) => {
  // 1. Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 2. Obtain Stripe Secret Key (from Supabase Vault or fallback to configured test key)
    const stripeSecretKey =
      Deno.env.get('STRIPE_SECRET_KEY') ||
      'sk_test_51UGajrK1YhEIoCnp4YKABndcsPt80n1VqUTjdnvGAA3fJ5fuRUdGezKidJi8f1zqtkgX5sbIdR4AXAetPlWWHZvR001xcU0F9x'

    if (!stripeSecretKey) {
      throw new Error('STRIPE_SECRET_KEY is not configured')
    }

    // 3. Parse Request Payload
    const body = await req.json()
    const {
      amount,
      currency = 'pkr',
      customerName = '',
      customerEmail = '',
      orderId = '',
      metadata = {},
    } = body

    if (!amount || Number(amount) <= 0) {
      return new Response(
        JSON.stringify({ error: 'A valid order amount is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Convert amount to smallest currency unit (cents / paisas: $10.00 -> 1000)
    const amountInSmallestUnit = Math.round(Number(amount) * 100)

    // 4. Create PaymentIntent via Stripe API directly (compatible across all Deno versions)
    const form = new URLSearchParams()
    form.append('amount', amountInSmallestUnit.toString())
    form.append('currency', currency.toLowerCase())
    form.append('payment_method_types[]', 'card')
    form.append('description', `ShopHub Order ${orderId}`.trim())
    if (customerEmail) {
      form.append('receipt_email', customerEmail)
    }
    form.append('metadata[customer_name]', customerName)
    form.append('metadata[customer_email]', customerEmail)
    form.append('metadata[order_id]', orderId)

    for (const [key, value] of Object.entries(metadata)) {
      form.append(`metadata[${key}]`, String(value))
    }

    const stripeRes = await fetch('https://api.stripe.com/v1/payment_intents', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${stripeSecretKey}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: form.toString(),
    })

    const stripeData = await stripeRes.json()

    if (!stripeRes.ok) {
      return new Response(
        JSON.stringify({
          error: stripeData.error?.message || 'Stripe payment intent creation failed',
          code: stripeData.error?.code,
          details: stripeData,
        }),
        {
          status: stripeRes.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // 5. Return client_secret & payment details to Flutter app
    return new Response(
      JSON.stringify({
        clientSecret: stripeData.client_secret,
        paymentIntentId: stripeData.id,
        amount: stripeData.amount,
        currency: stripeData.currency,
        status: stripeData.status,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
