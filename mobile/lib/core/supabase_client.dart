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
  // Telefon raqam bilan to'g'ridan-to'g'ri kirish (SMS/Email cheklovlarisiz)
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loginWithPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length < 9) {
      throw Exception('Iltimos, telefon raqamingizni to\'liq kiriting');
    }

    final formattedPhone = phone.startsWith('+') ? phone : '+$cleanPhone';

    try {
      // 1. Agar mavjud sessiya bo'lmasa, anonim sessiya yaratish
      var currentUser = client.auth.currentUser;
      if (currentUser == null) {
        final authResponse = await client.auth.signInAnonymously(
          data: {'phone': formattedPhone},
        );
        currentUser = authResponse.user;
      }

      if (currentUser == null) {
        throw Exception('Tizimga kirish amalga oshmadi');
      }

      // 2. Foydalanuvchi profilini ID yoki Telefon raqami bo'yicha topish
      var profile = await client
          .from('profiles')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      if (profile == null) {
        // Avval ro'yxatdan o'tgan profilni telefon orqali topish
        final existingByPhone = await client
            .from('profiles')
            .select()
            .eq('phone', formattedPhone)
            .maybeSingle();

        if (existingByPhone != null) {
          try {
            await client.from('profiles').update({
              'id': currentUser.id,
            }).eq('phone', formattedPhone);
          } catch (_) {}

          profile = existingByPhone;
          profile['id'] = currentUser.id;
        }
      }

      return {'user_id': currentUser.id, 'profile': profile};
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
    final formattedPhone = phone.startsWith('+') ? phone : '+$phone';

    // 1. Asosiy profil upsert
    await client.from('profiles').upsert({
      'id': userId,
      'phone': formattedPhone,
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
