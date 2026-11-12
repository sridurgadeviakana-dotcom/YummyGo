import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Service to open Google Maps turn-by-turn driving directions
/// for Delivery Partners directly to restaurant or customer drop-off locations.
class MapNavigationService {
  static const MethodChannel _channel =
      MethodChannel('com.example.yummy_go_application/navigation');

  static const Map<String, List<double>> _areaCoordinates = {
    'madhapur': [17.4483, 78.3915],
    'hitec city': [17.4442, 78.3845],
    'hiteccity': [17.4442, 78.3845],
    'cyber towers': [17.4504, 78.3809],
    'gachibowli': [17.4401, 78.3489],
    'kondapur': [17.4699, 78.3578],
    'jubilee hills': [17.4319, 78.4073],
    'banjara hills': [17.4156, 78.4354],
    'kukatpally': [17.4849, 78.4138],
    'begumpet': [17.4447, 78.4664],
    'ameerpet': [17.4375, 78.4482],
    'somajiguda': [17.4265, 78.4578],
    'secunderabad': [17.4399, 78.4983],
    'manikonda': [17.4022, 78.3879],
    'kothaguda': [17.4589, 78.3687],
    'miyapur': [17.4968, 78.3614],
    'chanda nagar': [17.4925, 78.3268],
    'hafeezpet': [17.4812, 78.3485],
    'film nagar': [17.4172, 78.4102],
    'panjagutta': [17.4287, 78.4503],
    'dilsukhnagar': [17.3688, 78.5247],
    'uppal': [17.4018, 78.5602],
    'charminar': [17.3616, 78.4747],
    'mehdipatnam': [17.3916, 78.4400],
    'tolichowki': [17.4014, 78.4116],
    'lingampally': [17.4834, 78.3158],
  };

  /// Open Google Maps driving route directions directly to the specified destination
  static Future<bool> openGoogleMapsDirections({
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    double? finalLat = latitude;
    double? finalLng = longitude;

    // If coordinates are missing or zero, resolve from address or fallback to Hyderabad center
    if (finalLat == null || finalLng == null || (finalLat == 0.0 && finalLng == 0.0)) {
      final lower = address.toLowerCase();
      for (final entry in _areaCoordinates.entries) {
        if (lower.contains(entry.key)) {
          finalLat = entry.value[0];
          finalLng = entry.value[1];
          break;
        }
      }
      finalLat ??= 17.4442;
      finalLng ??= 78.3845;
    }

    try {
      final success = await _channel.invokeMethod<bool>(
        'openGoogleMapsDirections',
        {
          'address': address,
          'latitude': finalLat,
          'longitude': finalLng,
        },
      );
      if (success == true) {
        debugPrint('MapNavigationService: Launched Google Maps route for $address ($finalLat, $finalLng)');
        return true;
      }
    } catch (e) {
      debugPrint('MapNavigationService: MethodChannel failed: $e');
    }

    // Reliable fallback: Copy and share web directions URL
    final query = '$finalLat,$finalLng';
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving';

    try {
      await Clipboard.setData(ClipboardData(text: url));
      await Share.share('Google Maps Route to: $address\n$url');
      return true;
    } catch (_) {
      return false;
    }
  }
}

