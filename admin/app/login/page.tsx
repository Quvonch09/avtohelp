'use client';

import React, { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  useEffect(() => {
    // If already logged in, redirect to dashboard
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session) {
        supabase.from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .single()
          .then(({ data }) => {
            if (data && data.role === 'ADMIN') {
              router.push('/');
            }
          });
      }
    });
  }, []);

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setErrorMsg('');

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) throw error;

      if (data.user) {
        // Verify role
        const { data: profile, error: profileErr } = await supabase
          .from('profiles')
          .select('role')
          .eq('id', data.user.id)
          .single();

        if (profileErr || !profile || profile.role !== 'ADMIN') {
          // Log out and throw error
          await supabase.auth.signOut();
          throw new Error('Kirish taqiqlandi. Siz administrator emassiz!');
        }

        router.push('/');
      }
    } catch (err: any) {
      console.error(err);
      setErrorMsg(err.message || 'Kirishda xatolik yuz berdi. Parol yoki email noto‘g‘ri.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#F5F7FB] px-4">
      <div className="max-w-md w-full bg-white rounded-3xl p-8 shadow-xl border border-gray-100 flex flex-col space-y-6">
        {/* Logo and Header */}
        <div className="flex flex-col items-center text-center space-y-3">
          <div className="w-16 h-16 rounded-full bg-[#132F4C] flex items-center justify-center shadow-lg">
            <span className="text-3xl font-black text-white">A</span>
          </div>
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-[#132F4C]">AVTOHELP</h1>
            <p className="text-xs text-gray-500 font-semibold uppercase mt-0.5">Super Admin Tizimi</p>
          </div>
        </div>

        {/* Form */}
        <form onSubmit={handleLogin} className="space-y-4">
          {errorMsg && (
            <div className="p-3 bg-red-50 text-red-600 rounded-xl text-xs font-semibold border border-red-100 text-center">
              ⚠️ {errorMsg}
            </div>
          )}

          <div className="space-y-1">
            <label className="text-xs font-bold text-gray-500 uppercase tracking-wider">Email Manzil</label>
            <input
              type="email"
              placeholder="admin@avtohelp.uz"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C] focus:ring-1 focus:ring-[#132F4C] transition-all font-medium"
            />
          </div>

          <div className="space-y-1">
            <label className="text-xs font-bold text-gray-500 uppercase tracking-wider">Maxfiy Parol</label>
            <input
              type="password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C] focus:ring-1 focus:ring-[#132F4C] transition-all"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-[#132F4C] hover:bg-[#0E2237] text-white font-bold py-3.5 rounded-xl transition-all shadow-md disabled:bg-gray-400 flex items-center justify-center gap-2"
          >
            {loading ? (
              <>
                <div className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
                Kirilmoqda...
              </>
            ) : (
              'Tizimga kirish 🚀'
            )}
          </button>

          <button
            type="button"
            onClick={() => {
              if (typeof window !== 'undefined') {
                localStorage.setItem('avtohelp_demo_mode', 'true');
              }
              router.push('/');
            }}
            className="w-full bg-emerald-600 hover:bg-emerald-700 text-white font-bold py-3 rounded-xl transition-all shadow-sm flex items-center justify-center gap-2 text-sm"
          >
            Demo rejimda kirish ✨
          </button>
        </form>

        {/* Help footer */}
        <div className="text-center text-[10px] text-gray-400">
          Xavfsiz tizim. Kirishlar loglanadi.
        </div>
      </div>
    </div>
  );
}
