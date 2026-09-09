import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { requireAdmin, HttpError } from '../_shared/adminAuth.ts';
import { generateTempPassword } from '../_shared/password.ts';

const VALID_ROLES = ['dispatcher', 'driver', 'hospital', 'admin'];

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    await requireAdmin(req);

    const { email, fullName, role, hospitalId, phone } = await req.json();

    if (!email || !fullName || !role) {
      throw new HttpError(400, 'email, fullName, and role are required');
    }
    if (!VALID_ROLES.includes(role)) {
      throw new HttpError(400, 'Invalid role');
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const tempPassword = generateTempPassword();

    const { data, error } = await adminClient.auth.admin.createUser({
      email,
      password: tempPassword,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        role,
        phone: phone ?? '',
        must_change_password: true,
      },
    });

    if (error || !data.user) {
      throw new HttpError(400, error?.message ?? 'Failed to create user');
    }

    if (hospitalId) {
      await adminClient
        .from('profiles')
        .update({ hospital_id: hospitalId })
        .eq('id', data.user.id);
    }

    return new Response(
      JSON.stringify({ id: data.user.id, tempPassword }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    const status = e instanceof HttpError ? e.status : 500;
    const message = e instanceof Error ? e.message : 'Unknown error';
    return new Response(
      JSON.stringify({ error: message }),
      { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
