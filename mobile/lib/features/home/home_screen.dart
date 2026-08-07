import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:master_help/core/location_service.dart';
import 'package:master_help/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:master_help/features/orders/order_screens.dart';
import 'package:master_help/features/profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  const HomeScreen({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final SupabaseService _db = SupabaseService();

  int _currentTab = 0; // 0: Bosh sahifa, 1: Ilova haqida, 2: Profil
  bool _isMasterRejimi = false; // Toggle between Client and Master modes (if MASTER role)

  // Client mode state
  Position? _currentPosition;
  String _currentPlusCode = "RQWW+RJG, Qarshi, Qa...";
  List<dynamic> _services = [];
  bool _isLoadingServices = true;

  // Master mode state
  bool _isOnline = false;
  List<dynamic> _newOrders = [];
  Map<String, dynamic>? _activeMasterOrder;
  bool _isLoadingMasterData = false;
  int _masterEarnings = 0;
  List<dynamic> _masterHistory = [];

  // Animation for pulsing button
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _isMasterRejimi = widget.userProfile['role'] == 'MASTER';
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initApp();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _locationService.stopLocationTracking();
    super.dispose();
  }

  Future<void> _initApp() async {
    // Determine position
    Position? pos;
    try {
      await _locationService.requestPermissions();
      pos = await _locationService.getCurrentLocation();
    } catch (e) {
      print('Location permission error: $e');
    }

    if (pos == null) {
      // Default to Qarshi center coordinates
      pos = Position(
        latitude: 38.8612,
        longitude: 65.7847,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );
    }

    setState(() {
      _currentPosition = pos;
    });

    if (pos != null) {
      _db.updateLocation(pos.latitude, pos.longitude);
    }

    // Load Services
    try {
      final servicesRes = await _db.client.from('services').select().order('id');
      setState(() {
        _services = servicesRes;
        _isLoadingServices = false;
      });
    } catch (e) {
      print('Error loading services: $e');
      setState(() {
        _isLoadingServices = false;
      });
    }

    // If Usta mode is active, load master data
    if (_isMasterRejimi) {
      _loadMasterData();
      _subscribeToMasterOrders();
    }
  }

  Future<void> _loadMasterData() async {
    final myId = widget.userProfile['id'];
    setState(() {
      _isLoadingMasterData = true;
    });

    try {
      // 1. Get online status
      final profileRes = await _db.client.from('profiles').select('is_online').eq('id', myId).single();
      // 2. Get active order (not DONE/CANCELLED)
      final activeOrderRes = await _db.client
          .from('orders')
          .select('*, profiles_user:user_id(*), services(*), user_cars(*, car_brands(*), car_models(*))')
          .eq('master_id', myId)
          .neq('status', 'DONE')
          .neq('status', 'CANCELLED')
          .maybeSingle();

      // 3. Get earnings & history
      final historyRes = await _db.client
          .from('orders')
          .select('*, services(*)')
          .eq('master_id', myId)
          .eq('status', 'DONE');

      // 4. Fetch pending orders in Qarshi (for online view)
      final pendingOrdersRes = await _db.client
          .from('orders')
          .select('*, profiles_user:user_id(*), services(*)')
          .eq('status', 'PENDING');

      int earnings = 0;
      if (historyRes != null) {
        for (var o in historyRes) {
          earnings += (o['price'] as int? ?? 0);
        }
      }

      setState(() {
        _isOnline = profileRes['is_online'] ?? false;
        _activeMasterOrder = activeOrderRes;
        _masterHistory = historyRes ?? [];
        _masterEarnings = earnings;
        _newOrders = pendingOrdersRes ?? [];
        _isLoadingMasterData = false;
      });

      if (_isOnline) {
        _locationService.startLocationTracking();
      }
    } catch (e) {
      print('Error loading master data: $e');
      setState(() {
        _isLoadingMasterData = false;
      });
    }
  }

  // Real-time listener for orders (useful for both clients and masters)
  void _subscribeToMasterOrders() {
    _db.client
        .channel('public:orders')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              _loadMasterData();
            })
        .subscribe();
  }

  // Toggle Online/Offline for master
  Future<void> _toggleOnline(bool val) async {
    final myId = widget.userProfile['id'];
    setState(() {
      _isOnline = val;
    });

    try {
      await _db.client.from('profiles').update({'is_online': val}).eq('id', myId);
      if (val) {
        _locationService.startLocationTracking();
      } else {
        _locationService.stopLocationTracking();
      }
      _loadMasterData();
    } catch (e) {
      print('Error toggling online: $e');
    }
  }

  // Status updates flow for master: ACCEPTED -> ON_WAY -> ARRIVED -> DONE
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _db.client.from('orders').update({'status': newStatus}).eq('id', orderId);
      
      // Trigger push notification to Client
      final orderData = _activeMasterOrder;
      if (orderData != null) {
        String title = "Buyurtma holati yangilandi";
        String body = "";
        if (newStatus == 'ON_WAY') body = "Usta yo'lga chiqdi!";
        if (newStatus == 'ARRIVED') body = "Usta yetib keldi va ish boshladi!";
        if (newStatus == 'DONE') body = "Ish yakunlandi! Iltimos, xizmatni baholang.";

        await _db.client.functions.invoke('send-push', body: {
          'user_id': orderData['user_id'],
          'title': title,
          'body': body,
          'data': {'order_id': orderId, 'status': newStatus}
        });
      }

      _loadMasterData();
    } catch (e) {
      print('Error updating order status: $e');
    }
  }

  // Accept a new order
  Future<void> _acceptOrder(String orderId) async {
    final myId = widget.userProfile['id'];
    try {
      await _db.client.from('orders').update({
        'status': 'ACCEPTED',
        'master_id': myId,
      }).eq('id', orderId);

      // Notify user
      await _db.client.functions.invoke('send-push', body: {
        'user_id': _newOrders.firstWhere((o) => o['id'] == orderId)['user_id'],
        'title': 'Buyurtma qabul qilindi!',
        'body': 'Usta buyurtmangizni qabul qildi va tez orada bog\'lanadi.',
        'data': {'order_id': orderId}
      });

      _loadMasterData();
    } catch (e) {
      print('Error accepting order: $e');
    }
  }

  // Reject an order (locally filter it out for simplicity)
  void _rejectOrder(String orderId) {
    setState(() {
      _newOrders.removeWhere((o) => o['id'] == orderId);
    });
  }

  // Google Maps Picker sheet for User
  void _openLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Xaritadan joylashuv',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF132F4C)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_currentPosition?.latitude ?? 38.8612, _currentPosition?.longitude ?? 65.7847),
                      zoom: 14.0,
                    ),
                    myLocationEnabled: true,
                    onTap: (LatLng latLng) {
                      setState(() {
                        _currentPosition = Position(
                          latitude: latLng.latitude,
                          longitude: latLng.longitude,
                          timestamp: DateTime.now(),
                          accuracy: 1.0,
                          altitude: 0.0,
                          heading: 0.0,
                          speed: 0.0,
                          speedAccuracy: 0.0,
                          altitudeAccuracy: 1.0,
                          headingAccuracy: 1.0,
                        );
                        _currentPlusCode = "Qarshi, Lat: ${latLng.latitude.toStringAsFixed(4)}, Lng: ${latLng.longitude.toStringAsFixed(4)}";
                      });
                      _db.updateLocation(latLng.latitude, latLng.longitude);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Joyni tanlash uchun xaritaga bosing. Avtomatik ravishda manzil yangilanadi.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isMasterRejimi) {
      return _buildMasterPanel();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: _buildClientTabContent(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- CLIENT MODE TABS ---
  Widget _buildClientTabContent() {
    switch (_currentTab) {
      case 1:
        return _buildIlovaHaqidaTab();
      case 2:
        return _buildProfilTab();
      case 0:
      default:
        return _buildBoshSahifaTab();
    }
  }

  // --- 1. BOSH SAHIFA TAB ---
  Widget _buildBoshSahifaTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Logo left, notification bell right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF132F4C),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'A',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Inter'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'AVTOHELP',
                          style: TextStyle(color: Color(0xFF132F4C), fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter'),
                        ),
                        Text(
                          'Yo\'l yordami',
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_none, color: Color(0xFF132F4C)),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Title & Subtitle
            const Text(
              'Yo\'lda muammo bormi?',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Bir tugma bilan tezkor yordam chaqiring',
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 36),

            // HUGE pulsing help button in center
            Center(
              child: GestureDetector(
                onTap: () {
                  // Default help triggers Tow truck / Evakuator form
                  if (_services.isNotEmpty) {
                    final evakuator = _services.firstWhere(
                      (s) => s['name'].toString().toLowerCase().contains('evakuator'),
                      orElse: () => _services.first,
                    );
                    _navigateToOrderForm(evakuator);
                  }
                },
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF132F4C).withOpacity(1 - _pulseController.value),
                        border: Border.all(
                          color: const Color(0xFF132F4C).withOpacity(_pulseController.value),
                          width: 15 * _pulseController.value,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: const BoxDecoration(
                            color: Color(0xFF132F4C),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 15,
                                offset: Offset(0, 8),
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.phone_in_talk, size: 48, color: Colors.white),
                              SizedBox(height: 8),
                              Text(
                                'YORDAM SO\'RASH',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 36),

            // Location card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF132F4C).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on, color: Color(0xFF132F4C), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sizning joylashuvingiz',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentPlusCode,
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF132F4C)),
                    onPressed: _openLocationPicker,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Grid Xizmat Tanlang
            const Text(
              'Xizmat tanlang',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
            ),
            const SizedBox(height: 12),
            _isLoadingServices
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _services.length,
                    itemBuilder: (context, index) {
                      final s = _services[index];
                      return _buildServiceCard(s);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    // Pastel backgrounds for the 6 services
    Color cardBg = const Color(0xFFDBEAFE); // default pastel blue
    IconData iconData = Icons.build;
    final name = service['name'].toString().toLowerCase();

    if (name.contains('yuvish') || name.contains('wash')) {
      cardBg = const Color(0xFFFFF7CC); // pastel yellow
      iconData = Icons.local_car_wash;
    } else if (name.contains('moy') || name.contains('oil')) {
      cardBg = const Color(0xFFFFEDD5); // pastel orange
      iconData = Icons.opacity;
    } else if (name.contains('evakuator') || name.contains('towing')) {
      cardBg = const Color(0xFFFFE4E6); // pastel red
      iconData = Icons.local_shipping;
    } else if (name.contains('g\'ildirak') || name.contains('vulkanizatsiya') || name.contains('tire')) {
      cardBg = const Color(0xFFDCFCE7); // pastel green
      iconData = Icons.incomplete_circle;
    } else if (name.contains('akkumulyator') || name.contains('battery')) {
      cardBg = const Color(0xFFE9D5FF); // pastel purple
      iconData = Icons.battery_charging_full;
    } else if (name.contains('motor') || name.contains('engine')) {
      cardBg = const Color(0xFFE9D5FF); // pastel purple
      iconData = Icons.settings;
    } else if (name.contains('elektrik') || name.contains('repair')) {
      cardBg = const Color(0xFFDBEAFE); // pastel blue
      iconData = Icons.flash_on;
    }

    return GestureDetector(
      onTap: () => _navigateToOrderForm(service),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Icon in pastel round square
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: const Color(0xFF132F4C), size: 24),
            ),
            const SizedBox(height: 10),
            // Title
            Text(
              service['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontSize: 13, fontFamily: 'Inter'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToOrderForm(Map<String, dynamic> service) {
    if (_currentPosition == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateOrderScreen(
          masterProfile: const {'full_name': 'Tezkor usta', 'master_id': null}, // Auto dispatch
          serviceId: service['id'],
          basePrice: service['base_price'],
          userLocation: _currentPosition!,
        ),
      ),
    );
  }

  // --- 2. ILOVA HAQIDA TAB ---
  Widget _buildIlovaHaqidaTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFF132F4C),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'A',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 40, fontFamily: 'Inter'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Avtohelp — yo\'lda siz bilan!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
            ),
            const SizedBox(height: 24),
            // Badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF132F4C).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF132F4C).withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle_outline, color: Color(0xFF132F4C), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Hozir Qarshi shahrida xizmat ko\'rsatamiz',
                      style: TextStyle(color: Color(0xFF132F4C), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Description Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Text(
                'Avtohelp — yo\'lda qolgan haydovchilar uchun tezkor yordam ko\'rsatish xizmati. Bizning platformamiz orqali siz evakuator chaqirishingiz, g\'ildirakni almashtirishingiz, motor yoki elektrik nosozliklarini bartaraf etadigan ustani 3km radiusda topishingiz mumkin.\n\nBizning maqsadimiz — yo\'lingizni xavfsiz va ishonchli qilishdir.',
                style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Biz taqdim etadigan xizmatlar:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
            ),
            const SizedBox(height: 12),
            // List of services
            ..._services.map((s) => Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.arrow_right, color: Color(0xFF132F4C)),
                    title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF132F4C))),
                    subtitle: Text('Boshlang\'ich narx: ${(s['base_price'] as num).toLocaleString()} UZS'),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // --- 3. PROFIL TAB ---
  Widget _buildProfilTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: const Color(0xFF132F4C).withOpacity(0.1),
                    child: const Icon(Icons.person, size: 40, color: Color(0xFF132F4C)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userProfile['full_name'] ?? 'Avtohelp Foydalanuvchisi',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Client rejimi',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.userProfile['phone'] ?? '',
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Menu List
            _buildMenuItem(Icons.drive_eta, 'Mening avtomobillarim', () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userProfile: widget.userProfile)));
            }),
            _buildMenuItem(Icons.payment, 'To\'lov usullari', () {}),
            _buildMenuItem(Icons.settings, 'Sozlamalar', () {}),
            _buildMenuItem(Icons.help_outline, 'Yordam markazi', () {}),

            // Role Switch (Only available if DB role is MASTER or for demo testing)
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.handyman, color: Color(0xFF132F4C)),
                      SizedBox(width: 12),
                      Text(
                        'Usta rejimiga o\'tish',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF132F4C)),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isMasterRejimi,
                    activeColor: const Color(0xFF132F4C),
                    onChanged: (val) async {
                      if (widget.userProfile['role'] != 'MASTER') {
                        // Allow switching for demo testing: update role to MASTER in DB
                        try {
                          await _db.client.from('profiles').update({'role': 'MASTER'}).eq('id', widget.userProfile['id']);
                          widget.userProfile['role'] = 'MASTER';
                        } catch (e) {
                          print(e);
                        }
                      }
                      setState(() {
                        _isMasterRejimi = val;
                      });
                      if (val) {
                        _loadMasterData();
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
            // Logout
            OutlinedButton(
              onPressed: () {
                _db.signOut();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Chiqish', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF132F4C)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF132F4C))),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  // --- BOTTOM NAV BAR ---
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(0, Icons.home_outlined, Icons.home, 'Bosh sahifa'),
              _buildBottomNavItem(1, Icons.info_outline, Icons.info, 'Ilova haqida'),
              _buildBottomNavItem(2, Icons.person_outline, Icons.person, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData outlineIcon, IconData solidIcon, String label) {
    final isSelected = _currentTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade200 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(isSelected ? solidIcon : outlineIcon, color: const Color(0xFF132F4C)),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF132F4C), fontWeight: FontWeight.bold, fontSize: 13),
              )
            ]
          ],
        ),
      ),
    );
  }

  // =============================================================
  // USTA PANEL (MASTER MODE)
  // =============================================================
  Widget _buildMasterPanel() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Avtohelp Usta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        backgroundColor: const Color(0xFF132F4C),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Switch to Client mode
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            tooltip: 'Mijoz rejimiga o\'tish',
            onPressed: () {
              setState(() {
                _isMasterRejimi = false;
                _currentTab = 0;
              });
            },
          ),
        ],
      ),
      body: _isLoadingMasterData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Online / Offline toggle Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnline ? 'Hozir: ONLINE' : 'Hozir: OFFLINE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _isOnline ? const Color(0xFF10B981) : Colors.red,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isOnline ? 'Buyurtmalar olishga tayyorsiz' : 'Buyurtma olish uchun online bo\'ling',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isOnline,
                          activeColor: const Color(0xFF10B981),
                          onChanged: _toggleOnline,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. ACTIVE ORDER CARD (If master has an active order)
                  if (_activeMasterOrder != null) ...[
                    const Text(
                      'Faol buyurtma',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
                    ),
                    const SizedBox(height: 10),
                    _buildActiveOrderCard(),
                    const SizedBox(height: 24),
                  ],

                  // 3. STATS & EARNINGS CARD
                  _buildEarningsCard(),
                  const SizedBox(height: 24),

                  // 4. NEW PENDING ORDERS (If online and no active order)
                  if (_isOnline && _activeMasterOrder == null) ...[
                    const Text(
                      'Yangi buyurtmalar ro\'yxati (Atrofingizda)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
                    ),
                    const SizedBox(height: 10),
                    _newOrders.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: const Center(
                            child: Text(
                              'Hozircha yangi buyurtmalar yo\'q. Kuting...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : Column(
                          children: _newOrders.map((o) => _buildNewOrderCard(o)).toList(),
                        ),
                  ],

                  // 5. COMPLETED HISTORY
                  const SizedBox(height: 24),
                  const Text(
                    'Oxirgi bajarilgan buyurtmalar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 10),
                  _masterHistory.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text('Tarix bo\'sh.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                      )
                    : Column(
                        children: _masterHistory.map((h) => Card(
                          color: Colors.white,
                          child: ListTile(
                            leading: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                            title: Text(h['services']?['name'] ?? 'Xizmat'),
                            subtitle: Text(DateTime.parse(h['created_at'].toString()).toLocal().toString().substring(0, 10)),
                            trailing: Text('${(h['price'] as num).toLocaleString()} UZS', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        )).toList(),
                      ),
                ],
              ),
            ),
    );
  }

  Widget _buildActiveOrderCard() {
    final o = _activeMasterOrder!;
    final user = o['profiles_user'] ?? {};
    final service = o['services'] ?? {};
    final car = o['user_cars'] ?? {};
    final status = o['status'];

    String buttonLabel = "Yo'lga chiqish";
    String nextStatus = "ON_WAY";
    if (status == 'ON_WAY') {
      buttonLabel = "Yetib keldim (Ish boshlash)";
      nextStatus = "ARRIVED";
    } else if (status == 'ARRIVED') {
      buttonLabel = "Ishni yakunlash (Tugatish)";
      nextStatus = "DONE";
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                service['name'] ?? 'Xizmat',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF132F4C)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF132F4C).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  status,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF132F4C)),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text('Mijoz: ${user['full_name'] ?? 'Noma\'lum'}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Telefon: ${user['phone'] ?? ''}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 4),
          Text('Manzil: ${o['user_address'] ?? ''}', style: const TextStyle(color: Colors.black54)),
          if (car.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Avto: ${car['plate'] ?? ''} - ${car['year'] ?? ''}-yil', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ],
          const SizedBox(height: 16),
          // Stepper representation
          _buildMasterStepper(status),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _updateOrderStatus(o['id'], nextStatus),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF132F4C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterStepper(String status) {
    int activeStep = 0;
    if (status == 'ACCEPTED') activeStep = 1;
    if (status == 'ON_WAY') activeStep = 2;
    if (status == 'ARRIVED') activeStep = 3;

    final steps = ['Qabul', 'Yo\'lda', 'Ishda'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (i) {
        final completed = i < activeStep;
        final current = i == activeStep;
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: completed || current ? const Color(0xFF132F4C) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                steps[i],
                style: TextStyle(color: completed || current ? Colors.white : Colors.black54, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            if (i < 2) Container(width: 20, height: 2, color: i < activeStep ? const Color(0xFF132F4C) : Colors.grey.shade300),
          ],
        );
      }),
    );
  }

  Widget _buildNewOrderCard(Map<String, dynamic> o) {
    final user = o['profiles_user'] ?? {};
    final service = o['services'] ?? {};
    
    // Simulate distance randomly for Qarshi (between 0.8 and 4.2 km)
    final double distance = 0.8 + (o['id'].hashCode % 10) * 0.35;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                service['name'] ?? 'Xizmat',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF132F4C)),
              ),
              Text(
                '${(o['price'] as num).toLocaleString()} UZS',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Mijoz: ${user['full_name'] ?? 'Mijoz'}', style: const TextStyle(fontSize: 13)),
          Text('Masofa: ${distance.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectOrder(o['id']),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Rad etish'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptOrder(o['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF132F4C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Qabul qilish'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mening daromadim',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '${_masterEarnings.toLocaleString()} UZS',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bajarilgan buyurtmalar: ${_masterHistory.length} ta',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Icon(Icons.trending_up, color: Color(0xFF34D399)),
            ],
          )
        ],
      ),
    );
  }
}

// Helper class for number formatting
extension NumberFormatting on num {
  String toLocaleString() {
    final str = toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0 && str[i] != '-') {
        buffer.write(' ');
      }
      buffer.write(str[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join('');
  }
}
