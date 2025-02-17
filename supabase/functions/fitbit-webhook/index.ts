import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7'
import { corsHeaders } from '../_shared/cors.ts'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const verificationCode = Deno.env.get('FITBIT_VERIFICATION_CODE')!

const supabase = createClient(supabaseUrl, supabaseServiceKey)

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Handle Fitbit's verification request
    if (req.method === 'GET') {
      const url = new URL(req.url)
      const verify = url.searchParams.get('verify')
      
      if (verify === verificationCode) {
        return new Response(verify, {
          headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
        })
      }
      
      return new Response('Unauthorized', { status: 401 })
    }

    // Handle webhook notifications
    if (req.method === 'POST') {
      const { notifications } = await req.json()

      // Process each notification
      for (const notification of notifications) {
        const { collectionType, date, ownerId, subscriptionId } = notification
        
        // Get user profile from subscription ID
        const userId = subscriptionId.split('-')[0]
        
        const { data: userProfile } = await supabase
          .from('user_profiles')
          .select('*')
          .eq('user_id', userId)
          .single()

        if (userProfile) {
          // Queue data sync for this user and date
          await supabase
            .from('sync_queue')
            .insert({
              user_id: userId,
              date,
              collection_type: collectionType,
              status: 'pending'
            })
        }
      }

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response('Method not allowed', { status: 405 })
  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})