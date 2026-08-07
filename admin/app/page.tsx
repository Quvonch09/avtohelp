'use client';

import React, { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, LineChart, Line } from 'recharts';

export default function Dashboard() {
  const [stats, setStats] = useState({
    activeUsers: 0,
    onlineMasters: 0,
    totalOrders: 0,
    todayEarnings: 0,
  });
  const [loading, setLoading] = useState(true);

  // Weekly analytics mock data
  const chartData = [
    { name: 'Dushanba', orders: 12, revenue: 1200000 },
    { name: 'Seshanba', orders: 19, revenue: 2100000 },
    { name: 'Chorshanba', orders: 15, revenue: 1500000 },
    { name: 'Payshanba', orders: 22, revenue: 2900000 },
    { name: 'Juma', orders: 30, revenue: 4500000 },
    { name: 'Shanba', orders: 45, revenue: 6800000 },
    { name: 'Yakshanba', orders: 25, revenue: 3200000 },
  ];

  useEffect(() => {
    fetchStats();
    
    // Refresh stats every 30 seconds
    const interval = setInterval(fetchStats, 30000);
    return () => clearInterval(interval);
  }, []);

  async function fetchStats() {
    try {
      // 1. Clients count
      const { count: usersCount } = await supabase
        .from('profiles')
        .select('*', { count: 'exact', head: true })
        .eq('role', 'USER');

      // 2. Active online masters count
      const { count: mastersCount } = await supabase
        .from('profiles')
        .select('*', { count: 'exact', head: true })
        .eq('role', 'MASTER')
        .eq('is_online', true);

      // 3. Total orders count
      const { count: ordersCount } = await supabase
        .from('orders')
        .select('*', { count: 'exact', head: true });

      // 4. Daily revenue (Completed orders today)
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const { data: doneOrders } = await supabase
        .from('orders')
        .select('price')
        .eq('status', 'DONE')
        .gte('created_at', today.toISOString());

      const earnings = doneOrders?.reduce((sum, order) => sum + (order.price || 0), 0) || 0;

      setStats({
        activeUsers: usersCount || 0,
        onlineMasters: mastersCount || 0,
        totalOrders: ordersCount || 0,
        todayEarnings: earnings,
      });
    } catch (error) {
      console.error('Error fetching statistics:', error);
    } finally {
      setLoading(false);
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
    <div className="space-y-8 animate-fade-in font-sans">
      {/* Title block */}
      <div>
        <h1 className="text-3xl font-extrabold tracking-tight text-[#132F4C]">Boshqaruv paneli</h1>
        <p className="text-gray-500 mt-1">Avtohelp yo'l yordami xizmati real-time KPI ko'rsatkichlari</p>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        {/* Total Orders */}
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm hover:shadow-md transition-all">
          <div className="text-xs font-bold text-gray-400 uppercase tracking-wider">Jami buyurtmalar</div>
          <div className="text-3xl font-black mt-2 text-[#132F4C]">{stats.totalOrders} ta</div>
          <div className="text-xs text-gray-500 mt-1">Hozirgacha yaratilgan so'rovlar</div>
        </div>

        {/* Active Masters */}
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm hover:shadow-md transition-all">
          <div className="text-xs font-bold text-gray-400 uppercase tracking-wider">Faol ustalar</div>
          <div className="text-3xl font-black mt-2 text-emerald-600">{stats.onlineMasters} ta</div>
          <div className="text-xs text-gray-500 mt-1">Hozir xizmatda va online</div>
        </div>

        {/* Clients Count */}
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm hover:shadow-md transition-all">
          <div className="text-xs font-bold text-gray-400 uppercase tracking-wider">Mijozlar soni</div>
          <div className="text-3xl font-black mt-2 text-[#132F4C]">{stats.activeUsers} nafar</div>
          <div className="text-xs text-gray-500 mt-1">Tizimda ro'yxatdan o'tgan</div>
        </div>

        {/* Daily Revenue */}
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm hover:shadow-md transition-all">
          <div className="text-xs font-bold text-gray-400 uppercase tracking-wider">Kunlik tushum</div>
          <div className="text-3xl font-black mt-2 text-indigo-600">
            {stats.todayEarnings.toLocaleString()} <span className="text-sm font-semibold">UZS</span>
          </div>
          <div className="text-xs text-gray-500 mt-1">Bugun yakunlangan ishlar summasi</div>
        </div>
      </div>

      {/* Charts Section */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Order chart */}
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm">
          <h2 className="text-lg font-bold text-[#132F4C] mb-4">Haftalik buyurtmalar oqimi</h2>
          <div className="h-80 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData}>
                <XAxis dataKey="name" stroke="#94a3b8" fontSize={11} tickLine={false} />
                <YAxis stroke="#94a3b8" fontSize={11} tickLine={false} />
                <Tooltip
                  contentStyle={{ backgroundColor: '#fff', border: '1px solid #e2e8f0', borderRadius: '12px' }}
                  labelStyle={{ color: '#132F4C', fontWeight: 'bold' }}
                />
                <Bar dataKey="orders" fill="#132F4C" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Revenue chart */}
        <div className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm">
          <h2 className="text-lg font-bold text-[#132F4C] mb-4">Haftalik daromad (UZS)</h2>
          <div className="h-80 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={chartData}>
                <XAxis dataKey="name" stroke="#94a3b8" fontSize={11} tickLine={false} />
                <YAxis stroke="#94a3b8" fontSize={11} tickLine={false} />
                <Tooltip
                  contentStyle={{ backgroundColor: '#fff', border: '1px solid #e2e8f0', borderRadius: '12px' }}
                  labelStyle={{ color: '#132F4C', fontWeight: 'bold' }}
                />
                <Line type="monotone" dataKey="revenue" stroke="#4f46e5" strokeWidth={3} dot={{ fill: '#4f46e5', r: 4 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
}
