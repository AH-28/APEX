// APEX contact form — Supabase Edge Function.
// Deployed to project `apex` (tugxgfpdcpsfzfckoqtc) as `contact`.
//
// POST { email, message } → relays the message to the APEX inbox via Resend,
// with subject "APEX Query" and the user's address as reply-to.
//
// Requires a Resend API key in the function secrets:
//   Dashboard → Project Settings → Edge Functions → Secrets → RESEND_API_KEY
// (Optionally CONTACT_TO / CONTACT_FROM to override the defaults below.)

import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const TO = Deno.env.get('CONTACT_TO') ?? 'ahmedeldien2006@gmail.com';
// Resend's shared sender works without verifying a domain. Swap for your own
// verified domain once you have one.
const FROM = Deno.env.get('CONTACT_FROM') ?? 'APEX <onboarding@resend.dev>';

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  let payload: { email?: unknown; message?: unknown };
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'Invalid request body.' }, 400);
  }

  const email = typeof payload.email === 'string' ? payload.email.trim() : '';
  const message =
    typeof payload.message === 'string' ? payload.message.trim() : '';

  if (message.length === 0) {
    return json({ error: 'Please enter a message.' }, 400);
  }
  if (message.length > 5000) {
    return json({ error: 'Message is too long (max 5000 characters).' }, 400);
  }

  const apiKey = Deno.env.get('RESEND_API_KEY');
  if (!apiKey) {
    return json(
      { error: 'Messaging is not configured yet. Please try again later.' },
      503,
    );
  }

  const replyTo = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ? email : undefined;
  const text = replyTo
    ? `From: ${replyTo}\n\n${message}`
    : message;

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: FROM,
      to: [TO],
      subject: 'APEX Query',
      reply_to: replyTo,
      text,
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    console.error('Resend error', res.status, detail);
    return json({ error: 'Could not send your message. Please try again.' }, 502);
  }

  return json({ ok: true });
});
