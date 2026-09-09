import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';

// ---------------------------------------------------------------------------
// Agora AccessToken2 builder — faithful port of Agora's own reference
// implementation:
// https://github.com/AgoraIO/Tools/blob/master/DynamicKey/AgoraDynamicKey/nodejs/src/AccessToken2.js
//
// Wire format: "007" + base64( zlib_deflate( putBytes(signature) + signingInfo ) )
//   signingInfo = putString(appId) + u32(issueTs) + u32(expire) + u32(salt)
//                 + u16(serviceCount) + services...
//   signature   = HMAC-SHA256(signingKey, signingInfo)
//   signingKey  = HMAC-SHA256(u32(salt), HMAC-SHA256(u32(issueTs), appCertificate))
//   expire / privilege-expire fields are DURATIONS in seconds, not absolute
//   timestamps — the server adds issueTs itself.
//
// This project's first implementation skipped the zlib-deflate step, used
// appCertificate directly as the HMAC key instead of the required two-round
// derivation, put the signingInfo fields in the wrong order, didn't
// length-prefix the signature, and sent absolute timestamps instead of
// durations — any one of these alone is enough to make Agora's server reject
// the token as invalid, which is what was happening.
// ---------------------------------------------------------------------------

function concat(...arrays: Uint8Array[]): Uint8Array {
  const total = arrays.reduce((s, a) => s + a.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const a of arrays) { out.set(a, offset); offset += a.length; }
  return out;
}

// Agora uses little-endian packing
function p16(v: number): Uint8Array {
  return new Uint8Array([v & 0xff, (v >> 8) & 0xff]);
}

function p32(v: number): Uint8Array {
  return new Uint8Array([
    v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff,
  ]);
}

function pBytes(bytes: Uint8Array): Uint8Array {
  return concat(p16(bytes.length), bytes);
}

function pStr(s: string): Uint8Array {
  return pBytes(new TextEncoder().encode(s));
}

function toBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

async function hmacSha256(key: Uint8Array, message: Uint8Array): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return new Uint8Array(await crypto.subtle.sign('HMAC', cryptoKey, message));
}

// Agora's wire format requires the signing_info to be zlib (RFC 1950)
// compressed before base64 encoding. The Web Compression Streams API's
// 'deflate' format is specifically the zlib format (not raw deflate, not
// gzip), matching Node's zlib.deflateSync used by Agora's own reference impl.
async function deflateZlib(data: Uint8Array): Promise<Uint8Array> {
  const cs = new CompressionStream('deflate');
  const writer = cs.writable.getWriter();
  const writeDone = writer.write(data).then(() => writer.close());
  const chunks: Uint8Array[] = [];
  const reader = cs.readable.getReader();
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (value) chunks.push(value);
  }
  await writeDone;
  return concat(...chunks);
}

// Privilege types for ServiceRtc
const PRIV_JOIN = 1;
const PRIV_PUB_AUDIO = 2;
const PRIV_PUB_VIDEO = 3;
const PRIV_PUB_DATA = 4;

async function buildRtcToken(
  appId: string,
  appCertificate: string,
  channelName: string,
  uid: number,
  tokenExpireSecs: number,
  privilegeExpireSecs: number,
): Promise<string> {
  const salt = Math.floor(Math.random() * 99999999) + 1;
  const issueTs = Math.floor(Date.now() / 1000);
  const uidStr = uid === 0 ? '' : String(uid);

  // ServiceRtc body: type + privileges (all granted for the same duration,
  // matching Agora's own buildTokenWithUid "publisher" convention) + channelName + uid
  const privs: [number, number][] = [
    [PRIV_JOIN, privilegeExpireSecs],
    [PRIV_PUB_AUDIO, privilegeExpireSecs],
    [PRIV_PUB_VIDEO, privilegeExpireSecs],
    [PRIV_PUB_DATA, privilegeExpireSecs],
  ];
  const serviceBody = concat(
    p16(1),              // service type = RTC (1)
    p16(privs.length),
    ...privs.flatMap(([t, e]) => [p16(t), p32(e)]),
    pStr(channelName),
    pStr(uidStr),
  );

  // signingInfo: appId + issueTs + expire + salt + num_services + service
  const signingInfo = concat(
    pStr(appId),
    p32(issueTs),
    p32(tokenExpireSecs),
    p32(salt),
    p16(1),              // 1 service
    serviceBody,
  );

  // Two-round HMAC key derivation, then sign signingInfo with the result.
  // HMAC is NOT symmetric — HMAC(key, msg) !== HMAC(msg, key) — so the operand
  // order below must match Agora's reference exactly: round 1 keys on u32(issueTs)
  // with the appCertificate as the message; round 2 keys on u32(salt) with round 1
  // as the message. Swapping key/message (as an earlier version did) produces a
  // different signing key and a signature the Agora server rejects as error 110
  // (invalid token), which fails the call before it can connect.
  const round1 = await hmacSha256(p32(issueTs), new TextEncoder().encode(appCertificate));
  const signingKey = await hmacSha256(p32(salt), round1);
  const signature = await hmacSha256(signingKey, signingInfo);

  const content = concat(pBytes(signature), signingInfo);
  const compressed = await deflateZlib(content);
  return '007' + toBase64(compressed);
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const appId = Deno.env.get('AGORA_APP_ID') ?? '';
    const appCertificate = Deno.env.get('AGORA_APP_CERTIFICATE') ?? '';

    if (!appId) {
      return new Response(
        JSON.stringify({ error: 'AGORA_APP_ID not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const { channelName, uid = 0 } = await req.json();

    if (!channelName) {
      return new Response(
        JSON.stringify({ error: 'channelName is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // If no certificate configured → test mode (no token needed, Agora console
    // must have "Testing Mode" enabled with no certificate). Return null so the
    // Flutter client connects with an empty token string.
    if (!appCertificate) {
      return new Response(
        JSON.stringify({ appId, token: null, channelName }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const TOKEN_EXPIRE_SECS = 3600;    // 1 hour
    const PRIV_EXPIRE_SECS = 3600;

    const token = await buildRtcToken(
      appId,
      appCertificate,
      channelName,
      uid,
      TOKEN_EXPIRE_SECS,
      PRIV_EXPIRE_SECS,
    );

    return new Response(
      JSON.stringify({ appId, token, channelName }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
