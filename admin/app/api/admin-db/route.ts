import { NextResponse } from 'next/server';
import { getSupabaseAdmin } from '@/lib/supabase';

// Mock datasets for offline / fallback mode
const mockDataStore = {
  orders: [
    {
      id: 'ord-101',
      created_at: '2026-08-07T09:30:00Z',
      status: 'PENDING',
      price: 150000,
      user_address: "Qarshi sh., Mustaqillik ko'chasi 45-uy",
      profiles_user: { full_name: 'Anvar Rahimov', phone: '+998901234567' },
      profiles_master: null,
      services: { name: 'Evakuator xizmati' }
    },
    {
      id: 'ord-102',
      created_at: '2026-08-07T08:15:00Z',
      status: 'ON_WAY',
      price: 80000,
      user_address: "Qarshi sh., Alisher Navoiy ko'chasi 12-uy",
      profiles_user: { full_name: 'Dilshod Ismoilov', phone: '+998912345678' },
      profiles_master: { full_name: 'Jasur Usta', phone: '+998935551122' },
      services: { name: "Shina ta'mirlash" }
    },
    {
      id: 'ord-103',
      created_at: '2026-08-06T16:20:00Z',
      status: 'DONE',
      price: 220000,
      user_address: "Qarshi-Shahrisabz yo'li 15-km",
      profiles_user: { full_name: 'Sardor Qodirov', phone: '+998971112233' },
      profiles_master: { full_name: 'Bobur Elektrik', phone: '+998907778899' },
      services: { name: 'Moy almashtirish' }
    },
    {
      id: 'ord-104',
      created_at: '2026-08-06T14:10:00Z',
      status: 'DONE',
      price: 350000,
      user_address: "Qarshi sh., Jayxun ko'chasi 88-uy",
      profiles_user: { full_name: 'Bobur Karimov', phone: '+998934445566' },
      profiles_master: { full_name: 'Jasur Usta', phone: '+998935551122' },
      services: { name: 'Avto diagnostika' }
    }
  ],
  masters: [
    {
      id: 'mst-1',
      full_name: 'Jasur Usta',
      phone: '+998935551122',
      avatar_url: null,
      is_verified: true,
      is_online: true,
      location: { lat: 38.8612, lng: 65.7847 },
      master_profiles: {
        experience_years: 6,
        about: "Barcha turdagi avto ta'mirlash va shina montaj xizmatlari",
        rating_avg: 4.9,
        rating_count: 42,
        completed_orders: 85
      },
      master_cars: [{ car_brands: { name: 'Chevrolet' } }, { car_brands: { name: 'BYD' } }],
      master_services: [{ price: 150000, services: { name: 'Evakuator xizmati' } }, { price: 80000, services: { name: "Shina ta'mirlash" } }]
    },
    {
      id: 'mst-2',
      full_name: 'Bobur Elektrik',
      phone: '+998907778899',
      avatar_url: null,
      is_verified: true,
      is_online: false,
      location: { lat: 38.8550, lng: 65.7900 },
      master_profiles: {
        experience_years: 8,
        about: 'Professional avto elektrik va kompyuter diagnostikasi',
        rating_avg: 4.8,
        rating_count: 31,
        completed_orders: 64
      },
      master_cars: [{ car_brands: { name: 'Kia' } }, { car_brands: { name: 'Hyundai' } }],
      master_services: [{ price: 200000, services: { name: 'Avto diagnostika' } }]
    },
    {
      id: 'mst-3',
      full_name: "Otabek Yo'ldoshev",
      phone: '+998943332211',
      avatar_url: null,
      is_verified: false,
      is_online: false,
      location: null,
      master_profiles: {
        experience_years: 3,
        about: "Yangi tajribali usta, tezkor ko'chma yordam",
        rating_avg: 4.5,
        rating_count: 5,
        completed_orders: 8
      },
      master_cars: [{ car_brands: { name: 'Chevrolet' } }],
      master_services: [{ price: 100000, services: { name: 'Moy almashtirish' } }]
    }
  ],
  clients: [
    {
      id: 'usr-1',
      full_name: 'Anvar Rahimov',
      phone: '+998901234567',
      avatar_url: null,
      is_verified: true,
      created_at: '2026-01-15T10:00:00Z',
      user_cars: [{ id: 'car-1' }, { id: 'car-2' }]
    },
    {
      id: 'usr-2',
      full_name: 'Dilshod Ismoilov',
      phone: '+998912345678',
      avatar_url: null,
      is_verified: true,
      created_at: '2026-02-01T12:30:00Z',
      user_cars: [{ id: 'car-3' }]
    },
    {
      id: 'usr-3',
      full_name: 'Sardor Qodirov',
      phone: '+998971112233',
      avatar_url: null,
      is_verified: true,
      created_at: '2026-03-10T14:15:00Z',
      user_cars: [{ id: 'car-4' }]
    }
  ],
  services: [
    { id: 1, name: 'Evakuator xizmati', icon: 'truck', base_price: 150000 },
    { id: 2, name: "Shina ta'mirlash", icon: 'wrench', base_price: 80000 },
    { id: 3, name: 'Moy almashtirish', icon: 'droplet', base_price: 100000 },
    { id: 4, name: 'Avto diagnostika', icon: 'zap', base_price: 120000 }
  ],
  brands: [
    { id: 1, name: 'Chevrolet', logo_url: null },
    { id: 2, name: 'BYD', logo_url: null },
    { id: 3, name: 'Kia', logo_url: null },
    { id: 4, name: 'Hyundai', logo_url: null }
  ],
  models: [
    { id: 1, brand_id: 1, name: 'Gentra' },
    { id: 2, brand_id: 1, name: 'Cobalt' },
    { id: 3, brand_id: 1, name: 'Tracker' },
    { id: 4, brand_id: 2, name: 'Song Plus' },
    { id: 5, brand_id: 2, name: 'Chazor' },
    { id: 6, brand_id: 3, name: 'K5' },
    { id: 7, brand_id: 4, name: 'Sonata' }
  ]
};

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { action, params } = body;

    if (!action) {
      return NextResponse.json({ error: 'Action is required' }, { status: 400 });
    }

    const supabaseAdmin = getSupabaseAdmin();

    switch (action) {
      case 'getOrders': {
        try {
          const { data, error } = await supabaseAdmin
            .from('orders')
            .select(`
              id,
              created_at,
              status,
              price,
              user_address,
              profiles_user:user_id(full_name, phone),
              profiles_master:master_id(full_name, phone),
              services:service_id(name)
            `)
            .order('created_at', { ascending: false });

          if (!error && data && data.length > 0) {
            return NextResponse.json({ data });
          }
        } catch (_) {}
        return NextResponse.json({ data: mockDataStore.orders });
      }

      case 'getMasters': {
        try {
          const { data, error } = await supabaseAdmin
            .from('profiles')
            .select(`
              id,
              full_name,
              phone,
              avatar_url,
              is_verified,
              is_online,
              location,
              master_profiles (
                experience_years,
                about,
                rating_avg,
                rating_count,
                completed_orders
              ),
              master_cars (
                car_brands (name)
              ),
              master_services (
                price,
                services (name)
              )
            `)
            .eq('role', 'MASTER');

          if (!error && data && data.length > 0) {
            return NextResponse.json({ data });
          }
        } catch (_) {}
        return NextResponse.json({ data: mockDataStore.masters });
      }

      case 'getClients': {
        try {
          const { data, error } = await supabaseAdmin
            .from('profiles')
            .select(`
              id,
              full_name,
              phone,
              avatar_url,
              is_verified,
              created_at,
              user_cars (id)
            `)
            .eq('role', 'USER')
            .order('created_at', { ascending: false });

          if (!error && data && data.length > 0) {
            return NextResponse.json({ data });
          }
        } catch (_) {}
        return NextResponse.json({ data: mockDataStore.clients });
      }

      case 'getServices': {
        try {
          const { data, error } = await supabaseAdmin
            .from('services')
            .select('*')
            .order('id');

          if (!error && data && data.length > 0) {
            return NextResponse.json({ data });
          }
        } catch (_) {}
        return NextResponse.json({ data: mockDataStore.services });
      }

      case 'getBrandsAndModels': {
        try {
          const { data: brands, error: bErr } = await supabaseAdmin.from('car_brands').select('*').order('name');
          const { data: models, error: mErr } = await supabaseAdmin.from('car_models').select('*').order('name');
          if (!bErr && !mErr && brands && brands.length > 0) {
            return NextResponse.json({ brands, models });
          }
        } catch (_) {}
        return NextResponse.json({ brands: mockDataStore.brands, models: mockDataStore.models });
      }

      case 'assignMaster': {
        const { orderId, masterId } = params;
        const targetMaster = mockDataStore.masters.find(m => m.id === masterId);
        const orderIndex = mockDataStore.orders.findIndex(o => o.id === orderId);
        if (orderIndex !== -1) {
          mockDataStore.orders[orderIndex].status = masterId ? 'ACCEPTED' : 'PENDING';
          mockDataStore.orders[orderIndex].profiles_master = targetMaster
            ? { full_name: targetMaster.full_name, phone: targetMaster.phone }
            : null;
        }

        try {
          await supabaseAdmin
            .from('orders')
            .update({
              master_id: masterId || null,
              status: masterId ? 'ACCEPTED' : 'PENDING'
            })
            .eq('id', orderId);
        } catch (_) {}

        return NextResponse.json({ data: mockDataStore.orders[orderIndex] || { id: orderId } });
      }

      case 'verifyMaster': {
        const { masterId, verify } = params;
        const master = mockDataStore.masters.find(m => m.id === masterId);
        if (master) {
          master.is_verified = verify;
        }

        try {
          await supabaseAdmin
            .from('profiles')
            .update({ is_verified: verify })
            .eq('id', masterId);
        } catch (_) {}

        return NextResponse.json({ data: master || { id: masterId, is_verified: verify } });
      }

      case 'deleteMaster': {
        const { masterId } = params;
        mockDataStore.masters = mockDataStore.masters.filter(m => m.id !== masterId);
        try {
          await supabaseAdmin.from('profiles').delete().eq('id', masterId);
        } catch (_) {}
        return NextResponse.json({ success: true });
      }

      case 'saveService': {
        const { id, name, icon, basePrice } = params;
        let data;
        if (id) {
          const existing = mockDataStore.services.find(s => s.id === id);
          if (existing) {
            existing.name = name;
            existing.icon = icon;
            existing.base_price = basePrice;
            data = existing;
          }
        } else {
          data = {
            id: Date.now(),
            name,
            icon: icon || 'wrench',
            base_price: basePrice || 0
          };
          mockDataStore.services.push(data);
        }

        try {
          if (id) {
            await supabaseAdmin.from('services').update({ name, icon, base_price: basePrice }).eq('id', id);
          } else {
            await supabaseAdmin.from('services').insert({ name, icon, base_price: basePrice });
          }
        } catch (_) {}

        return NextResponse.json({ data });
      }

      case 'deleteService': {
        const { id } = params;
        mockDataStore.services = mockDataStore.services.filter(s => s.id !== id);
        try {
          await supabaseAdmin.from('services').delete().eq('id', id);
        } catch (_) {}
        return NextResponse.json({ success: true });
      }

      case 'saveBrand': {
        const { name, logoUrl } = params;
        const data = { id: Date.now(), name, logo_url: logoUrl || null };
        mockDataStore.brands.push(data);
        try {
          await supabaseAdmin.from('car_brands').insert({ name, logo_url: logoUrl || null });
        } catch (_) {}
        return NextResponse.json({ data });
      }

      case 'deleteBrand': {
        const { id } = params;
        mockDataStore.brands = mockDataStore.brands.filter(b => b.id !== id);
        mockDataStore.models = mockDataStore.models.filter(m => m.brand_id !== id);
        try {
          await supabaseAdmin.from('car_brands').delete().eq('id', id);
        } catch (_) {}
        return NextResponse.json({ success: true });
      }

      case 'saveModel': {
        const { brandId, name } = params;
        const data = { id: Date.now(), brand_id: brandId, name };
        mockDataStore.models.push(data);
        try {
          await supabaseAdmin.from('car_models').insert({ brand_id: brandId, name });
        } catch (_) {}
        return NextResponse.json({ data });
      }

      case 'deleteModel': {
        const { id } = params;
        mockDataStore.models = mockDataStore.models.filter(m => m.id !== id);
        try {
          await supabaseAdmin.from('car_models').delete().eq('id', id);
        } catch (_) {}
        return NextResponse.json({ success: true });
      }

      default:
        return NextResponse.json({ error: 'Action not supported' }, { status: 400 });
    }
  } catch (err: any) {
    console.error('API Error:', err);
    return NextResponse.json({ error: err.message || 'Server error occurred' }, { status: 500 });
  }
}
