import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const allowedRoles = new Set([
  'admin',
  'manager',
  'booking_officer',
  'finance',
  'viewer',
]);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) return json({ error: 'Authentication required.' }, 401);

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!serviceRole) return json({ error: 'Server configuration is incomplete.' }, 500);

    const adminClient = createClient(supabaseUrl, serviceRole, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: userData, error: userError } = await adminClient.auth.getUser(token);
    if (userError || !userData.user) return json({ error: 'Authentication required.' }, 401);

    const callerId = userData.user.id;
    const { data: caller, error: callerError } = await adminClient
      .from('wesley_staff_users')
      .select('role, active')
      .eq('user_id', callerId)
      .maybeSingle();

    if (callerError || !caller?.active || caller.role !== 'admin') {
      return json({ error: 'Administrator access is required.' }, 403);
    }

    const body = await req.json();
    const action = String(body.action ?? 'list');

    if (action === 'list') {
      const { data, error } = await adminClient
        .from('wesley_staff_users')
        .select('user_id, display_name, username, email, role, active, created_at')
        .order('created_at');
      if (error) throw error;
      return json({ staff: data ?? [] });
    }

    if (action === 'create') {
      const username = String(body.username ?? '').trim().toLowerCase();
      const displayName = String(body.display_name ?? '').trim();
      const role = String(body.role ?? 'viewer');
      const password = String(body.password ?? '');
      const contactEmail = String(body.email ?? '').trim().toLowerCase();

      if (!username || !/^[a-z0-9._-]{3,40}$/.test(username)) {
        return json({ error: 'Username must be 3-40 letters, numbers, dots, dashes, or underscores.' }, 400);
      }
      if (!allowedRoles.has(role)) return json({ error: 'Invalid staff role.' }, 400);
      if (password.length < 8) return json({ error: 'Temporary password must be at least 8 characters.' }, 400);

      const authEmail = `${username}@wesleyhall.local`;

      const { data: created, error: createError } = await adminClient.auth.admin.createUser({
        email: authEmail,
        password,
        email_confirm: true,
      });
      if (createError || !created.user) {
        return json({ error: createError?.message ?? 'Unable to create user.' }, 400);
      }

      const { error: profileError } = await adminClient.from('wesley_staff_users').insert({
        user_id: created.user.id,
        display_name: displayName || username,
        username,
        email: contactEmail || authEmail,
        role,
        active: true,
      });
      if (profileError) {
        await adminClient.auth.admin.deleteUser(created.user.id);
        return json({ error: profileError.message }, 400);
      }

      return json({ success: true, user_id: created.user.id });
    }

    if (action === 'update') {
      const userId = String(body.user_id ?? '');
      const role = String(body.role ?? 'viewer');
      const active = body.active == null ? true : Boolean(body.active);
      const displayName = String(body.display_name ?? '').trim();

      if (!userId) return json({ error: 'User id is required.' }, 400);
      if (!allowedRoles.has(role)) return json({ error: 'Invalid staff role.' }, 400);
      if (userId === callerId && (role !== 'admin' || !active)) {
        return json({ error: 'You cannot remove your own administrator access.' }, 400);
      }

      const { error } = await adminClient
        .from('wesley_staff_users')
        .update({ role, active, display_name: displayName })
        .eq('user_id', userId);
      if (error) throw error;
      return json({ success: true });
    }

    if (action === 'reset_password') {
      const userId = String(body.user_id ?? '');
      const password = String(body.password ?? '');
      if (!userId) return json({ error: 'User id is required.' }, 400);
      if (password.length < 8) return json({ error: 'Password must be at least 8 characters.' }, 400);

      const { error } = await adminClient.auth.admin.updateUserById(userId, { password });
      if (error) return json({ error: error.message }, 400);
      return json({ success: true });
    }

    return json({ error: 'Unknown action.' }, 400);
  } catch (error) {
    console.error(error);
    return json({ error: 'Unable to manage Wesley Hall staff.' }, 500);
  }
});
