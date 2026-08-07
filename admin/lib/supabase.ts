import { createClient } from '@supabase/supabase-js';

let rawUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
  rawUrl = 'https://placeholder.supabase.co';
}

let rawKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';
if (!rawKey || rawKey.length < 10) {
  rawKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.placeholder_key';
}

export const supabaseUrl = rawUrl;
export const supabaseAnonKey = rawKey;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Admin-level actions or service actions require service role key (must only run server-side)
export const getSupabaseAdmin = () => {
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || supabaseAnonKey;
  return createClient(supabaseUrl, serviceKey);
};
