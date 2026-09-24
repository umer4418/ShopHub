// Supabase Edge Function: shopbot
// Intelligent AI customer support chatbot for ShopHub e-commerce marketplace.
// Powered by Google Gemini AI with Supabase Order & Product Tracking and Strict Guardrails.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const DEFAULT_GEMINI_API_KEY = 'AIzaSyCDIEz5yERvB7ip2Iicdy0d8sZUFZN-vNE'
const DEFAULT_GEMINI_MODEL = 'gemini-flash-latest'
const DEFAULT_GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models'

interface ChatPayload {
  message: string
  conversationHistory?: Array<{ role: 'user' | 'assistant'; content: string }>
  userId?: string
  customerName?: string
  customerPhone?: string
  orderId?: string
}

// Strict domain guardrail: Check if the message is relevant to ShopHub shopping/orders/delivery/stock/app
function isRelevantQuery(text: string): boolean {
  const lower = text.toLowerCase().trim()

  // Common greetings and courtesies
  if (/^(hi|hello|hey|greetings|good morning|good afternoon|good evening|who are you|what can you do|help|assalam|aoa)\b/i.test(lower)) {
    return true
  }

  // Shopping, app features & order keywords matching whole words
  const commerceRegex = /\b(orders?|track(ing)?|status|deliver(y|ies|ing)?|ship(ping|ped|ment)?|dispatch(ed)?|process(ing)?|stocks?|availab(le|ility)|restock(ing)?|products?|items?|prices?|costs?|buy(ing)?|cart|checkout|pay(ment|ing)?|cash on delivery|cod|stripe|cards?|cancel(lation)?|returns?|refunds?|exchanges?|warranty|shophub|store|packages?|parcels?|couriers?|arriv(e|al|ing)|delay(ed)?|address(es)?|accounts?|passwords?|forgot|reset|login|log in|signin|sign in|signup|sign up|register(ing)?|logout|log out|signout|sign out|profiles?|users?|names?|phones?|mobiles?|settings|wishlists?|favorites?|coupons?|promos?|discounts?|vouchers?|categories?|search(ing)?|filters?|sort(ing)?|reviews?|ratings?|admin|dashboard|contacts?|helplines?|emails?|apps?|features?|how to|working)\b/i
  if (commerceRegex.test(lower)) return true

  // Check if text looks like an order code or product query (e.g. ORD-1234, #1234, SH-1234)
  if (/ord-?\d+/i.test(lower) || /sh-?\d+/i.test(lower) || /#\d+/.test(lower)) return true

  // Irrelevant queries (e.g., general programming, math, world trivia, recipes, personal opinions)
  return false
}

// Builds the system training prompt for Gemini AI
function buildSystemTrainingPrompt(options: {
  ordersContext?: string
  productsContext?: string
  customerName?: string
}): string {
  let prompt = `You are ShopBot, the dedicated official AI customer support assistant for the ShopHub mobile e-commerce application.

YOUR CORE BEHAVIOR & RESPONSE RULES:
1. SHOPHUB APP QUESTIONS:
   If the customer asks about the ShopHub app (including password reset, account management, registration, login, order tracking, delivery times, processing times, product stock, payment options COD & Stripe, returns and refunds, or helpline):
   Provide a detailed, helpful, and friendly response with clear markdown bullet points and emojis.

2. ANYTHING ELSE / GENERAL QUESTIONS (Non-ShopHub Topics):
   If the customer asks ANYTHING ELSE that is not related to ShopHub (such as general knowledge, coding, python/java code, math, history, science, recipes, weather, definitions, casual chitchat):
   Answer their question in EXACTLY 1 concise line.
   Then, on the very next line, you MUST say:
   "I am here to assist you regarding the ShopHub app only. How can I help you with your ShopHub shopping, orders, or account today?"

SHOPHUB APP KNOWLEDGE BASE:
- How to Reset Password:
  1. Open the ShopHub app and tap on the 'Account' tab at the bottom right.
  2. If logged out, tap 'Forgot Password?' on the Login screen.
  3. Enter your registered ShopHub email address.
  4. Check your email for the password recovery link.
  5. Open the link to set your new password and sign back into ShopHub.
- Account Registration & Login:
  * New users can tap Register in the Account tab and sign up with their name, email, and password.
  * To log out, visit the Account tab and tap 'Log Out'.
- Delivery Times:
  * Major metropolitan cities: 2 to 4 business days.
  * Regional and nationwide delivery: 3 to 7 business days.
  * Express delivery: 24 to 48 hours where available.
- Processing Times:
  * Order verification & warehouse packaging takes within 24 hours of placement.
  * Courier dispatch is handled in 1 to 2 business days (Monday to Saturday).
- Product Stock & Restocking:
  * Listed items show live stock.
  * If an item is out of stock, it is restocked within 3 to 5 business days. Customers can add it to their Wishlist to receive an instant restock alert.
- Payment Methods:
  1. Cash on Delivery (COD) - Pay with cash upon doorstep delivery.
  2. Secure Card Payment (Stripe) - Visa, MasterCard, credit and debit cards.
- Return, Refund & Cancellation Policy:
  * 7-day hassle-free return window for damaged, defective, or incorrect items.
  * Free cancellation before the order is dispatched (while status is 'Placed').
  * Approved refunds are processed in 3 to 5 business days back to the original payment method.
- Customer Helpline & Support:
  * Email: support@shophub.com
  * Toll-Free Helpline: 0800-SHOPHUB (0800-7467482)
  * Operating Hours: Mon-Sat, 9:00 AM - 6:00 PM.

ORDER TRACKING GUIDELINES:
- When a user asks about an order or provides an Order ID (like ORD-xxxx or SH-xxxx), check the [LINKED SUPABASE ORDERS DATA] below.
- If order data is present, present the Order ID, status (Placed, Processing, Shipped, Delivered, Cancelled), recipient name, delivery address, items, and total amount with markdown bullet points and emojis.
- If the Order ID is not in their records, inform them politely and suggest checking the Account > Orders section or double-checking the order number.`

  if (options.ordersContext) {
    prompt += `\n\n[LINKED SUPABASE ORDERS DATA]\n${options.ordersContext}`
  }

  if (options.productsContext) {
    prompt += `\n\n[LINKED SUPABASE PRODUCTS DATA]\n${options.productsContext}`
  }

  return prompt
}

// Calls Gemini AI with graceful model fallback (e.g. if 503 high demand spike occurs)
// Generates a fast, intelligent 1-line answer for off-topic/general knowledge queries.
function generateOffTopicAnswer(message: string): string {
  const lower = message.toLowerCase().trim()

  // 1. Math calculation solver
  const mathMatch = lower.match(/(?:solve|calculate|what is)?\s*(-?\d+(?:\.\d+)?)\s*([\+\-\*\/xX]|times|plus|minus|divided by)\s*(-?\d+(?:\.\d+)?)\s*\??/i)
  if (mathMatch) {
    try {
      const n1 = parseFloat(mathMatch[1])
      const op = mathMatch[2].trim()
      const n2 = parseFloat(mathMatch[3])
      let result: number | null = null

      if (op === '+' || op === 'plus') result = n1 + n2
      else if (op === '-' || op === 'minus') result = n1 - n2
      else if (op === '*' || op === 'x' || op === 'X' || op === 'times') result = n1 * n2
      else if (op === '/' || op === 'divided by') {
        if (n2 !== 0) result = n1 / n2
      }

      if (result !== null) {
        const resStr = Number.isInteger(result) ? result.toString() : result.toFixed(2)
        const opSymbol = op === 'times' ? '*' : op === 'plus' ? '+' : op === 'minus' ? '-' : op
        return `${n1} ${opSymbol} ${n2} = ${resStr}.`
      }
    } catch (_) {}
  }

  // 2. Geography & Capitals
  if (lower.includes('capital')) {
    if (lower.includes('france')) return 'The capital of France is Paris.'
    if (lower.includes('canada')) return 'The capital of Canada is Ottawa.'
    if (lower.includes('usa') || lower.includes('united states') || lower.includes('america')) return 'The capital of the United States is Washington, D.C.'
    if (lower.includes('uk') || lower.includes('united kingdom') || lower.includes('england')) return 'The capital of the United Kingdom is London.'
    if (lower.includes('pakistan')) return 'The capital of Pakistan is Islamabad.'
    if (lower.includes('india')) return 'The capital of India is New Delhi.'
    if (lower.includes('germany')) return 'The capital of Germany is Berlin.'
    if (lower.includes('australia')) return 'The capital of Australia is Canberra.'
    if (lower.includes('japan')) return 'The capital of Japan is Tokyo.'
    if (lower.includes('china')) return 'The capital of China is Beijing.'
    if (lower.includes('italy')) return 'The capital of Italy is Rome.'
    if (lower.includes('spain')) return 'The capital of Spain is Madrid.'
    if (lower.includes('russia')) return 'The capital of Russia is Moscow.'
    if (lower.includes('turkey')) return 'The capital of Turkey is Ankara.'
    if (lower.includes('brazil')) return 'The capital of Brazil is Brasília.'
  }

  // 3. World Leaders & Presidents
  if (lower.includes('president') || lower.includes('prime minister') || lower.includes('leader')) {
    if (lower.includes('france')) return 'The current president of France is Emmanuel Macron.'
    if (lower.includes('usa') || lower.includes('united states') || lower.includes('us') || lower.includes('america')) return 'The current president of the United States is Joe Biden.'
    if (lower.includes('pakistan')) return 'The prime minister of Pakistan is Shehbaz Sharif.'
    if (lower.includes('uk') || lower.includes('united kingdom')) return 'The prime minister of the United Kingdom is Keir Starmer.'
    if (lower.includes('india')) return 'The prime minister of India is Narendra Modi.'
    if (lower.includes('russia')) return 'The president of Russia is Vladimir Putin.'
    if (lower.includes('canada')) return 'The prime minister of Canada is Justin Trudeau.'
  }

  // 4. Literature & Art
  if (lower.includes('romeo and juliet') || lower.includes('shakespeare')) {
    return 'William Shakespeare wrote Romeo and Juliet.'
  }
  if (lower.includes('harry potter') || lower.includes('rowling')) {
    return 'J.K. Rowling wrote the Harry Potter series.'
  }
  if (lower.includes('mona lisa') || lower.includes('da vinci')) {
    return 'Leonardo da Vinci painted the Mona Lisa.'
  }

  // 5. Programming & Algorithms
  if (lower.includes('binary tree')) {
    return 'Invert a binary tree by swapping each node\'s left and right child pointers recursively (root.left, root.right = root.right, root.left).'
  }
  if (lower.includes('python') || lower.includes('code') || lower.includes('program') || lower.includes('java') || lower.includes('c++')) {
    if (lower.includes('sort')) {
      return 'You can sort an array using built-in methods like .sort() or algorithms like Quicksort and Mergesort.'
    }
    return 'Programming languages like Python and Java use structured syntax, functions, and object-oriented principles.'
  }

  // 6. Cooking & Recipes
  if (lower.includes('cake') || lower.includes('bake')) {
    return 'Combine flour, sugar, cocoa powder, eggs, milk, and bake at 350°F (175°C) for about 30 minutes.'
  }
  if (lower.includes('tea') || lower.includes('coffee')) {
    return 'Brew tea leaves or ground coffee beans in boiling water, then add milk or sweetener to taste.'
  }

  // 7. Sports & World Cups
  if (lower.includes('world cup')) {
    if (lower.includes('1998')) return 'France won the 1998 FIFA World Cup by defeating Brazil 3-0.'
    if (lower.includes('2022')) return 'Argentina won the 2022 FIFA World Cup.'
    if (lower.includes('2018')) return 'France won the 2018 FIFA World Cup.'
    if (lower.includes('2014')) return 'Germany won the 2014 FIFA World Cup.'
    if (lower.includes('1992')) return 'Pakistan won the 1992 Cricket World Cup.'
    return 'The FIFA World Cup is the premier international soccer tournament held every four years.'
  }

  // 8. Jokes & Humor
  if (lower.includes('joke')) {
    if (lower.includes('dog')) return 'What kind of dog does a magician have? A Labracadabrador!'
    if (lower.includes('cat')) return 'Why was the cat sitting on the computer? To keep an eye on the mouse!'
    return 'Why don\'t scientists trust atoms? Because they make up everything!'
  }

  // 9. Science, Nature & Space
  if (lower.includes('speed of light')) return 'The speed of light in a vacuum is approximately 299,792 kilometers per second.'
  if (lower.includes('boiling point')) return 'Water boils at 100°C (212°F) under standard atmospheric pressure.'
  if (lower.includes('planets') || lower.includes('solar system')) return 'There are 8 planets in our solar system: Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, and Neptune.'
  if (lower.includes('sky') && lower.includes('blue')) return 'The sky appears blue because molecules in Earth\'s atmosphere scatter short-wavelength blue sunlight.'
  if (lower.includes('largest animal') || lower.includes('largest mammal')) return 'The blue whale is the largest animal on Earth.'
  if (lower.includes('fastest animal')) return 'The cheetah is the fastest land animal, running up to 120 km/h (75 mph).'

  // 10. Weather & Time
  if (lower.includes('weather')) return 'Weather conditions vary by location; please check a dedicated weather service for your area.'
  if (lower.includes('time') || lower.includes('date')) return 'Please check your device\'s system clock for the current local time and date.'

  // 11. General Fallback
  if (lower.startsWith('who is') || lower.startsWith('who was')) return 'That person is a recognized public or historical figure.'
  if (lower.startsWith('what is') || lower.startsWith('what are')) return 'That is a recognized concept in general knowledge.'
  if (lower.startsWith('where is')) return 'That location can be referenced on international mapping services.'
  if (lower.startsWith('how to') || lower.startsWith('how do')) return 'Detailed steps for that task can be found in general educational resources.'

  return 'That is an interesting topic outside the scope of retail shopping.'
}

// Calls Gemini AI with graceful model fallback (e.g. if 503 high demand spike occurs)
async function callGemini(
  prompt: string,
  userMessage: string,
  apiKey: string,
  primaryModel: string,
  baseUrl: string,
  history: Array<{ role: 'user' | 'assistant'; content: string }> = []
): Promise<string | null> {
  const modelsToTry = [
    'gemini-flash-lite-latest',
    'gemini-3.6-flash',
    primaryModel,
  ]

  // Deduplicate models
  const uniqueModels = [...new Set(modelsToTry)]

  for (const model of uniqueModels) {
    try {
      const endpoint = `${baseUrl}/${model}:generateContent?key=${apiKey}`

      const contents = [
        {
          role: 'user',
          parts: [{ text: `${prompt}\n\n[USER INQUIRY]\n${userMessage}` }]
        }
      ]

      const controller = new AbortController()
      const timeoutId = setTimeout(() => controller.abort(), 3500)

      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: controller.signal,
        body: JSON.stringify({
          contents,
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 400,
          }
        })
      })
      clearTimeout(timeoutId)

      if (res.status === 429) {
        console.warn(`Gemini model ${model} hit 429 quota limit. Breaking to fast fallback.`)
        break
      }

      if (res.ok) {
        const data = await res.json()
        const parts = data.candidates?.[0]?.content?.parts as Array<{ text?: string }> | undefined
        const text = parts?.find(p => typeof p.text === 'string' && p.text.trim().length > 0)?.text
        if (text) {
          return text.trim()
        }
      } else {
        console.warn(`Gemini model ${model} returned HTTP ${res.status}`)
      }
    } catch (err) {
      console.warn(`Gemini model ${model} timed out or failed:`, err)
      break
    }
  }

  return null
}

serve(async (req: Request) => {
  // 1. Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body: ChatPayload = await req.json()
    const rawMessage = (body.message || '').trim()

    if (!rawMessage) {
      return new Response(
        JSON.stringify({ error: 'Message cannot be empty' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Initialize Supabase Client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY') || ''
    const supabase = createClient(supabaseUrl, supabaseKey)

    const lower = rawMessage.toLowerCase()

    // 4. Query live Supabase context (Orders & Products)
    let ordersContext = ''
    let matchedOrderId: string | null = null

    const idMatch = rawMessage.match(/\b((?:ORD|SH)(?:[-_][0-9a-zA-Z]+|\d+))\b/i)
    const hashMatch = rawMessage.match(/#([0-9a-zA-Z_-]+)/)
    const keywordMatch = rawMessage.match(/\border\s*(?:id|#|number)?\s*[:#]?\s*([0-9a-zA-Z_-]+)\b/i)
    const explicitOrderId = body.orderId ||
      (idMatch ? idMatch[1] : (hashMatch ? hashMatch[1] : (keywordMatch && !['details', 'status', 'time', 'my', 'the'].includes(keywordMatch[1].toLowerCase()) ? keywordMatch[1] : null)))

    if (explicitOrderId || lower.includes('track') || (lower.includes('my order') && (body.userId || body.customerPhone))) {
      let query = supabase.from('orders').select('*')
      if (explicitOrderId) {
        query = query.or(`id.ilike.%${explicitOrderId}%,id.eq.${explicitOrderId}`)
      } else if (body.userId) {
        query = query.eq('user_id', body.userId).order('created_at', { ascending: false }).limit(3)
      } else if (body.customerPhone) {
        query = query.eq('phone', body.customerPhone).order('created_at', { ascending: false }).limit(3)
      }

      const { data: orders } = await query
      if (orders && orders.length > 0) {
        matchedOrderId = orders[0].id
        ordersContext = orders.map((o: any) =>
          `Order ID: ${o.id}, Status: ${o.status}, Recipient: ${o.customer_name}, Phone: ${o.phone}, Address: ${o.address}, Total: Rs. ${o.total}, Payment: ${o.payment_method}, Date: ${o.created_at}`
        ).join('\n')
      }
    }

    // Check products stock context if inquiry relates to products
    let productsContext = ''
    if (lower.includes('stock') || lower.includes('available') || lower.includes('product') || lower.includes('price')) {
      const { data: products } = await supabase.from('products').select('id, name, price, stock').limit(30)
      if (products && products.length > 0) {
        productsContext = products.map((p: any) =>
          `Product: ${p.name}, Price: Rs. ${p.price}, Stock: ${p.stock}`
        ).join('\n')
      }
    }

    // 5. Invoke Gemini AI with full training & grounding
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY') || DEFAULT_GEMINI_API_KEY
    const geminiModel = Deno.env.get('GEMINI_MODEL') || DEFAULT_GEMINI_MODEL
    const geminiUrl = Deno.env.get('GEMINI_URL') || DEFAULT_GEMINI_URL

    if (geminiApiKey) {
      const trainingPrompt = buildSystemTrainingPrompt({
        ordersContext,
        productsContext,
        customerName: body.customerName,
      })

      const geminiReply = await callGemini(
        trainingPrompt,
        rawMessage,
        geminiApiKey,
        geminiModel,
        geminiUrl,
        body.conversationHistory
      )

      if (geminiReply) {
        let formattedReply = geminiReply
        const isRefusal = geminiReply.includes('I am here to assist you regarding the ShopHub app only')
        const isOffTopic = isRefusal || !isRelevantQuery(rawMessage)

        if (isOffTopic && !isRefusal) {
          const firstLine = formattedReply.split('\n').find(l => l.trim().length > 0) || formattedReply
          formattedReply = `${firstLine.trim()}\nI am here to assist you regarding the ShopHub app only. How can I help you with your ShopHub shopping, orders, or account today?`
        }

        return new Response(
          JSON.stringify({
            reply: formattedReply,
            orderId: matchedOrderId || (explicitOrderId ?? undefined),
            quickReplies: matchedOrderId
              ? ["What is the delivery time?", "Processing time details", "Contact support"]
              : [
                  "Track my order",
                  "How to reset password?",
                  "What is the delivery time?",
                  "Payment options",
                ],
            isGuardrail: isOffTopic,
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // 6. Resilient Fallback: If Gemini is unreachable, use rule-based responses
    if (!isRelevantQuery(rawMessage)) {
      const offTopicAns = generateOffTopicAnswer(rawMessage)
      return new Response(
        JSON.stringify({
          reply: `${offTopicAns}\nI am here to assist you regarding the ShopHub app only. How can I help you with your ShopHub shopping, orders, or account today?`,
          quickReplies: [
            "How to reset password?",
            "Track my order",
            "What is the delivery time?",
            "Payment options",
          ],
          isGuardrail: true,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (ordersContext && matchedOrderId) {
      return new Response(
        JSON.stringify({
          reply: `📦 **Order Status Found:**\n\n${ordersContext}\n\nEstimated delivery time is 2 to 4 business days.`,
          orderId: matchedOrderId,
          quickReplies: ["What is the delivery time?", "Processing time details", "Contact support"],
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (lower.includes('password') || lower.includes('reset') || (lower.includes('forgot') && lower.includes('pass'))) {
      return new Response(
        JSON.stringify({
          reply: `🔑 **How to Reset Your ShopHub Password:**\n\n` +
            `1. Tap the **Account** tab in the bottom navigation bar.\n` +
            `2. If you are not logged in, tap **'Forgot Password?'** on the login screen.\n` +
            `3. Enter the email address registered with your ShopHub account.\n` +
            `4. Check your email for the password recovery link.\n` +
            `5. Click the link to set your new password and sign back in!`,
          quickReplies: ["How to create account", "Track my order", "Contact support"],
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({
        reply: `👋 Hello! I am **ShopBot**, your ShopHub AI assistant.\n\nI can help you with:\n` +
          `• 📦 **Order Tracking** — Live tracking linked to your Supabase orders\n` +
          `• 🔑 **Account & Password** — How to reset password or manage profile\n` +
          `• 🚚 **Delivery Times** — Expected arrival timelines across cities\n` +
          `• ⏱️ **Processing Times** — Packaging and dispatch schedules\n` +
          `• 🏷️ **Product Stock** — Availability and restocking updates\n\n` +
          `How can I help you with ShopHub today?`,
        quickReplies: [
          "Track my order",
          "How to reset password?",
          "What is the delivery time?",
          "Payment options",
        ],
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
