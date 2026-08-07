import 'package:flutter/material.dart';
import 'package:master_help/core/supabase_client.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  const ProfileScreen({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _db = SupabaseService();
  
  // User uchun
  List<dynamic> _userCars = [];
  List<dynamic> _brands = [];
  
  // Master uchun
  List<dynamic> _masterBrands = [];
  List<dynamic> _masterServices = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final role = widget.userProfile['role'];
    
    if (role == 'USER') {
      final cars = await _db.client
          .from('user_cars')
          .select('*, car_brands(name), car_models(name)')
          .eq('user_id', widget.userProfile['id']);
      
      final brands = await _db.client.from('car_brands').select();

      setState(() {
        _userCars = cars;
        _brands = brands;
      });
    } else if (role == 'MASTER') {
      final masterCars = await _db.client
          .from('master_cars')
          .select('*, car_brands(name)')
          .eq('master_id', widget.userProfile['id']);
      
      final masterServices = await _db.client
          .from('master_services')
          .select('*, services(name)')
          .eq('master_id', widget.userProfile['id']);

      setState(() {
        _masterBrands = masterCars;
        _masterServices = masterServices;
      });
    }
  }

  // --- Mashina qo'shish Dialogi ---
  void _showAddCarDialog() {
    int? selectedBrandId;
    int? selectedModelId;
    final yearController = TextEditingController();
    final plateController = TextEditingController();
    List<dynamic> filteredModels = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Mashina qo\'shish', style: TextStyle(color: Color(0xFF132F4C), fontWeight: FontWeight.bold, fontFamily: 'Inter')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand tanlash
                    DropdownButtonFormField<int>(
                      dropdownColor: Colors.white,
                      decoration: const InputDecoration(labelText: 'Brend', labelStyle: TextStyle(color: Colors.grey)),
                      items: _brands.map((b) {
                        return DropdownMenuItem<int>(
                          value: b['id'],
                          child: Text(b['name'] ?? '', style: const TextStyle(color: Color(0xFF132F4C))),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          final models = await _db.client.from('car_models').select().eq('brand_id', val);
                          setDialogState(() {
                            selectedBrandId = val;
                            filteredModels = models;
                            selectedModelId = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Model tanlash
                    DropdownButtonFormField<int>(
                      dropdownColor: Colors.white,
                      decoration: const InputDecoration(labelText: 'Model', labelStyle: TextStyle(color: Colors.grey)),
                      value: selectedModelId,
                      items: filteredModels.map((m) {
                        return DropdownMenuItem<int>(
                          value: m['id'],
                          child: Text(m['name'] ?? '', style: const TextStyle(color: Color(0xFF132F4C))),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedModelId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: yearController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF132F4C), fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(labelText: 'Yil', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: plateController,
                      style: const TextStyle(color: Color(0xFF132F4C), fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(labelText: 'Davlat raqami (Plate)', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedBrandId != null && selectedModelId != null && plateController.text.isNotEmpty) {
                      await _db.client.from('user_cars').insert({
                        'user_id': widget.userProfile['id'],
                        'brand_id': selectedBrandId,
                        'model_id': selectedModelId,
                        'year': int.tryParse(yearController.text.trim()),
                        'plate': plateController.text.trim().toUpperCase(),
                      });
                      Navigator.pop(context);
                      _loadProfileData();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF132F4C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Qo\'shish', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.userProfile['role'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Profil tafsilotlari', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        backgroundColor: const Color(0xFF132F4C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar and title
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: const Color(0xFF132F4C).withOpacity(0.1),
                    child: const Icon(Icons.person, size: 50, color: Color(0xFF132F4C)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.userProfile['full_name'] ?? '',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.userProfile['phone'] ?? '',
                    style: const TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            if (role == 'USER') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mening mashinalarim',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF132F4C), size: 28),
                    onPressed: _showAddCarDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _userCars.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text('Hozircha avtomobillar yo\'q.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ),
                    )
                  : Column(
                      children: _userCars.map((car) {
                        final brand = car['car_brands']?['name'] ?? 'Brend';
                        final model = car['car_models']?['name'] ?? 'Model';
                        final plate = car['plate'] ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))],
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.drive_eta, color: Color(0xFF132F4C)),
                            title: Text('$brand $model', style: const TextStyle(color: Color(0xFF132F4C), fontWeight: FontWeight.bold)),
                            subtitle: Text('Raqam: $plate', style: const TextStyle(color: Colors.black54)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () async {
                                await _db.client.from('user_cars').delete().eq('id', car['id']);
                                _loadProfileData();
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ] else if (role == 'MASTER') ...[
              const Text(
                'Xizmat ko\'rsatiladigan brendlar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
              ),
              const SizedBox(height: 12),
              _masterBrands.isEmpty
                  ? const Text('Brendlar tanlanmagan.', style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      children: _masterBrands.map((b) {
                        return Chip(
                          label: Text(
                            b['car_brands']?['name'] ?? '',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: const Color(0xFF132F4C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 28),
              const Text(
                'Mening xizmatlarim va narxlarim',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
              ),
              const SizedBox(height: 12),
              _masterServices.isEmpty
                  ? const Text('Xizmatlar qo\'shilmagan.', style: TextStyle(color: Colors.grey))
                  : Column(
                      children: _masterServices.map((s) {
                        final serviceName = s['services']?['name'] ?? 'Xizmat';
                        final price = s['price'] as int? ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.check_circle_outline, color: Color(0xFF132F4C)),
                            title: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF132F4C))),
                            trailing: Text(
                              '${price.toString()} UZS',
                              style: const TextStyle(color: Color(0xFF132F4C), fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
