'use client';

import React, { useState, useEffect } from 'react';

interface Service {
  id: number;
  name: string;
  icon: string | null;
  base_price: number;
}

export default function ServicesCrud() {
  const [services, setServices] = useState<Service[]>([]);
  const [loading, setLoading] = useState(true);

  // Forms
  const [name, setName] = useState('');
  const [icon, setIcon] = useState('wrench');
  const [basePrice, setBasePrice] = useState<number>(0);
  const [editId, setEditId] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchServices();
  }, []);

  async function fetchServices() {
    try {
      setLoading(true);
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'getServices' }),
      });
      const result = await res.json();
      setServices(result.data || []);
    } catch (err) {
      console.error('Error fetching services:', err);
    } finally {
      setLoading(false);
    }
  }

  async function handleSave() {
    if (!name.trim()) return;
    setSaving(true);

    try {
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'saveService',
          params: { id: editId, name: name.trim(), icon: icon.trim(), basePrice }
        }),
      });
      const result = await res.json();
      if (result.error) throw new Error(result.error);

      // Refresh list
      fetchServices();

      // Reset form
      setName('');
      setIcon('wrench');
      setBasePrice(0);
      setEditId(null);
    } catch (err: any) {
      alert('Xizmatni saqlashda xatolik: ' + err.message);
    } finally {
      setSaving(false);
    }
  }

  function handleEdit(service: Service) {
    setEditId(service.id);
    setName(service.name);
    setIcon(service.icon || 'wrench');
    setBasePrice(service.base_price);
  }

  async function handleDelete(id: number) {
    if (!confirm('Haqiqatdan ham ushbu xizmat turini o\'chirib tashlamoqchimisiz?')) return;

    try {
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'deleteService',
          params: { id }
        }),
      });
      const result = await res.json();
      if (result.error) throw new Error(result.error);

      setServices(services.filter(s => s.id !== id));
    } catch (err: any) {
      alert('Xatolik: ' + err.message);
    }
  }

  if (loading) {
    return (
      <div className="flex-1 flex items-center justify-center min-h-[400px]">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-[#132F4C] border-t-transparent"></div>
      </div>
    );
  }

  return (
    <div className="space-y-8 font-sans">
      {/* Title */}
      <div>
        <h1 className="text-3xl font-extrabold tracking-tight text-[#132F4C]">Xizmatlar sozlamalari</h1>
        <p className="text-gray-500 mt-1">Platformadagi barcha yordam va servis turlarining narxlari hamda boshqaruvi (CRUD)</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Form Column */}
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm space-y-6">
          <h2 className="text-lg font-bold text-[#132F4C]">
            {editId !== null ? '✏️ Xizmatni tahrirlash' : '➕ Yangi xizmat qo\'shish'}
          </h2>

          <div className="space-y-4">
            <div className="space-y-1">
              <label className="text-xs font-bold text-gray-500 uppercase tracking-wider block">Xizmat Nomi</label>
              <input
                type="text"
                placeholder="Masalan: Moy almashtirish"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C]"
              />
            </div>

            <div className="space-y-1">
              <label className="text-xs font-bold text-gray-500 uppercase tracking-wider block">Ikonka nomi</label>
              <input
                type="text"
                placeholder="wrench, truck, droplet, zap..."
                value={icon}
                onChange={(e) => setIcon(e.target.value)}
                className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C]"
              />
            </div>

            <div className="space-y-1">
              <label className="text-xs font-bold text-gray-500 uppercase tracking-wider block">Boshlang'ich Narxi (Base Price UZS)</label>
              <input
                type="number"
                placeholder="100000"
                value={basePrice}
                onChange={(e) => setBasePrice(Number(e.target.value))}
                className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C]"
              />
            </div>

            <div className="flex gap-3 pt-2">
              {editId !== null && (
                <button
                  onClick={() => {
                    setEditId(null);
                    setName('');
                    setIcon('wrench');
                    setBasePrice(0);
                  }}
                  className="flex-1 bg-gray-100 hover:bg-gray-200 text-gray-500 font-bold py-2.5 rounded-xl text-sm transition-all"
                >
                  Bekor qilish
                </button>
              )}
              <button
                onClick={handleSave}
                disabled={saving}
                className="flex-1 bg-[#132F4C] hover:bg-[#0E2237] text-white font-bold py-2.5 rounded-xl text-sm transition-all shadow-md"
              >
                {saving ? 'Saqlanmoqda...' : editId !== null ? 'Yangilash 💾' : 'Saqlash 💾'}
              </button>
            </div>
          </div>
        </div>

        {/* List Column */}
        <div className="lg:col-span-2 bg-white border border-gray-100 rounded-2xl p-6 shadow-sm space-y-6">
          <h2 className="text-lg font-bold text-[#132F4C]">⚙️ Xizmat turlari ({services.length} ta)</h2>

          <div className="grid grid-cols-1 gap-4">
            {services.map(s => (
              <div
                key={s.id}
                className="border border-gray-100 p-4 rounded-2xl flex justify-between items-center hover:border-gray-200 transition-all bg-white shadow-sm"
              >
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 rounded-xl bg-[#132F4C]/5 text-[#132F4C] flex items-center justify-center font-bold text-xl">
                    {s.icon === 'truck' ? '🚚' : s.icon === 'droplet' ? '💧' : s.icon === 'wrench' ? '🔧' : s.icon === 'zap' ? '⚡' : '📦'}
                  </div>
                  <div>
                    <h3 className="font-extrabold text-[#132F4C]">{s.name}</h3>
                    <p className="text-xs text-gray-400 font-semibold mt-0.5">Ikon: {s.icon} | Narxi: {s.base_price.toLocaleString()} UZS</p>
                  </div>
                </div>

                <div className="flex gap-2">
                  <button
                    onClick={() => handleEdit(s)}
                    className="text-xs bg-[#F5F7FB] hover:bg-[#132F4C]/5 text-[#132F4C] font-bold px-3 py-2 rounded-xl transition-all"
                  >
                    ✏️ Tahrirlash
                  </button>
                  <button
                    onClick={() => handleDelete(s.id)}
                    className="text-xs bg-red-50 hover:bg-red-100 text-red-600 font-bold px-3 py-2 rounded-xl transition-all"
                  >
                    🗑️ O'chirish
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
