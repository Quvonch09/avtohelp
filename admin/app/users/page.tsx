'use client';

import React, { useState, useEffect } from 'react';

interface Client {
  id: string;
  full_name: string;
  phone: string;
  avatar_url: string | null;
  created_at: string;
  user_cars: { id: string }[];
}

export default function ClientsPage() {
  const [clients, setClients] = useState<Client[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  async function fetchClients() {
    try {
      setLoading(true);
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'getClients' }),
      });
      const result = await res.json();
      setClients(result.data || []);
    } catch (err) {
      console.error('Error fetching clients:', err);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchClients();
  }, []);

  // Filter clients by name or phone
  const filteredClients = clients.filter(c => {
    const name = (c.full_name || '').toLowerCase();
    const phone = (c.phone || '').toLowerCase();
    const query = searchQuery.toLowerCase();
    return name.includes(query) || phone.includes(query);
  });

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
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-3xl font-extrabold tracking-tight text-[#132F4C]">Mijozlar boshqaruvi</h1>
          <p className="text-gray-500 mt-1">Platformadagi ro'yxatdan o'tgan barcha haydovchilar (mijozlar) ro'yxati</p>
        </div>

        {/* Search Input */}
        <div className="w-full sm:w-72">
          <input
            type="text"
            placeholder="Ism yoki telefon raqam bo'yicha qidiruv..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-white border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C] shadow-sm font-semibold"
          />
        </div>
      </div>

      {/* Clients Table Card */}
      <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm space-y-6">
        <h2 className="text-lg font-bold text-[#132F4C]">👥 Mijozlar ro'yxati ({filteredClients.length} nafar)</h2>

        {filteredClients.length === 0 ? (
          <div className="text-center text-gray-400 py-16">🔍 Hech qanday mijoz topilmadi.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm text-left text-gray-700">
              <thead className="text-xs uppercase bg-[#F5F7FB] text-gray-500 font-bold border-b border-gray-100">
                <tr>
                  <th className="px-4 py-3">Mijoz Ismi</th>
                  <th className="px-4 py-3">Telefon raqami</th>
                  <th className="px-4 py-3">Mashinalar soni</th>
                  <th className="px-4 py-3">Ro'yxatdan o'tgan sana</th>
                  <th className="px-4 py-3 text-right">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filteredClients.map(client => (
                  <tr key={client.id} className="hover:bg-gray-50/50 transition-colors">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-[#132F4C]/5 text-[#132F4C] flex items-center justify-center font-bold text-sm border border-gray-100">
                          {client.full_name ? client.full_name.charAt(0) : 'M'}
                        </div>
                        <div>
                          <div className="font-semibold text-[#132F4C]">{client.full_name || 'Noma\'lum Mijoz'}</div>
                          <div className="text-[10px] text-gray-400 font-mono">ID: {client.id.substring(0, 8)}...</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 font-semibold text-gray-700">
                      {client.phone || 'Kiritilmagan'}
                    </td>
                    <td className="px-4 py-3 font-bold text-[#132F4C]">
                      {client.user_cars?.length || 0} ta avto
                    </td>
                    <td className="px-4 py-3 text-gray-500">
                      {new Date(client.created_at).toLocaleDateString('uz-UZ')}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-100">
                        Faol mijoz
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
