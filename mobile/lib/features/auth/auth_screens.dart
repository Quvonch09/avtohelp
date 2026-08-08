import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:master_help/features/auth/auth_bloc.dart';

// ─────────────────────────────────────────────────────────────
// DESIGN CONSTANTS
// ─────────────────────────────────────────────────────────────
const _primary = Color(0xFF132F4C);
const _bg = Color(0xFFF5F7FB);
const _accent = Color(0xFF2563EB);

BoxDecoration _cardDecor() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))
      ],
    );

InputDecoration _inputDecor(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIcon: Icon(icon, color: _primary, size: 22),
    );

Widget _primaryButton({required String label, required VoidCallback? onTap, bool loading = false}) =>
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
    );

// ─────────────────────────────────────────────────────────────
// STEP PROGRESS INDICATOR
// ─────────────────────────────────────────────────────────────
class _StepBar extends StatelessWidget {
  final int current; // 1-based
  final int total;
  const _StepBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final done = i < current;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: done ? _primary : Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 1. LOGIN SCREEN — Telefon raqam
// ─────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ctrl = TextEditingController(text: '+998');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    final phone = _ctrl.text.trim();
    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 11) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Telefon raqamni to\'liq kiriting'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }
    ctx.read<AuthBloc>().add(PhoneSubmitted(phone));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Center(
                  child: Text('A', style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('AVTOHELP',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _primary, letterSpacing: 2.5)),
              const SizedBox(height: 6),
              const Text("Yo'l yordami platformasi",
                  style: TextStyle(fontSize: 15, color: Colors.black45, fontStyle: FontStyle.italic)),
              const Spacer(flex: 2),
              // Phone field
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Telefon raqamingiz',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _primary.withOpacity(0.8))),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: _cardDecor(),
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primary),
                  decoration: _inputDecor('', Icons.phone_android),
                ),
              ),
              const SizedBox(height: 20),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (ctx, state) => _primaryButton(
                  label: 'Davom etish',
                  onTap: state is AuthLoading ? null : () => _submit(ctx),
                  loading: state is AuthLoading,
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 2. NAME INPUT SCREEN — Ism-familiya
// ─────────────────────────────────────────────────────────────
class NameInputScreen extends StatefulWidget {
  const NameInputScreen({Key? key}) : super(key: key);

  @override
  State<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends State<NameInputScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    final name = _ctrl.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Ism-sharifingizni to\'liq kiriting'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }
    ctx.read<AuthBloc>().add(NameSubmitted(name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StepBar(current: 1, total: 3),
              const SizedBox(height: 36),
              const Text('Ismingiz', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _primary)),
              const SizedBox(height: 8),
              const Text("To'liq ism-sharifingizni kiriting",
                  style: TextStyle(fontSize: 15, color: Colors.black45)),
              const SizedBox(height: 36),
              Container(
                decoration: _cardDecor(),
                child: TextField(
                  controller: _ctrl,
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _primary),
                  decoration: _inputDecor('Ism Familiya', Icons.person_outline),
                ),
              ),
              const Spacer(),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (ctx, state) => _primaryButton(
                  label: 'Davom etish →',
                  onTap: state is AuthLoading ? null : () => _submit(ctx),
                  loading: state is AuthLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 3. PHOTO UPLOAD SCREEN — Profil rasmi
// ─────────────────────────────────────────────────────────────
class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({Key? key}) : super(key: key);

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  Uint8List? _imgBytes;
  String _ext = 'jpg';
  final _picker = ImagePicker();

  Future<void> _pick() async {
    try {
      final XFile? f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      setState(() {
        _imgBytes = bytes;
        _ext = f.path.split('.').last.toLowerCase();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rasm tanlashda xatolik: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _upload(BuildContext ctx) {
    if (_imgBytes != null) {
      ctx.read<AuthBloc>().add(PhotoUploadRequested(bytes: _imgBytes!, extension: _ext));
    }
  }

  void _skip(BuildContext ctx) => ctx.read<AuthBloc>().add(PhotoSkipped());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            children: [
              const Align(alignment: Alignment.topLeft, child: _StepBar(current: 2, total: 3)),
              const SizedBox(height: 36),
              const Text('Profil rasmi',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _primary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text("Rasm tanlang yoki keyinroq qo'shing",
                  style: TextStyle(fontSize: 15, color: Colors.black45), textAlign: TextAlign.center),
              const Spacer(),
              // Avatar circle
              GestureDetector(
                onTap: _pick,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: _primary.withOpacity(0.2), width: 3),
                        boxShadow: [
                          BoxShadow(color: _primary.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 10))
                        ],
                        image: _imgBytes != null
                            ? DecorationImage(image: MemoryImage(_imgBytes!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _imgBytes == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded, size: 48, color: _primary),
                                SizedBox(height: 10),
                                Text('Rasm tanlash',
                                    style: TextStyle(fontSize: 13, color: _primary, fontWeight: FontWeight.w600)),
                              ],
                            )
                          : null,
                    ),
                    if (_imgBytes != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, color: Colors.white, size: 18),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (ctx, state) {
                  final loading = state is AuthLoading;
                  return Column(
                    children: [
                      if (_imgBytes != null) ...[
                        _primaryButton(
                          label: 'Saqlash va davom etish',
                          onTap: loading ? null : () => _upload(ctx),
                          loading: loading,
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: loading ? null : () => _skip(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: _primary.withOpacity(0.35), width: 1.5),
                            foregroundColor: _primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            _imgBytes == null ? "O'tkazib yuborish →" : "Rasmsiz davom etish",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 4. ROLE CHOICE SCREEN — Rol tanlash (User / Usta)
// ─────────────────────────────────────────────────────────────
class RoleChoiceScreen extends StatelessWidget {
  const RoleChoiceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StepBar(current: 3, total: 3),
              const SizedBox(height: 36),
              const Text('Rolingizni tanlang',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _primary)),
              const SizedBox(height: 8),
              const Text('Avtohelp dan qanday maqsadda foydalanasiz?',
                  style: TextStyle(fontSize: 15, color: Colors.black45)),
              const SizedBox(height: 48),
              // Haydovchi card
              _RoleCard(
                icon: Icons.drive_eta_rounded,
                title: 'Men Haydovchiman',
                subtitle: "Yo'lda muammoga tushganda usta chaqiraman",
                badge: 'Bepul',
                badgeColor: const Color(0xFF22C55E),
                onTap: () => context.read<AuthBloc>().add(UserRoleChosen()),
              ),
              const SizedBox(height: 16),
              // Usta card
              _RoleCard(
                icon: Icons.handyman_rounded,
                title: 'Men Ustaman',
                subtitle: 'Buyurtma qabul qilib, daromad olaman',
                badge: 'Pro',
                badgeColor: const Color(0xFF8B5CF6),
                onTap: () => context.read<AuthBloc>().add(MasterRoleChosen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 34, color: _primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _primary)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(badge,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black45)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: _primary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 5. SERVICE SELECTION SCREEN — Usta xizmatlarni tanlaydi
// ─────────────────────────────────────────────────────────────
class ServiceSelectionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> services;
  const ServiceSelectionScreen({Key? key, required this.services}) : super(key: key);

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  final Set<int> _selected = {};

  // Xizmat nomi bo'yicha icon va rang
  (IconData, Color) _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('evakuator') || n.contains('towing')) return (Icons.local_shipping, const Color(0xFFEF4444));
    if (n.contains('g\'ildirak') || n.contains('vulkan') || n.contains('tire')) return (Icons.tire_repair, const Color(0xFF22C55E));
    if (n.contains('moy') || n.contains('oil')) return (Icons.opacity, const Color(0xFFF97316));
    if (n.contains('yuvish') || n.contains('wash')) return (Icons.local_car_wash, const Color(0xFFEAB308));
    if (n.contains('akkumulyator') || n.contains('battery')) return (Icons.battery_charging_full, const Color(0xFF8B5CF6));
    if (n.contains('elektrik')) return (Icons.flash_on, const Color(0xFF3B82F6));
    if (n.contains('motor') || n.contains('engine')) return (Icons.settings, const Color(0xFF6366F1));
    return (Icons.build_circle, _primary);
  }

  void _confirm(BuildContext ctx) {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Kamida bitta xizmat tanlang'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    ctx.read<AuthBloc>().add(ServicesConfirmed(_selected.toList()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Xizmatlaringiz',
            style: TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('${_selected.length} tanlandi',
                      style: const TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text(
              widget.services.isEmpty
                  ? "Admin paneldan xizmatlarni qo'shing"
                  : 'Ko\'rsatadigan xizmatlaringizni tanlang',
              style: const TextStyle(fontSize: 15, color: Colors.black45),
            ),
          ),
          Expanded(
            child: widget.services.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.engineering_outlined, size: 90, color: Colors.black12),
                        SizedBox(height: 16),
                        Text(
                          'Hozircha xizmatlar mavjud emas\nAdmin paneldan qo\'shing',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black38, fontSize: 15, height: 1.5),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    itemCount: widget.services.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final svc = widget.services[i];
                      final id = svc['id'] as int;
                      final name = svc['name'] as String? ?? 'Xizmat';
                      final selected = _selected.contains(id);
                      final (icon, iconColor) = _iconFor(name);

                      return GestureDetector(
                        onTap: () => setState(() {
                          selected ? _selected.remove(id) : _selected.add(id);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: selected ? _primary : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? _primary : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: selected ? Colors.white.withOpacity(0.15) : iconColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: selected ? Colors.white : iconColor, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: selected ? Colors.white : _primary,
                                        )),
                                    if (svc['base_price'] != null)
                                      Text(
                                        'Boshlang\'ich: ${svc['base_price']} UZS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: selected ? Colors.white70 : Colors.black38,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: selected
                                    ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26, key: ValueKey(true))
                                    : Icon(Icons.circle_outlined, color: Colors.black12, size: 24, key: const ValueKey(false)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (ctx, state) => _primaryButton(
                label: _selected.isEmpty
                    ? 'Kamida bitta tanlang'
                    : 'Usta sifatida kirish  (${_selected.length} xizmat)',
                onTap: state is AuthLoading ? null : () => _confirm(ctx),
                loading: state is AuthLoading,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PENDING VERIFICATION SCREEN (mos kelsa)
// ─────────────────────────────────────────────────────────────
class PendingVerificationScreen extends StatelessWidget {
  const PendingVerificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hourglass_top_rounded, size: 100, color: _primary),
            const SizedBox(height: 24),
            const Text('Tasdiqlash kutilmoqda',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _primary)),
            const SizedBox(height: 16),
            const Text(
              'Profilingiz muvaffaqiyatli topshirildi.\nAdmin 24 soat ichida tekshirib tasdiqlaydi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 48),
            OutlinedButton(
              onPressed: () => context.read<AuthBloc>().add(SignOutRequested()),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Tizimdan chiqish', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
