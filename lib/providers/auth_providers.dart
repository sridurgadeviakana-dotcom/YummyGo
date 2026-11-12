import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yummy_go_application/models/app_user_model.dart';
import 'package:yummy_go_application/models/user_role.dart';
import 'package:yummy_go_application/services/auth_service.dart';
import 'package:yummy_go_application/services/role_service.dart';

/// Provider for FirebaseAuth instance.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provider for AuthService singleton/instance.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider for RoleService singleton/instance.
final roleServiceProvider = Provider<RoleService>((ref) {
  return RoleService();
});

/// Stream of authentication state changes.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Returns the currently signed-in User (or null).
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateChangesProvider).asData?.value ??
      ref.watch(firebaseAuthProvider).currentUser;
});

/// Stream of the current user's role in real-time.
final currentUserRoleProvider = StreamProvider<UserRole>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(UserRole.customer);
  }
  return ref.watch(roleServiceProvider).watchCurrentUserRole();
});

/// Future provider for the current user's full Firestore profile model.
final currentUserProfileProvider = FutureProvider<AppUserModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(roleServiceProvider).getCurrentUserProfile();
});

/// Checks if the current user has verified Admin access.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return ref.watch(roleServiceProvider).verifyAdminAccess(user.uid);
});

