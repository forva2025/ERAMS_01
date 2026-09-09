import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

// ---------------------------------------------------------------------------
// send_sms — shared Africa's Talking SMS helper.
//
// Called by the Flutter client at the four Phase 16 trigger points (driver
// job offer, patient driver-accepted, patient driver-arrived, hospital
// incoming-patient). Accepts { phone, message, incidentId? }.
//
// Never returns a hard failure to the caller for messaging problems (missing
// credentials, AT rejection, bad phone) — those are reported in the response
// body as { sent: false, reason } and, when incidentId is supplied, logged to
// incident_events so the failure is auditable without blocking the caller's
// main flow.
// ---------------------------------------------------------------------------

function normalizeUgandaPhone(raw: string): string | null {
  const digits = raw.replace(/[^\d+]/g, '');
  const match = digits.match(/^(?:\+?256|0)?(7\d{8})$/);
  if (!match) return null;
  return `+256${match[1]}`;
}

async function logSmsFailure(
  supabase: ReturnType<typeof createClient>,
  incidentId: string | undefined,
  reason: string,
) {
  if (!incidentId) return;
  try {
    await supabase.from('incident_events').insert({
      incident_id: incidentId,
      event_type: 'message',
      payload: JSON.stringify({ type: 'sms_failed', reason }),
    });
  } catch (_) {
    // Best-effort audit log — never let a logging failure surface to the caller.
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  let incidentId: string | undefined;

  try {
    const body = await req.json();
    const phone = body.phone as string | undefined;
    const message = body.message as string | undefined;
    incidentId = body.incidentId as string | undefined;

    if (!phone || !message) {
      return new Response(
        JSON.stringify({ error: 'phone and message are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const to = normalizeUgandaPhone(phone);
    if (!to) {
      await logSmsFailure(supabase, incidentId, 'invalid_phone_number');
      return new Response(
        JSON.stringify({ sent: false, reason: 'invalid_phone_number' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const apiKey = Deno.env.get('AT_API_KEY');
    const username = Deno.env.get('AT_USERNAME');

    if (!apiKey || !username) {
      await logSmsFailure(supabase, incidentId, 'sms_not_configured');
      return new Response(
        JSON.stringify({ sent: false, reason: 'sms_not_configured' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const atUrl = username === 'sandbox'
      ? 'https://api.sandbox.africastalking.com/version1/messaging'
      : 'https://api.africastalking.com/version1/messaging';

    const atRes = await fetch(atUrl, {
      method: 'POST',
      headers: {
        apiKey,
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body: new URLSearchParams({ username, to, message }).toString(),
    });

    const atBody = await atRes.json().catch(() => null);
    const recipient = atBody?.SMSMessageData?.Recipients?.[0];
    const success = atRes.ok && recipient?.status === 'Success';

    if (!success) {
      const reason = recipient?.status ?? `http_${atRes.status}`;
      await logSmsFailure(supabase, incidentId, `at_send_failed:${reason}`);
      return new Response(
        JSON.stringify({ sent: false, reason, atResponse: atBody }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    return new Response(
      JSON.stringify({ sent: true, messageId: recipient?.messageId }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    await logSmsFailure(supabase, incidentId, String(err));
    return new Response(
      JSON.stringify({ sent: false, error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
