import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/marker_detail.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

/// Live single-bus tracker page.
/// - Auto-refreshes at custom user-configured interval (milliseconds).
/// - Smooth marker animation (Uber/Ola style) between GPS points.
/// - Bus icon rotates smoothly along shortest angular distance.
/// - Camera NEVER resets zoom/pan — user has complete interactive control.
class TrackBusPage extends StatefulWidget {
  final String busNumber;
  final int initialRefreshIntervalMs;

  const TrackBusPage({
    super.key,
    required this.busNumber,
    this.initialRefreshIntervalMs = 2000,
  });

  @override
  State<TrackBusPage> createState() => _TrackBusPageState();
}

class _TrackBusPageState extends State<TrackBusPage>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final Completer<GoogleMapController> _mapCompleter = Completer();

  MarkerDetail? _bus;
  Set<Marker> _markers = {};
  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _hasCenteredOnce = false; // Only auto-center on the very first load
  String _statusText = 'Searching...';

  // Configurable refresh interval in milliseconds (default: 2000 ms)
  late int _refreshIntervalMs;

  // Icon configuration
  static const int _iconSizePx = 72;
  static const double _iconHeadingOffsetDeg = 180.0;
  final Map<int, BitmapDescriptor> _rotatedIconCache = {};
  Uint8List? _busIconBytes;

  // Pulse animation for LIVE indicator
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Movement animation controller for smooth Uber-style vehicle interpolation
  late AnimationController _movementController;
  LatLng? _startPosition;
  LatLng? _targetPosition;
  double _startBearing = 0.0;
  double _targetBearing = 0.0;
  double _bearingDelta = 0.0; // Shortest angular difference
  LatLng? _currentPosition;
  double _currentBearing = 0.0;

  static const CameraPosition _defaultCameraPosition = CameraPosition(
    target: LatLng(30.9010, 75.8573),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _refreshIntervalMs = widget.initialRefreshIntervalMs;

    // LIVE indicator pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_pulseController);

    // Smooth movement animation controller
    _movementController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _refreshIntervalMs),
    )..addListener(_onMovementTick);

    _loadBusIconBytes().then((_) => _fetchBus());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _movementController.dispose();
    super.dispose();
  }

  // ─── Smooth Movement Animation ──────────────────────────────────────────

  void _onMovementTick() async {
    if (_startPosition == null || _targetPosition == null) return;

    final double t = _movementController.value;

    // Linear interpolation of latitude and longitude
    final double lat = _startPosition!.latitude +
        (_targetPosition!.latitude - _startPosition!.latitude) * t;
    final double lng = _startPosition!.longitude +
        (_targetPosition!.longitude - _startPosition!.longitude) * t;

    // Shortest-arc circular interpolation of bearing
    double bearing = (_startBearing + _bearingDelta * t) % 360.0;
    if (bearing < 0) bearing += 360.0;

    _currentPosition = LatLng(lat, lng);
    _currentBearing = bearing;

    final icon = await _getRotatedIcon(bearing);
    if (!mounted) return;

    final marker = Marker(
      markerId: MarkerId('tracked_bus_${widget.busNumber}'),
      position: _currentPosition!,
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      infoWindow: InfoWindow(
        title: 'Bus ${widget.busNumber}',
        snippet: '${_bus?.routeName ?? ""} • ${_bus?.speedFormatted ?? ""}',
      ),
    );

    setState(() {
      _markers = {marker};
    });
  }

  void _animateBusMovement(LatLng newPos, double newBearing) {
    if (_currentPosition == null) {
      // First position received
      _startPosition = newPos;
      _targetPosition = newPos;
      _startBearing = newBearing;
      _targetBearing = newBearing;
      _bearingDelta = 0.0;
      _currentPosition = newPos;
      _currentBearing = newBearing;

      _getRotatedIcon(newBearing).then((icon) {
        if (!mounted) return;
        final marker = Marker(
          markerId: MarkerId('tracked_bus_${widget.busNumber}'),
          position: newPos,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: 'Bus ${widget.busNumber}',
            snippet: '${_bus?.routeName ?? ""} • ${_bus?.speedFormatted ?? ""}',
          ),
        );
        setState(() {
          _markers = {marker};
        });
      });
      return;
    }

    // Capture current animated state as starting point
    _startPosition = _currentPosition;
    _startBearing = _currentBearing;
    _targetPosition = newPos;
    _targetBearing = newBearing;

    // Calculate shortest circular difference between bearings (-180 to +180)
    double diff = (_targetBearing - _startBearing) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    _bearingDelta = diff;

    // Set duration matching the refresh rate (leaves small margin for network latency)
    final int animDurationMs = math.max(300, (_refreshIntervalMs * 0.95).round());
    _movementController.duration = Duration(milliseconds: animDurationMs);
    _movementController.forward(from: 0.0);
  }

  // ─── Icon Loading & Rotation ──────────────────────────────────────────────

  Future<void> _loadBusIconBytes() async {
    try {
      final data = await rootBundle.load('assets/icons/bus_topview48x48.png');
      _busIconBytes = data.buffer.asUint8List();
    } catch (_) {
      _busIconBytes = null;
    }
  }

  /// Returns a BitmapDescriptor for the bus icon rotated to [bearingDeg].
  /// Cached by 5-degree increments to provide high 60fps performance without frame drops.
  Future<BitmapDescriptor> _getRotatedIcon(double bearingDeg) async {
    final rounded = ((bearingDeg / 5).round() * 5) % 360;
    if (_rotatedIconCache.containsKey(rounded)) {
      return _rotatedIconCache[rounded]!;
    }

    if (_busIconBytes == null) {
      final icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _rotatedIconCache[rounded] = icon;
      return icon;
    }

    final codec = await ui.instantiateImageCodec(
      _busIconBytes!,
      targetWidth: _iconSizePx,
      targetHeight: _iconSizePx,
    );
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rad = (rounded + _iconHeadingOffsetDeg) * math.pi / 180.0;
    final half = _iconSizePx / 2.0;

    canvas.translate(half, half);
    canvas.rotate(rad);
    canvas.translate(-half, -half);
    canvas.drawImage(srcImage, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final img = await picture.toImage(_iconSizePx, _iconSizePx);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      final icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _rotatedIconCache[rounded] = icon;
      return icon;
    }

    final icon = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
    _rotatedIconCache[rounded] = icon;
    return icon;
  }

  // ─── Fetching & Timer ─────────────────────────────────────────────────────

  void _startPeriodicTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(milliseconds: _refreshIntervalMs),
      (_) => _silentRefresh(),
    );
  }

  Future<void> _fetchBus() async {
    if (!mounted) return;

    try {
      final bus = await _apiService.trackBus(widget.busNumber);

      if (!mounted) return;

      if (bus == null) {
        setState(() {
          _bus = null;
          _isLoading = false;
          _statusText = 'No GPS signal right now';
          _markers = {};
        });
      } else {
        _applyBusUpdate(bus);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusText = 'Error fetching location';
        });
      }
    }

    _startPeriodicTimer();
  }

  /// Silent refresh — updates bus data and smoothly glides marker without map jump
  Future<void> _silentRefresh() async {
    if (!mounted) return;
    try {
      final bus = await _apiService.trackBus(widget.busNumber);
      if (!mounted) return;
      if (bus != null) {
        _applyBusUpdate(bus);
      } else {
        setState(() {
          _statusText = 'Signal lost • Retrying...';
        });
      }
    } catch (_) {
      // Silent on transient network errors
    }
  }

  void _applyBusUpdate(MarkerDetail bus) async {
    if (!mounted) return;

    setState(() {
      _bus = bus;
      _isLoading = false;
      _statusText = bus.isMoving
          ? 'Moving • ${bus.speedFormatted}'
          : 'Stationary • ${bus.speedFormatted}';
    });

    if (bus.hasValidLocation) {
      _animateBusMovement(
        LatLng(bus.latitude, bus.longitude),
        bus.bearing,
      );

      // Only on first successful load: center camera once on bus
      if (!_hasCenteredOnce) {
        _hasCenteredOnce = true;
        final controller = await _mapCompleter.future;
        if (mounted) {
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(bus.latitude, bus.longitude),
                zoom: 15.5,
              ),
            ),
          );
        }
      }
    }
  }

  // ─── Refresh Rate Configuration Dialog ────────────────────────────────────

  void _showRefreshRateDialog() {
    final textController = TextEditingController(text: _refreshIntervalMs.toString());
    final presets = [500, 1000, 2000, 3000, 5000];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
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
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Icon(Icons.speed_rounded, color: AppColors.primary, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Set Refresh Rate',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Specify how frequently the bus location updates in milliseconds (ms). Lower values provide faster real-time updates.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),

                  // Quick presets
                  const Text(
                    'Quick Presets:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((ms) {
                      final bool isSelected = textController.text == ms.toString();
                      final String label = ms < 1000 ? '${ms}ms' : '${(ms / 1000).toStringAsFixed(1).replaceAll('.0', '')}s ($ms ms)';
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.primaryLight.withOpacity(0.4),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() {
                              textController.text = ms.toString();
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Custom Milliseconds Input Field
                  TextField(
                    controller: textController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Refresh Interval (Milliseconds)',
                      hintText: 'e.g. 2000 for 2 seconds',
                      suffixText: 'ms',
                      prefixIcon: const Icon(Icons.timer_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      helperText: 'Minimum: 500 ms (0.5 sec) • Maximum: 60000 ms (60 sec)',
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            final val = int.tryParse(textController.text.trim());
                            if (val == null || val < 500 || val > 60000) {
                              Fluttertoast.showToast(msg: 'Please enter between 500 ms and 60,000 ms');
                              return;
                            }

                            setState(() {
                              _refreshIntervalMs = val;
                            });
                            _startPeriodicTimer();

                            Navigator.pop(ctx);
                            Fluttertoast.showToast(
                              msg: 'Refresh rate set to ${val}ms (${(val / 1000).toStringAsFixed(1)}s)',
                            );
                          },
                          child: const Text('Apply Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _reCenterOnBus() async {
    if (_bus == null || !_bus!.hasValidLocation) {
      Fluttertoast.showToast(msg: 'Bus location not available yet');
      return;
    }
    final controller = await _mapCompleter.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentPosition ?? LatLng(_bus!.latitude, _bus!.longitude),
          zoom: 15.5,
        ),
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String intervalDisplay = _refreshIntervalMs < 1000
        ? '${_refreshIntervalMs}ms'
        : '${(_refreshIntervalMs / 1000).toStringAsFixed(1).replaceAll('.0', '')}s (${_refreshIntervalMs}ms)';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live • Bus ${widget.busNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              _statusText,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // LIVE blinking pulse indicator
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Icon(
              Icons.circle,
              color: Colors.greenAccent.withOpacity(_pulseAnim.value),
              size: 10,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),

          // Clickable Refresh Rate Badge/Chip
          InkWell(
            onTap: _showRefreshRateDialog,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white38),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${_refreshIntervalMs}ms',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Manual re-center button
          IconButton(
            tooltip: 'Re-center on bus',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: _reCenterOnBus,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _defaultCameraPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            onMapCreated: (ctrl) {
              if (!_mapCompleter.isCompleted) _mapCompleter.complete(ctrl);
            },
          ),

          // Top Info Banner with Refresh Rate shortcut
          Positioned(
            top: 10,
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
                  const Icon(Icons.route_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Smooth Glide: Active • Updating every $intervalDisplay',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                  ),
                  InkWell(
                    onTap: _showRefreshRateDialog,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Locating Bus ${widget.busNumber}…',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom info card (Uber-style, persistent)
          if (_bus != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildInfoCard(_bus!),
            ),

          // "No signal" banner
          if (!_isLoading && _bus == null)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.signal_wifi_off_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bus ${widget.busNumber} has no active GPS signal. Retrying every ${_refreshIntervalMs}ms…',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(MarkerDetail bus) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -2))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
          const SizedBox(height: 12),
          Row(
            children: [
              // Bus number badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Bus ${widget.busNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Speed badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bus.isMoving ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: bus.isMoving ? Colors.green : Colors.amber.shade700,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: bus.isMoving ? Colors.green.shade700 : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Bearing indicator
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Transform.rotate(
                  angle: (_currentBearing) * math.pi / 180.0,
                  child: const Icon(Icons.navigation_rounded, size: 20, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (bus.routeName.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.alt_route_rounded, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    bus.routeName,
                    style: const TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (bus.currentLocation.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    bus.currentLocation,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              const Icon(Icons.update_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                'Last GPS: ${bus.lastUpdated.isNotEmpty ? bus.lastUpdated : "Just now"}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const Spacer(),
              InkWell(
                onTap: _showRefreshRateDialog,
                child: Row(
                  children: [
                    const Icon(Icons.settings_suggest_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Rate: ${_refreshIntervalMs}ms',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
