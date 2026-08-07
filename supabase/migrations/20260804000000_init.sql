-- 1. PostGIS kengaytmasini yoqish (agar yoqilmagan bo'lsa)
CREATE EXTENSION IF NOT EXISTS postgis;

-- OTP kodlarini vaqtincha saqlash jadvali (Eskiz uchun)
CREATE TABLE IF NOT EXISTS public.otp_codes (
  phone VARCHAR(15) PRIMARY KEY,
  code VARCHAR(6) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL
);

-- 2. Foydalanuvchilar (Profiles)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone VARCHAR(15) UNIQUE NOT NULL,
  role VARCHAR(10) CHECK (role IN ('ADMIN', 'MASTER', 'USER')) NOT NULL,
  full_name VARCHAR(100),
  avatar_url TEXT,
  is_verified BOOLEAN DEFAULT false, -- Masterlar uchun admin tasdiqi
  is_online BOOLEAN DEFAULT false, -- Masterlarning ish holati
  fcm_token TEXT,
  location GEOGRAPHY(POINT, 4326), -- PostGIS nuqta (WGS 84 koordinata tizimi)
  last_location_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Location va Role bo'yicha qidiruvni tezlashtirish uchun indekslar
CREATE INDEX IF NOT EXISTS idx_profiles_location ON public.profiles USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_profiles_role_verified ON public.profiles(role, is_verified) WHERE role = 'MASTER';

-- 3. Master qo'shimcha profili (Profil tafsilotlari)
CREATE TABLE IF NOT EXISTS public.master_profiles (
  id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  experience_years INT DEFAULT 0,
  about TEXT,
  rating_avg NUMERIC(2,1) DEFAULT 0.0,
  rating_count INT DEFAULT 0,
  completed_orders INT DEFAULT 0
);

-- 4. Avtomobil Brendlari (Admin boshqaradi)
CREATE TABLE IF NOT EXISTS public.car_brands (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL,
  logo_url TEXT
);

-- 5. Avtomobil Modellari (Admin boshqaradi)
CREATE TABLE IF NOT EXISTS public.car_models (
  id SERIAL PRIMARY KEY,
  brand_id INT REFERENCES public.car_brands(id) ON DELETE CASCADE,
  name VARCHAR(50) NOT NULL
);

-- 6. Servis Turlari (Admin boshqaradi)
CREATE TABLE IF NOT EXISTS public.services (
  id SERIAL PRIMARY KEY,
  name VARCHAR(80) UNIQUE NOT NULL,
  icon VARCHAR(50),
  base_price INT NOT NULL DEFAULT 0
);

-- 7. Usta qaysi avto brendlarida ishlay oladi (Many-to-Many)
CREATE TABLE IF NOT EXISTS public.master_cars (
  master_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  brand_id INT REFERENCES public.car_brands(id) ON DELETE CASCADE,
  PRIMARY KEY(master_id, brand_id)
);

-- 8. Usta qaysi servislarni taqdim etadi va o'z narxi (Many-to-Many)
CREATE TABLE IF NOT EXISTS public.master_services (
  master_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  service_id INT REFERENCES public.services(id) ON DELETE CASCADE,
  price INT NOT NULL,
  PRIMARY KEY(master_id, service_id)
);

-- 9. Oddiy foydalanuvchilarning avtomobillari
CREATE TABLE IF NOT EXISTS public.user_cars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  brand_id INT REFERENCES public.car_brands(id) ON DELETE CASCADE,
  model_id INT REFERENCES public.car_models(id) ON DELETE CASCADE,
  year INT,
  plate VARCHAR(20) NOT NULL
);

-- 10. Buyurtmalar (Orders)
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) NOT NULL,
  master_id UUID REFERENCES public.profiles(id),
  user_car_id UUID REFERENCES public.user_cars(id),
  service_id INT REFERENCES public.services(id) NOT NULL,
  status VARCHAR(15) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'ON_WAY', 'ARRIVED', 'DONE', 'CANCELLED')),
  user_location GEOGRAPHY(POINT, 4326) NOT NULL,
  user_address TEXT,
  price INT,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);

-- 11. Reyting va Feedbacklar (Har bir buyurtma uchun bitta rating)
CREATE TABLE IF NOT EXISTS public.ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE UNIQUE,
  from_user UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  to_master UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  stars INT NOT NULL CHECK(stars BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 12. Bildirishnomalar Log (FCM yuborilgan xabarlar arxivi)
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  title VARCHAR(120) NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Row Level Security (RLS) Sozlamalari
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.car_brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.car_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_cars ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_cars ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Oddiy foydalanuvchilar o'z profilini ko'ra oladi va yangilay oladi
CREATE POLICY "Profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (true);
CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Master Profiles hamma ko'rishi mumkin
CREATE POLICY "Master profiles are viewable by everyone" ON public.master_profiles FOR SELECT USING (true);
CREATE POLICY "Masters can update their own profile details" ON public.master_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Masters can insert their own profile details" ON public.master_profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Car Brands, Models va Services hamma o'qiy oladi, faqat admin yoza oladi
CREATE POLICY "Car brands viewable by everyone" ON public.car_brands FOR SELECT USING (true);
CREATE POLICY "Car models viewable by everyone" ON public.car_models FOR SELECT USING (true);
CREATE POLICY "Services viewable by everyone" ON public.services FOR SELECT USING (true);

-- Master Cars va Services
CREATE POLICY "Master cars are viewable by everyone" ON public.master_cars FOR SELECT USING (true);
CREATE POLICY "Masters can manage their own cars" ON public.master_cars FOR ALL USING (auth.uid() = master_id);

CREATE POLICY "Master services are viewable by everyone" ON public.master_services FOR SELECT USING (true);
CREATE POLICY "Masters can manage their own services" ON public.master_services FOR ALL USING (auth.uid() = master_id);

-- User Cars (Faqat egasi boshqara oladi)
CREATE POLICY "Users can manage their own cars" ON public.user_cars FOR ALL USING (auth.uid() = user_id);

-- Orders
CREATE POLICY "Users and masters can view their own orders" ON public.orders FOR SELECT USING (auth.uid() = user_id OR auth.uid() = master_id);
CREATE POLICY "Users can insert their own orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users and masters can update their own orders" ON public.orders FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = master_id);

-- Ratings
CREATE POLICY "Ratings viewable by everyone" ON public.ratings FOR SELECT USING (true);
CREATE POLICY "Users can create rating for their orders" ON public.ratings FOR INSERT WITH CHECK (auth.uid() = from_user);

-- Notifications
CREATE POLICY "Users can view their own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);

-- -------------------------------------------------------------
-- YAQIN USTALARNI QIDIRISH FUNKSIYASI (PostGIS yordamida)
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION search_nearby_masters(
  user_lat double precision,
  user_lng double precision,
  target_service_id int,
  target_brand_id int,
  radius_meters float DEFAULT 3000.0,
  max_results int DEFAULT 20
)
RETURNS TABLE (
  master_id UUID,
  full_name VARCHAR,
  avatar_url TEXT,
  experience_years INT,
  rating_avg NUMERIC,
  rating_count INT,
  service_price INT,
  latitude double precision,
  longitude double precision,
  distance_meters float
) 
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id AS master_id,
    p.full_name,
    p.avatar_url,
    mp.experience_years,
    mp.rating_avg,
    mp.rating_count,
    ms.price AS service_price,
    ST_Y(p.location::geometry) AS latitude,
    ST_X(p.location::geometry) AS longitude,
    ST_Distance(
      p.location, 
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
    ) AS distance_meters
  FROM public.profiles p
  JOIN public.master_profiles mp ON p.id = mp.id
  JOIN public.master_services ms ON p.id = ms.master_id
  JOIN public.master_cars mc ON p.id = mc.master_id
  WHERE p.role = 'MASTER'
    AND p.is_verified = true
    AND p.is_online = true
    AND ms.service_id = target_service_id
    AND mc.brand_id = target_brand_id
    AND ST_DWithin(
      p.location, 
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography, 
      radius_meters
    )
  ORDER BY distance_meters ASC
  LIMIT max_results;
END;
$$ LANGUAGE plpgsql;

-- -------------------------------------------------------------
-- TRIGGER: Yangi master ro'yxatdan o'tganda avtomatik profil yaratish
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_master_profile()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role = 'MASTER' THEN
    INSERT INTO public.master_profiles (id, experience_years, about)
    VALUES (NEW.id, 0, '');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER on_master_profile_created
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_master_profile();

-- -------------------------------------------------------------
-- TRIGGER: Yangi reyting qo'yilganda master o'rtacha reytingini hisoblash
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_master_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.master_profiles
  SET 
    rating_avg = COALESCE((SELECT AVG(stars)::NUMERIC(2,1) FROM public.ratings WHERE to_master = NEW.to_master), 0.0),
    rating_count = COALESCE((SELECT COUNT(id) FROM public.ratings WHERE to_master = NEW.to_master), 0)
  WHERE id = NEW.to_master;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER on_rating_added
  AFTER INSERT OR UPDATE ON public.ratings
  FOR EACH ROW EXECUTE FUNCTION public.calculate_master_rating();

-- -------------------------------------------------------------
-- DASTLABKI MA'LUMOTLARNI SEED QILISH (Boshlang'ich qiymatlar)
-- -------------------------------------------------------------
INSERT INTO public.car_brands (name, logo_url) VALUES
('Chevrolet', 'https://storage.googleapis.com/master-help/brands/chevrolet.png'),
('BYD', 'https://storage.googleapis.com/master-help/brands/byd.png'),
('Hyundai', 'https://storage.googleapis.com/master-help/brands/hyundai.png'),
('Kia', 'https://storage.googleapis.com/master-help/brands/kia.png'),
('Toyota', 'https://storage.googleapis.com/master-help/brands/toyota.png')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.car_models (brand_id, name) VALUES
((SELECT id FROM public.car_brands WHERE name='Chevrolet'), 'Cobalt'),
((SELECT id FROM public.car_brands WHERE name='Chevrolet'), 'Gentra'),
((SELECT id FROM public.car_brands WHERE name='Chevrolet'), 'Tracker'),
((SELECT id FROM public.car_brands WHERE name='BYD'), 'Song Plus'),
((SELECT id FROM public.car_brands WHERE name='BYD'), 'Chazor'),
((SELECT id FROM public.car_brands WHERE name='Hyundai'), 'Elantra'),
((SELECT id FROM public.car_brands WHERE name='Hyundai'), 'Santa Fe'),
((SELECT id FROM public.car_brands WHERE name='Kia'), 'K5'),
((SELECT id FROM public.car_brands WHERE name='Kia'), 'Seltos')
ON CONFLICT DO NOTHING;

INSERT INTO public.services (name, icon, base_price) VALUES
('Evakuator (Towing)', 'truck', 150000),
('Vulkanizatsiya (Tire Repair)', 'wrench', 50000),
('Moy Almashtirish (Oil Change)', 'droplet', 80000),
('Akkumulyator (Battery Start)', 'battery-charging', 40000),
('Avto Elektrik (Auto Electrician)', 'zap', 100000),
('Motorist (Engine Specialist)', 'settings', 200000)
ON CONFLICT (name) DO NOTHING;
