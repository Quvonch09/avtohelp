import 'dart:typed_data';
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

  String? get currentUserId => client.auth.currentUser?.id;

  // ─────────────────────────────────────────────────────────────────────────
  // ⚠️ SMS OTP BYPASS MODE (SMS provider ulanmagan)
  // TODO: SMS provider ulanganidan keyin bu metodlarni o'zgartiring:
  //   1. loginWithPhone → Edge Function 'send-otp' + 'verify-otp' bilan
  //   2. Bu metodni ikkiga bo'ling: sendOtp() va verifyOtp()
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loginWithPhone(String phone) async {
    // Telefon raqamni email ko'rinishiga o'giramiz (bypass)
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final fakeEmail = 'user_$cleanPhone@avtohelp.uz';
    final fakePassword = 'avtohelp_bypass_$cleanPhone';

    AuthResponse authResponse;
    try {
      // Mavjud foydalanuvchi — login
      authResponse = await client.auth.signInWithPassword(
        email: fakeEmail,
        password: fakePassword,
      );
    } catch (_) {
      // Yangi foydalanuvchi — ro'yxatdan o'tkazish
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
      'user_id': user.id,
      'profile': profile, // null → yangi foydalanuvchi
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Profil rasmi yuklash (Supabase Storage 'avatars' bucket)
  // ─────────────────────────────────────────────────────────────────────────
  Future<String?> uploadAvatar(String userId, Uint8List bytes, String extension) async {
    try {
      final fileName = '$userId.$extension';
      await client.storage.from('avatars').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      return client.storage.from('avatars').getPublicUrl(fileName);
    } catch (e) {
      // Rasm yuklash muvaffaqiyatsiz bo'lsa, skip qilamiz
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Xizmatlar ro'yxatini yuklash (admin panel orqali qo'shiladi)
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchServices() async {
    try {
      final response = await client.from('services').select().order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Xizmatlarni yuklashda xatolik: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Profil yaratish (user va master uchun)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> createProfile({
    required String userId,
    required String phone,
    required String fullName,
    required String role, // 'USER' yoki 'MASTER'
    String? photoUrl,
    List<int>? serviceIds, // Faqat MASTER uchun
  }) async {
    // 1. Asosiy profil yaratish
    await client.from('profiles').insert({
      'id': userId,
      'phone': phone,
      'role': role,
      'full_name': fullName,
      'avatar_url': photoUrl,
      'is_verified': role == 'USER', // User — avtomatik verified
      'is_online': false,
    });

    // 2. Usta qo'shimcha ma'lumotlari
    if (role == 'MASTER') {
      // master_profiles trigger orqali avtomatik yaratiladi
      await client.from('master_profiles').update({
        'experience_years': 0,
        'about': '',
      }).eq('id', userId);

      // Tanlangan xizmatlarni qo'shish
      if (serviceIds != null && serviceIds.isNotEmpty) {
        await client.from('master_services').insert(
          serviceIds.map((id) => {
            'master_id': userId,
            'service_id': id,
            'price': 0, // Narx keyinroq ustaning o'zi belgilaydi
          }).toList(),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Joylashuv yangilash (PostGIS WKT format)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> updateLocation(double lat, double lng) async {
    final userId = currentUserId;
    if (userId == null) return;
    await client.from('profiles').update({
      'location': 'POINT($lng $lat)',
      'last_location_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3km radiusda ustalarni qidirish (PostGIS RPC)
  // ─────────────────────────────────────────────────────────────────────────
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

  // Tizimdan chiqish
  Future<void> signOut() async {
    await client.auth.signOut();
  }
}
