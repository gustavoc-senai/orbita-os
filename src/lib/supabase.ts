import { createClient } from '@supabase/supabase-js';
const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_ANON_KEY;
export const configured = Boolean(url && key && !url.includes('SEU-PROJETO'));
export const supabase = createClient(url || 'https://placeholder.supabase.co', key || 'not-configured', { auth: { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true } });
