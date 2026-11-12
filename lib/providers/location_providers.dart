import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yummy_go_application/services/location_service.dart';

/// Provider for LocationService instance.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Future provider fetching the device's current GPS position.
final userCurrentLocationProvider = FutureProvider<Position>((ref) async {
  return ref.watch(locationServiceProvider).getCurrentLocation();
});

/// Coordinates record type.
typedef Coordinates = ({double latitude, double longitude});

/// Notifier holding user's manually chosen or GPS coordinates.
class ActiveUserCoordinatesNotifier extends Notifier<Coordinates?> {
  @override
  Coordinates? build() {
    final pos = ref.watch(userCurrentLocationProvider).asData?.value;
    if (pos != null) {
      return (latitude: pos.latitude, longitude: pos.longitude);
    }
    return null;
  }

  set state(Coordinates? value) => super.state = value;
  void setCoordinates(double latitude, double longitude) =>
      state = (latitude: latitude, longitude: longitude);
  void clear() => state = null;
}

final activeUserCoordinatesProvider =
    NotifierProvider<ActiveUserCoordinatesNotifier, Coordinates?>(
  ActiveUserCoordinatesNotifier.new,
);
