import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:master_help/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Events ---
abstract class AuthEvent {}

class CheckAuthStatus extends AuthEvent {}

class SendOtpRequested extends AuthEvent {
  final String phone;
  SendOtpRequested(this.phone);
}

class VerifyOtpRequested extends AuthEvent {
  final String phone;
  final String code;
  VerifyOtpRequested({required this.phone, required this.code});
}

class RegisterDetailsSubmitted extends AuthEvent {
  final String fullName;
  final String role; // 'USER' yoki 'MASTER'
  final String? avatarUrl;
  
  // Master uchun maxsus
  final int? experienceYears;
  final String? about;
  final List<int>? selectedBrands;
  final List<Map<String, dynamic>>? selectedServices; // [{'service_id': 1, 'price': 50000}, ...]

  RegisterDetailsSubmitted({
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.experienceYears,
    this.about,
    this.selectedBrands,
    this.selectedServices,
  });
}

class SignOutRequested extends AuthEvent {}

// --- States ---
abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthOtpSent extends AuthState {
  final String phone;
  AuthOtpSent(this.phone);
}
class AuthNeedsRegistration extends AuthState {
  final String userId;
  final String phone;
  AuthNeedsRegistration({required this.userId, required this.phone});
}
class AuthPendingVerification extends AuthState {}
class AuthAuthenticated extends AuthState {
  final String role;
  final Map<String, dynamic> profile;
  AuthAuthenticated({required this.role, required this.profile});
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// --- BLoC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseService _db = SupabaseService();

  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SendOtpRequested>(_onSendOtpRequested);
    on<VerifyOtpRequested>(_onVerifyOtpRequested);
    on<RegisterDetailsSubmitted>(_onRegisterDetailsSubmitted);
    on<SignOutRequested>(_onSignOutRequested);
  }

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
        emit(AuthNeedsRegistration(userId: userId, phone: _db.client.auth.currentUser!.phone ?? ''));
      } else {
        final String role = profile['role'];
        final bool isVerified = profile['is_verified'] ?? false;

        if (role == 'MASTER' && !isVerified) {
          emit(AuthPendingVerification());
        } else {
          emit(AuthAuthenticated(role: role, profile: profile));
        }
      }
    } catch (e) {
      emit(AuthError('Profil tekshirishda xatolik: $e'));
    }
  }

  Future<void> _onSendOtpRequested(SendOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _db.sendOtp(event.phone);
      emit(AuthOtpSent(event.phone));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onVerifyOtpRequested(VerifyOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final data = await _db.verifyOtp(event.phone, event.code);
      
      final bool hasProfile = data['has_profile'] ?? false;
      
      if (!hasProfile) {
        emit(AuthNeedsRegistration(userId: data['user']['id'], phone: event.phone));
      } else {
        final String role = data['role'];
        final Map<String, dynamic> user = data['user'];
        
        // Profilni yuklash
        final profile = await _db.client
            .from('profiles')
            .select()
            .eq('id', user['id'])
            .single();

        final bool isVerified = profile['is_verified'] ?? false;

        if (role == 'MASTER' && !isVerified) {
          emit(AuthPendingVerification());
        } else {
          emit(AuthAuthenticated(role: role, profile: profile));
        }
      }
    } catch (e) {
      emit(AuthError('Kod tasdiqlanmadi: ${e.toString()}'));
    }
  }

  Future<void> _onRegisterDetailsSubmitted(RegisterDetailsSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final userId = _db.currentUserId!;
      final currentUser = _db.client.auth.currentUser!;
      String phone = currentUser.phone ?? '';
      if (phone.isEmpty && currentUser.email != null && currentUser.email!.endsWith('@masterhelp.uz')) {
        phone = '+' + currentUser.email!.split('@')[0];
      }

      // 1. Profiles jadvaliga yozish
      final profileData = {
        'id': userId,
        'phone': phone,
        'role': event.role,
        'full_name': event.fullName,
        'avatar_url': event.avatarUrl,
        'is_verified': event.role == 'USER', // Foydalanuvchi auto-verified, Usta esa yo'q
        'is_online': false
      };

      await _db.client.from('profiles').insert(profileData);

      // 2. Agar usta bo'lsa qo'shimcha ma'lumotlarni yozish
      if (event.role == 'MASTER') {
        // master_profiles trigger orqali avtomatik yaratiladi, faqat yangilaymiz
        await _db.client.from('master_profiles').update({
          'experience_years': event.experienceYears ?? 0,
          'about': event.about ?? '',
        }).eq('id', userId);

        // Usta mashina brendlari (Many-to-Many)
        if (event.selectedBrands != null) {
          final list = event.selectedBrands!.map((brandId) => {
            'master_id': userId,
            'brand_id': brandId
          }).toList();
          await _db.client.from('master_cars').insert(list);
        }

        // Usta xizmatlari va narxlari (Many-to-Many)
        if (event.selectedServices != null) {
          final list = event.selectedServices!.map((s) => {
            'master_id': userId,
            'service_id': s['service_id'],
            'price': s['price']
          }).toList();
          await _db.client.from('master_services').insert(list);
        }

        emit(AuthPendingVerification());
      } else {
        emit(AuthAuthenticated(role: 'USER', profile: profileData));
      }
    } catch (e) {
      emit(AuthError('Ro\'yxatdan o\'tishda xatolik: $e'));
    }
  }

  Future<void> _onSignOutRequested(SignOutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _db.signOut();
    emit(AuthUnauthenticated());
  }
}
