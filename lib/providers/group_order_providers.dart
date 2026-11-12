import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yummy_go_application/models/poll_model.dart';
import 'package:yummy_go_application/providers/auth_providers.dart';
import 'package:yummy_go_application/services/group_order_service.dart';

/// Provider for GroupOrderService instance.
final groupOrderServiceProvider = Provider<GroupOrderService>((ref) {
  return GroupOrderService();
});

/// Stream of all group orders created by or joined by the current user.
final userGroupOrdersStreamProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(groupOrderServiceProvider).userGroupsStream();
});

/// Stream of real-time group details document by groupId.
final groupDetailsStreamProvider =
    StreamProvider.family<DocumentSnapshot<Map<String, dynamic>>, String>(
  (ref, groupId) {
    return ref.watch(groupOrderServiceProvider).groupStream(groupId);
  },
);

/// Stream of group members subcollection.
final groupMembersStreamProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>(
  (ref, groupId) {
    return ref.watch(groupOrderServiceProvider).membersStream(groupId);
  },
);

/// Shared group cart stream provider (used across group ordering & group room screens).
final groupCartProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>(
  (ref, groupId) {
    return ref.watch(groupOrderServiceProvider).cartStream(groupId);
  },
);

/// Stream of group chat messages ordered newest first.
final groupMessagesStreamProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>(
  (ref, groupId) {
    return ref.watch(groupOrderServiceProvider).messagesStream(groupId);
  },
);

/// Stream of raw group food voting polls.
final groupPollsStreamProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>(
  (ref, groupId) {
    return ref.watch(groupOrderServiceProvider).pollsStream(groupId);
  },
);

/// Parsed list of PollModel instances sorted newest first.
final groupPollModelsProvider =
    Provider.family<List<PollModel>, String>((ref, groupId) {
  final snap = ref.watch(groupPollsStreamProvider(groupId)).asData?.value;
  if (snap == null) return const [];

  final polls = snap.docs.map((doc) => PollModel.fromFirestore(doc)).toList();
  polls.sort((a, b) {
    final timeA = a.createdAt ?? DateTime(0);
    final timeB = b.createdAt ?? DateTime(0);
    return timeB.compareTo(timeA);
  });
  return polls;
});

/// Returns only active polls for this group order (no timer-based expiry).
final activeGroupPollsProvider =
    Provider.family<List<PollModel>, String>((ref, groupId) {
  final polls = ref.watch(groupPollModelsProvider(groupId));
  return polls.where((p) => !p.isClosed).toList();
});

/// Returns finalized/closed polls for this group order with winning item or ties.
final closedGroupPollsProvider =
    Provider.family<List<PollModel>, String>((ref, groupId) {
  final polls = ref.watch(groupPollModelsProvider(groupId));
  return polls.where((p) => p.isClosed).toList();
});

/// Stream of archived completed group order history.
final groupOrderHistoryStreamProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>(
  (ref, groupId) {
    return ref.watch(groupOrderServiceProvider).orderHistoryStream(groupId);
  },
);

