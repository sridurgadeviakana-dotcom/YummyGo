import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Real-time GPS Location Tracking Service for Delivery Partners.
/// Continuously streams rider coordinates to Firestore (orders/{orderId}/tracking/current)
/// until delivery completion.
class DeliveryTrackingService {
  static final DeliveryTrackingService _instance =
      DeliveryTrackingService._internal();

  factory DeliveryTrackingService() => _instance;

  DeliveryTrackingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionSubscription;

  String? _activeOrderId;
  String? _activePartnerId;
  String? _activePartnerName;
  String? _activePartnerPhone;

  final ValueNotifier<String> gpsStatus =
      ValueNotifier<String>('GPS Ready');

  bool get isTracking => _positionSubscription != null;
  String? get currentOrderId => _activeOrderId;

  /// Open Android/iOS system location settings
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('DeliveryTrackingService: Error opening location settings: $e');
    }
  }

  /// Re-attempt to acquire GPS and resume live tracking
  Future<bool> retryTracking() async {
    if (_activeOrderId != null && _activePartnerId != null) {
      return startTracking(
        orderId: _activeOrderId!,
        partnerId: _activePartnerId!,
        partnerName: _activePartnerName ?? 'Partner',
        partnerPhone: _activePartnerPhone ?? '',
      );
    }
    return false;
  }

  /// Start streaming live GPS coordinates to Firestore for the active order
  Future<bool> startTracking({
    required String orderId,
    required String partnerId,
    required String partnerName,
    String partnerPhone = '',
  }) async {
    _activeOrderId = orderId;
    _activePartnerId = partnerId;
    _activePartnerName = partnerName;
    _activePartnerPhone = partnerPhone;

    // 1. Initial fallback: write initial active tracking record immediately so map never hangs
    await _recordFallbackInitialPosition(orderId, partnerId, partnerName, partnerPhone);

    // 2. Check location services on device
    bool serviceEnabled = false;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {}

    if (!serviceEnabled) {
      gpsStatus.value = 'Location Disabled (Tap to enable)';
      debugPrint('DeliveryTrackingService: Location services are disabled.');
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          gpsStatus.value = 'Permission Denied';
          debugPrint('DeliveryTrackingService: Location permission denied.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        gpsStatus.value = 'Permission Permanently Denied';
        debugPrint('DeliveryTrackingService: Location permission permanently denied.');
        return false;
      }
    } catch (e) {
      debugPrint('DeliveryTrackingService: Permission check error: $e');
    }

    gpsStatus.value = 'Acquiring GPS Fix...';

    // 3. Try to get last known or immediate position
    try {
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (position != null) {
        await _recordPosition(position);
        gpsStatus.value = 'Broadcasting Live GPS';
      }
    } catch (e) {
      debugPrint('DeliveryTrackingService: Initial position fetch: $e');
    }

    // 4. Cancel previous subscription if any
    await _positionSubscription?.cancel();

    // 5. Start continuous position streaming
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // Update every 3 meters of movement
    );

    try {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          gpsStatus.value =
              'Live (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
          await _recordPosition(position);
        },
        onError: (error) {
          gpsStatus.value = 'GPS Stream Reconnecting...';
          debugPrint('DeliveryTrackingService: Stream error: $error');
        },
      );
      debugPrint('DeliveryTrackingService: Started GPS streaming for order $orderId');
      return true;
    } catch (e) {
      gpsStatus.value = 'GPS Off (Tap to enable)';
      debugPrint('DeliveryTrackingService: getPositionStream error: $e');
      return false;
    }
  }

  /// Write baseline coordinates if GPS fix is still being acquired
  Future<void> _recordFallbackInitialPosition(
    String orderId,
    String partnerId,
    String partnerName,
    String partnerPhone,
  ) async {
    try {
      final docRef = _firestore
          .collection('orders')
          .doc(orderId)
          .collection('tracking')
          .doc('current');

      final snap = await docRef.get();
      if (!snap.exists || snap.data()?['latitude'] == null) {
        await docRef.set({
          'latitude': 17.4442,
          'longitude': 78.3845,
          'heading': 0.0,
          'speed': 0.0,
          'partnerAssigned': true,
          'deliveryPartnerId': partnerId,
          'deliveryPartnerName': partnerName,
          'deliveryPartnerPhone': partnerPhone,
          'isLiveTracking': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  /// Push updated coordinates to Firestore
  Future<void> _recordPosition(Position position) async {
    final orderId = _activeOrderId;
    if (orderId == null) return;

    try {
      final trackingData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'partnerAssigned': true,
        'deliveryPartnerId': _activePartnerId,
        'deliveryPartnerName': _activePartnerName,
        'deliveryPartnerPhone': _activePartnerPhone,
        'isLiveTracking': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update order's current tracking doc
      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('tracking')
          .doc('current')
          .set(trackingData, SetOptions(merge: true));

      // Also update delivery partner's current location in delivery_partners collection
      final partnerId = _activePartnerId;
      if (partnerId != null && partnerId.isNotEmpty) {
        await _firestore.collection('delivery_partners').doc(partnerId).set({
          'currentLatitude': position.latitude,
          'currentLongitude': position.longitude,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('DeliveryTrackingService: Failed to record position: $e');
    }
  }

  /// Stop tracking when delivery is completed or cancelled
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _activeOrderId = null;
    _activePartnerId = null;
    _activePartnerName = null;
    _activePartnerPhone = null;
    gpsStatus.value = 'Stopped';
    debugPrint('DeliveryTrackingService: Stopped GPS streaming.');
  }
}
