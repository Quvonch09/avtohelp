import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:master_help/core/supabase_client.dart';

// ═══════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════
abstract class AuthEvent {}

/// Ilova ochilganda sessiyani tekshirish
class CheckAuthStatus extends AuthEvent {}

/// Telefon raqam kiritildi → login yoki ro'yxatdan o'tish
class PhoneSubmitted extends AuthEvent {
  final String phone;
  PhoneSubmitted(this.phone);
}

/// Ism-familiya kiritildi
class NameSubmitted extends AuthEvent {
  final String name;
  NameSubmitted(this.name);
}

/// Rasm tanlandi → yuklansin
class PhotoUploadRequested extends AuthEvent {
  final Uint8List bytes;
  final String extension;
  PhotoUploadRequested({required this.bytes, required this.extension});
}

/// Rasm o'tkazib yuborildi
class PhotoSkipped extends AuthEvent {}

/// Foydalanuvchi roli tanlandi
class UserRoleChosen extends AuthEvent {}

/// Usta roli tanlandi → xizmatlar ekrani
class MasterRoleChosen extends AuthEvent {}

/// Usta xizmatlarini tasdiqladi → profil yaratish
class ServicesConfirmed extends AuthEvent {
  final List<int> serviceIds;
  ServicesConfirmed(this.serviceIds);
}

/// Tizimdan chiqish
class SignOutRequested extends AuthEvent {}

// ═══════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════
abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

/// Tizimga kirilmagan → LoginScreen
class AuthUnauthenticated extends AuthState {}

/// Qadam 1: Ism kiritish
class AuthNameStep extends AuthState {
  final String phone;
  final String userId;
  AuthNameStep({required this.phone, required this.userId});
}

/// Qadam 2: Rasm yuklash
class AuthPhotoStep extends AuthState {
  final String phone;
  final String userId;
  final String name;
  AuthPhotoStep({required this.phone, required this.userId, required this.name});
}

/// Qadam 3: Rol tanlash
class AuthRoleStep extends AuthState {
  final String phone;
  final String userId;
  final String name;
  final String? photoUrl;
  AuthRoleStep({required this.phone, required this.userId, required this.name, this.photoUrl});
}

/// Qadam 4 (Usta): Xizmatlar tanlash
class AuthServiceStep extends AuthState {
  final String phone;
  final String userId;
  final String name;
  final String? photoUrl;
  final List<Map<String, dynamic>> services;
  AuthServiceStep({
    required this.phone,
    required this.userId,
    required this.name,
    this.photoUrl,
    required this.services,
  });
}

/// Tizimga kirildi → HomeScreen
class AuthAuthenticated extends AuthState {
  final String role;
  final Map<String, dynamic> profile;
  AuthAuthenticated({required this.role, required this.profile});
}

/// Xatolik
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseService _db = SupabaseService();

  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<PhoneSubmitted>(_onPhoneSubmitted);
    on<NameSubmitted>(_onNameSubmitted);
    on<PhotoUploadRequested>(_onPhotoUploadRequested);
    on<PhotoSkipped>(_onPhotoSkipped);
    on<UserRoleChosen>(_onUserRoleChosen);
    on<MasterRoleChosen>(_onMasterRoleChosen);
    on<ServicesConfirmed>(_onServicesConfirmed);
    on<SignOutRequested>(_onSignOutRequested);
  }

  // ─── Sessiyani tekshirish ──────────────────────────────────
  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final session = _db.client.auth.currentSession;
    if (session == null) {
      emit(AuthUnauthenticated());
      return;
    }
    try {
      final userId = _db.currentUserId!;
      final profile = await _db.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        // Sessiya bor, profil yo'q → ism bosqichiga
        final emailPrefix = _db.client.auth.currentUser?.email?.split('@').first ?? '';
        emit(AuthNameStep(phone: '+$emailPrefix', userId: userId));
      } else {
        emit(AuthAuthenticated(role: profile['role'], profile: profile));
      }
    } catch (e) {
      emit(AuthError('Profil tekshirishda xatolik: $e'));
    }
  }

  // ─── Telefon kiritildi ─────────────────────────────────────
  Future<void> _onPhoneSubmitted(PhoneSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final result = await _db.loginWithPhone(event.phone);
      final userId = result['user_id'] as String;
      final profile = result['profile'];

      if (profile != null) {
        // Mavjud foydalanuvchi → panelga
        emit(AuthAuthenticated(role: profile['role'], profile: profile));
      } else {
        // Yangi foydalanuvchi → ism bosqichi
        emit(AuthNameStep(phone: event.phone, userId: userId));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  // ─── Ism kiritildi ────────────────────────────────────────
  Future<void> _onNameSubmitted(NameSubmitted event, Emitter<AuthState> emit) async {
    if (state is! AuthNameStep) return;
    final s = state as AuthNameStep;
    emit(AuthPhotoStep(phone: s.phone, userId: s.userId, name: event.name));
  }

  // ─── Rasm yuklanmoqda ─────────────────────────────────────
  Future<void> _onPhotoUploadRequested(PhotoUploadRequested event, Emitter<AuthState> emit) async {
    if (state is! AuthPhotoStep) return;
    final s = state as AuthPhotoStep;
    emit(AuthLoading());
    // Yuklash amalga oshmasa null qaytadi — ilovani bloklamaydi
    final photoUrl = await _db.uploadAvatar(s.userId, event.bytes, event.extension);
    emit(AuthRoleStep(phone: s.phone, userId: s.userId, name: s.name, photoUrl: photoUrl));
  }

  // ─── Rasm o'tkazib yuborildi ───────────────────────────────
  Future<void> _onPhotoSkipped(PhotoSkipped event, Emitter<AuthState> emit) async {
    if (state is! AuthPhotoStep) return;
    final s = state as AuthPhotoStep;
    emit(AuthRoleStep(phone: s.phone, userId: s.userId, name: s.name, photoUrl: null));
  }

  // ─── User roli tanlandi ────────────────────────────────────
  Future<void> _onUserRoleChosen(UserRoleChosen event, Emitter<AuthState> emit) async {
    if (state is! AuthRoleStep) return;
    final s = state as AuthRoleStep;
    emit(AuthLoading());
    try {
      await _db.createProfile(
        userId: s.userId,
        phone: s.phone,
        fullName: s.name,
        role: 'USER',
        photoUrl: s.photoUrl,
      );
      final profile = await _db.client.from('profiles').select().eq('id', s.userId).single();
      emit(AuthAuthenticated(role: 'USER', profile: profile));
    } catch (e) {
      emit(AuthError('Profil yaratishda xatolik: $e'));
    }
  }

  // ─── Usta roli tanlandi → xizmatlarni yuklash ─────────────
  Future<void> _onMasterRoleChosen(MasterRoleChosen event, Emitter<AuthState> emit) async {
    if (state is! AuthRoleStep) return;
    final s = state as AuthRoleStep;
    emit(AuthLoading());
    try {
      final services = await _db.fetchServices();
      emit(AuthServiceStep(
        phone: s.phone,
        userId: s.userId,
        name: s.name,
        photoUrl: s.photoUrl,
        services: services,
      ));
    } catch (e) {
      emit(AuthError('Xizmatlarni yuklashda xatolik: $e'));
    }
  }

  // ─── Xizmatlar tasdiqlandi → usta profili yaratish ────────
  Future<void> _onServicesConfirmed(ServicesConfirmed event, Emitter<AuthState> emit) async {
    if (state is! AuthServiceStep) return;
    final s = state as AuthServiceStep;
    emit(AuthLoading());
    try {
      await _db.createProfile(
        userId: s.userId,
        phone: s.phone,
        fullName: s.name,
        role: 'MASTER',
        photoUrl: s.photoUrl,
        serviceIds: event.serviceIds,
      );
      final profile = await _db.client.from('profiles').select().eq('id', s.userId).single();
      emit(AuthAuthenticated(role: 'MASTER', profile: profile));
    } catch (e) {
      emit(AuthError('Usta profili yaratishda xatolik: $e'));
    }
  }

  // ─── Tizimdan chiqish ─────────────────────────────────────
  Future<void> _onSignOutRequested(SignOutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _db.signOut();
    emit(AuthUnauthenticated());
  }
}
