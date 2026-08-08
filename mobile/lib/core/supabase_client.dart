import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://mtwcfkyuvapnvgcxgmda.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_bFQK59UKRpkgM1Bc1Az-dA_FYhgkh6e';
}

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient client = Supabase.instance.client;

  // Foydalanuvchining joriy ID si
  String? get currentUserId => client.auth.currentUser?.id;

  // ⚠️ SMS OTP VAQTINCHA DISABLED (SMS provider ulanmagan)
  // SMS provider ulanganidan keyin bu metodlarni asl holiga qaytaring.

  // OTP SMS yuborish — hozircha bypass (hech narsa qilmaydi)
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    // TODO: SMS provider ulanganidan keyin Edge Function 'send-otp' ni yoqing
    // Hozircha shunchaki muvaffaqiyat qaytaradi
    return {'success': true, 'message': 'bypass mode'};
  }

  // OTP tasdiqlash — hozircha bypass (istalgan kod bilan kirish)
  // Supabase email trick: telefon raqamni email formatiga o'girib anonymous login
  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    // TODO: SMS provider ulanganidan keyin Edge Function 'verify-otp' ni yoqing
    try {
      // Telefon raqamni email ko'rinishiga o'giramiz: +998901234567 → 998901234567@avtohelp.uz
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final fakeEmail = '$cleanPhone@avtohelp.uz';
      // OTP kodi parol sifatida ishlatiladi (bypass: istalgan 4-raqamli kod)
      final fakePassword = 'avtohelp_$cleanPhone';

      AuthResponse authResponse;
      try {
        // Avval login qilib ko'ramiz
        authResponse = await client.auth.signInWithPassword(
          email: fakeEmail,
          password: fakePassword,
        );
      } catch (_) {
        // Foydalanuvchi mavjud emas — yangi ro'yxatdan o'tkazamiz
        authResponse = await client.auth.signUp(
          email: fakeEmail,
          password: fakePassword,
        );
      }

      final user = authResponse.user;
      if (user == null) throw Exception('Kirish amalga oshmadi');

      // Profil mavjudligini tekshirish
      final profile = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return {
        'user': {'id': user.id, 'email': user.email},
        'has_profile': profile != null,
        'role': profile?['role'],
      };
    } catch (e) {
      throw Exception('Kirish xatosi: $e');
    }
  }

  // RPC: 3km radiusda yaqin ustalarni qidirish (PostGIS)
  Future<List<dynamic>> searchNearbyMasters({
    required double latitude,
    required double longitude,
    required int serviceId,
    required int brandId,
    double radiusMeters = 3000.0,
  }) async {
    try {
      final List<dynamic> response = await client.rpc(
        'search_nearby_masters',
        params: {
          'user_lat': latitude,
          'user_lng': longitude,
          'target_service_id': serviceId,
          'target_brand_id': brandId,
          'radius_meters': radiusMeters,
        },
      );
      return response;
    } catch (e) {
      throw Exception('Ustalarni qidirishda xatolik: $e');
    }
  }

  // Location update: profildagi joriy joylashuvni yangilash
  Future<void> updateLocation(double lat, double lng) async {
    final userId = currentUserId;
    if (userId == null) return;
    
    // WKT (Well-Known Text) formatida point yaratish
    final pointWkt = 'POINT($lng $lat)';
    
    await client.from('profiles').update({
      'location': pointWkt,
      'last_location_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  // Logout xizmati
  Future<void> signOut() async {
    await client.auth.signOut();
  }
}
