'use client';

import React, { useState, useEffect } from 'react';

interface Brand {
  id: number;
  name: string;
  logo_url: string | null;
}

interface Model {
  id: number;
  brand_id: number;
  name: string;
}

export default function CarsCrud() {
  const [brands, setBrands] = useState<Brand[]>([]);
  const [models, setModels] = useState<Model[]>([]);
  const [selectedBrandId, setSelectedBrandId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);

  // Forms
  const [newBrandName, setNewBrandName] = useState('');
  const [newBrandLogo, setNewBrandLogo] = useState('');
  const [newModelName, setNewModelName] = useState('');
  const [savingBrand, setSavingBrand] = useState(false);
  const [savingModel, setSavingModel] = useState(false);

  useEffect(() => {
    fetchBrandsAndModels();
  }, []);

  async function fetchBrandsAndModels() {
    try {
      setLoading(true);
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'getBrandsAndModels' }),
      });
      const result = await res.json();
      const bData = result.brands || [];
      const mData = result.models || [];
      
      setBrands(bData);
      setModels(mData);
      
      if (bData.length > 0 && selectedBrandId === null) {
        setSelectedBrandId(bData[0].id);
      }
    } catch (err) {
      console.error('Error fetching brands/models:', err);
    } finally {
      setLoading(false);
    }
  }

  async function handleAddBrand() {
    if (!newBrandName.trim()) return;
    setSavingBrand(true);

    try {
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'saveBrand',
          params: { name: newBrandName.trim(), logoUrl: newBrandLogo.trim() }
        }),
      });
      const result = await res.json();
      if (result.error) throw new Error(result.error);

      // Refresh list
      fetchBrandsAndModels();
      setNewBrandName('');
      setNewBrandLogo('');
      if (result.data) {
        setSelectedBrandId(result.data.id);
      }
    } catch (err: any) {
      alert('Brend qo\'shishda xatolik: ' + err.message);
    } finally {
      setSavingBrand(false);
    }
  }

  async function handleDeleteBrand(id: number) {
    if (!confirm('Haqiqatdan ham ushbu brendni o\'chirmoqchimisiz? (Barcha modellar o\'chib ketadi)')) return;

    try {
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'deleteBrand',
          params: { id }
        }),
      });
      const result = await res.json();
      if (result.error) throw new Error(result.error);

      setBrands(brands.filter(b => b.id !== id));
      if (selectedBrandId === id) {
        setSelectedBrandId(brands.length > 1 ? brands.find(b => b.id !== id)!.id : null);
      }
    } catch (err: any) {
      alert('O\'chirishda xatolik: ' + err.message);
    }
  }

  async function handleAddModel() {
    if (!newModelName.trim() || selectedBrandId === null) return;
    setSavingModel(true);

    try {
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'saveModel',
          params: { brandId: selectedBrandId, name: newModelName.trim() }
        }),
      });
      const result = await res.json();
      if (result.error) throw new Error(result.error);

      fetchBrandsAndModels();
      setNewModelName('');
    } catch (err: any) {
      alert('Model qo\'shishda xatolik: ' + err.message);
    } finally {
      setSavingModel(false);
    }
  }

  async function handleDeleteModel(id: number) {
    if (!confirm('Ushbu modelni o\'chirmoqchimisiz?')) return;

    try {
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'deleteModel',
          params: { id }
        }),
      });
      const result = await res.json();
      if (result.error) throw new Error(result.error);

      setModels(models.filter(m => m.id !== id));
    } catch (err: any) {
      alert('O\'chirishda xatolik: ' + err.message);
    }
  }

  if (loading) {
    return (
      <div className="flex-1 flex items-center justify-center min-h-[400px]">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-[#132F4C] border-t-transparent"></div>
      </div>
    );
  }

  const activeModels = models.filter(m => m.brand_id === selectedBrandId);

  return (
    <div className="space-y-8 font-sans">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-extrabold tracking-tight text-[#132F4C]">Avtomobillar sozlamalari</h1>
        <p className="text-gray-500 mt-1">Platformadagi avto brendlar va modellarni boshqarish (CRUD)</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Brands Column */}
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm space-y-6">
          <h2 className="text-lg font-bold text-[#132F4C]">🚗 Brendlar ({brands.length})</h2>
          
          {/* Add brand form */}
          <div className="space-y-3 p-4 bg-[#F5F7FB] rounded-xl border border-gray-200/50">
            <input
              type="text"
              placeholder="Brend nomi (masalan: BYD)"
              value={newBrandName}
              onChange={(e) => setNewBrandName(e.target.value)}
              className="w-full bg-white border border-gray-200 rounded-lg px-3 py-2 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C]"
            />
            <input
              type="text"
              placeholder="Logo URL (ixtiyoriy)"
              value={newBrandLogo}
              onChange={(e) => setNewBrandLogo(e.target.value)}
              className="w-full bg-white border border-gray-200 rounded-lg px-3 py-2 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C]"
            />
            <button
              onClick={handleAddBrand}
              disabled={savingBrand}
              className="w-full bg-[#132F4C] hover:bg-[#0E2237] text-white font-bold py-2 rounded-lg text-sm transition-all shadow-md"
            >
              {savingBrand ? 'Qo\'shilmoqda...' : '+ Brend qo\'shish'}
            </button>
          </div>

          {/* Brands List */}
          <div className="space-y-2 max-h-96 overflow-y-auto pr-2">
            {brands.map(b => (
              <div
                key={b.id}
                onClick={() => setSelectedBrandId(b.id)}
                className={`flex justify-between items-center p-3 rounded-xl cursor-pointer transition-all border ${
                  selectedBrandId === b.id
                    ? 'bg-[#132F4C] text-white border-transparent shadow-md'
                    : 'bg-white border-gray-100 hover:bg-[#F5F7FB] text-gray-700'
                }`}
              >
                <span className="font-bold text-sm">{b.name}</span>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    handleDeleteBrand(b.id);
                  }}
                  className={`p-1 rounded hover:bg-black/10 transition-colors ${
                    selectedBrandId === b.id ? 'text-white' : 'text-red-500'
                  }`}
                >
                  🗑️
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* Models Column */}
        <div className="lg:col-span-2 bg-white border border-gray-100 rounded-2xl p-6 shadow-sm space-y-6">
          <h2 className="text-lg font-bold text-[#132F4C]">
            ⚙️ Modellari ({brands.find(b => b.id === selectedBrandId)?.name || 'Tanlanmagan'})
          </h2>

          {selectedBrandId === null ? (
            <div className="text-center text-gray-400 py-16">Iltimos, chap tomondan brend tanlang.</div>
          ) : (
            <div className="space-y-6">
              {/* Add model form */}
              <div className="flex gap-3 bg-[#F5F7FB] p-4 rounded-xl border border-gray-200/50">
                <input
                  type="text"
                  placeholder="Model nomi (masalan: Song Plus)"
                  value={newModelName}
                  onChange={(e) => setNewModelName(e.target.value)}
                  className="flex-1 bg-white border border-gray-200 rounded-lg px-3 py-2 text-sm text-[#132F4C] focus:outline-none focus:border-[#132F4C]"
                />
                <button
                  onClick={handleAddModel}
                  disabled={savingModel}
                  className="bg-[#132F4C] hover:bg-[#0E2237] text-white font-bold px-6 py-2 rounded-lg text-sm transition-all shadow-md"
                >
                  {savingModel ? 'Qo\'shilmoqda...' : '+ Model qo\'shish'}
                </button>
              </div>

              {/* Models List */}
              {activeModels.length === 0 ? (
                <div className="text-center text-gray-400 py-16">Ushbu brend uchun modellar qo'shilmagan.</div>
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {activeModels.map(m => (
                    <div
                      key={m.id}
                      className="border border-gray-100 p-3.5 rounded-xl flex justify-between items-center hover:border-gray-200 transition-all bg-white shadow-sm"
                    >
                      <span className="text-[#132F4C] font-bold text-sm">{m.name}</span>
                      <button
                        onClick={() => handleDeleteModel(m.id)}
                        className="text-red-500 hover:text-red-700 p-1 text-xs font-bold"
                      >
                        🗑️ O'chirish
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
