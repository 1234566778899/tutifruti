import { createClient } from '@supabase/supabase-js';

/** Mismo proyecto que la app iOS. La clave publicable es la única que puede ir en el cliente. */
export const SUPABASE_URL = 'https://liejnmzxlpctqybecrbu.supabase.co';
export const SUPABASE_KEY = 'sb_publishable_kcbf362MFjHNT0ozSuXmOA_zfX9koBw';
export const INVITE_HOST = 'tutifruti-ai.vercel.app';

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
	auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
});
