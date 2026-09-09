import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

/// Verifies the request's bearer token belongs to a signed-in user whose
/// profiles.role = 'admin'. Throws HttpError(401/403) otherwise.
export async function requireAdmin(req: Request): Promise<{ id: string }> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) throw new HttpError(401, 'Missing authorization header');

  const callerClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) throw new HttpError(401, 'Invalid session');

  const { data: profile, error: profileError } = await callerClient
    .from('profiles')
    .select('role')
    .eq('id', userData.user.id)
    .single();

  if (profileError || profile?.role !== 'admin') {
    throw new HttpError(403, 'Admin role required');
  }

  return { id: userData.user.id };
}
