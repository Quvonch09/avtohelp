'use client';

import React, { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';

interface Master {
  id: string;
  full_name: string;
  phone: string;
  avatar_url: string | null;
  is_verified: boolean;
  is_online: boolean;
  location: any;
  master_profiles: {
    experience_years: number;
    about: string;
    rating_avg: number;
    rating_count: number;
    completed_orders: number;
  } | null;
  master_cars: {
    car_brands: { name: string } | null;
  }[];
  master_services: {
    price: number;
    services: { name: string } | null;
  }[];
}

export default function MastersVerification() {
  const [masters, setMasters] = useState<Master[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'pending' | 'approved' | 'online'>('pending');
  
  // Modals state
  const [showAddModal, setShowAddModal] = useState(false);
  const [showLocModal, setShowLocModal] = useState<Master | null>(null);
  const [showDocModal, setShowDocModal] = useState<Master | null>(null);

  // Forms
  const [newName, setNewName] = useState('');
  const [newPhone, setNewPhone] = useState('+998');
  const [newExp, setNewExp] = useState(2);
  const [newAbout, setNewAbout] = useState('');
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    fetchMasters();
  }, []);

  async function fetchMasters() {
    try {
      setLoading(true);
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'getMasters' }),
      });
      const result = await res.json();
      setMasters(result.data || []);
    } catch (err) {
      console.error('Error fetching masters:', err);
    } finally {
      setLoading(false);
    }
  }

  // Verify master
  async function handleVerify(masterId: string, verify: boolean) {
    try {
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'verifyMaster',
          params: { masterId, verify }
        }),
      });
      const result = await res.json();
      if (result.error) throw new Error(result.error);
      
      // Update local state
      setMasters(masters.map(m => m.id === masterId ? { ...m, is_verified: verify } : m));
    } catch (err: any) {
      alert('Xatolik: ' + err.message);
    }
  }

  // Delete master
  async function handleDelete(masterId: string) {
    if (!confirm('Haqiqatdan ham ushbu ustani o\'chirmoqchimisiz?')) return;
    try {
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'deleteMaster',
          params: { masterId }
        }),
      });
      const result = await res.json();
      if (result.error) throw new Error(result.error);

      setMasters(masters.filter(m => m.id !== masterId));
    } catch (err: any) {
      alert('O\'chirishda xatolik: ' + err.message);
    }
  }

  // Create Usta
  async function handleCreateMaster(e: React.FormEvent) {
    e.preventDefault();
    setActionLoading(true);
    try {
      // 1. Create User in auth (we bypass auth check for demo by creating profile directly)
      // For Super Admin to add master, we can write a custom endpoint or insert in DB
      // We will generate a mock auth ID and register in profiles table
      const mockAuthId = '00000000-0000-0000-0000-' + Math.floor(100000000000 + Math.random() * 900000000000).toString();
      
      // Submit profile and master details
      const response = await supabase.from('profiles').insert({
        id: mockAuthId,
        phone: newPhone.trim(),
        role: 'MASTER',
        full_name: newName.trim(),
        is_verified: true, // auto approve since created by admin
        is_online: false
      });

      if (response.error) throw response.error;

      // Update details
      await supabase.from('master_profiles').update({
        experience_years: newExp,
        about: newAbout.trim()
      }).eq('id', mockAuthId);

      // Add default service (Evakuator) & car brand (Chevrolet) for mock setup
      await supabase.from('master_cars').insert({ master_id: mockAuthId, brand_id: 1 });
      await supabase.from('master_services').insert({ master_id: mockAuthId, service_id: 1, price: 150000 });

      fetchMasters();
      setShowAddModal(false);
      setNewName('');
      setNewPhone('+998');
      setNewExp(2);
      setNewAbout('');
    } catch (err: any) {
      alert('Usta qo\'shishda xatolik: ' + err.message);
    } finally {
      setActionLoading(false);
    }
  }

  // Categorize masters
  const pendingMasters = masters.filter(m => !m.is_verified);
  const approvedMasters = masters.filter(m => m.is_verified);
  const onlineMasters = masters.filter(m => m.is_verified && m.is_online);
  const offlineMasters = masters.filter(m => m.is_verified && !m.is_online);
  const currentMasters = activeTab === 'pending' ? pendingMasters : activeTab === 'approved' ? approvedMasters : [...onlineMasters, ...offlineMasters];

  function renderMasterCard(master: Master) {
    const profile = master.master_profiles || {
      experience_years: 0,
      about: '',
      rating_avg: 0,
      rating_count: 0,
      completed_orders: 0
    };
    const mockBalance = (getStringHashCode(master.id) % 10) * 45000 + 120000;

    return (
      <div
        key={master.id}
        className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm flex flex-col justify-between gap-6 hover:shadow-md transition-all"
      >
        <div className="space-y-4">
          {/* Basic user info card */}
          <div className="flex items-start justify-between">
            <div className="flex gap-4">
              <div className="relative">
                <div className="w-14 h-14 rounded-full bg-[#132F4C]/5 text-[#132F4C] flex items-center justify-center font-bold text-xl border border-gray-100">
                  {master.full_name ? master.full_name.charAt(0) : 'U'}
                </div>
                <span className={`absolute -bottom-0.5 -right-0.5 w-4 h-4 rounded-full border-2 border-white ${
                  master.is_online ? 'bg-emerald-500' : 'bg-gray-300'
                }`}></span>
              </div>
              <div>
                <h3 className="text-lg font-bold text-[#132F4C]">{master.full_name}</h3>
                <p className="text-sm font-semibold text-gray-400">{master.phone || 'Telefon raqamsiz'}</p>
                <div className="flex items-center gap-3 mt-1.5">
                  <span className="text-[11px] bg-indigo-50 text-indigo-700 font-bold px-2.5 py-0.5 rounded-full">
                    Tajriba: {profile.experience_years} yil
                  </span>
                  <span className={`text-[11px] font-bold px-2.5 py-0.5 rounded-full ${
                    master.is_online ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-500'
                  }`}>
                    {master.is_online ? '🟢 Online' : '⚫ Offline'}
                  </span>
                </div>
              </div>
            </div>
            
            {/* Rating display */}
            <div className="flex flex-col items-end">
              <div className="flex items-center gap-1 text-amber-500 font-bold">
                <span>★</span>
                <span>{profile.rating_avg.toFixed(1)}</span>
              </div>
              <span className="text-[10px] text-gray-400 font-semibold">({profile.rating_count} ta baho)</span>
            </div>
          </div>

          {/* Bio */}
          {profile.about && (
            <div className="text-xs text-gray-600 bg-gray-50 p-3 rounded-xl border border-gray-100/50">
              <span className="font-bold text-[10px] text-gray-400 block mb-0.5">MA'LUMOT:</span>
              {profile.about}
            </div>
          )}

          {/* Brands & Services */}
          <div className="grid grid-cols-2 gap-4 pt-2">
            <div>
              <span className="text-[10px] font-bold text-gray-400 uppercase tracking-wider block mb-1">Brendlar</span>
              <div className="flex flex-wrap gap-1">
                {master.master_cars?.map((c, i) => (
                  <span key={i} className="text-[10px] bg-[#F5F7FB] text-[#132F4C] px-2 py-0.5 rounded border border-gray-100 font-semibold">
                    {c.car_brands?.name}
                  </span>
                ))}
              </div>
            </div>
            <div>
              <span className="text-[10px] font-bold text-gray-400 uppercase tracking-wider block mb-1">Asosiy xizmat</span>
              <span className="text-xs font-bold text-[#132F4C]">
                {master.master_services?.[0]?.services?.name || 'Yo\'l yordami'}
              </span>
            </div>
          </div>

          {/* Financial Stats */}
          <div className="grid grid-cols-2 gap-4 border-t border-gray-100 pt-3 text-xs">
            <div>
              <span className="text-gray-400 font-semibold">Balansi:</span>
              <span className="font-bold text-[#132F4C] block text-sm mt-0.5">{mockBalance.toLocaleString()} UZS</span>
            </div>
            <div>
              <span className="text-gray-400 font-semibold">Bajarilgan ishlar:</span>
              <span className="font-bold text-emerald-600 block text-sm mt-0.5">{profile.completed_orders} ta</span>
            </div>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex gap-2 border-t border-gray-50 pt-4 mt-2">
          {master.is_verified ? (
            <button
              onClick={() => handleVerify(master.id, false)}
              className="flex-1 bg-amber-50 hover:bg-amber-100 text-amber-700 text-xs font-bold py-2 rounded-xl transition-all"
            >
              🚫 Bloklash
            </button>
          ) : (
            <button
              onClick={() => handleVerify(master.id, true)}
              className="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold py-2 rounded-xl shadow-sm transition-all"
            >
              ✅ Tasdiqlash
            </button>
          )}

          <button
            onClick={() => setShowDocModal(master)}
            className="bg-[#F5F7FB] hover:bg-[#132F4C]/5 text-[#132F4C] text-xs font-bold px-3 py-2 rounded-xl transition-all"
          >
            📄 Hujjatlari
          </button>

          <button
            onClick={() => setShowLocModal(master)}
            className="bg-[#F5F7FB] hover:bg-[#132F4C]/5 text-indigo-600 text-xs font-bold px-3 py-2 rounded-xl transition-all"
          >
            📍 Joylashuvi
          </button>

          <button
            onClick={() => handleDelete(master.id)}
            className="bg-red-50 hover:bg-red-100 text-red-600 text-xs font-bold px-3 py-2 rounded-xl transition-all"
          >
            🗑️
          </button>
        </div>
      </div>
    );
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
      {/* Header Block */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-3xl font-extrabold tracking-tight text-[#132F4C]">Ustalar boshqaruvi</h1>
          <p className="text-gray-500 mt-1">Platformadagi barcha ro'yxatdan o'tgan ustalar va ularning arizalari</p>
        </div>

        <button
          onClick={() => setShowAddModal(true)}
          className="bg-[#132F4C] hover:bg-[#0E2237] text-white text-sm font-bold px-4 py-3 rounded-xl shadow-md transition-all flex items-center gap-2"
        >
          <span>➕</span> Yangi usta qo'shish
        </button>
      </div>

      {/* Online/Offline Summary Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-emerald-100 flex items-center justify-center text-emerald-600 font-bold text-lg">🟢</div>
          <div>
            <div className="text-[11px] text-gray-400 font-semibold uppercase tracking-wider">Online</div>
            <div className="text-2xl font-extrabold text-emerald-600">{onlineMasters.length}</div>
          </div>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center text-gray-400 font-bold text-lg">⚫</div>
          <div>
            <div className="text-[11px] text-gray-400 font-semibold uppercase tracking-wider">Offline</div>
            <div className="text-2xl font-extrabold text-gray-500">{offlineMasters.length}</div>
          </div>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-bold text-lg">✅</div>
          <div>
            <div className="text-[11px] text-gray-400 font-semibold uppercase tracking-wider">Tasdiqlangan</div>
            <div className="text-2xl font-extrabold text-blue-600">{approvedMasters.length}</div>
          </div>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-amber-100 flex items-center justify-center text-amber-600 font-bold text-lg">⏳</div>
          <div>
            <div className="text-[11px] text-gray-400 font-semibold uppercase tracking-wider">Kutilmoqda</div>
            <div className="text-2xl font-extrabold text-amber-600">{pendingMasters.length}</div>
          </div>
        </div>
      </div>

      {/* Tabs Menu */}
      <div className="flex border-b border-gray-200">
        <button
          onClick={() => setActiveTab('pending')}
          className={`px-6 py-3 font-bold text-sm border-b-2 transition-all ${
            activeTab === 'pending'
              ? 'border-[#132F4C] text-[#132F4C]'
              : 'border-transparent text-gray-400 hover:text-gray-600'
          }`}
        >
          ⏳ Kutilayotganlar ({pendingMasters.length})
        </button>
        <button
          onClick={() => setActiveTab('approved')}
          className={`px-6 py-3 font-bold text-sm border-b-2 transition-all ${
            activeTab === 'approved'
              ? 'border-[#132F4C] text-[#132F4C]'
              : 'border-transparent text-gray-400 hover:text-gray-600'
          }`}
        >
          ✅ Tasdiqlangan ({approvedMasters.length})
        </button>
        <button
          onClick={() => setActiveTab('online')}
          className={`px-6 py-3 font-bold text-sm border-b-2 transition-all ${
            activeTab === 'online'
              ? 'border-emerald-500 text-emerald-600'
              : 'border-transparent text-gray-400 hover:text-gray-600'
          }`}
        >
          🟢 Band / Bo'sh ({onlineMasters.length} / {offlineMasters.length})
        </button>
      </div>

      {/* Masters List */}
      {activeTab === 'online' ? (
        <div className="space-y-8">
          {/* Online Masters Section */}
          <div>
            <div className="flex items-center gap-2 mb-4">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse inline-block"></span>
              <h3 className="text-sm font-extrabold text-emerald-700 uppercase tracking-wider">
                Online — Band ustalar ({onlineMasters.length})
              </h3>
            </div>
            {onlineMasters.length === 0 ? (
              <div className="bg-white border border-gray-100 rounded-2xl p-10 text-center text-gray-400 shadow-sm text-sm">
                Hozirda online usta yo'q.
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {onlineMasters.map(master => renderMasterCard(master))}
              </div>
            )}
          </div>
          {/* Offline Masters Section */}
          <div>
            <div className="flex items-center gap-2 mb-4">
              <span className="w-2.5 h-2.5 rounded-full bg-gray-400 inline-block"></span>
              <h3 className="text-sm font-extrabold text-gray-500 uppercase tracking-wider">
                Offline — Bo'sh ustalar ({offlineMasters.length})
              </h3>
            </div>
            {offlineMasters.length === 0 ? (
              <div className="bg-white border border-gray-100 rounded-2xl p-10 text-center text-gray-400 shadow-sm text-sm">
                Hozirda offline usta yo'q.
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {offlineMasters.map(master => renderMasterCard(master))}
              </div>
            )}
          </div>
        </div>
      ) : currentMasters.length === 0 ? (
        <div className="bg-white border border-gray-100 rounded-2xl p-16 text-center text-gray-400 shadow-sm">
          🔍 Bu bo'limda ustalar mavjud emas.
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {currentMasters.map(master => renderMasterCard(master))}
        </div>
      )}

      {/* CRUD Modal: Add Master */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
          <div className="bg-white max-w-md w-full rounded-2xl p-6 shadow-2xl border border-gray-100 space-y-6">
            <div className="flex justify-between items-center border-b border-gray-100 pb-3">
              <h3 className="text-lg font-bold text-[#132F4C]">Usta qo'shish (Registratsiya)</h3>
              <button onClick={() => setShowAddModal(false)} className="text-gray-400 hover:text-gray-600 text-lg">✕</button>
            </div>

            <form onSubmit={handleCreateMaster} className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider block">To'liq ismi *</label>
                <input
                  type="text"
                  required
                  placeholder="Masalan: Olimov Botir"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C]"
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider block">Telefon raqam *</label>
                <input
                  type="text"
                  required
                  placeholder="+998991234567"
                  value={newPhone}
                  onChange={(e) => setNewPhone(e.target.value)}
                  className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C]"
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider block">Ish tajribasi (yil) *</label>
                <input
                  type="number"
                  required
                  value={newExp}
                  onChange={(e) => setNewExp(Number(e.target.value))}
                  className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C]"
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-500 uppercase tracking-wider block">O'zi haqida (bio)</label>
                <textarea
                  placeholder="Xizmat ko'rsatish yo'nalishi va tajribalar haqida yozing..."
                  value={newAbout}
                  onChange={(e) => setNewAbout(e.target.value)}
                  className="w-full bg-[#F5F7FB] border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C] h-20"
                />
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
                  disabled={actionLoading}
                  className="bg-[#132F4C] hover:bg-[#0E2237] text-white text-sm font-bold px-6 py-2 rounded-xl transition-all shadow-md"
                >
                  {actionLoading ? 'Saqlanmoqda...' : 'Saqlash 💾'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Document Verification Mock */}
      {showDocModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
          <div className="bg-white max-w-md w-full rounded-2xl p-6 shadow-2xl border border-gray-100 space-y-6">
            <div className="flex justify-between items-center border-b border-gray-100 pb-3">
              <h3 className="text-lg font-bold text-[#132F4C]">Usta hujjatlarini tekshirish</h3>
              <button onClick={() => setShowDocModal(null)} className="text-gray-400 hover:text-gray-600 text-lg">✕</button>
            </div>

            <div className="space-y-4">
              <div className="space-y-1">
                <div className="text-xs font-bold text-gray-400 uppercase">Usta ismi:</div>
                <div className="font-bold text-[#132F4C] text-sm">{showDocModal.full_name}</div>
              </div>

              {/* Passport Mock */}
              <div className="border border-gray-200 rounded-xl p-4 bg-gray-50 space-y-2">
                <div className="text-xs font-bold text-gray-500 flex justify-between">
                  <span>passport_copy_scan.jpg</span>
                  <span className="text-emerald-600 font-bold">Yuklangan ✅</span>
                </div>
                <div className="w-full h-32 bg-gray-200 rounded-lg flex items-center justify-center text-gray-400 text-xs border border-dashed border-gray-300 font-bold uppercase">
                  Passport Scan Mockup
                </div>
              </div>

              {/* Driver's License Mock */}
              <div className="border border-gray-200 rounded-xl p-4 bg-gray-50 space-y-2">
                <div className="text-xs font-bold text-gray-500 flex justify-between">
                  <span>driver_license_front.jpg</span>
                  <span className="text-emerald-600 font-bold">Yuklangan ✅</span>
                </div>
                <div className="w-full h-32 bg-gray-200 rounded-lg flex items-center justify-center text-gray-400 text-xs border border-dashed border-gray-300 font-bold uppercase">
                  Haydovchilik guvohnomasi Mockup
                </div>
              </div>
            </div>

            <div className="flex justify-end border-t border-gray-100 pt-3">
              <button
                onClick={() => setShowDocModal(null)}
                className="px-4 py-2 text-sm font-semibold text-gray-500 hover:bg-gray-100 rounded-xl"
              >
                Yopish
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: Usta Location Mock */}
      {showLocModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
          <div className="bg-white max-w-lg w-full rounded-2xl p-6 shadow-2xl border border-gray-100 space-y-6">
            <div className="flex justify-between items-center border-b border-gray-100 pb-3">
              <h3 className="text-lg font-bold text-[#132F4C]">Usta joylashuvi live</h3>
              <button onClick={() => setShowLocModal(null)} className="text-gray-400 hover:text-gray-600 text-lg">✕</button>
            </div>

            <div className="space-y-2">
              <div className="text-sm font-semibold text-gray-600">
                Usta: <span className="font-bold text-[#132F4C]">{showLocModal.full_name}</span>
              </div>
              <div className="text-xs text-gray-400 font-medium">
                Oxirgi koordinatalari: Lat: 38.8612, Lng: 65.7847 (Qarshi shahri)
              </div>
            </div>

            {/* Static Simulated Map Container */}
            <div className="w-full h-64 bg-gray-100 border border-gray-200 rounded-xl relative flex items-center justify-center overflow-hidden">
              <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(19,47,76,0.03)_0,transparent_75%)]"></div>
              {/* Grid representation */}
              <div className="absolute inset-0 bg-[linear-gradient(to_right,#e5e7eb_1px,transparent_1px),linear-gradient(to_bottom,#e5e7eb_1px,transparent_1px)] bg-[size:40px_40px] opacity-40"></div>
              
              {/* Usta Dot */}
              <div className="absolute w-4 h-4 bg-emerald-500 rounded-full flex items-center justify-center shadow-lg">
                <span className="absolute w-8 h-8 rounded-full border border-emerald-400 animate-ping"></span>
              </div>
              
              <div className="absolute bottom-3 left-3 bg-white px-2 py-1 rounded text-[10px] font-bold text-[#132F4C] border border-gray-100">
                Usta online holatda
              </div>
            </div>

            <div className="flex justify-end pt-2 border-t border-gray-100">
              <button
                onClick={() => setShowLocModal(null)}
                className="px-4 py-2 text-sm font-semibold text-gray-500 hover:bg-gray-100 rounded-xl"
              >
                Yopish
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// Helper hashing function for random balances
function getStringHashCode(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = str.charCodeAt(i) + ((hash << 5) - hash);
  }
  return Math.abs(hash);
}
