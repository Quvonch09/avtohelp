import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:master_help/core/supabase_client.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;

  // Joylashuv huquqlarini so'rash (Foreground + Background)
  Future<bool> requestPermissions() async {
    // 1. Standart Foreground ruxsati
    var status = await Permission.location.request();
    if (status.isGranted) {
      if (kIsWeb) {
        return true; // Web-da locationAlways ruxsati mavjud emas va kerak emas
      }
      // 2. Background ruxsati (Agar usta bo'lsa yo'lda kuzatish uchun shart)
      var bgStatus = await Permission.locationAlways.request();
      return bgStatus.isGranted || status.isGranted;
    }
    return false;
  }

  // Hozirgi joylashuvni olish
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Real-time kuzatuvni boshlash (Master online bo'lganda chaqiriladi)
  void startLocationTracking() {
    if (_positionStreamSubscription != null) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // 10 metrdan ortiq yurganda yangilanadi
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      try {
        // Supabase bazasidagi usta joylashuvini yangilash
        await SupabaseService().updateLocation(
          position.latitude,
          position.longitude,
        );
      } catch (e) {
        print('Joylashuvni yangilashda xatolik: $e');
      }
    });
  }

  // Real-time kuzatuvni to'xtatish
  void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }
}
