import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/marker_detail.dart';
import '../services/api_service.dart';
import '../services/bus_storage.dart';
import '../utils/constants.dart';

class MapPage extends StatefulWidget {
  final List<MarkerDetail> initialBuses;
  final List<String> searchNumbers;

  const MapPage({
    super.key,
    required this.initialBuses,
    required this.searchNumbers,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _controllerCompleter = Completer();
  final ApiService _apiService = ApiService();
  final BusStorage _busStorage = BusStorage();

  List<MarkerDetail> _buses = [];
  Set<Marker> _markers = {};
  bool _isRefreshing = false;
  BitmapDescriptor? _busIcon;
  MarkerDetail? _selectedBus;

  // Default center (Punjab - Chandigarh/Jalandhar/Ludhiana region)
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(30.9010, 75.8573), // Ludhiana center of Punjab
    zoom: 7.5,
  );

  @override
  void initState() {
    super.initState();
    _buses = List.from(widget.initialBuses);
    _loadCustomMarker();
    _updateMarkers();
  }

  Future<void> _loadCustomMarker() async {
    try {
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(44, 44)),
        'assets/icons/bus_topview48x48.png',
      );
      if (mounted) {
        setState(() {
          _busIcon = icon;
          _updateMarkers();
        });
      }
    } catch (_) {
      // Fallback to default marker if asset loading fails
    }
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    for (final bus in _buses) {
      if (!bus.hasValidLocation) continue;

      markers.add(
        Marker(
          markerId: MarkerId(bus.busId.isNotEmpty ? bus.busId : bus.regNo),
          position: LatLng(bus.latitude, bus.longitude),
          rotation: bus.bearing,
          icon: _busIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: bus.displayTitle,
            snippet: '${bus.routeName} • ${bus.speedFormatted}',
            onTap: () => _showBusDetailSheet(bus),
          ),
          onTap: () {
            setState(() => _selectedBus = bus);
            _showBusDetailSheet(bus);
          },
        ),
      );
    }

    setState(() {
      _markers = markers;
    });

    _fitBounds();
  }

  Future<void> _fitBounds() async {
    final validBuses = _buses.where((b) => b.hasValidLocation).toList();
    if (validBuses.isEmpty) return;

    final controller = await _controllerCompleter.future;

    if (validBuses.length == 1) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(validBuses.first.latitude, validBuses.first.longitude),
            zoom: 14.0,
          ),
        ),
      );
      return;
    }

    double minLat = validBuses.first.latitude;
    double maxLat = validBuses.first.latitude;
    double minLng = validBuses.first.longitude;
    double maxLng = validBuses.first.longitude;

    for (final bus in validBuses) {
      if (bus.latitude < minLat) minLat = bus.latitude;
      if (bus.latitude > maxLat) maxLat = bus.latitude;
      if (bus.longitude < minLng) minLng = bus.longitude;
      if (bus.longitude > maxLng) maxLng = bus.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  /// Re-fetch all bus locations simultaneously (No Captcha!)
  Future<void> _refreshBuses() async {
    setState(() => _isRefreshing = true);
    Fluttertoast.showToast(msg: 'Updating bus locations...');

    try {
      final numbers = widget.searchNumbers.isNotEmpty
          ? widget.searchNumbers
          : await _busStorage.getBuses();

      final updatedBuses = await _apiService.trackMultipleBuses(numbers);

      if (mounted) {
        setState(() {
          _buses = updatedBuses;
          _isRefreshing = false;
        });

        _updateMarkers();

        Fluttertoast.showToast(
          msg: updatedBuses.isNotEmpty
              ? 'Updated ${updatedBuses.length} active bus(es)'
              : 'No active signals received',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        Fluttertoast.showToast(msg: 'Failed to refresh: $e');
      }
    }
  }

  void _showBusDetailSheet(MarkerDetail bus) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.displayTitle,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    Text(
                      bus.vehType.isNotEmpty ? 'Type: ${bus.vehType}' : 'Punjab Roadways / PunBus',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: bus.isMoving ? Colors.green[50] : Colors.amber[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: bus.isMoving ? Colors.green : Colors.amber.shade800,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        bus.isMoving ? Icons.speed_rounded : Icons.pause_circle_outline_rounded,
                        size: 16,
                        color: bus.isMoving ? Colors.green : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        bus.speedFormatted,
                        style: TextStyle(
                          color: bus.isMoving ? Colors.green.shade800 : Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow(Icons.alt_route_rounded, 'Route', bus.routeName),
            if (bus.stopName.isNotEmpty)
              _buildDetailRow(Icons.place_rounded, 'Next Stop', bus.stopName),
            if (bus.arvlTm.isNotEmpty)
              _buildDetailRow(Icons.schedule_rounded, 'Arrival Time (ETA)', bus.arvlTm),
            if (bus.sTime.isNotEmpty)
              _buildDetailRow(Icons.timelapse_rounded, 'Scheduled Time', bus.sTime),
            if (bus.lastUpdated.isNotEmpty)
              _buildDetailRow(Icons.update_rounded, 'Last Updated', bus.lastUpdated),
            _buildDetailRow(
              Icons.my_location_rounded,
              'Coordinates',
              '${bus.latitude.toStringAsFixed(5)}, ${bus.longitude.toStringAsFixed(5)}',
            ),
            if (bus.mobile.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.call_rounded),
                  label: Text('Call Crew (${bus.mobile})'),
                  onPressed: () => _callNumber(bus.mobile),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Multi-Bus Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              '${_markers.length} Active Bus${_markers.length == 1 ? '' : 'es'} On Map',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Fit all buses',
            icon: const Icon(Icons.crop_free_rounded),
            onPressed: _fitBounds,
          ),
          IconButton(
            tooltip: 'Refresh locations',
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isRefreshing ? null : _refreshBuses,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              if (!_controllerCompleter.isCompleted) {
                _controllerCompleter.complete(controller);
              }
              _fitBounds();
            },
          ),

          // Top Info Banner
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _buses.isEmpty
                          ? 'No buses with live transmission found right now.'
                          : 'Tap any bus marker for real-time ETA, route, and crew details.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Horizontal Bus Selector Carousel
          if (_buses.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _buses.length,
                itemBuilder: (ctx, idx) {
                  final bus = _buses[idx];
                  final isSelected = _selectedBus == bus;

                  return GestureDetector(
                    onTap: () async {
                      setState(() => _selectedBus = bus);
                      if (bus.hasValidLocation) {
                        final controller = await _controllerCompleter.future;
                        controller.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: LatLng(bus.latitude, bus.longitude),
                              zoom: 15.0,
                            ),
                          ),
                        );
                      }
                      _showBusDetailSheet(bus);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryDark : Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.directions_bus_rounded,
                            color: isSelected ? Colors.white : AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                bus.displayTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isSelected ? Colors.white : AppColors.textDark,
                                ),
                              ),
                              Text(
                                bus.speedFormatted,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected ? Colors.white70 : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
