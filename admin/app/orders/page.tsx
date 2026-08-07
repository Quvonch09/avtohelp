'use client';

import React, { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';

interface Order {
  id: string;
  created_at: string;
  status: string;
  price: number;
  user_address: string;
  profiles_user: { full_name: string; phone: string } | null;
  profiles_master: { full_name: string; phone: string } | null;
  services: { name: string } | null;
}

interface Master {
  id: string;
  full_name: string;
  phone: string;
  is_online: boolean;
  is_verified: boolean;
}

export default function OrdersLive() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [masters, setMasters] = useState<Master[]>([]);
  const [loading, setLoading] = useState(true);
  
  // Filters
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [serviceFilter, setServiceFilter] = useState('ALL');
  
  // Assign modal state
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
  const [assigning, setAssigning] = useState(false);

  // Radar simulation coordinates
  const [simulatedCoord, setSimulatedCoord] = useState({ lat: 38.8612, lng: 65.7847 });

  useEffect(() => {
    fetchData();

    // Subscribe to order changes (realtime)
    const channel = supabase
      .channel('schema-db-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'orders' },
        () => {
          fetchData();
        }
      )
      .subscribe();

    // Radar coordinate simulation
    const interval = setInterval(() => {
      setSimulatedCoord(prev => ({
        lat: prev.lat + (Math.random() - 0.5) * 0.0008,
        lng: prev.lng + (Math.random() - 0.5) * 0.0008,
      }));
    }, 4000);

    return () => {
      supabase.removeChannel(channel);
      clearInterval(interval);
    };
  }, []);

  async function fetchData() {
    try {
      // Fetch orders via server-side API
      const ordersRes = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'getOrders' }),
      });
      const ordersData = await ordersRes.json();
      setOrders(ordersData.data || []);

      // Fetch masters for assigning
      const mastersRes = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'getMasters' }),
      });
      const mastersData = await mastersRes.json();
      setMasters(mastersData.data || []);
    } catch (err) {
      console.error('Error fetching data:', err);
    } finally {
      setLoading(false);
    }
  }

  // Filter orders
  const filteredOrders = orders.filter(o => {
    const matchStatus = statusFilter === 'ALL' || o.status === statusFilter;
    const matchService = serviceFilter === 'ALL' || (o.services && o.services.name === serviceFilter);
    return matchStatus && matchService;
  });

  // Extract unique services for the filter dropdown
  const uniqueServices = Array.from(
    new Set(orders.map(o => o.services?.name).filter(Boolean))
  ) as string[];

  // Assign master handler
  async function handleAssignMaster(masterId: string | null) {
    if (!selectedOrder) return;
    setAssigning(true);

    try {
      const res = await fetch('/api/admin-db', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'assignMaster',
          params: { orderId: selectedOrder.id, masterId }
        }),
      });
      const result = await res.json();
      if (result.error) throw new Error(result.error);

      // Refresh list
      fetchData();
      setSelectedOrder(null);
    } catch (err: any) {
      alert('Usta biriktirishda xatolik: ' + err.message);
    } finally {
      setAssigning(false);
    }
  }

  function getStatusStyle(status: string) {
    switch (status) {
      case 'PENDING':
        return 'bg-amber-50 text-amber-700 border-amber-200';
      case 'ACCEPTED':
        return 'bg-blue-50 text-blue-700 border-blue-200';
      case 'ON_WAY':
        return 'bg-cyan-50 text-cyan-700 border-cyan-200';
      case 'ARRIVED':
        return 'bg-indigo-50 text-indigo-700 border-indigo-200';
      case 'DONE':
        return 'bg-emerald-50 text-emerald-700 border-emerald-200';
      case 'CANCELLED':
        return 'bg-red-50 text-red-700 border-red-200';
      default:
        return 'bg-gray-50 text-gray-700 border-gray-200';
    }
  }

  if (loading) {
    return (
      <div className="flex-1 flex items-center justify-center min-h-[400px]">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-[#132F4C] border-t-transparent"></div>
      </div>
    );
  }

  // Get active online masters for assign select
  const onlineMastersList = masters.filter(m => m.is_online && m.is_verified);

  return (
    <div className="space-y-8 font-sans">
      {/* Title Block */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h1 className="text-3xl font-extrabold tracking-tight text-[#132F4C]">Buyurtmalar boshqaruvi</h1>
          <p className="text-gray-500 mt-1">Platformadagi barcha real-time buyurtmalar va monitoring</p>
        </div>

        {/* Filters */}
        <div className="flex flex-wrap gap-3">
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="bg-white border border-gray-200 text-sm font-semibold text-[#132F4C] rounded-xl px-3 py-2.5 shadow-sm focus:outline-none"
          >
            <option value="ALL">Barcha holatlar</option>
            <option value="PENDING">PENDING (Kutilmoqda)</option>
            <option value="ACCEPTED">ACCEPTED (Qabul qilindi)</option>
            <option value="ON_WAY">ON_WAY (Yo'lda)</option>
            <option value="ARRIVED">ARRIVED (Ish boshlandi)</option>
            <option value="DONE">DONE (Tugallandi)</option>
            <option value="CANCELLED">CANCELLED (Bekor qilindi)</option>
          </select>

          <select
            value={serviceFilter}
            onChange={(e) => setServiceFilter(e.target.value)}
            className="bg-white border border-gray-200 text-sm font-semibold text-[#132F4C] rounded-xl px-3 py-2.5 shadow-sm focus:outline-none"
          >
            <option value="ALL">Barcha xizmatlar</option>
            {uniqueServices.map(name => (
              <option key={name} value={name}>{name}</option>
            ))}
          </select>
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
        {/* Table Column */}
        <div className="xl:col-span-2 bg-white border border-gray-100 rounded-2xl p-6 shadow-sm space-y-6">
          <h2 className="text-lg font-bold text-[#132F4C]">📋 Buyurtmalar ro'yxati ({filteredOrders.length} ta)</h2>

          {filteredOrders.length === 0 ? (
            <div className="text-center text-gray-400 py-16">🔍 Hech qanday buyurtma topilmadi.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm text-left text-gray-700">
                <thead className="text-xs uppercase bg-[#F5F7FB] text-gray-500 font-bold border-b border-gray-100">
                  <tr>
                    <th className="px-4 py-3">Mijoz / Mashina</th>
                    <th className="px-4 py-3">Xizmat va Narx</th>
                    <th className="px-4 py-3">Usta</th>
                    <th className="px-4 py-3">Holati</th>
                    <th className="px-4 py-3 text-right">Amallar</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {filteredOrders.map(o => (
                    <tr key={o.id} className="hover:bg-gray-50/50 transition-colors">
                      <td className="px-4 py-3">
                        <div className="font-semibold text-[#132F4C]">{o.profiles_user?.full_name || 'Mijoz'}</div>
                        <div className="text-xs text-gray-400">{o.profiles_user?.phone}</div>
                        <div className="text-xs text-gray-500 mt-1 italic">{o.user_address || 'Qarshi sh.'}</div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="font-bold text-[#132F4C]">{o.services?.name || 'Yo\'l yordami'}</div>
                        <div className="text-xs font-semibold text-emerald-600 mt-0.5">{o.price.toLocaleString()} UZS</div>
                      </td>
                      <td className="px-4 py-3">
                        {o.profiles_master ? (
                          <div>
                            <div className="font-semibold text-[#132F4C]">{o.profiles_master.full_name}</div>
                            <div className="text-xs text-gray-400">{o.profiles_master.phone}</div>
                          </div>
                        ) : (
                          <span className="text-xs font-semibold text-red-500 bg-red-50 px-2 py-1 rounded-md">
                            Tayinlanmagan
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        <span className={`px-2.5 py-1 rounded-full text-xs font-semibold border ${getStatusStyle(o.status)}`}>
                          {o.status}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right">
                        {(o.status === 'PENDING' || o.status === 'ACCEPTED') && (
                          <button
                            onClick={() => setSelectedOrder(o)}
                            className="bg-[#132F4C] hover:bg-[#0E2237] text-white text-xs font-bold px-3 py-2 rounded-xl transition-all"
                          >
                            Ustani biriktirish 🛠️
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Live Simulation Radar Map */}
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm flex flex-col justify-between space-y-6">
          <div>
            <h2 className="text-lg font-bold text-[#132F4C]">📡 Live Radar Monitor</h2>
            <p className="text-xs text-gray-500 mt-1">Qarshi shahridagi faol buyurtmalar va online ustalar nuqtalari</p>
          </div>

          {/* Interactive Simulation Container */}
          <div className="relative w-full h-80 bg-gray-50 rounded-2xl border border-gray-100 flex items-center justify-center overflow-hidden">
            {/* Sweep radar lines */}
            <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(19,47,76,0.06)_0,transparent_75%)]"></div>
            <div className="absolute w-72 h-72 rounded-full border border-gray-200/60 flex items-center justify-center animate-pulse">
              <div className="w-48 h-48 rounded-full border border-gray-200/80 flex items-center justify-center">
                <div className="w-24 h-24 rounded-full border border-gray-200"></div>
              </div>
            </div>

            {/* Sweep animation line */}
            <div className="absolute w-full h-0.5 bg-gradient-to-r from-transparent via-[#132F4C]/20 to-transparent top-1/2 left-0 transform -translate-y-1/2 rotate-0 animate-[spin_8s_linear_infinite]"></div>

            {/* Master marker (Online - simulated displacement) */}
            <div
              className="absolute w-4 h-4 bg-emerald-500 rounded-full flex items-center justify-center shadow-[0_0_12px_rgba(16,185,129,0.8)] transition-all duration-[3000ms] ease-out"
              style={{
                transform: `translate(${(simulatedCoord.lng - 65.7847) * 70000}px, ${(simulatedCoord.lat - 38.8612) * 70000}px)`,
              }}
            >
              <span className="absolute w-8 h-8 rounded-full border border-emerald-400/40 animate-ping"></span>
            </div>

            {/* Client order marker (Center) */}
            <div className="absolute w-3 h-3 bg-indigo-600 rounded-full shadow-[0_0_8px_rgba(79,70,229,0.8)]">
              <span className="absolute -top-6 -left-8 bg-white border border-gray-100 text-[9px] font-bold text-[#132F4C] px-1.5 py-0.5 rounded shadow-sm">
                Mijoz (Qarshi)
              </span>
            </div>

            {/* Location tag */}
            <div className="absolute bottom-4 left-4 bg-white/95 border border-gray-100 px-3 py-1.5 rounded-xl text-[9px] text-gray-500 shadow-sm font-semibold">
              Usta Lat: {simulatedCoord.lat.toFixed(5)} <br />
              Usta Lng: {simulatedCoord.lng.toFixed(5)}
            </div>
          </div>

          <div className="bg-[#F5F7FB] p-4 rounded-xl text-xs text-gray-500 space-y-2">
            <div className="flex justify-between font-medium">
              <span>Faol monitoring shahri:</span>
              <span className="text-[#132F4C] font-bold">Qarshi</span>
            </div>
            <div className="flex justify-between font-medium">
              <span>Geospatial so'rov:</span>
              <span className="text-[#132F4C] font-bold">PostGIS (ST_DWithin 3km)</span>
            </div>
          </div>
        </div>
      </div>

      {/* Manual Assign Master Modal */}
      {selectedOrder && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
          <div className="bg-white max-w-md w-full rounded-2xl p-6 shadow-2xl border border-gray-100 space-y-6 transform scale-100 transition-all">
            <div className="flex justify-between items-center">
              <h3 className="text-lg font-bold text-[#132F4C]">Usta biriktirish</h3>
              <button
                onClick={() => setSelectedOrder(null)}
                className="text-gray-400 hover:text-gray-600 text-lg"
              >
                ✕
              </button>
            </div>

            <div className="bg-[#F5F7FB] p-4 rounded-xl space-y-1">
              <div className="text-xs font-bold text-gray-500 uppercase">Mijoz so'rovi</div>
              <div className="font-bold text-[#132F4C]">{selectedOrder.services?.name}</div>
              <div className="text-xs text-gray-500">{selectedOrder.user_address}</div>
            </div>

            <div className="space-y-3">
              <label className="text-xs font-bold text-gray-400 uppercase tracking-wider block">
                Online bo'lgan faol ustalar ({onlineMastersList.length})
              </label>

              {onlineMastersList.length === 0 ? (
                <div className="text-center text-sm text-red-500 bg-red-50 p-4 rounded-xl font-medium">
                  ⚠️ Hozirda online bo'lgan faol ustalar topilmadi.
                </div>
              ) : (
                <div className="space-y-2 max-h-48 overflow-y-auto pr-1">
                  {onlineMastersList.map(master => (
                    <button
                      key={master.id}
                      disabled={assigning}
                      onClick={() => handleAssignMaster(master.id)}
                      className="w-full text-left bg-[#F5F7FB] hover:bg-[#132F4C]/5 border border-transparent hover:border-[#132F4C]/10 p-3 rounded-xl flex justify-between items-center transition-all"
                    >
                      <div>
                        <div className="font-bold text-[#132F4C]">{master.full_name}</div>
                        <div className="text-xs text-gray-500">{master.phone}</div>
                      </div>
                      <span className="text-[10px] bg-emerald-100 text-emerald-700 font-bold px-2 py-0.5 rounded-full">
                        Online
                      </span>
                    </button>
                  ))}
                </div>
              )}
            </div>

            <div className="flex gap-3 justify-end pt-2">
              <button
                onClick={() => setSelectedOrder(null)}
                className="px-4 py-2 text-sm font-semibold text-gray-500 hover:bg-gray-100 rounded-xl transition-all"
              >
                Bekor qilish
              </button>
              {selectedOrder.profiles_master && (
                <button
                  onClick={() => handleAssignMaster(null)}
                  disabled={assigning}
                  className="px-4 py-2 text-sm font-semibold text-red-600 bg-red-50 hover:bg-red-100 rounded-xl transition-all"
                >
                  Ustani olib tashlash
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
