import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:master_help/core/supabase_client.dart';
import 'package:master_help/features/auth/auth_bloc.dart';
import 'package:master_help/features/auth/auth_screens.dart';
import 'package:master_help/features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase-ni initsializatsiya qilish
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc()..add(CheckAuthStatus()),
      child: MaterialApp(
        title: 'Avtohelp',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF132F4C),
          scaffoldBackgroundColor: const Color(0xFFF5F7FB),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Color(0xFF132F4C), fontFamily: 'sans-serif'),
            bodyMedium: TextStyle(color: Colors.black87, fontFamily: 'sans-serif'),
          ),
          colorScheme: const ColorScheme.light().copyWith(
            primary: const Color(0xFF132F4C),
            secondary: const Color(0xFF64748B), // Slate gray accent
            surface: Colors.white,
            background: const Color(0xFFF5F7FB),
          ),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        // Yuklanyapti
        if (state is AuthLoading || state is AuthInitial) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F7FB),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF132F4C)),
            ),
          );
        }

        // ── Ro'yxatdan o'tish qadamlari ────────────────────
        if (state is AuthNameStep) {
          return const NameInputScreen();
        }
        if (state is AuthPhotoStep) {
          return const PhotoUploadScreen();
        }
        if (state is AuthRoleStep) {
          return const RoleChoiceScreen();
        }
        if (state is AuthServiceStep) {
          return ServiceSelectionScreen(services: state.services);
        }

        // ── Kirgan foydalanuvchi ──────────────────────────
        if (state is AuthAuthenticated) {
          return HomeScreen(userProfile: state.profile);
        }

        // ── Xatolik ───────────────────────────────────────
        if (state is AuthError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FB),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_rounded, color: Colors.redAccent, size: 72),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: const TextStyle(color: Color(0xFF132F4C), fontSize: 16, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: () => context.read<AuthBloc>().add(CheckAuthStatus()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF132F4C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Qayta urunish', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ── Default: Login ekrani ─────────────────────────
        return const LoginScreen();
      },
    );
  }
}
