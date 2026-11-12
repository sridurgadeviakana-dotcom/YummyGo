import 'package:firebase_auth/firebase_auth.dart';
import 'package:yummy_go_application/models/user_role.dart';
import 'package:yummy_go_application/services/role_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RoleService _roleService = RoleService();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Register customer with Firebase Auth and sync role to Firestore
  Future<UserCredential> registerCustomer({
    required String name,
    required String email,
    required String password,
  }) async {
    return registerWithRole(
      name: name,
      email: email,
      password: password,
      role: UserRole.customer,
    );
  }

  /// Register a user with any designated role
  Future<UserCredential> registerWithRole({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String phone = '',
    Map<String, dynamic>? extraData,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await credential.user?.updateDisplayName(name.trim());

    if (credential.user != null) {
      await _roleService.registerUserWithRole(
        uid: credential.user!.uid,
        name: name.trim(),
        email: email.trim(),
        role: role,
        phone: phone.trim(),
        extra: extraData,
      );
    }

    return credential;
  }

  /// Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Password reset email
  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }
}
