'use client';

import React, { useState, useEffect } from 'react';

interface Region {
  id: number;
  name: string;
  status: 'ACTIVE' | 'SOON';
  masters_count: number;
}

export default function RegionsPage() {
  const [regions, setRegions] = useState<Region[]>([]);
  const [showAddModal, setShowAddModal] = useState(false);
  const [newName, setNewName] = useState('');
  const [newStatus, setNewStatus] = useState<'ACTIVE' | 'SOON'>('SOON');

  useEffect(() => {
    // Load regions from localStorage or default
    const saved = localStorage.getItem('avtohelp_regions');
    if (saved) {
      setRegions(JSON.parse(saved));
    } else {
      const defaultRegions: Region[] = [
        { id: 1, name: 'Qarshi', status: 'ACTIVE', masters_count: 5 },
        { id: 2, name: 'Toshkent', status: 'SOON', masters_count: 0 },
        { id: 3, name: 'Samarqand', status: 'SOON', masters_count: 0 },
      ];
      setRegions(defaultRegions);
      localStorage.setItem('avtohelp_regions', JSON.stringify(defaultRegions));
    }
  }, []);

  function saveRegions(newRegions: Region[]) {
    setRegions(newRegions);
    localStorage.setItem('avtohelp_regions', JSON.stringify(newRegions));
  }

  function handleAddRegion(e: React.FormEvent) {
    e.preventDefault();
    if (!newName.trim()) return;

    const newRegion: Region = {
      id: Date.now(),
      name: newName.trim(),
      status: newStatus,
      masters_count: 0,
    };

    const updated = [...regions, newRegion];
    saveRegions(updated);
    
    setShowAddModal(false);
    setNewName('');
    setNewStatus('SOON');
  }

  function toggleStatus(id: number) {
    const updated = regions.map((r): Region => {
      if (r.id === id) {
        return {
          ...r,
          status: r.status === 'ACTIVE' ? 'SOON' : 'ACTIVE'
        };
      }
      return r;
    });
    saveRegions(updated);
  }

  function handleDelete(id: number) {
    if (id === 1) {
      alert('Boshlang‘ich Qarshi shahrini o‘chirib bo‘lmaydi!');
      return;
    }
    if (!confirm('Ushbu hududni o‘chirmoqchimisiz?')) return;
    const updated = regions.filter(r => r.id !== id);
    saveRegions(updated);
  }

  return (
    <div className="space-y-8 font-sans">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-3xl font-extrabold tracking-tight text-[#132F4C]">Hududlar boshqaruvi</h1>
          <p className="text-gray-500 mt-1">Avtohelp yo'l yordami xizmat ko'rsatuvchi hududlar va shaharlar ro'yxati</p>
        </div>

        <button
          onClick={() => setShowAddModal(true)}
          className="bg-[#132F4C] hover:bg-[#0E2237] text-white text-sm font-bold px-4 py-3 rounded-xl shadow-md transition-all flex items-center gap-2"
        >
          <span>➕</span> Yangi shahar qo'shish
        </button>
      </div>

      {/* Regions List Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {regions.map(r => (
          <div
            key={r.id}
            className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm flex flex-col justify-between space-y-4 hover:shadow-md transition-all"
          >
            <div className="flex justify-between items-start">
              <div>
                <h3 className="text-xl font-bold text-[#132F4C]">{r.name} shahri</h3>
                <span className="text-xs font-semibold text-gray-400 mt-0.5 block">O'zbekiston</span>
              </div>
              <span className={`px-2.5 py-1 rounded-full text-[10px] font-black border ${
                r.status === 'ACTIVE'
                  ? 'bg-emerald-50 text-emerald-700 border-emerald-100'
                  : 'bg-amber-50 text-amber-700 border-amber-100'
              }`}>
                {r.status === 'ACTIVE' ? 'FAOL' : 'TEZ ORADA'}
              </span>
            </div>

            <div className="bg-[#F5F7FB] p-4 rounded-xl flex justify-between items-center text-xs">
              <span className="text-gray-500 font-semibold">Tizimdagi ustalar:</span>
              <span className="font-extrabold text-[#132F4C] text-sm">{r.masters_count} ta</span>
            </div>

            <div className="flex gap-2 pt-2 border-t border-gray-50">
              <button
                onClick={() => toggleStatus(r.id)}
                className="flex-1 bg-[#F5F7FB] hover:bg-[#132F4C]/5 text-[#132F4C] text-xs font-bold py-2 rounded-xl transition-all"
              >
                {r.status === 'ACTIVE' ? 'Deaktiv qilish' : 'Faollashtirish'}
              </button>
              {r.id !== 1 && (
                <button
                  onClick={() => handleDelete(r.id)}
                  className="bg-red-50 hover:bg-red-100 text-red-600 text-xs font-bold px-3 py-2 rounded-xl transition-all"
                >
                  🗑️
                </button>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Add Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
          <div className="bg-white max-w-md w-full rounded-2xl p-6 shadow-2xl border border-gray-100 space-y-6">
            <div className="flex justify-between items-center border-b border-gray-100 pb-3">
              <h3 className="text-lg font-bold text-[#132F4C]">Yangi hudud qo'shish</h3>
              <button onClick={() => setShowAddModal(false)} className="text-gray-400 hover:text-gray-600 text-lg">✕</button>
            </div>

            <form onSubmit={handleAddRegion} className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase block">Shahar Nomi *</label>
                <input
                  type="text"
                  required
                  placeholder="Masalan: Buxoro, Samarqand"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C]"
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase block">Holati</label>
                <select
                  value={newStatus}
                  onChange={(e) => setNewStatus(e.target.value as any)}
                  className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C]"
                >
                  <option value="SOON">Tez orada (Soon)</option>
                  <option value="ACTIVE">Faol (Active)</option>
                </select>
              </div>

              <div className="flex gap-3 justify-end pt-3">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-4 py-2 text-sm font-semibold text-gray-500 hover:bg-gray-100 rounded-xl"
                >
                  Bekor qilish
                </button>
                <button
                  type="submit"
                  className="bg-[#132F4C] hover:bg-[#0E2237] text-white text-sm font-bold px-6 py-2 rounded-xl transition-all shadow-md"
                >
                  Qo'shish 🗺️
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
