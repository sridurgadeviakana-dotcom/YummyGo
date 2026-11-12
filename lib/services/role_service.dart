import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yummy_go_application/models/app_user_model.dart';
import 'package:yummy_go_application/models/user_role.dart';

class RoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  /// Fetch user profile from Firestore or create a fallback customer record.
  Future<AppUserModel?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _usersCol.doc(user.uid).get();
    if (doc.exists && doc.data() != null) {
      return AppUserModel.fromFirestore(doc);
    }

    // If doc does not exist yet in Firestore, bootstrap it with Customer role
    final newModel = AppUserModel(
      uid: user.uid,
      name: user.displayName ?? (user.email?.split('@').first ?? 'Customer'),
      email: user.email ?? '',
      role: UserRole.customer,
      createdAt: DateTime.now(),
    );

    await _usersCol.doc(user.uid).set(newModel.toMap(), SetOptions(merge: true));
    return newModel;
  }

  /// Watch real-time role of the authenticated user
  Stream<UserRole> watchCurrentUserRole() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(UserRole.customer);
    }

    return _usersCol.doc(user.uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return UserRole.customer;
      }
      final roleStr = doc.data()?['role']?.toString();
      return UserRole.fromString(roleStr);
    });
  }

  /// Get current role once
  Future<UserRole> getCurrentUserRole() async {
    final profile = await getCurrentUserProfile();
    return profile?.role ?? UserRole.customer;
  }

  /// Assign or update user's role securely in Firestore
  Future<void> setUserRole({
    required String uid,
    required UserRole role,
    Map<String, dynamic>? extraData,
  }) async {
    final payload = <String, dynamic>{
      'role': role.id,
      'updatedAt': FieldValue.serverTimestamp(),
      if (extraData != null) ...extraData,
    };

    await _usersCol.doc(uid).set(payload, SetOptions(merge: true));

    // If role is delivery partner, ensure entry in delivery_partners collection
    if (role == UserRole.deliveryPartner) {
      final user = _auth.currentUser;
      await _firestore.collection('delivery_partners').doc(uid).set({
        'userId': uid,
        'name': user?.displayName ?? 'Delivery Partner',
        'email': user?.email ?? '',
        'phone': extraData?['phone'] ?? '',
        'vehicleType': extraData?['vehicleType'] ?? 'Bike',
        'vehicleNumber': extraData?['vehicleNumber'] ?? '',
        'isAvailable': true,
        'isOnline': true,
        'rating': 4.9,
        'totalDeliveries': 0,
        'earnings': 0.0,
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Verify if user is genuinely an Admin in Firestore
  Future<bool> verifyAdminAccess(String uid) async {
    try {
      final doc = await _usersCol.doc(uid).get();
      if (!doc.exists) return false;
      final role = doc.data()?['role']?.toString();
      final status = doc.data()?['status']?.toString() ?? 'active';
      return (role == 'admin' || role == 'administrator') && status == 'active';
    } catch (_) {
      return false;
    }
  }

  /// Register new user with a designated role
  Future<void> registerUserWithRole({
    required String uid,
    required String name,
    required String email,
    required UserRole role,
    String phone = '',
    Map<String, dynamic>? extra,
  }) async {
    final isPendingReview = role == UserRole.restaurantOwner;

    final userModel = AppUserModel(
      uid: uid,
      name: name,
      email: email,
      phone: phone,
      role: role,
      status: isPendingReview ? 'pending' : 'active',
      createdAt: DateTime.now(),
    );

    final map = userModel.toMap();
    if (extra != null) {
      map.addAll(extra);
    }

    await _usersCol.doc(uid).set(map, SetOptions(merge: true));

    // Restaurant Owner Registration: Submit to Admin for review
    if (role == UserRole.restaurantOwner) {
      final restaurantName = extra?['restaurantName']?.toString().trim();
      final rName = (restaurantName != null && restaurantName.isNotEmpty)
          ? restaurantName
          : (name.isNotEmpty ? '$name\'s Restaurant' : 'New Restaurant');

      await _firestore.collection('restaurants').doc(uid).set({
        'id': uid,
        'name': rName,
        'branchName': 'Main Branch',
        'area': 'Local Area',
        'cuisine': 'Multi-Cuisine',
        'deliveryTime': '30-40 min',
        'imageUrl': '',
        'rating': 4.5,
        'isAvailable': false, // Hidden until Admin approval
        'isActive': false,
        'status': 'pending', // Pending Admin review and approval
        'ownerId': uid,
        'ownerEmail': email,
        'ownerName': name,
        'phone': phone,
        'openingHours': '9:00 AM - 11:00 PM',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _usersCol.doc(uid).set({
        'restaurantId': uid,
        'restaurantName': rName,
        'status': 'pending',
      }, SetOptions(merge: true));
    }

    if (role == UserRole.deliveryPartner) {
      await _firestore.collection('delivery_partners').doc(uid).set({
        'userId': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'vehicleType': extra?['vehicleType'] ?? 'Bike',
        'vehicleNumber': extra?['vehicleNumber'] ?? '',
        'isAvailable': true,
        'isOnline': true,
        'rating': 4.9,
        'totalDeliveries': 0,
        'earnings': 0.0,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}

