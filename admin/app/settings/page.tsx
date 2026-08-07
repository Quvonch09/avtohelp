'use client';

import React, { useState } from 'react';
import { supabase } from '@/lib/supabase';

export default function SettingsPage() {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [recipient, setRecipient] = useState<'ALL' | 'USER' | 'MASTER'>('ALL');
  const [sending, setSending] = useState(false);
  const [logMsgs, setLogMsgs] = useState<string[]>(['[Tizim] Bildirishnomalar boshqaruv paneli yuklandi.']);

  function addLog(msg: string) {
    const time = new Date().toLocaleTimeString();
    setLogMsgs(prev => [...prev, `[${time}] ${msg}`]);
  }

  async function handleSendPush(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim() || !body.trim()) return;
    setSending(true);
    addLog(`Foydalanuvchilarga push jo'natish boshlandi: Roli = ${recipient}, Sarlavha = "${title}"`);

    try {
      // Mock / Real push notification trigger via Supabase edge function
      // In a real project, we invoke 'send-push' function
      const response = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/send-push`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({
          recipient_role: recipient,
          title: title.trim(),
          body: body.trim(),
        }),
      });

      // Save into DB notifications log
      // Get profiles based on role to insert notification rows
      const query = supabase.from('profiles').select('id');
      if (recipient !== 'ALL') {
        query.eq('role', recipient);
      }
      const { data: users } = await query;
      
      if (users && users.length > 0) {
        const notificationsToInsert = users.map(u => ({
          user_id: u.id,
          title: title.trim(),
          body: body.trim(),
          is_read: false
        }));

        await supabase.from('notifications').insert(notificationsToInsert);
      }

      addLog(`Push-xabarnoma muvaffaqiyatli jo'natildi va ma'lumotlar bazasida ${users?.length || 0} nafar foydalanuvchiga saqlandi!`);
      setTitle('');
      setBody('');
    } catch (err: any) {
      console.error(err);
      addLog(`Xatolik yuz berdi: ${err.message || 'Push jo\'natilmadi, lekin baza jadvallariga saqlandi.'}`);
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="space-y-8 font-sans">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-extrabold tracking-tight text-[#132F4C]">Sozlamalar va Push</h1>
        <p className="text-gray-500 mt-1">Platforma sozlamalari hamda barcha foydalanuvchilarga push-bildirishnomalar yuborish</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Push Notification Panel */}
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm space-y-6">
          <div>
            <h2 className="text-lg font-bold text-[#132F4C]">🔔 Push bildirishnoma yuborish</h2>
            <p className="text-xs text-gray-500 mt-0.5">Ilovadagi faol foydalanuvchilar ekraniga real-time push-xabar chiqarish</p>
          </div>

          <form onSubmit={handleSendPush} className="space-y-4">
            <div className="space-y-1">
              <label className="text-xs font-bold text-gray-500 uppercase block">Qabul qiluvchilar</label>
              <select
                value={recipient}
                onChange={(e) => setRecipient(e.target.value as any)}
                className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C] font-semibold"
              >
                <option value="ALL">Barcha foydalanuvchilar (Mijozlar + Ustalar)</option>
                <option value="USER">Faqat Mijozlar (Clients)</option>
                <option value="MASTER">Faqat Ustalar (Masters)</option>
              </select>
            </div>

            <div className="space-y-1">
              <label className="text-xs font-bold text-gray-500 uppercase block">Xabar sarlavhasi (Title) *</label>
              <input
                type="text"
                required
                placeholder="Masalan: Tizimda yangilanish yoki Yangi aksiya!"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C] font-medium"
              />
            </div>

            <div className="space-y-1">
              <label className="text-xs font-bold text-gray-500 uppercase block">Xabar matni (Body) *</label>
              <textarea
                required
                placeholder="Push xabarnoma matnini to'liq kiriting..."
                value={body}
                onChange={(e) => setBody(e.target.value)}
                className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C] h-24"
              />
            </div>

            <button
              type="submit"
              disabled={sending}
              className="w-full bg-[#132F4C] hover:bg-[#0E2237] text-white font-bold py-3.5 rounded-xl transition-all shadow-md disabled:bg-gray-400 flex items-center justify-center gap-2"
            >
              {sending ? (
                <>
                  <div className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
                  Yuborilmoqda...
                </>
              ) : (
                'Bildirishnomani yuborish 🚀'
              )}
            </button>
          </form>
        </div>

        {/* Real-time System Logs Console */}
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm flex flex-col justify-between space-y-6">
          <div>
            <h2 className="text-lg font-bold text-[#132F4C]">💻 Tizim loglari console</h2>
            <p className="text-xs text-gray-500 mt-0.5">Xabarnoma yuborish va API webhook monitoringi</p>
          </div>

          <div className="flex-1 bg-[#132F4C] text-[#F5F7FB] border border-gray-200 rounded-2xl p-4 font-mono text-xs overflow-y-auto space-y-2 h-72 shadow-inner">
            {logMsgs.map((msg, i) => (
              <div key={i}>{msg}</div>
            ))}
          </div>

          <button
            onClick={() => setLogMsgs(['[Tizim] Loglar tozalandi.'])}
            className="w-full bg-[#F5F7FB] hover:bg-gray-100 text-[#132F4C] font-bold py-2 rounded-xl text-xs transition-all border border-gray-200/60"
          >
            Loglarni tozalash
          </button>
        </div>
      </div>
    </div>
  );
}
