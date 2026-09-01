import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

// ---------------------------------------------------------------------------
// send_push_notification — fans a `notifications` row out to every device
// the recipient has registered, via FCM's HTTP v1 API.
//
// Triggered by a Supabase Database Webhook on `notifications` INSERT
// (configured in the Dashboard, not this file — same category as Auth
// settings, not a schema change). Payload is the standard webhook envelope:
// { type: 'INSERT', table: 'notifications', record: {...}, schema: 'public' }.
//
// Sends a DATA-ONLY message (no top-level `notification:` field) so the
// Flutter client's background handler picks the Android notification
// channel/sound itself based on `data.type` — e.g. a loud custom ringtone
// for 'incoming_call' vs. the default channel for everything else. A
// `notification:` payload would let the OS auto-display it with no client
// control over sound.
//
// Best-effort like send_sms: never hard-fails the webhook, logs and moves
// on. Self-heals by deleting device_tokens rows FCM reports as
// unregistered/invalid.
// ---------------------------------------------------------------------------

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri: string;
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function signJwtRs256(claims: Record<string, unknown>, privateKeyPem: string): Promise<string> {
  const header = { alg: 'RS256', typ: 'JWT' };
  const encoder = new TextEncoder();
  const headerB64 = base64UrlEncode(encoder.encode(JSON.stringify(header)));
  const claimsB64 = base64UrlEncode(encoder.encode(JSON.stringify(claims)));
  const signingInput = `${headerB64}.${claimsB64}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(privateKeyPem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(signingInput));
  return `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;
}

// Google OAuth2 access tokens for FCM v1 last 1 hour; cache in-memory for
// ~55 minutes to avoid re-minting one per notification.
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.token;
  }

  const claims = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  };
  const assertion = await signJwtRs256(claims, sa.private_key);

  const res = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) {
    throw new Error(`token_exchange_failed: ${res.status} ${await res.text()}`);
  }
  const json = await res.json();
  cachedAccessToken = { token: json.access_token, expiresAt: now + json.expires_in };
  return cachedAccessToken.token;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  try {
    const payload = await req.json();
    const record = payload.record;
    if (!record?.user_id) {
      return new Response(JSON.stringify({ sent: 0, reason: 'no_user_id' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const saJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
    const projectId = Deno.env.get('FCM_PROJECT_ID');
    if (!saJson || !projectId) {
      console.error('send_push_notification: FCM_SERVICE_ACCOUNT_JSON/FCM_PROJECT_ID not configured');
      return new Response(JSON.stringify({ sent: 0, reason: 'fcm_not_configured' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const sa: ServiceAccount = JSON.parse(saJson);

    const { data: tokens, error: tokensError } = await supabase
      .from('device_tokens')
      .select('fcm_token')
      .eq('user_id', record.user_id);
    if (tokensError) throw tokensError;
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: 'no_device_tokens' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const accessToken = await getAccessToken(sa);
    let sent = 0;

    for (const { fcm_token } of tokens) {
      const message = {
        message: {
          token: fcm_token,
          data: {
            type: String(record.type ?? ''),
            title: String(record.title ?? ''),
            body: String(record.body ?? ''),
            notificationId: String(record.id ?? ''),
            payload: JSON.stringify(record.data ?? {}),
          },
        },
      };

      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(message),
        },
      );

      if (res.ok) {
        sent++;
        continue;
      }

      const errBody = await res.text();
      console.error(`send_push_notification: FCM send failed for token: ${errBody}`);

      // Self-heal: a token FCM reports as unregistered/invalid is stale
      // (app uninstalled, token rotated) — remove it so future sends don't
      // keep failing against it.
      if (errBody.includes('UNREGISTERED') || errBody.includes('INVALID_ARGUMENT') || errBody.includes('NOT_FOUND')) {
        await supabase.from('device_tokens').delete().eq('fcm_token', fcm_token);
      }
    }

    return new Response(JSON.stringify({ sent, total: tokens.length }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    // Best-effort, mirrors send_sms — never let a push failure surface as a
    // hard error to the Database Webhook caller.
    console.error('send_push_notification: unexpected error', err);
    return new Response(JSON.stringify({ sent: 0, error: String(err) }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
