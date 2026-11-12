import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';

/// Interactive OpenStreetMap Location Picker Widget.
/// Allows panning, zooming, and tapping "Use Current Location" to pinpoint delivery coordinates.
class AddressOsmPicker extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final ValueChanged<({double latitude, double longitude})> onLocationChanged;
  final double height;

  const AddressOsmPicker({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onLocationChanged,
    this.height = 240,
  });

  @override
  State<AddressOsmPicker> createState() => _AddressOsmPickerState();
}

class _AddressOsmPickerState extends State<AddressOsmPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late double _currentLat;
  late double _currentLng;
  int _zoom = 16;
  bool _isLoadingGps = false;
  String _gpsStatus = 'Ready';

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLatitude;
    _currentLng = widget.initialLongitude;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AddressOsmPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLatitude != widget.initialLatitude ||
        oldWidget.initialLongitude != widget.initialLongitude) {
      setState(() {
        _currentLat = widget.initialLatitude;
        _currentLng = widget.initialLongitude;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double _lngToTileX(double lng, int zoom) {
    return (lng + 180.0) / 360.0 * (1 << zoom);
  }

  double _latToTileY(double lat, int zoom) {
    final latRad = (lat.clamp(-85.0511, 85.0511)) * math.pi / 180.0;
    return (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
        2.0 *
        (1 << zoom);
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLoadingGps = true;
      _gpsStatus = 'Checking GPS...';
    });

    try {
      // 1. Check if location services are enabled
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        setState(() {
          _isLoadingGps = false;
          _gpsStatus = 'Location Service Disabled';
        });
        if (mounted) {
          _showGpsSettingsDialog(
            title: 'GPS is Disabled',
            message: 'Please enable device location to detect your delivery address.',
            actionLabel: 'Open Location Settings',
            onAction: () => Geolocator.openLocationSettings(),
          );
        }
        return;
      }

      // 2. Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingGps = false;
            _gpsStatus = 'Permission Denied';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission was denied.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingGps = false;
          _gpsStatus = 'Permission Blocked';
        });
        if (mounted) {
          _showGpsSettingsDialog(
            title: 'Location Permission Blocked',
            message: 'Location access is permanently blocked. Enable it in app settings.',
            actionLabel: 'Open App Settings',
            onAction: () => Geolocator.openAppSettings(),
          );
        }
        return;
      }

      // 3. Get accurate current position
      setState(() => _gpsStatus = 'Acquiring GPS Fix...');

      Position? position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      ).catchError((_) => null);

      position ??= await Geolocator.getLastKnownPosition();

      if (position != null) {
        setState(() {
          _currentLat = position!.latitude;
          _currentLng = position!.longitude;
          _isLoadingGps = false;
          _gpsStatus = 'GPS Fixed';
        });

        widget.onLocationChanged(
          (latitude: position.latitude, longitude: position.longitude),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: AppColors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Location detected: ${_currentLat.toStringAsFixed(4)}, ${_currentLng.toStringAsFixed(4)}'),
                ],
              ),
              backgroundColor: AppColors.teal,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isLoadingGps = false;
          _gpsStatus = 'GPS Timeout';
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _isLoadingGps = false;
        _gpsStatus = 'Error detecting location';
      });
    }
  }

  void _showGpsSettingsDialog({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: AppColors.goldenOrange),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepTeal)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.mutedText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onAction();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.lightTeal,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoalBlack.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            if (size.width <= 0 || size.height <= 0) {
              return const SizedBox.shrink();
            }

            final centerTileX = _lngToTileX(_currentLng, _zoom);
            final centerTileY = _latToTileY(_currentLat, _zoom);
            final halfW = size.width / 2.0;
            final halfH = size.height / 2.0;

            final minTileX = (centerTileX - halfW / 256.0).floor();
            final maxTileX = (centerTileX + halfW / 256.0).floor();
            final minTileY = (centerTileY - halfH / 256.0).floor();
            final maxTileY = (centerTileY + halfH / 256.0).floor();

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                final double lngPerPixel = 360.0 / (256.0 * (1 << _zoom));
                final double latPerPixel = 180.0 / (256.0 * (1 << _zoom));

                setState(() {
                  _currentLng = _currentLng - (details.delta.dx * lngPerPixel);
                  _currentLat = (_currentLat + (details.delta.dy * latPerPixel)).clamp(-85.0, 85.0);
                });

                widget.onLocationChanged(
                  (latitude: _currentLat, longitude: _currentLng),
                );
              },
              child: Stack(
                children: [
                  // Layer 1: Vector Road Grid (Always visible fallback)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _AddressVectorRoadPainter(),
                    ),
                  ),

                  // Layer 2: OpenStreetMap Raster Tiles
                  for (int tx = minTileX; tx <= maxTileX; tx++)
                    for (int ty = minTileY; ty <= maxTileY; ty++)
                      Positioned(
                        left: halfW + (tx - centerTileX) * 256.0,
                        top: halfH + (ty - centerTileY) * 256.0,
                        width: 256.0,
                        height: 256.0,
                        child: Image.network(
                          'https://tile.openstreetmap.org/$_zoom/$tx/$ty.png',
                          headers: const {
                            'User-Agent': 'YummyGoApp/1.0 (flutter; contact@yummygo.com)',
                          },
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),

                  // Layer 3: Center Pin Marker (Target)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.deepTeal,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.charcoalBlack.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Deliver here',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulsing radar ring
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, _) {
                                final value = _pulseController.value;
                                return Container(
                                  width: 32 + (value * 24),
                                  height: 32 + (value * 24),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.teal.withOpacity((1.0 - value) * 0.45),
                                  ),
                                );
                              },
                            ),
                            // Marker pin
                            const Icon(
                              Icons.location_on_rounded,
                              size: 40,
                              color: AppColors.error,
                            ),
                            const Positioned(
                              top: 9,
                              child: Icon(
                                Icons.circle,
                                size: 10,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                        // Shadow dot below pin tip
                        Container(
                          width: 8,
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: AppColors.charcoalBlack.withOpacity(0.38),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Layer 4: Top Information Pill (Coordinates & Status)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: AppColors.charcoalBlack.withOpacity(0.08), blurRadius: 6),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'OSM GPS: ${_currentLat.toStringAsFixed(4)}, ${_currentLng.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Layer 5: Zoom Controls
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Column(
                      children: [
                        _buildMapButton(
                          icon: Icons.add,
                          onPressed: () {
                            if (_zoom < 18) setState(() => _zoom++);
                          },
                        ),
                        const SizedBox(height: 6),
                        _buildMapButton(
                          icon: Icons.remove,
                          onPressed: () {
                            if (_zoom > 10) setState(() => _zoom--);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Layer 6: "Use Current Location" Floating Button
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepTeal,
                        foregroundColor: AppColors.white,
                        elevation: 3,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isLoadingGps
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 16),
                      label: Text(
                        _isLoadingGps ? 'Locating...' : 'Use Current Location',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                      onPressed: _isLoadingGps ? null : _fetchCurrentLocation,
                    ),
                  ),

                  // Layer 7: Pan instruction hint
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.charcoalBlack.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pan_tool_alt_rounded, size: 11, color: AppColors.white.withOpacity(0.70)),
                          const SizedBox(width: 4),
                          const Text(
                            'Drag map to pin exact door',
                            style: TextStyle(color: AppColors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMapButton({required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: AppColors.charcoalBlack.withOpacity(0.08), blurRadius: 4),
          ],
        ),
        child: Icon(icon, size: 16, color: AppColors.deepTeal),
      ),
    );
  }
}

class _AddressVectorRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.lightTeal;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final roadPaint = Paint()
      ..color = AppColors.white
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final secondaryPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 3.5;

    // Horizontal grid
    for (double y = 30; y < size.height; y += 45) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), secondaryPaint);
    }
    // Vertical grid
    for (double x = 40; x < size.width; x += 55) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), secondaryPaint);
    }

    // Main arteries
    canvas.drawLine(
      Offset(0, size.height * 0.45),
      Offset(size.width, size.height * 0.52),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.48, 0),
      Offset(size.width * 0.52, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

