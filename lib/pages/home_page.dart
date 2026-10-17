import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/marker_detail.dart';
import '../services/api_service.dart';
import '../services/bus_storage.dart';
import '../utils/constants.dart';
import '../widgets/bus_chip.dart';
import '../widgets/curved_header.dart';
import '../widgets/menu_card.dart';
import 'map_page.dart';
import 'eta_page.dart';
import 'etd_page.dart';
import 'nearby_buses_page.dart';
import 'contact_us.dart';
import 'grievance_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BusStorage _busStorage = BusStorage();
  final ApiService _apiService = ApiService();

  List<String> _savedBuses = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSavedBuses();
  }

  Future<void> _loadSavedBuses() async {
    setState(() => _isLoading = true);
    final buses = await _busStorage.getBuses();
    if (mounted) {
      setState(() {
        _savedBuses = buses;
        _isLoading = false;
      });
    }
  }

  Future<void> _addBusDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Add Bus to Track', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter 4-digit bus number (e.g. 2401):',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: 'e.g. 2401',
                  prefixIcon: const Icon(Icons.directions_bus_rounded, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  counterText: '',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a bus number';
                  }
                  if (val.trim().length < 2) {
                    return 'Number too short';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final busNum = controller.text.trim();
                final added = await _busStorage.addBus(busNum);
                if (added) {
                  Navigator.pop(ctx);
                  _loadSavedBuses();
                  Fluttertoast.showToast(msg: 'Bus #$busNum added to tracking list');
                } else {
                  Fluttertoast.showToast(msg: 'Bus #$busNum is already in your list');
                }
              }
            },
            child: const Text('Add Bus'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeBus(String busNumber) async {
    await _busStorage.removeBus(busNumber);
    _loadSavedBuses();
    Fluttertoast.showToast(msg: 'Bus #$busNumber removed');
  }

  /// Search single bus and navigate to map
  Future<void> _searchSingleBus(String busNumber) async {
    setState(() => _isSearching = true);
    Fluttertoast.showToast(msg: 'Searching Bus #$busNumber...');

    try {
      final marker = await _apiService.trackBus(busNumber);
      if (mounted) {
        setState(() => _isSearching = false);
        if (marker != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => MapPage(
                initialBuses: [marker],
                searchNumbers: [busNumber],
              ),
            ),
          );
        } else {
          _showNoRecordDialog(busNumber);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        Fluttertoast.showToast(msg: 'Error tracking bus #$busNumber');
      }
    }
  }

  /// Batch search ALL saved buses simultaneously (No Captcha!)
  Future<void> _searchAllBuses() async {
    if (_savedBuses.isEmpty) {
      Fluttertoast.showToast(msg: 'Please add bus numbers first');
      _addBusDialog();
      return;
    }

    setState(() => _isSearching = true);

    try {
      final foundBuses = await _apiService.trackMultipleBuses(_savedBuses);

      if (mounted) {
        setState(() => _isSearching = false);

        if (foundBuses.isNotEmpty) {
          Fluttertoast.showToast(
            msg: 'Found ${foundBuses.length} active bus(es) out of ${_savedBuses.length}',
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => MapPage(
                initialBuses: foundBuses,
                searchNumbers: List.from(_savedBuses),
              ),
            ),
          );
        } else {
          _showBatchNotFoundDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        Fluttertoast.showToast(msg: 'Failed to search buses: $e');
      }
    }
  }

  void _showNoRecordDialog(String busNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.info_outline_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('No Active Signal'),
          ],
        ),
        content: Text('Bus #$busNumber currently has no active GPS data or is not in service right now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              // Open map view anyway
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => MapPage(
                    initialBuses: const [],
                    searchNumbers: [busNumber],
                  ),
                ),
              );
            },
            child: const Text('Open Map Anyway', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBatchNotFoundDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.info_outline_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('No Active Buses Found'),
          ],
        ),
        content: Text(
          'None of your ${_savedBuses.length} saved buses (${_savedBuses.join(", ")}) currently have active GPS transmissions on the server.\n\nBuses may be idle, parked, or offline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => MapPage(
                    initialBuses: const [],
                    searchNumbers: List.from(_savedBuses),
                  ),
                ),
              );
            },
            child: const Text('Open Map', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // PunBus Header with branding
              SliverToBoxAdapter(
                child: CurvedHeader(
                  title: 'PunBus Tracker',
                  subtitle: 'Punjab Roadways & PUNBUS Live Tracking',
                  leading: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icons/punbus_icon.png',
                      width: 44,
                      height: 44,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.directions_bus_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
                  height: 180,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Instant Multi-Bus Tracking • No Captcha',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // "My Buses" Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Card(
                    elevation: 3,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.bookmark_added_rounded, color: AppColors.primary, size: 22),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'My Buses',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_savedBuses.length}',
                                      style: const TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add Bus', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _addBusDialog,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_isLoading)
                            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                          else if (_savedBuses.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.directions_bus_outlined, size: 40, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    const Text('No saved buses yet', style: TextStyle(color: AppColors.textMuted)),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryLight,
                                        foregroundColor: AppColors.primaryDark,
                                        elevation: 0,
                                      ),
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Add 4-Digit Bus Number'),
                                      onPressed: _addBusDialog,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _savedBuses.map((bus) {
                                return BusChip(
                                  busNumber: bus,
                                  onTap: () => _searchSingleBus(bus),
                                  onRemove: () => _removeBus(bus),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 16),
                          // Big Prominent "🔍 Search All Buses" Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _isSearching ? null : _searchAllBuses,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.search_rounded, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    '🔍 Search All Buses Simultaneously',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Menu Options Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Services & Features',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 10),
                      MenuCard(
                        title: 'Live Tracking',
                        subtitle: 'Instant GPS tracking for all your saved buses',
                        iconAsset: 'assets/icons/bus_track.png',
                        accentColor: AppColors.primary,
                        onTap: _searchAllBuses,
                      ),
                      const SizedBox(height: 8),
                      MenuCard(
                        title: 'Nearby Buses',
                        subtitle: 'Find buses around your current live location',
                        iconAsset: 'assets/icons/nearby_buss.png',
                        accentColor: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (ctx) => const NearbyBusesPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      MenuCard(
                        title: 'ETA (Arrival Time)',
                        subtitle: 'Estimated time of bus arrival by station',
                        iconAsset: 'assets/icons/arrival.svg',
                        accentColor: Colors.indigo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (ctx) => const EtaPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      MenuCard(
                        title: 'ETD (Departure Time)',
                        subtitle: 'Bus timetable and departures from stop',
                        iconAsset: 'assets/icons/departure.svg',
                        accentColor: Colors.deepOrange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (ctx) => const EtdPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      MenuCard(
                        title: 'Grievance Portal',
                        subtitle: 'Register complaint or feedback with Punjab Govt',
                        iconAsset: 'assets/icons/grievance.svg',
                        accentColor: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (ctx) => const GrievancePage()),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      MenuCard(
                        title: 'Contact Us',
                        subtitle: 'Helpline numbers, depots, and support info',
                        iconAsset: 'assets/icons/contacts.svg',
                        accentColor: Colors.blueGrey,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (ctx) => const ContactUsPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay
          if (_isSearching)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/movingbus.gif',
                          width: 80,
                          height: 50,
                          errorBuilder: (_, __, ___) => const CircularProgressIndicator(color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tracking Saved Buses...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Querying live server simultaneously without captcha',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
