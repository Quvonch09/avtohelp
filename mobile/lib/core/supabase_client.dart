import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

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

  // Custom Edge Function: OTP SMS yuborish
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final response = await client.functions.invoke(
        'send-otp',
        body: {'phone': phone},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('OTP kod jo\'natishda xatolik: $e');
    }
  }

  // Custom Edge Function: OTP kodni tasdiqlash va tizimga kirish
  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    try {
      final response = await client.functions.invoke(
        'verify-otp',
        body: {'phone': phone, 'code': code},
      );
      
      final data = response.data as Map<String, dynamic>;
      
      if (data.containsKey('session') && data['session'] != null) {
        final sessionData = data['session'] as Map<String, dynamic>;
        
        // Supabase sessiyasini yuklash (Tokenlarni saqlab qolish uchun)
        await client.auth.recoverSession(jsonEncode(sessionData));
      }
      
      return data;
    } catch (e) {
      throw Exception('OTP tasdiqlashda xatolik: $e');
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
