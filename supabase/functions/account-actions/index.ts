import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const USERNAME_RE = /^[a-z0-9._]{3,20}$/;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return jsonResponse({ ok: true }, 200);
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'server_misconfigured' }, 500);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: 'invalid_json' }, 400);
  }

  const action = payload.action;

  if (action === 'create_username_account') {
    const rawUsername = typeof payload.username === 'string' ? payload.username : '';
    const password = typeof payload.password === 'string' ? payload.password : '';
    const fullName = typeof payload.full_name === 'string' ? payload.full_name.trim() : '';
    const layout = payload.layout === 'app' ? 'app' : 'web';

    const username = rawUsername.trim().toLowerCase();
    if (!USERNAME_RE.test(username)) {
      return jsonResponse({ error: 'invalid_username', message: 'Invalid username format.' }, 400);
    }
    if (password.length < 8) {
      return jsonResponse({ error: 'weak_password', message: 'Password must be at least 8 characters.' }, 400);
    }
    if (!fullName) {
      return jsonResponse({ error: 'invalid_name', message: 'Full name is required.' }, 400);
    }

    const syntheticEmail = `${username}@u.settliv.app`;
    const { data, error } = await admin.auth.admin.createUser({
      email: syntheticEmail,
      password,
      email_confirm: true,
      user_metadata: { display_name: fullName, layout },
    });

    if (error) {
      const msg = error.message.toLowerCase();
      if (msg.includes('already') || msg.includes('exists') || msg.includes('registered')) {
        return jsonResponse({ error: 'username_taken', message: 'That username is taken' }, 409);
      }
      return jsonResponse({ error: 'create_failed', message: 'Could not create account.' }, 400);
    }

    return jsonResponse({ ok: true, user_id: data.user?.id ?? null }, 201);
  }

  if (action === 'delete_account') {
    const authHeader = req.headers.get('Authorization') ?? '';
    const jwt = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
    if (!jwt) {
      return jsonResponse({ error: 'unauthorized' }, 401);
    }

    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData.user) {
      return jsonResponse({ error: 'unauthorized' }, 401);
    }

    const { error: delErr } = await admin.auth.admin.deleteUser(userData.user.id);
    if (delErr) {
      return jsonResponse({ error: 'delete_failed', message: 'Could not delete account.' }, 500);
    }

    return jsonResponse({ ok: true }, 200);
  }

  return jsonResponse({ error: 'unsupported_action' }, 400);
});
