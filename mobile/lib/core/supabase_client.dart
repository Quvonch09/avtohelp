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
  // Telefon raqam bilan doimiy avtorizatsiya (Auto-login va bir marta registratsiya)
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loginWithPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length < 9) {
      throw Exception('Iltimos, telefon raqamingizni to\'liq kiriting');
    }

    final formattedPhone = phone.startsWith('+') ? phone : '+$cleanPhone';
    final fakeEmail = 'u${cleanPhone}x@avtohelp.uz';
    final fakePassword = 'av2h3lp_$cleanPhone';

    try {
      // 1. Agar avvaldan keshda sessiya bo'lsa
      final currentUser = client.auth.currentUser;
      if (currentUser != null) {
        var profile = await client
            .from('profiles')
            .select()
            .eq('id', currentUser.id)
            .maybeSingle();

        if (profile != null) {
          return {'user_id': currentUser.id, 'profile': profile};
        }
      }

      // 2. Telefon raqamga bog'langan maxsus hisob orqali kirish
      AuthResponse authResponse;
      try {
        authResponse = await client.auth.signInWithPassword(
          email: fakeEmail,
          password: fakePassword,
        );
      } catch (signInErr) {
        // Agar hisob hali yaratilmagan bo'lsa → ro'yxatdan o'tkazish
        authResponse = await client.auth.signUp(
          email: fakeEmail,
          password: fakePassword,
          data: {'phone': formattedPhone},
        );
      }

      final user = authResponse.user ?? client.auth.currentUser;
      if (user == null) throw Exception('Tizimga kirish amalga oshmadi');

      // 3. Foydalanuvchi profili mavjudligini tekshirish
      var profile = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        // Telefon raqam bo'yicha profilni tekshirish
        profile = await client
            .from('profiles')
            .select()
            .eq('phone', formattedPhone)
            .maybeSingle();
      }

      return {'user_id': user.id, 'profile': profile};
    } catch (e) {
      print('Login error: $e');
      throw Exception('Kirishda xatolik yuz berdi: ${e.toString().replaceAll('Exception: ', '')}');
    }
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
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Xizmatlar ro'yxatini yuklash
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchServices() async {
    try {
      final response = await client.from('services').select().order('id');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Xizmatlarni yuklashda xatolik: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Profil yaratish / yangilash (user va master uchun)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> createProfile({
    required String userId,
    required String phone,
    required String fullName,
    required String role, // 'USER' yoki 'MASTER'
    String? photoUrl,
    List<int>? serviceIds, // Faqat MASTER uchun
  }) async {
    // 1. Asosiy profil upsert
    await client.from('profiles').upsert({
      'id': userId,
      'phone': phone,
      'role': role,
      'full_name': fullName,
      'avatar_url': photoUrl,
      'is_verified': role == 'USER',
      'is_online': role == 'MASTER',
    });

    // 2. Usta qo'shimcha ma'lumotlari
    if (role == 'MASTER') {
      try {
        await client.from('master_profiles').upsert({
          'id': userId,
          'experience_years': 2,
          'about': 'Tezkor yordam ustasi',
        });
      } catch (_) {}

      // Tanlangan xizmatlarni qo'shish
      if (serviceIds != null && serviceIds.isNotEmpty) {
        try {
          await client.from('master_services').delete().eq('master_id', userId);
          await client.from('master_services').insert(
            serviceIds.map((id) => {
              'master_id': userId,
              'service_id': id,
              'price': 0,
            }).toList(),
          );
        } catch (_) {}
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Joylashuv yangilash (PostGIS WKT format)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> updateLocation(double lat, double lng) async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      await client.from('profiles').update({
        'location': 'POINT($lng $lat)',
        'last_location_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3km radiusda ustalarni qidirish
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
