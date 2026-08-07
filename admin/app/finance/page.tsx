'use client';

import React, { useState, useEffect } from 'react';

interface Transaction {
  id: string;
  created_at: string;
  status: string;
  price: number;
  user_address: string;
  profiles_user: { full_name: string; phone: string } | null;
  profiles_master: { full_name: string; phone: string } | null;
  services: { name: string } | null;
}

export default function FinancePage() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [commission, setCommission] = useState<number>(10); // default 10%

  useEffect(() => {
    fetchTransactions();
    // Load commission settings from localStorage
    const savedComm = localStorage.getItem('avtohelp_commission');
    if (savedComm) {
      setCommission(Number(savedComm));
    }
  }, []);

  async function fetchTransactions() {
    try {
      setLoading(true);
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'getOrders' }),
      });
      const result = await res.json();
      // Filter only completed orders (DONE status) for transactions list
      const completedOrders = (result.data || []).filter((o: any) => o.status === 'DONE');
      setTransactions(completedOrders);
    } catch (err) {
      console.error('Error fetching transactions:', err);
    } finally {
      setLoading(false);
    }
  }

  function handleSaveCommission(val: number) {
    setCommission(val);
    localStorage.setItem('avtohelp_commission', String(val));
  }

  // Calculations
  const totalVolume = transactions.reduce((sum, t) => sum + (t.price || 0), 0);
  const totalCommissionEarned = (totalVolume * commission) / 100;
  const mastersPayout = totalVolume - totalCommissionEarned;

  if (loading) {
    return (
      <div className="flex-1 flex items-center justify-center min-h-[400px]">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-[#132F4C] border-t-transparent"></div>
      </div>
    );
  }

  return (
    <div className="space-y-8 font-sans">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-extrabold tracking-tight text-[#132F4C]">Moliya boshqaruvi</h1>
        <p className="text-gray-500 mt-1">Platformadagi to'lovlar, komissiya hisoblari va tranzaksiyalar tarixi</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm">
          <div className="text-xs font-bold text-gray-400 uppercase tracking-wider">Jami to'lov hajmi</div>
          <div className="text-2xl font-black mt-2 text-[#132F4C]">
            {totalVolume.toLocaleString()} <span className="text-xs font-semibold">UZS</span>
          </div>
          <div className="text-[11px] text-gray-500 mt-1">Bajarilgan ishlar umumiy summasi</div>
        </div>

        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm">
          <div className="text-xs font-bold text-gray-400 uppercase tracking-wider">Platforma komissiyasi ({commission}%)</div>
          <div className="text-2xl font-black mt-2 text-indigo-600">
            {totalCommissionEarned.toLocaleString()} <span className="text-xs font-semibold">UZS</span>
          </div>
          <div className="text-[11px] text-gray-500 mt-1">Loyihaga tushgan foyda ulushi</div>
        </div>

        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm">
          <div className="text-xs font-bold text-gray-400 uppercase tracking-wider">Ustalarga to'langan mablag'</div>
          <div className="text-2xl font-black mt-2 text-emerald-600">
            {mastersPayout.toLocaleString()} <span className="text-xs font-semibold">UZS</span>
          </div>
          <div className="text-[11px] text-gray-500 mt-1">Komissiyadan tashqari sof usta daromadi</div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Commission settings card */}
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm space-y-6 h-fit">
          <div>
            <h2 className="text-lg font-bold text-[#132F4C]">⚙️ Komissiya sozlamalari</h2>
            <p className="text-xs text-gray-500 mt-0.5">Har bir bajarilgan buyurtmadan olinadigan foiz stavkasi</p>
          </div>

          <div className="space-y-4">
            <div className="flex justify-between items-center text-sm font-bold text-[#132F4C]">
              <span>Komissiya foizi:</span>
              <span className="bg-[#132F4C]/5 px-3 py-1 rounded-lg text-[#132F4C] text-base">{commission}%</span>
            </div>
            
            <input
              type="range"
              min="0"
              max="50"
              step="1"
              value={commission}
              onChange={(e) => handleSaveCommission(Number(e.target.value))}
              className="w-full h-2 bg-[#F5F7FB] rounded-lg appearance-none cursor-pointer accent-[#132F4C]"
            />

            <div className="text-xs text-gray-500 bg-[#F5F7FB] p-3.5 rounded-xl border border-gray-200/50 space-y-1">
              <div className="font-bold text-[#132F4C] mb-1">Eslatma:</div>
              Komissiya foizini o'zgartirish kelgusi buyurtmalar yakunlanganda hisob-kitoblar uchun avtomatik qo'llaniladi.
            </div>
          </div>
        </div>

        {/* Transactions list table */}
        <div className="lg:col-span-2 bg-white border border-gray-100 rounded-2xl p-6 shadow-sm space-y-6">
          <h2 className="text-lg font-bold text-[#132F4C]">📋 To'lovlar tarixi ({transactions.length} ta tranzaksiya)</h2>

          {transactions.length === 0 ? (
            <div className="text-center text-gray-400 py-16">🔍 Hozircha yakunlangan tranzaksiyalar yo'q.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm text-left text-gray-700">
                <thead className="text-xs uppercase bg-[#F5F7FB] text-gray-500 font-bold border-b border-gray-100">
                  <tr>
                    <th className="px-4 py-3">Usta / Mijoz</th>
                    <th className="px-4 py-3">Xizmat va Narx</th>
                    <th className="px-4 py-3">Komissiya summasi</th>
                    <th className="px-4 py-3">Sana</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {transactions.map(t => {
                    const commSum = (t.price * commission) / 100;
                    return (
                      <tr key={t.id} className="hover:bg-gray-50/50 transition-colors">
                        <td className="px-4 py-3">
                          <div className="font-semibold text-[#132F4C]">{t.profiles_master?.full_name || 'Usta'}</div>
                          <div className="text-xs text-gray-400">Mijoz: {t.profiles_user?.full_name}</div>
                        </td>
                        <td className="px-4 py-3">
                          <div className="font-bold text-[#132F4C]">{t.services?.name}</div>
                          <div className="text-xs text-gray-500">{t.price.toLocaleString()} UZS</div>
                        </td>
                        <td className="px-4 py-3 font-bold text-indigo-600">
                          {commSum.toLocaleString()} UZS
                        </td>
                        <td className="px-4 py-3 text-xs text-gray-500">
                          {new Date(t.created_at).toLocaleDateString('uz-UZ')}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
