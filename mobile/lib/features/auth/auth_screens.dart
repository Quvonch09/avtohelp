import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:master_help/features/auth/auth_bloc.dart';

// -------------------------------------------------------------
// 1. LOGIN SCREEN
// -------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController(text: '+998');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo: Dark navy blue circle #132F4C with white letter "A"
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: Color(0xFF132F4C),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'AVTOHELP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF132F4C),
                  letterSpacing: 1.5,
                  fontFamily: 'Inter',
                ),
              ),
              const Text(
                'Yo\'l yordami',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Avtohelp — yo\'lda ishonchli hamkoringiz!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF132F4C),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Phone Input Field inside a Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Color(0xFF132F4C), fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Telefon raqam',
                    labelStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    prefixIcon: const Icon(Icons.phone, color: Color(0xFF132F4C)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final phone = _phoneController.text.trim();
                  context.read<AuthBloc>().add(SendOtpRequested(phone));
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF132F4C),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Kodni yuborish',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. OTP VERIFICATION SCREEN
// -------------------------------------------------------------
class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({Key? key, required this.phone}) : super(key: key);

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF132F4C)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tasdiqlash kodi',
              style: TextStyle(color: Color(0xFF132F4C), fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.phone} raqamiga yuborilgan 4 xonali kodni kiriting.',
              style: const TextStyle(color: Colors.black54, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF132F4C), fontSize: 28, letterSpacing: 16, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final code = _codeController.text.trim();
                context.read<AuthBloc>().add(VerifyOtpRequested(phone: widget.phone, code: code));
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF132F4C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Tasdiqlash',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. ROLE CHOICE SCREEN
// -------------------------------------------------------------
class RoleChoiceScreen extends StatefulWidget {
  final String userId;
  final String phone;
  const RoleChoiceScreen({Key? key, required this.userId, required this.phone}) : super(key: key);

  @override
  State<RoleChoiceScreen> createState() => _RoleChoiceScreenState();
}

class _RoleChoiceScreenState extends State<RoleChoiceScreen> {
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Rolingizni tanlang',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Avtohelp ilovasidan qanday maqsadda foydalanasiz?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),
            const SizedBox(height: 48),
            _buildRoleCard(
              role: 'USER',
              title: 'Men Haydovchiman',
              description: 'Yo\'lda yordam yoki usta chaqirish uchun',
              icon: Icons.drive_eta,
            ),
            const SizedBox(height: 16),
            _buildRoleCard(
              role: 'MASTER',
              title: 'Men Ustaman',
              description: 'Mijozlar buyurtmalarini qabul qilish va daromad olish uchun',
              icon: Icons.handyman,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _selectedRole == null
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegisterDetailsScreen(
                            role: _selectedRole!,
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF132F4C),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black12,
                disabledForegroundColor: Colors.black38,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Davom etish',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF132F4C) : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 48, color: const Color(0xFF132F4C)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF132F4C),
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. REGISTRATION DETAILS SCREEN
// -------------------------------------------------------------
class RegisterDetailsScreen extends StatefulWidget {
  final String role;
  const RegisterDetailsScreen({Key? key, required this.role}) : super(key: key);

  @override
  State<RegisterDetailsScreen> createState() => _RegisterDetailsScreenState();
}

class _RegisterDetailsScreenState extends State<RegisterDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  
  // Master uchun
  final TextEditingController _expController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isMaster = widget.role == 'MASTER';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Profilni sozlash', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF132F4C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF132F4C).withOpacity(0.1),
                      child: const Icon(Icons.person, size: 60, color: Color(0xFF132F4C)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF132F4C),
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          onPressed: () {
                            // Avatar upload
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Color(0xFF132F4C), fontWeight: FontWeight.w600),
                  decoration: _inputDecoration('To\'liq ism-sharifingiz', Icons.person),
                  validator: (v) => v == null || v.isEmpty ? 'Ism-sharifingizni kiriting' : null,
                ),
              ),
              if (isMaster) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: TextFormField(
                    controller: _expController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Color(0xFF132F4C), fontWeight: FontWeight.w600),
                    decoration: _inputDecoration('Ish tajribasi (yillarda)', Icons.work),
                    validator: (v) => v == null || v.isEmpty ? 'Tajribangizni kiriting' : null,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: TextFormField(
                    controller: _aboutController,
                    maxLines: 3,
                    style: const TextStyle(color: Color(0xFF132F4C)),
                    decoration: _inputDecoration('O\'zingiz haqingizda (bio)', Icons.description),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF132F4C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Ro\'yxatdan o\'tish',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        RegisterDetailsSubmitted(
          fullName: _nameController.text.trim(),
          role: widget.role,
          experienceYears: widget.role == 'MASTER' ? int.tryParse(_expController.text.trim()) : null,
          about: widget.role == 'MASTER' ? _aboutController.text.trim() : null,
          selectedBrands: widget.role == 'MASTER' ? [1, 2, 3] : null, // Default brand links Chevrolet, BYD, Hyundai
          selectedServices: widget.role == 'MASTER'
              ? [
                  {'service_id': 1, 'price': 150000},
                  {'service_id': 2, 'price': 40000}
                ]
              : null,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      prefixIcon: Icon(icon, color: const Color(0xFF132F4C)),
    );
  }
}

// -------------------------------------------------------------
// 5. PENDING VERIFICATION SCREEN
// -------------------------------------------------------------
class PendingVerificationScreen extends StatelessWidget {
  const PendingVerificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hourglass_empty, size: 100, color: Color(0xFF132F4C)),
            const SizedBox(height: 24),
            const Text(
              'Tasdiqlash kutilmoqda',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Arizangiz muvaffaqiyatli topshirildi. Admin profilingizni 24 soat ichida tekshirib tasdiqlaydi. Tasdiqlanganingizdan so\'ng sizga push-bildirishnoma boradi va ishni boshlay olasiz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 48),
            OutlinedButton(
              onPressed: () {
                context.read<AuthBloc>().add(SignOutRequested());
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Tizimdan chiqish',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
