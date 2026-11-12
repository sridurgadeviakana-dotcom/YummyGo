import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yummy_go_application/models/user_role.dart';

class AppUserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? restaurantId;
  final String status;
  final bool isOnline;
  final DateTime? createdAt;
  final String? preferredCuisine;
  final List<String> favoriteRestaurants;

  const AppUserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = UserRole.customer,
    this.restaurantId,
    this.status = 'active',
    this.isOnline = false,
    this.createdAt,
    this.preferredCuisine,
    this.favoriteRestaurants = const [],
  });

  factory AppUserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUserModel.fromMap(doc.id, data);
  }

  factory AppUserModel.fromMap(String uid, Map<String, dynamic> data) {
    final roleStr = data['role']?.toString();
    final createdTimestamp = data['createdAt'];
    DateTime? created;
    if (createdTimestamp is Timestamp) {
      created = createdTimestamp.toDate();
    } else if (createdTimestamp is String) {
      created = DateTime.tryParse(createdTimestamp);
    }

    final rawFavorites = data['favoriteRestaurants'];
    final favoriteRestaurants = <String>[];
    if (rawFavorites is List) {
      for (final item in rawFavorites) {
        if (item != null) favoriteRestaurants.add(item.toString());
      }
    }

    final preferredCuisine = data['preferredCuisine']?.toString() ??
        (data['preferredCuisines'] is List && (data['preferredCuisines'] as List).isNotEmpty
            ? (data['preferredCuisines'] as List).first.toString()
            : null);

    return AppUserModel(
      uid: uid,
      name: data['name']?.toString() ?? data['displayName']?.toString() ?? 'User',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? data['phoneNumber']?.toString() ?? '',
      role: UserRole.fromString(roleStr),
      restaurantId: data['restaurantId']?.toString(),
      status: data['status']?.toString() ?? 'active',
      isOnline: data['isOnline'] == true || data['isAvailable'] == true,
      createdAt: created,
      preferredCuisine: preferredCuisine,
      favoriteRestaurants: favoriteRestaurants,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.id,
      if (restaurantId != null) 'restaurantId': restaurantId,
      'status': status,
      'isOnline': isOnline,
      if (preferredCuisine != null) 'preferredCuisine': preferredCuisine,
      if (favoriteRestaurants.isNotEmpty) 'favoriteRestaurants': favoriteRestaurants,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

