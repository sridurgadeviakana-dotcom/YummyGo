import 'package:geolocator/geolocator.dart';
import 'package:yummy_go_application/models/returent_model.dart';


class LocationService {
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Please enable location services.');
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission was not granted.');
    }

    return Geolocator.getCurrentPosition();
  }

  List<RestaurantModel> getNearbyRestaurants({
    required List<RestaurantModel> restaurants,
    required double latitude,
    required double longitude,
    double radiusInKm = 25,
  }) {
    final nearby = restaurants.where((restaurant) {
      final distanceKm = restaurant.getDistanceInKm(latitude, longitude);
      return distanceKm <= radiusInKm;
    }).toList();

    nearby.sort((a, b) {
      final distanceA = a.getDistanceInKm(latitude, longitude);
      final distanceB = b.getDistanceInKm(latitude, longitude);
      return distanceA.compareTo(distanceB);
    });

    return nearby;
  }
}