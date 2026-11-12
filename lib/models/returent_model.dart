import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class RestaurantModel {
  final String id;
  final String name;
  final String branchName;
  final String area;
  final String cuisine;
  final String imageUrl;
  final double rating;
  final String deliveryTime;
  final bool isAvailable;
  final String status;
  final GeoPoint? location;
  final String offerTitle;
  final String offerDescription;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.branchName,
    this.area = '',
    required this.cuisine,
    required this.imageUrl,
    required this.rating,
    required this.deliveryTime,
    required this.isAvailable,
    this.status = 'approved',
    this.location,
    this.offerTitle = '',
    this.offerDescription = '',
  });

  bool get isApproved {
    final s = status.trim().toLowerCase();
    return s == 'active' || s == 'approved';
  }

  /// True if the restaurant is approved and currently open / accepting orders
  bool get isOpen => isApproved && isAvailable;

  /// Display address combining area and branch name
  String get address =>
      area.isNotEmpty ? (branchName.isNotEmpty ? '$area, $branchName' : area) : branchName;

  static const Map<String, List<double>> knownAreaCoords = {
    'hitec': [17.4442, 78.3845],
    'cyber': [17.4475, 78.3768],
    'madhapur': [17.4483, 78.3915],
    'gachibowli': [17.4401, 78.3489],
    'kondapur': [17.4699, 78.3578],
    'jubilee': [17.4319, 78.4073],
    'banjara': [17.4156, 78.4357],
    'kukatpally': [17.4947, 78.3996],
    'kphb': [17.4932, 78.4013],
    'ameerpet': [17.4375, 78.4482],
    'begumpet': [17.4447, 78.4664],
    'secunderabad': [17.4399, 78.4983],
    'charminar': [17.3616, 78.4747],
    'miyapur': [17.4968, 78.3614],
    'panjagutta': [17.4265, 78.4526],
    'somajiguda': [17.4256, 78.4583],
    'mehdipatnam': [17.3916, 78.4428],
    'manikonda': [17.4018, 78.3792],
    'dilsukhnagar': [17.3688, 78.5247],
    'uppal': [17.4057, 78.5591],
    'tarnaka': [17.4286, 78.5317],
    'abids': [17.3924, 78.4738],
    'himayatnagar': [17.4062, 78.4856],
    'tolichowki': [17.4019, 78.4124],
    'hafeezpet': [17.4877, 78.3432],
    'chandanagar': [17.4933, 78.3248],
    'lingampally': [17.4851, 78.3189],
  };

  static List<double>? findCoordinatesForText(String text) {
    if (text.trim().isEmpty) return null;
    final lower = text.toLowerCase();
    for (final entry in knownAreaCoords.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  double? getResolvedLatitude() {
    if (location != null) return location!.latitude;
    final lowerArea = area.toLowerCase();
    for (final entry in knownAreaCoords.entries) {
      if (lowerArea.contains(entry.key)) return entry.value[0];
    }
    return null;
  }

  double? getResolvedLongitude() {
    if (location != null) return location!.longitude;
    final lowerArea = area.toLowerCase();
    for (final entry in knownAreaCoords.entries) {
      if (lowerArea.contains(entry.key)) return entry.value[1];
    }
    return null;
  }

  double getDistanceInKm(double userLat, double userLng) {
    final rLat = getResolvedLatitude();
    final rLng = getResolvedLongitude();
    if (rLat == null || rLng == null) {
      final hash = id.hashCode.abs();
      final offsetMeters = 800.0 + (hash % 2700);
      return offsetMeters / 1000.0;
    }
    final distanceInMeters = Geolocator.distanceBetween(userLat, userLng, rLat, rLng);
    return distanceInMeters / 1000.0;
  }

  String getDistanceText(double userLat, double userLng) {
    final km = getDistanceInKm(userLat, userLng);
    if (km < 1.0) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  factory RestaurantModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return RestaurantModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory RestaurantModel.fromMap(String id, Map<String, dynamic> data) {
    final imageUrl =
        data['imageUrl'] ??
        data['imageURL'] ??
        data['image'] ??
        data['photoUrl'] ??
        data['photoURL'];
    final availability =
        data['isAvailable'] ??
        data['available'] ??
        data['isActive'] ??
        data['is_active'];
    final branchName = data['branchName']?.toString() ?? '';
    final locationValue = data['location'];
    final area =
        data['area'] ??
        data['locality'] ??
        data['neighborhood'] ??
        data['locationName'] ??
        data['city'] ??
        data['address'] ??
        (locationValue is String ? locationValue : null) ??
        branchName;

    GeoPoint? geoPoint;
    if (data['location'] is GeoPoint) {
      geoPoint = data['location'] as GeoPoint;
    } else if (data['location'] is Map) {
      final m = data['location'] as Map;
      final lat = (m['latitude'] ?? m['lat']) as num?;
      final lng = (m['longitude'] ?? m['lng']) as num?;
      if (lat != null && lng != null) geoPoint = GeoPoint(lat.toDouble(), lng.toDouble());
    } else if (data['latitude'] != null && data['longitude'] != null) {
      final lat = (data['latitude'] as num).toDouble();
      final lng = (data['longitude'] as num).toDouble();
      geoPoint = GeoPoint(lat, lng);
    } else if (data['lat'] != null && data['lng'] != null) {
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      geoPoint = GeoPoint(lat, lng);
    }

    final rawStatus = data['status']?.toString().toLowerCase() ??
        (availability == false ? 'inactive' : 'active');

    return RestaurantModel(
      id: id,
      name: data['name']?.toString() ?? '',
      branchName: branchName,
      area: area.toString().trim(),
      cuisine: data['cuisine']?.toString() ?? 'Other',
      imageUrl: imageUrl?.toString().trim() ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      deliveryTime: data['deliveryTime']?.toString() ?? '30-40 min',
      isAvailable: _parseAvailability(availability, data['status']),
      status: rawStatus,
      location: geoPoint,
      offerTitle: (data['offerTitle'] ?? data['offer'] ?? '').toString(),
      offerDescription:
          (data['offerDescription'] ?? data['offerSubtitle'] ?? '').toString(),
    );
  }

  static bool _parseAvailability(dynamic value, dynamic status) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'false':
        case '0':
        case 'closed':
        case 'inactive':
        case 'unavailable':
          return false;
        case 'true':
        case '1':
        case 'active':
        case 'available':
        case 'open':
          return true;
      }
    }

    if (status is String) {
      switch (status.trim().toLowerCase()) {
        case 'closed':
        case 'inactive':
        case 'unavailable':
        case 'pending':
        case 'rejected':
          return false;
        case 'active':
        case 'available':
        case 'approved':
        case 'open':
          return true;
      }
    }

    return true;
  }
}
