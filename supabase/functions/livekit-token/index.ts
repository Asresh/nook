import { createClient } from 'jsr:@supabase/supabase-js@2';
import { AccessToken } from 'npm:livekit-server-sdk@2.13.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return json({ error: 'Use POST' }, 405);
  }

  const apiKey = Deno.env.get('LIVEKIT_API_KEY');
  const apiSecret = Deno.env.get('LIVEKIT_API_SECRET');
  const livekitUrl = Deno.env.get('LIVEKIT_URL');

  if (!apiKey || !apiSecret || !livekitUrl) {
    return json(
      { error: 'LIVEKIT_API_KEY, LIVEKIT_API_SECRET and LIVEKIT_URL must be set.' },
      500,
    );
  }

  const authHeader = request.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return json({ error: 'Missing bearer token.' }, 401);
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: 'Not signed in.' }, 401);
  }

  let body: { room?: string; name?: string };
  try {
    body = await request.json();
  } catch {
    return json({ error: 'Invalid JSON body.' }, 400);
  }

  const room = body.room?.trim();
  if (!room) {
    return json({ error: 'room is required.' }, 400);
  }

  const name = body.name?.trim() || userData.user.id;

  const token = new AccessToken(apiKey, apiSecret, {
    identity: userData.user.id,
    name,
    ttl: '6h',
  });

  token.addGrant({
    room,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
  });

  return json({ token: await token.toJwt(), url: livekitUrl });
});

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
