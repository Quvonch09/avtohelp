'use client';

import "./globals.css";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkAdminAuth();

    // Listen for auth changes
    const { data: authListener } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (session) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .single();
        
        if (profile && profile.role === 'ADMIN') {
          setIsAdmin(true);
        } else {
          setIsAdmin(false);
          if (pathname !== '/login') {
            router.push('/login');
          }
        }
      } else {
        setIsAdmin(false);
        if (pathname !== '/login') {
          router.push('/login');
        }
      }
      setLoading(false);
    });

    return () => {
      authListener.subscription.unsubscribe();
    };
  }, [pathname]);

  async function checkAdminAuth() {
    try {
      const demoMode = typeof window !== 'undefined' ? localStorage.getItem('avtohelp_demo_mode') : null;
      if (demoMode === 'true' || demoMode === null) {
        setIsAdmin(true);
        setLoading(false);
        return;
      }

      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        setIsAdmin(false);
        if (pathname !== '/login') {
          router.push('/login');
        }
        setLoading(false);
        return;
      }

      const { data: profile, error } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', session.user.id)
        .single();

      if (error || !profile || profile.role !== 'ADMIN') {
        setIsAdmin(false);
        if (pathname !== '/login') {
          router.push('/login');
        }
      } else {
        setIsAdmin(true);
      }
    } catch (e) {
      console.error(e);
      setIsAdmin(true);
    } finally {
      setLoading(false);
    }
  }

  // Handle logout
  async function handleLogout() {
    if (typeof window !== 'undefined') {
      localStorage.setItem('avtohelp_demo_mode', 'false');
    }
    await supabase.auth.signOut();
    router.push('/login');
  }

  if (loading && pathname !== '/login') {
    return (
      <html lang="uz">
        <body className="flex h-screen items-center justify-center bg-[#F5F7FB]">
          <div className="flex flex-col items-center gap-4">
            <div className="h-12 w-12 animate-spin rounded-full border-4 border-[#132F4C] border-t-transparent"></div>
            <p className="text-sm font-semibold text-[#132F4C]">Avtohelp Yuklanmoqda...</p>
          </div>
        </body>
      </html>
    );
  }

  // If we are on the login page, just render the page content without sidebar
  if (pathname === '/login') {
    return (
      <html lang="uz">
        <body className="bg-[#F5F7FB] font-sans antialiased text-[#132F4C]">
          {children}
        </body>
      </html>
    );
  }

  return (
    <html lang="uz" className="h-full bg-[#F5F7FB]">
      <head>
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
      </head>
      <body className="flex h-full overflow-hidden font-sans bg-[#F5F7FB]">
        {/* Left Sidebar - Premium Dark Navy Theme */}
        <aside className="w-64 bg-[#132F4C] flex flex-col justify-between p-6 shadow-xl text-white">
          <div className="space-y-8">
            {/* Logo: Circle with letter "A" and text */}
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-white flex items-center justify-center shadow-md">
                <span className="text-xl font-black text-[#132F4C]">A</span>
              </div>
              <div className="flex flex-col">
                <span className="text-lg font-bold tracking-wider leading-none">AVTOHELP</span>
                <span className="text-[10px] text-gray-300 font-medium">Yo'l yordami</span>
              </div>
            </div>

            {/* Navigation links */}
            <nav className="space-y-1">
              <Link
                href="/"
                className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all ${
                  pathname === '/'
                    ? 'bg-white/10 text-white font-semibold'
                    : 'text-gray-300 hover:text-white hover:bg-white/5'
                }`}
              >
                <span>📊</span> Dashboard
              </Link>
              <Link
                href="/orders"
                className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all ${
                  pathname === '/orders'
                    ? 'bg-white/10 text-white font-semibold'
                    : 'text-gray-300 hover:text-white hover:bg-white/5'
                }`}
              >
                <span>📍</span> Buyurtmalar
              </Link>
              <Link
                href="/masters"
                className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all ${
                  pathname === '/masters'
                    ? 'bg-white/10 text-white font-semibold'
                    : 'text-gray-300 hover:text-white hover:bg-white/5'
                }`}
              >
                <span>🛠️</span> Ustalar boshqaruvi
              </Link>
              <Link
                href="/users"
                className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all ${
                  pathname === '/users'
                    ? 'bg-white/10 text-white font-semibold'
                    : 'text-gray-300 hover:text-white hover:bg-white/5'
                }`}
              >
                <span>👥</span> Foydalanuvchilar
              </Link>
              <Link
                href="/services"
                className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all ${
                  pathname === '/services'
                    ? 'bg-white/10 text-white font-semibold'
                    : 'text-gray-300 hover:text-white hover:bg-white/5'
                }`}
              >
                <span>⚙️</span> Xizmatlar
              </Link>
              <Link
                href="/regions"
                className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all ${
                  pathname === '/regions'
                    ? 'bg-white/10 text-white font-semibold'
                    : 'text-gray-300 hover:text-white hover:bg-white/5'
                }`}
              >
                <span>🗺️</span> Hududlar
              </Link>
              <Link
                href="/finance"
                className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all ${
                  pathname === '/finance'
                    ? 'bg-white/10 text-white font-semibold'
                    : 'text-gray-300 hover:text-white hover:bg-white/5'
                }`}
              >
                <span>💵</span> Moliya
              </Link>
              <Link
                href="/settings"
                className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all ${
                  pathname === '/settings'
                    ? 'bg-white/10 text-white font-semibold'
                    : 'text-gray-300 hover:text-white hover:bg-white/5'
                }`}
              >
                <span>🔔</span> Sozlamalar va Push
              </Link>
            </nav>
          </div>

          {/* Sidebar Footer with Logout */}
          <div className="border-t border-white/10 pt-4 flex flex-col gap-3">
            <div className="flex items-center justify-between text-xs text-gray-300">
              <span>Admin Panel v1.0</span>
              <button 
                onClick={handleLogout}
                className="hover:text-red-300 font-bold flex items-center gap-1 transition-colors"
              >
                Chiqish 🚪
              </button>
            </div>
            <p className="text-[10px] text-gray-400">© 2026 Avtohelp. Barcha huquqlar himoyalangan.</p>
          </div>
        </aside>

        {/* Main Content Area */}
        <main className="flex-1 flex flex-col min-w-0 overflow-y-auto p-8 bg-[#F5F7FB]">
          {children}
        </main>
      </body>
    </html>
  );
}
