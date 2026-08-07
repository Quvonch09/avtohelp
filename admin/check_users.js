const { createClient } = require('@supabase/supabase-js');
const supabaseUrl = 'https://mtwcfkyuvapnvgcxgmda.supabase.co';
const supabaseAnonKey = 'sb_publishable_bFQK59UKRpkgM1Bc1Az-dA_FYhgkh6e';
const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function check() {
  const { data, error } = await supabase.from('profiles').select('id, full_name, role, is_verified, phone');
  if (error) {
    console.error('Xatolik:', error);
  } else {
    console.log('Profillar:', JSON.stringify(data, null, 2));
  }
}
check();
