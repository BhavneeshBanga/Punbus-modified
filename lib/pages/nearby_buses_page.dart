import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/marker_detail.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/curved_header.dart';
import 'map_page.dart';

class NearbyBusesPage extends StatefulWidget {
  const NearbyBusesPage({super.key});

  @override
  State<NearbyBusesPage> createState() => _NearbyBusesPageState();
}

class _NearbyBusesPageState extends State<NearbyBusesPage> {
  final Completer<GoogleMapController> _controllerCompleter = Completer();
  final ApiService _apiService = ApiService();

  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isFetchingBuses = false;
  List<MarkerDetail> _nearbyBuses = [];
  Set<Marker> _markers = {};
  BitmapDescriptor? _busIcon;

  static const CameraPosition _defaultPunjabPosition = CameraPosition(
    target: LatLng(30.9010, 75.8573),
    zoom: 10,
  );

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    _determinePosition();
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
        });
      }
    } catch (_) {}
  }

  Future<void> _determinePosition() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Fluttertoast.showToast(msg: 'Location services are disabled');
        _setDefaultPosition();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Fluttertoast.showToast(msg: 'Location permissions are denied');
          _setDefaultPosition();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Fluttertoast.showToast(msg: 'Location permissions are permanently denied');
        _setDefaultPosition();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });

        final controller = await _controllerCompleter.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 12.0,
            ),
          ),
        );

        _fetchNearbyBuses(position.latitude, position.longitude);
      }
    } catch (e) {
      _setDefaultPosition();
    }
  }

  void _setDefaultPosition() {
    if (mounted) {
      setState(() {
        _isLoadingLocation = false;
      });
      _fetchNearbyBuses(30.9010, 75.8573);
    }
  }

  Future<void> _fetchNearbyBuses(double lat, double lng) async {
    setState(() => _isFetchingBuses = true);

    try {
      final buses = await _apiService.getNearbyBuses(lat: lat, lng: lng);

      if (mounted) {
        setState(() {
          _nearbyBuses = buses;
          _isFetchingBuses = false;
        });

        _buildMarkers();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingBuses = false);
      }
    }
  }

  void _buildMarkers() {
    final markers = <Marker>{};

    // User position marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_pos'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'My Location'),
        ),
      );
    }

    // Bus markers
    for (final bus in _nearbyBuses) {
      if (!bus.hasValidLocation) continue;

      markers.add(
        Marker(
          markerId: MarkerId(bus.busId.isNotEmpty ? bus.busId : bus.regNo),
          position: LatLng(bus.latitude, bus.longitude),
          icon: _busIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          rotation: bus.bearing,
          infoWindow: InfoWindow(
            title: bus.displayTitle,
            snippet: '${bus.routeName} • ${bus.speedFormatted}',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _defaultPunjabPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              if (!_controllerCompleter.isCompleted) {
                _controllerCompleter.complete(controller);
              }
            },
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CurvedHeader(
              title: 'Nearby Buses',
              subtitle: 'Buses around your current location',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              height: 140,
            ),
          ),

          // Bottom card showing count / status
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.radar_rounded, color: Colors.teal),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isLoadingLocation
                                    ? 'Acquiring GPS location...'
                                    : '${_nearbyBuses.length} Nearby Bhav vehicles found',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isFetchingBuses
                                    ? 'Scanning nearby routes...'
                                    : 'Real-time GPS positioning active',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                          onPressed: _determinePosition,
                        ),
                      ],
                    ),
                    if (_nearbyBuses.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.map_rounded),
                          label: const Text('View All In Live Map'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => MapPage(
                                  initialBuses: _nearbyBuses,
                                  searchNumbers: _nearbyBuses.map((b) => b.regNo).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
