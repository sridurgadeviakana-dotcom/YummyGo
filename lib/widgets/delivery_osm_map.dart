import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/delivery_tracking_service.dart';
import 'package:yummy_go_application/services/map_navigation_service.dart';
import 'package:yummy_go_application/services/order_service.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

/// Interactive OpenStreetMap widget for Order Tracking & Delivery Partner Flow.
/// Supports live GPS coordinates, OpenStreetMap raster tiles, vector road network fallback,
/// route polyline, pulsating radar beacon, and interactive zoom controls.
class DeliveryOsmMap extends StatefulWidget {
  final OrderModel order;
  final Map<String, dynamic>? trackingData;
  final int stageIndex;
  final String etaText;
  final String distanceText;
  final bool isDeliveryPartner;
  final double height;
  final EdgeInsetsGeometry? margin;

  const DeliveryOsmMap({
    super.key,
    required this.order,
    this.trackingData,
    required this.stageIndex,
    required this.etaText,
    required this.distanceText,
    this.isDeliveryPartner = false,
    this.height = 260.0,
    this.margin,
  });

  @override
  State<DeliveryOsmMap> createState() => _DeliveryOsmMapState();
}

class _DeliveryOsmMapState extends State<DeliveryOsmMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  int _zoom = 15;
  double? _customCenterLat;
  double? _customCenterLng;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
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

  Offset _geoToScreen(
    double lat,
    double lng,
    double centerLat,
    double centerLng,
    int zoom,
    Size size,
  ) {
    final centerTileX = _lngToTileX(centerLng, zoom);
    final centerTileY = _latToTileY(centerLat, zoom);
    final targetTileX = _lngToTileX(lng, zoom);
    final targetTileY = _latToTileY(lat, zoom);

    const tileSize = 256.0;
    final dx = (size.width / 2.0) + (targetTileX - centerTileX) * tileSize;
    final dy = (size.height / 2.0) + (targetTileY - centerTileY) * tileSize;
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Live Coordinates
    final riderLat =
        (widget.trackingData?['latitude'] as num?)?.toDouble() ?? 17.4442;
    final riderLng =
        (widget.trackingData?['longitude'] as num?)?.toDouble() ?? 78.3845;

    // Customer Delivery Location: Priority to the location selected while food ordering
    final custCoords = RestaurantModel.findCoordinatesForText(widget.order.deliveryAddress);
    final custLat =
        ((widget.order.deliveryLatitude != null && widget.order.deliveryLatitude != 0.0)
            ? widget.order.deliveryLatitude!
            : null) ??
        (widget.trackingData?['customerLatitude'] as num?)?.toDouble() ??
        custCoords?[0] ??
        (riderLat - 0.0065);
    final custLng =
        ((widget.order.deliveryLongitude != null && widget.order.deliveryLongitude != 0.0)
            ? widget.order.deliveryLongitude!
            : null) ??
        (widget.trackingData?['customerLongitude'] as num?)?.toDouble() ??
        custCoords?[1] ??
        (riderLng + 0.0090);

    // Restaurant Location:
    final restCoords = RestaurantModel.findCoordinatesForText(widget.order.restaurantName);
    final restLat =
        (widget.trackingData?['restaurantLatitude'] as num?)?.toDouble() ??
        restCoords?[0] ??
        (riderLat + 0.0070);
    final restLng =
        (widget.trackingData?['restaurantLongitude'] as num?)?.toDouble() ??
        restCoords?[1] ??
        (riderLng - 0.0085);

    final riderName =
        widget.trackingData?['deliveryPartnerName']?.toString() ??
            widget.order.deliveryPartnerName ??
            'Partner';

    final centerLat = _customCenterLat ?? riderLat;
    final centerLng = _customCenterLng ?? riderLng;

    return Container(
      height: widget.height,
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F1ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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

            final centerTileX = _lngToTileX(centerLng, _zoom);
            final centerTileY = _latToTileY(centerLat, _zoom);
            final halfW = size.width / 2.0;
            final halfH = size.height / 2.0;

            final minTileX = (centerTileX - halfW / 256.0).floor();
            final maxTileX = (centerTileX + halfW / 256.0).floor();
            final minTileY = (centerTileY - halfH / 256.0).floor();
            final maxTileY = (centerTileY + halfH / 256.0).floor();

            final restScreen = _geoToScreen(
                restLat, restLng, centerLat, centerLng, _zoom, size);
            final riderScreen = _geoToScreen(
                riderLat, riderLng, centerLat, centerLng, _zoom, size);
            final custScreen = _geoToScreen(
                custLat, custLng, centerLat, centerLng, _zoom, size);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                setState(() {
                  final double lngPerPixel = 360.0 / (256.0 * (1 << _zoom));
                  final double latPerPixel = 180.0 / (256.0 * (1 << _zoom));
                  _customCenterLng =
                      (_customCenterLng ?? riderLng) - (details.delta.dx * lngPerPixel);
                  _customCenterLat =
                      (_customCenterLat ?? riderLat) + (details.delta.dy * latPerPixel);
                });
              },
              child: Stack(
                children: [
                // Layer 1: Instant Vector Road Grid (Always visible, zero network failure)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _OsmVectorRoadPainter(),
                  ),
                ),

                // Layer 2: OpenStreetMap Raster Tiles (Overlaid with proper User-Agent)
                ...List.generate(
                  math.max(1, (maxTileX - minTileX + 1) * (maxTileY - minTileY + 1)),
                  (index) {
                    final widthCount = math.max(1, (maxTileX - minTileX + 1));
                    final tx = minTileX + (index % widthCount);
                    final ty = minTileY + (index ~/ widthCount);

                    final left = halfW + (tx - centerTileX) * 256.0;
                    final top = halfH + (ty - centerTileY) * 256.0;

                    return Positioned(
                      left: left,
                      top: top,
                      width: 256,
                      height: 256,
                      child: Image.network(
                        'https://tile.openstreetmap.org/$_zoom/$tx/$ty.png',
                        headers: const {
                          'User-Agent':
                              'YummyGoDelivery/1.0 (contact: support@yummygo.com)',
                        },
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Image.network(
                            'https://a.basemaps.cartocdn.com/rastertiles/voyager/$_zoom/$tx/$ty.png',
                            headers: const {
                              'User-Agent':
                                  'YummyGoDelivery/1.0 (contact: support@yummygo.com)',
                            },
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          );
                        },
                      ),
                    );
                  },
                ),

                // Layer 3: Delivery Route Polyline & Pulsing Radar Wave
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _DeliveryOsmRoutePainter(
                          restaurantPos: restScreen,
                          riderPos: riderScreen,
                          customerPos: custScreen,
                          stageIndex: widget.stageIndex,
                          pulseValue: _pulseController.value,
                        ),
                      );
                    },
                  ),
                ),

                // Layer 4: Restaurant Pin
                _buildMarker(
                  pos: restScreen,
                  color: AppColors.goldenOrange,
                  icon: Icons.storefront_rounded,
                  label: widget.order.restaurantName.isNotEmpty
                      ? widget.order.restaurantName
                      : 'Restaurant',
                ),

                // Layer 5: Customer Destination Pin
                _buildMarker(
                  pos: custScreen,
                  color: AppColors.success,
                  icon: Icons.home_rounded,
                  label: widget.order.deliveryAddress.isNotEmpty
                      ? widget.order.deliveryAddress.split(',').first.trim()
                      : 'Delivery Location',
                ),

                // Layer 6: Live Delivery Partner Pin
                _buildMarker(
                  pos: riderScreen,
                  color: AppColors.deepTeal,
                  icon: Icons.electric_moped_rounded,
                  label: widget.isDeliveryPartner ? 'You (Live)' : '$riderName (Live)',
                  isRider: true,
                ),

                // Top-Left: ETA or Delivery Partner Mode Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isDeliveryPartner
                              ? Icons.navigation_rounded
                              : Icons.flash_on_rounded,
                          size: 15,
                          color: AppColors.teal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.isDeliveryPartner
                              ? 'Rider Route'
                              : 'Est. ${widget.etaText}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top-Right: Live GPS Coordinates Indicator & Fullscreen OSM Button
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gps_fixed_rounded,
                                size: 12, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              '${riderLat.toStringAsFixed(3)}°, ${riderLng.toStringAsFixed(3)}°',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeliveryOsmFullScreenScreen(
                                order: widget.order,
                                isDeliveryPartner: widget.isDeliveryPartner,
                                initialTrackingData: widget.trackingData,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.deepTeal,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_full_rounded,
                                  size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Open OSM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom-Left: OpenStreetMap Attribution
                Positioned(
                  left: 12,
                  bottom: 46,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_rounded,
                            size: 10, color: AppColors.mutedText),
                        SizedBox(width: 3),
                        Text(
                          '© OpenStreetMap',
                          style: TextStyle(
                            fontSize: 8.5,
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom-Right: Interactive Zoom & Recenter Controls
                Positioned(
                  right: 12,
                  bottom: 46,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _mapControlButton(
                        icon: Icons.add,
                        tooltip: 'Zoom In',
                        onTap: () {
                          if (_zoom < 18) setState(() => _zoom++);
                        },
                      ),
                      const SizedBox(height: 4),
                      _mapControlButton(
                        icon: Icons.remove,
                        tooltip: 'Zoom Out',
                        onTap: () {
                          if (_zoom > 12) setState(() => _zoom--);
                        },
                      ),
                      const SizedBox(height: 4),
                      _mapControlButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Center on Me',
                        onTap: () {
                          setState(() {
                            _customCenterLat = null;
                            _customCenterLng = null;
                          });
                        },
                      ),
                      const SizedBox(height: 4),
                      _mapControlButton(
                        icon: Icons.storefront_rounded,
                        tooltip: 'Focus Restaurant',
                        onTap: () {
                          setState(() {
                            _customCenterLat = restLat;
                            _customCenterLng = restLng;
                          });
                        },
                      ),
                      const SizedBox(height: 4),
                      _mapControlButton(
                        icon: Icons.home_rounded,
                        tooltip: 'Focus Customer',
                        onTap: () {
                          setState(() {
                            _customCenterLat = custLat;
                            _customCenterLng = custLng;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Bottom Center: Status Strip (Tap to Open Fullscreen OpenStreetMap)
                Positioned(
                  bottom: 8,
                  left: 12,
                  right: 12,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeliveryOsmFullScreenScreen(
                            order: widget.order,
                            isDeliveryPartner: widget.isDeliveryPartner,
                            initialTrackingData: widget.trackingData,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.deepTeal.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.electric_moped_rounded,
                              color: Colors.white, size: 17),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.stageIndex >= 4
                                  ? 'Order Delivered to Destination'
                                  : widget.stageIndex >= 3
                                      ? (widget.isDeliveryPartner
                                          ? 'Head to Customer: ${widget.order.customerName}'
                                          : '$riderName is on the way to your delivery address')
                                      : (widget.isDeliveryPartner
                                          ? 'Head to Restaurant: ${widget.order.restaurantName}'
                                          : '$riderName assigned · Collecting food from restaurant'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.teal,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Open OSM',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.arrow_forward_ios_rounded,
                                    size: 9, color: AppColors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildMarker({
    required Offset pos,
    required Color color,
    required IconData icon,
    required String label,
    bool isRider = false,
  }) {
    return Positioned(
      left: pos.dx - 40,
      top: pos.dy - 44,
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _mapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: AppColors.deepTeal),
      ),
    );
  }
}

/// Instant Vector Road & City Block Painter (Always renders instantly)
class _OsmVectorRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background terrain
    final bgPaint = Paint()..color = const Color(0xFFEAF1EE);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // City Park block
    final parkPaint = Paint()..color = const Color(0xFFD6ECDE);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.06, size.height * 0.08,
            size.width * 0.22, size.height * 0.22),
        const Radius.circular(8),
      ),
      parkPaint,
    );

    // Secondary park / water block
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.70, size.height * 0.55,
            size.width * 0.24, size.height * 0.24),
        const Radius.circular(8),
      ),
      parkPaint,
    );

    // Major Avenue Roads
    final majorRoadPaint = Paint()
      ..color = const Color(0xFFD8E5DF)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
        Offset(0, size.height * 0.32), Offset(size.width, size.height * 0.32), majorRoadPaint);
    canvas.drawLine(
        Offset(0, size.height * 0.68), Offset(size.width, size.height * 0.68), majorRoadPaint);
    canvas.drawLine(
        Offset(size.width * 0.32, 0), Offset(size.width * 0.32, size.height), majorRoadPaint);
    canvas.drawLine(
        Offset(size.width * 0.70, 0), Offset(size.width * 0.70, size.height), majorRoadPaint);

    // Minor Street Roads
    final minorRoadPaint = Paint()
      ..color = const Color(0xFFE2EDE8)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
        Offset(0, size.height * 0.50), Offset(size.width, size.height * 0.50), minorRoadPaint);
    canvas.drawLine(
        Offset(size.width * 0.50, 0), Offset(size.width * 0.50, size.height), minorRoadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dynamic Route Line & Pulsing Radar Painter
class _DeliveryOsmRoutePainter extends CustomPainter {
  final Offset restaurantPos;
  final Offset riderPos;
  final Offset customerPos;
  final int stageIndex;
  final double pulseValue;

  _DeliveryOsmRoutePainter({
    required this.restaurantPos,
    required this.riderPos,
    required this.customerPos,
    required this.stageIndex,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Delivery route curve connecting Restaurant -> Rider -> Customer
    final routePath = Path();
    routePath.moveTo(restaurantPos.dx, restaurantPos.dy);

    final mid1 = Offset(
      (restaurantPos.dx + riderPos.dx) / 2,
      (restaurantPos.dy + riderPos.dy) / 2 - 8,
    );
    routePath.quadraticBezierTo(mid1.dx, mid1.dy, riderPos.dx, riderPos.dy);

    final mid2 = Offset(
      (riderPos.dx + customerPos.dx) / 2,
      (riderPos.dy + customerPos.dy) / 2 + 8,
    );
    routePath.quadraticBezierTo(mid2.dx, mid2.dy, customerPos.dx, customerPos.dy);

    // Route shadow / casing
    final routeShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(routePath, routeShadow);

    // Route active stroke
    final routePaint = Paint()
      ..color = stageIndex >= 4 ? AppColors.success : AppColors.teal
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(routePath, routePaint);

    // 2. Pulsing radar wave around live rider location
    if (stageIndex < 4) {
      final pulseRadius = 14.0 + (pulseValue * 18.0);
      final pulseOpacity = (1.0 - pulseValue).clamp(0.0, 1.0);
      final pulsePaint = Paint()
        ..color = AppColors.teal.withValues(alpha: pulseOpacity * 0.45)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(riderPos, pulseRadius, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DeliveryOsmRoutePainter oldDelegate) {
    return oldDelegate.restaurantPos != restaurantPos ||
        oldDelegate.riderPos != riderPos ||
        oldDelegate.customerPos != customerPos ||
        oldDelegate.stageIndex != stageIndex ||
        oldDelegate.pulseValue != pulseValue;
  }
}

// ===========================================================================
// FULL-SCREEN INTERACTIVE OPENSTREETMAP NAVIGATION SCREEN
// ===========================================================================
class DeliveryOsmFullScreenScreen extends StatefulWidget {
  final OrderModel order;
  final bool isDeliveryPartner;
  final Map<String, dynamic>? initialTrackingData;

  const DeliveryOsmFullScreenScreen({
    super.key,
    required this.order,
    this.isDeliveryPartner = false,
    this.initialTrackingData,
  });

  @override
  State<DeliveryOsmFullScreenScreen> createState() =>
      _DeliveryOsmFullScreenScreenState();
}

class _DeliveryOsmFullScreenScreenState
    extends State<DeliveryOsmFullScreenScreen> {
  final OrderService _orderService = OrderService();

  void _openInOsmWeb(
      double riderLat, double riderLng, double destLat, double destLng) async {
    final url =
        'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=$riderLat%2C$riderLng%3B$destLat%2C$destLng#map=16/$riderLat/$riderLng';

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: url));

    // Also share
    try {
      await Share.share('OpenStreetMap Live Navigation Route:\n$url');
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OpenStreetMap Route URL copied & ready to open!\n$url'),
          backgroundColor: AppColors.deepTeal,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .collection('tracking')
          .doc('current')
          .snapshots(),
      builder: (context, trackSnap) {
        final trackingData =
            trackSnap.data?.data() ?? widget.initialTrackingData;
        final riderLat =
            (trackingData?['latitude'] as num?)?.toDouble() ?? 17.4442;
        final riderLng =
            (trackingData?['longitude'] as num?)?.toDouble() ?? 78.3845;
        final restCoords =
            RestaurantModel.findCoordinatesForText(widget.order.restaurantName);
        final restLat =
            (trackingData?['restaurantLatitude'] as num?)?.toDouble() ??
                restCoords?[0] ??
                (riderLat + 0.0070);
        final restLng =
            (trackingData?['restaurantLongitude'] as num?)?.toDouble() ??
                restCoords?[1] ??
                (riderLng - 0.0085);

        final custCoords =
            RestaurantModel.findCoordinatesForText(widget.order.deliveryAddress);
        final custLat =
            ((widget.order.deliveryLatitude != null && widget.order.deliveryLatitude != 0.0)
                ? widget.order.deliveryLatitude!
                : null) ??
            (trackingData?['customerLatitude'] as num?)?.toDouble() ??
            custCoords?[0] ??
            (riderLat - 0.0065);
        final custLng =
            ((widget.order.deliveryLongitude != null && widget.order.deliveryLongitude != 0.0)
                ? widget.order.deliveryLongitude!
                : null) ??
            (trackingData?['customerLongitude'] as num?)?.toDouble() ??
            custCoords?[1] ??
            (riderLng + 0.0090);

        final isStagePickup = widget.order.orderStatus == 'ready_for_pickup';
        final targetLat = isStagePickup ? restLat : custLat;
        final targetLng = isStagePickup ? restLng : custLng;

        return Scaffold(
          backgroundColor: AppColors.warmIvory,
          appBar: CommonAppBar(
            backgroundColor: AppColors.white,
            title: widget.isDeliveryPartner
                ? 'Rider OSM Navigation'
                : 'Live Order OpenStreetMap',
            subtitle: 'Order #${widget.order.id.length > 8 ? widget.order.id.substring(0, 8).toUpperCase() : widget.order.id}',
            actions: [
              IconButton(
                icon: const Icon(Icons.navigation_rounded,
                    color: AppColors.teal),
                tooltip: 'Open in Google Maps',
                onPressed: () {
                  final targetAddress = isStagePickup
                      ? widget.order.restaurantName
                      : (widget.order.deliveryAddress.isNotEmpty
                          ? widget.order.deliveryAddress
                          : widget.order.customerName);
                  MapNavigationService.openGoogleMapsDirections(
                    address: targetAddress,
                    latitude: targetLat,
                    longitude: targetLng,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded,
                    color: AppColors.deepTeal),
                tooltip: 'Share OpenStreetMap Route',
                onPressed: () =>
                    _openInOsmWeb(riderLat, riderLng, targetLat, targetLng),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_browser_rounded,
                    color: AppColors.deepTeal),
                tooltip: 'Copy OpenStreetMap Web Link',
                onPressed: () =>
                    _openInOsmWeb(riderLat, riderLng, targetLat, targetLng),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              // Top Turn-by-Turn Guidance Banner
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.deepTeal,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isStagePickup
                            ? Icons.storefront_rounded
                            : Icons.navigation_rounded,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isStagePickup
                                ? 'STAGE 1: HEAD TO RESTAURANT'
                                : 'STAGE 2: HEAD TO CUSTOMER DROP-OFF',
                            style: const TextStyle(
                              color: AppColors.darkBannerAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isStagePickup
                                ? widget.order.restaurantName
                                : widget.order.customerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (!isStagePickup &&
                              widget.order.deliveryAddress.isNotEmpty)
                            Text(
                              widget.order.deliveryAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.darkBannerSubtext,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Full Viewport OpenStreetMap
              Expanded(
                child: DeliveryOsmMap(
                  order: widget.order,
                  trackingData: trackingData,
                  stageIndex: isStagePickup ? 2 : 3,
                  etaText: 'Active Navigation',
                  distanceText: 'Live Route',
                  isDeliveryPartner: widget.isDeliveryPartner,
                  height: double.infinity,
                  margin: EdgeInsets.zero,
                ),
              ),

              // Bottom Control & Destination Details Card
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Direct Google Maps Driving Directions Button
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: Text(
                            isStagePickup
                                ? 'View Route to Restaurant (Google Maps)'
                                : 'View Route to Customer (Google Maps)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () {
                            final targetAddress = isStagePickup
                                ? widget.order.restaurantName
                                : (widget.order.deliveryAddress.isNotEmpty
                                    ? widget.order.deliveryAddress
                                    : widget.order.customerName);
                            MapNavigationService.openGoogleMapsDirections(
                              address: targetAddress,
                              latitude: targetLat,
                              longitude: targetLng,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.share_rounded,
                                  size: 16, color: AppColors.deepTeal),
                              label: const Text('Open in OSM Web',
                                  style: TextStyle(
                                      color: AppColors.deepTeal,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                              onPressed: () => _openInOsmWeb(
                                  riderLat, riderLng, targetLat, targetLng),
                            ),
                          ),
                          if (widget.isDeliveryPartner) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isStagePickup
                                      ? AppColors.deepTeal
                                      : AppColors.success,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: Icon(
                                    isStagePickup
                                        ? Icons.shopping_bag_rounded
                                        : Icons.check_circle_rounded,
                                    size: 16),
                                label: Text(
                                  isStagePickup
                                      ? 'Picked Up Food'
                                      : 'Delivered',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                                onPressed: () async {
                                  if (isStagePickup) {
                                    await _orderService.updateOrderStatus(
                                        widget.order.id, 'out_for_delivery');
                                  } else {
                                    await DeliveryTrackingService()
                                        .stopTracking();
                                    await _orderService.completeDelivery(
                                        widget.order.id,
                                        widget.order.deliveryPartnerId ?? '');
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
