import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/route_model.dart';
import '../models/marker_detail.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/curved_header.dart';
import 'map_page.dart';

class EtaPage extends StatefulWidget {
  const EtaPage({super.key});

  @override
  State<EtaPage> createState() => _EtaPageState();
}

class _EtaPageState extends State<EtaPage> {
  final ApiService _apiService = ApiService();

  // Common Punjab bus stops
  final List<Map<String, String>> _stations = [
    {'id': '1', 'name': 'ISBT Sector 43, Chandigarh'},
    {'id': '2', 'name': 'ISBT Sector 17, Chandigarh'},
    {'id': '3', 'name': 'ISBT Jalandhar (Shaheed Bhagat Singh)'},
    {'id': '4', 'name': 'General Bus Stand, Amritsar'},
    {'id': '5', 'name': 'ISBT Ludhiana'},
    {'id': '6', 'name': 'Bus Stand Patiala'},
    {'id': '7', 'name': 'Bus Stand Bathinda'},
    {'id': '8', 'name': 'Bus Stand Pathankot'},
    {'id': '9', 'name': 'Bus Stand Hoshiarpur'},
    {'id': '10', 'name': 'Bus Stand Ferozepur'},
    {'id': '11', 'name': 'Bus Stand Mohali (Phase 8)'},
    {'id': '12', 'name': 'Bus Stand Ropar'},
  ];

  String? _selectedStationId;
  String _selectedStationName = '';
  List<RouteItem> _routes = [];
  bool _isLoading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _selectedStationId = _stations.first['id'];
    _selectedStationName = _stations.first['name']!;
  }

  Future<void> _fetchEta() async {
    if (_selectedStationId == null) return;

    setState(() {
      _isLoading = true;
      _searched = true;
    });

    final routes = await _apiService.getEtaRoutes(_selectedStationId!);

    if (mounted) {
      setState(() {
        _routes = routes;
        _isLoading = false;
      });

      if (routes.isEmpty) {
        Fluttertoast.showToast(msg: 'No incoming buses reported for this station right now');
      }
    }
  }

  Future<void> _trackRouteBus(RouteItem route) async {
    final busNo = route.regNo ?? route.vehId;
    if (busNo == null || busNo.isEmpty) {
      Fluttertoast.showToast(msg: 'No bus registration available for this route');
      return;
    }

    Fluttertoast.showToast(msg: 'Tracking Bus #$busNo...');
    final marker = await _apiService.trackBus(busNo);
    if (mounted) {
      if (marker != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => MapPage(
              initialBuses: [marker],
              searchNumbers: [busNo],
            ),
          ),
        );
      } else {
        // Navigate to map centered on station
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => MapPage(
              initialBuses: [
                MarkerDetail(
                  busId: busNo,
                  regNo: busNo,
                  routeName: route.routeName,
                  latitude: 30.9010,
                  longitude: 75.8573,
                  arvlTm: route.arrivalTime ?? 'Approaching',
                ),
              ],
              searchNumbers: [busNo],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          CurvedHeader(
            title: 'ETA Search',
            subtitle: 'Estimated Time of Arrival',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            height: 160,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Card(
              elevation: 2.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Arrival Station',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStationId,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                          items: _stations.map((st) {
                            return DropdownMenuItem<String>(
                              value: st['id'],
                              child: Text(st['name']!, style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedStationId = val;
                                _selectedStationName = _stations.firstWhere((e) => e['id'] == val)['name']!;
                                _searched = false;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Find Arriving Buses'),
                        onPressed: _isLoading ? null : _fetchEta,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : !_searched
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_bus_outlined, size: 54, color: Colors.grey[350]),
                            const SizedBox(height: 10),
                            const Text(
                              'Select a station above to view live arrival times',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : _routes.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.departure_board_rounded, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No incoming buses scheduled for\n$_selectedStationName right now.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Check back closer to peak departure hours.',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _routes.length,
                            itemBuilder: (ctx, idx) {
                              final route = _routes[idx];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.primaryLight,
                                    child: Icon(Icons.directions_bus_rounded, color: AppColors.primaryDark),
                                  ),
                                  title: Text(route.routeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text(
                                    'Bus: ${route.regNo ?? 'N/A'} • ETA: ${route.arrivalTime ?? 'In Transit'}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                  trailing: const Icon(Icons.gps_fixed_rounded, color: AppColors.primary, size: 20),
                                  onTap: () => _trackRouteBus(route),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
