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
        if (state is AuthLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00D2ff)),
            ),
          );
        } else if (state is AuthOtpSent) {
          return OtpScreen(phone: state.phone);
        } else if (state is AuthNeedsRegistration) {
          return RoleChoiceScreen(userId: state.userId, phone: state.phone);
        } else if (state is AuthPendingVerification) {
          return const PendingVerificationScreen();
        } else if (state is AuthAuthenticated) {
          return HomeScreen(userProfile: state.profile);
        } else if (state is AuthError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.redAccent, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(CheckAuthStatus());
                      },
                      child: const Text('Qayta urunish'),
                    )
                  ],
                ),
              ),
            ),
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
