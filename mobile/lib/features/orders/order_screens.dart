import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:master_help/core/supabase_client.dart';

// -------------------------------------------------------------
// 1. CREATE ORDER SCREEN (Buyurtma formi)
// -------------------------------------------------------------
class CreateOrderScreen extends StatefulWidget {
  final Map<String, dynamic> masterProfile;
  final int serviceId;
  final int basePrice;
  final Position userLocation;

  const CreateOrderScreen({
    Key? key,
    required this.masterProfile,
    required this.serviceId,
    required this.basePrice,
    required this.userLocation,
  }) : super(key: key);

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final SupabaseService _db = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  late double _selectedLat;
  late double _selectedLng;
  String _addressText = "Xaritadan joyni belgilang >";
  
  final TextEditingController _phoneController = TextEditingController(text: '+998');
  final TextEditingController _detailsController = TextEditingController();
  
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isUrgent = false;
  
  bool _creatingOrder = false;

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.userLocation.latitude;
    _selectedLng = widget.userLocation.longitude;
    _addressText = "Belgilangan nuqta: ${_selectedLat.toStringAsFixed(4)}, ${_selectedLng.toStringAsFixed(4)}";
    
    // Prefill phone from user if logged in
    final user = _db.client.auth.currentUser;
    if (user != null && user.phone != null && user.phone!.isNotEmpty) {
      _phoneController.text = user.phone!;
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  void _openMapPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Chaqirish joyini belgilang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF132F4C))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_selectedLat, _selectedLng),
                      zoom: 15.0,
                    ),
                    myLocationEnabled: true,
                    onTap: (LatLng latLng) {
                      setState(() {
                        _selectedLat = latLng.latitude;
                        _selectedLng = latLng.longitude;
                        _addressText = "Belgilangan nuqta: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Joylashuvni tasdiqlash uchun xaritadagi kerakli nuqtaga bosing.', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isUrgent && _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iltimos, vaqtni tanlang yoki "Hozir" tugmasini bosing!')),
      );
      return;
    }

    setState(() {
      _creatingOrder = true;
    });

    try {
      final locationWkt = 'POINT($_selectedLng $_selectedLat)';
      final extraDetails = _detailsController.text.trim();
      final timeRangeText = _isUrgent 
          ? "HOZIR (Shoshilinch ariza)"
          : "Boshlanish: ${_startTime!.format(context)}" + (_endTime != null ? " - Tugash: ${_endTime!.format(context)}" : "");

      // 1. Fetch user car (default to a mock car if none exist)
      final cars = await _db.client.from('user_cars').select().eq('user_id', _db.currentUserId!);
      String? carId;
      if (cars.isNotEmpty) {
        carId = cars.first['id'];
      } else {
        // Create a default mock car to prevent foreign key errors
        final newCar = await _db.client.from('user_cars').insert({
          'user_id': _db.currentUserId!,
          'brand_id': 1,
          'model_id': 1,
          'year': 2022,
          'plate': '01A777AA'
        }).select().single();
        carId = newCar['id'];
      }

      // 2. Insert order
      final response = await _db.client.from('orders').insert({
        'user_id': _db.currentUserId!,
        'master_id': widget.masterProfile['master_id'], // Can be null for auto dispatch
        'user_car_id': carId,
        'service_id': widget.serviceId,
        'status': 'PENDING',
        'user_location': locationWkt,
        'user_address': 'Qarshi, O\'zbekiston | $timeRangeText' + (extraDetails.isNotEmpty ? ' | $extraDetails' : ''),
        'price': widget.basePrice,
      }).select().single();

      // 3. Trigger FCM Push Notification
      try {
        await _db.client.functions.invoke('send-push', body: {
          'user_id': widget.masterProfile['master_id'] ?? 'ALL_MASTERS',
          'title': 'Yangi yordam so\'rovi!',
          'body': 'Avtohelp tizimida yangi buyurtma yaratildi.',
          'data': {'order_id': response['id']}
        });
      } catch (_) {}

      setState(() {
        _creatingOrder = false;
      });

      // Go to tracking screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingScreen(orderId: response['id']),
        ),
      );
    } catch (e) {
      setState(() {
        _creatingOrder = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik yuz berdi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Xizmat chaqirish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
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
              // 1. Chaqirish joyi card selector
              const Text('Xizmat chaqirish joyi *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF132F4C))),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _openMapPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _addressText,
                          style: TextStyle(color: _addressText.contains('>') ? Colors.grey : const Color(0xFF132F4C), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.map, color: Color(0xFF132F4C)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Phone Input
              const Text('Telefon raqam *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF132F4C))),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF132F4C)),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    prefixIcon: Icon(Icons.phone, color: Color(0xFF132F4C)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Telefon raqamingizni kiriting' : null,
                ),
              ),
              const SizedBox(height: 20),

              // 3. Time Section — Hozir or custom time
              const Text('Vaqti *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF132F4C))),
              const SizedBox(height: 10),
              // HOZIR (urgent) button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isUrgent = !_isUrgent;
                    if (_isUrgent) {
                      _startTime = null;
                      _endTime = null;
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: _isUrgent ? const Color(0xFF132F4C) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isUrgent ? const Color(0xFF132F4C) : const Color(0xFFE53E3E),
                      width: 2,
                    ),
                    boxShadow: _isUrgent ? [
                      BoxShadow(color: const Color(0xFF132F4C).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                    ] : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flash_on_rounded,
                        color: _isUrgent ? Colors.amber : const Color(0xFFE53E3E),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isUrgent ? 'Shoshilinch ariza yuboriladi!' : 'HOZIR — Tezkor yordam',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _isUrgent ? Colors.white : const Color(0xFFE53E3E),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_isUrgent) ...[
                const SizedBox(height: 12),
                const Text('yoki vaqt belgilang:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectStartTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Center(
                            child: Text(
                              _startTime == null ? 'Boshlanish --:--' : 'Boshlanish: ${_startTime!.format(context)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectEndTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Center(
                            child: Text(
                              _endTime == null ? 'Tugash (ixtiyoriy)' : 'Tugash: ${_endTime!.format(context)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // 4. Extra Info Textarea
              const Text('Qo\'shimcha ma\'lumot', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF132F4C))),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextFormField(
                  controller: _detailsController,
                  maxLines: 4,
                  style: const TextStyle(color: Color(0xFF132F4C)),
                  decoration: const InputDecoration(
                    hintText: 'Masalan: 3-qavat, kirish oldida kuting...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 5. Submit Button
              ElevatedButton(
                onPressed: _creatingOrder ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF132F4C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _creatingOrder
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'So\'rov yuborish',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. ORDER TRACKING SCREEN (Real-time tracking)
// -------------------------------------------------------------
class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final SupabaseService _db = SupabaseService();
  StreamSubscription? _orderSubscription;
  StreamSubscription? _masterLocationSubscription;

  Map<String, dynamic>? _order;
  Map<String, dynamic>? _masterProfile;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _subscribeToOrder();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _masterLocationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToOrder() {
    _orderSubscription = _db.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', widget.orderId)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            final order = data.first;
            setState(() {
              _order = order;
            });

            if (_masterProfile == null && order['master_id'] != null) {
              _loadMasterAndSubscribe(order['master_id']);
            }

            if (order['status'] == 'DONE') {
              _orderSubscription?.cancel();
              _masterLocationSubscription?.cancel();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => RatingScreen(order: order)),
              );
            }
          }
        });
  }

  Future<void> _loadMasterAndSubscribe(String masterId) async {
    final master = await _db.client.from('profiles').select().eq('id', masterId).single();
    setState(() {
      _masterProfile = master;
    });

    _masterLocationSubscription = _db.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', masterId)
        .listen((List<Map<String, dynamic>> profiles) {
          if (profiles.isNotEmpty) {
            final profile = profiles.first;
            setState(() {
              _masterProfile = profile;
              _updateTrackingMarkers();
            });
          }
        });
  }

  void _updateTrackingMarkers() {
    if (_order == null) return;
    final newMarkers = <Marker>{};

    // User location (Qarshi coordinates)
    newMarkers.add(
      const Marker(
        markerId: MarkerId('user'),
        position: LatLng(38.8612, 65.7847),
        infoWindow: InfoWindow(title: 'Sizning joylashuvingiz'),
      ),
    );

    // Master location (simulated or real)
    if (_masterProfile != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('master'),
          position: const LatLng(38.8632, 65.7877),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Usta yo\'lda'),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_order == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final status = _order!['status'];

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _updateTrackingMarkers();
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(38.8612, 65.7847),
              zoom: 14.5,
            ),
            markers: _markers,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _getStatusText(status),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF132F4C), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 20),
                  _buildStepper(status),
                  const SizedBox(height: 20),
                  if (_masterProfile != null) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF132F4C).withOpacity(0.1),
                          child: const Icon(Icons.person, color: Color(0xFF132F4C)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _masterProfile!['full_name'] ?? 'Usta',
                              style: const TextStyle(color: Color(0xFF132F4C), fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _masterProfile!['phone'] ?? '',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(String status) {
    int activeStep = 0;
    if (status == 'ACCEPTED') activeStep = 1;
    if (status == 'ON_WAY') activeStep = 2;
    if (status == 'ARRIVED') activeStep = 3;
    if (status == 'DONE') activeStep = 4;

    final steps = ['Chaqiruv', 'Qabul', 'Yo\'lda', 'Ishda'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) {
        final isCompleted = index < activeStep;
        final isActive = index == activeStep;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted || isActive ? const Color(0xFF132F4C) : Colors.grey.shade300,
                  border: isActive ? Border.all(color: Colors.white, width: 2) : null,
                ),
                child: Center(
                  child: Icon(
                    index < activeStep ? Icons.check : Icons.circle,
                    size: index < activeStep ? 14 : 8,
                    color: isCompleted || isActive ? Colors.white : Colors.black38,
                  ),
                ),
              ),
              if (index < 3)
                Expanded(
                  child: Container(
                    height: 3,
                    color: index < activeStep ? const Color(0xFF132F4C) : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'Usta javobi kutilmoqda...';
      case 'ACCEPTED':
        return 'Usta qabul qildi!';
      case 'ON_WAY':
        return 'Usta yo\'lda kelmoqda...';
      case 'ARRIVED':
        return 'Usta yetib keldi va ish boshladi!';
      case 'DONE':
        return 'Buyurtma bajarildi!';
      case 'CANCELLED':
        return 'Buyurtma bekor qilindi.';
      default:
        return 'Kuzatilmoqda...';
    }
  }
}

// -------------------------------------------------------------
// 3. RATING SCREEN
// -------------------------------------------------------------
class RatingScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const RatingScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final SupabaseService _db = SupabaseService();
  int _stars = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  Future<void> _submitRating() async {
    setState(() {
      _submitting = true;
    });

    try {
      await _db.client.from('ratings').insert({
        'order_id': widget.order['id'],
        'from_user': widget.order['user_id'],
        'to_master': widget.order['master_id'],
        'stars': _stars,
        'comment': _commentController.text.trim(),
      });

      // Update completed orders counter for master
      try {
        final masterId = widget.order['master_id'];
        final profileRes = await _db.client.from('master_profiles').select('completed_orders').eq('id', masterId).single();
        final count = (profileRes['completed_orders'] as int? ?? 0) + 1;
        await _db.client.from('master_profiles').update({'completed_orders': count}).eq('id', masterId);
      } catch (_) {}

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      setState(() {
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Baho berishda xatolik: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Color(0xFF132F4C)),
              const SizedBox(height: 24),
              const Text(
                'Xizmat bajarildi!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF132F4C), fontFamily: 'Inter'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Iltimos, ustaning xizmat sifatini baholang.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _stars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                    onPressed: () {
                      setState(() {
                        _stars = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _commentController,
                  maxLines: 3,
                  style: const TextStyle(color: Color(0xFF132F4C)),
                  decoration: const InputDecoration(
                    labelText: 'Fikr-mulohaza (ixtiyoriy)',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _submitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF132F4C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _submitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Baholash va tugatish',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
