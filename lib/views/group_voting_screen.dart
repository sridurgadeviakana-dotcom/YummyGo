import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/services/group_order_service.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class GroupVotingScreen extends StatefulWidget {
  final String groupId;

  const GroupVotingScreen({super.key, required this.groupId});

  @override
  State<GroupVotingScreen> createState() => _GroupVotingScreenState();
}

class _GroupVotingScreenState extends State<GroupVotingScreen> {
  final GroupOrderService _service = GroupOrderService();
  String? _submittingPollId;

  DateTime _extractTimestamp(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();
    final clientCreatedAt = data['clientCreatedAt'];
    if (clientCreatedAt is Timestamp) return clientCreatedAt.toDate();
    return DateTime.now();
  }

  String _formatPollTime(Map<String, dynamic> data) {
    final rawTs = data['createdAt'] ?? data['clientCreatedAt'];
    if (rawTs is! Timestamp) return 'Just now';

    final dt = rawTs.toDate().toLocal();
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;

    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final timePart = '$hour12:$minute $period';

    if (isToday) return 'Today, $timePart';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month, $timePart';
  }

  Future<void> _castVote({
    required String pollId,
    required int optionIndex,
    required String optionName,
    required bool isVoteChange,
  }) async {
    if (_submittingPollId != null) return;
    setState(() => _submittingPollId = pollId);
    try {
      await _service.submitVote(
        groupId: widget.groupId,
        pollId: pollId,
        optionIndex: optionIndex,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVoteChange
                ? 'Vote changed to "$optionName"! (1 active vote per member)'
                : 'Your vote for "$optionName" has been recorded!',
            style: const TextStyle(color: AppColors.white),
          ),
          backgroundColor: AppColors.limeGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: const TextStyle(color: AppColors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingPollId = null);
      }
    }
  }

  Future<void> _openCreatePollSheet([bool isGroupPlaced = false]) async {
    if (isGroupPlaced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The group order has already been placed. New polls cannot be started.',
            style: TextStyle(color: AppColors.white),
          ),
          backgroundColor: AppColors.deepTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePollSheet(
        groupId: widget.groupId,
        service: _service,
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Poll created! It remains active until order placement.',
            style: TextStyle(color: AppColors.white),
          ),
          backgroundColor: AppColors.limeGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _service.groupStream(widget.groupId),
      builder: (context, groupSnap) {
        if (groupSnap.connectionState == ConnectionState.waiting &&
            !groupSnap.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.warmIvory,
            appBar: CommonAppBar(
              title: 'Group Voting',
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
            ),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            ),
          );
        }

        if (groupSnap.hasError) {
          return Scaffold(
            backgroundColor: AppColors.warmIvory,
            appBar: const CommonAppBar(
              title: 'Group Voting',
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
            ),
            body: _buildStatusState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to Load Polls',
              subtitle: groupSnap.error.toString(),
              isError: true,
            ),
          );
        }

        final groupDoc = groupSnap.data;
        if (groupDoc == null || !groupDoc.exists || groupDoc.data() == null) {
          return Scaffold(
            backgroundColor: AppColors.warmIvory,
            appBar: const CommonAppBar(
              title: 'Group Voting',
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
            ),
            body: _buildStatusState(
              icon: Icons.group_off_rounded,
              title: 'Group Order Not Found',
              subtitle: 'This group order has ended or is no longer available.',
            ),
          );
        }

        final groupData = groupDoc.data()!;
        final isMember = _service.isCurrentUserGroupMember(groupData);
        final groupName = groupData['groupName']?.toString() ?? 'Group Order';

        if (!isMember) {
          return Scaffold(
            backgroundColor: AppColors.warmIvory,
            appBar: CommonAppBar(
              title: groupName,
              subtitle: 'Group Voting',
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
            ),
            body: _buildStatusState(
              icon: Icons.lock_outline_rounded,
              title: 'Members Only',
              subtitle:
                  'Only invited members of this group order can create polls or vote.',
            ),
          );
        }

        final isGroupPlaced = groupData['paymentStatus'] == 'paid' ||
            groupData['status'] == 'paid' ||
            (groupData['orderId'] != null &&
                groupData['orderId'].toString().isNotEmpty);

        return Scaffold(
          backgroundColor: AppColors.warmIvory,
          appBar: CommonAppBar(
            title: groupName,
            subtitle: isGroupPlaced
                ? 'Group Voting • Final Results'
                : 'Group Voting • Live Polls',
            backgroundColor: AppColors.deepTeal,
            foregroundColor: AppColors.white,
            actions: [
              if (isGroupPlaced)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: AppColors.white,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Order Placed',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: () => _openCreatePollSheet(false),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Create Poll',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _service.pollsStream(widget.groupId),
            builder: (context, pollSnap) {
              if (pollSnap.connectionState == ConnectionState.waiting &&
                  !pollSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.teal),
                );
              }

              if (pollSnap.hasError) {
                return _buildStatusState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could Not Load Polls',
                  subtitle: pollSnap.error.toString(),
                  isError: true,
                );
              }

              final docs =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                pollSnap.data?.docs ?? const [],
              );

              docs.sort((a, b) {
                final timeA = _extractTimestamp(a.data());
                final timeB = _extractTimestamp(b.data());
                return timeB.compareTo(timeA);
              });

              if (docs.isEmpty) {
                return _buildEmptyPollsState(isGroupPlaced);
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: docs.length + (isGroupPlaced ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (isGroupPlaced && index == 0) {
                    return _buildOrderPlacedBanner();
                  }
                  final docIndex = isGroupPlaced ? index - 1 : index;
                  final doc = docs[docIndex];
                  return _buildPollCard(doc.id, doc.data(), isGroupPlaced);
                },
              );
            },
          ),
          floatingActionButton: isGroupPlaced
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openCreatePollSheet(false),
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.white,
                  icon: const Icon(Icons.poll_rounded),
                  label: const Text(
                    'New Poll',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildOrderPlacedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.lightLime, Color(0xFFE8F5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.limeGreen.withValues(alpha: 0.6),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.limeGreen.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: AppColors.limeGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Group Order Placed — Voting Finalized',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepTeal,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Active polls are now closed. Review the winning food items and final group choices below.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepTeal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollCard(
    String pollId,
    Map<String, dynamic> data,
    bool isGroupPlaced,
  ) {
    final poll = PollModel.fromMap(pollId, data);
    final result = poll.result;
    final options = poll.options;
    final isClosed = poll.isClosed || isGroupPlaced;
    final myVoteIndex = poll.userVoteIndex(_service.userId);
    final hasVoted = myVoteIndex != null;
    final isSubmittingThis = _submittingPollId == pollId;
    final timeLabel = _formatPollTime(data);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClosed
              ? AppColors.teal.withValues(alpha: 0.25)
              : AppColors.border,
          width: isClosed ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoalBlack.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isClosed
                      ? AppColors.lightTeal
                      : (hasVoted ? AppColors.lightLime : AppColors.lightTeal),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isClosed
                          ? Icons.lock_rounded
                          : (hasVoted
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_checked_rounded),
                      size: 12,
                      color: isClosed
                          ? AppColors.deepTeal
                          : (hasVoted ? AppColors.limeGreen : AppColors.teal),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isClosed
                          ? 'Poll Closed • Final Results'
                          : (hasVoted ? 'Active • You Voted' : 'Active Poll'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isClosed
                            ? AppColors.deepTeal
                            : (hasVoted ? AppColors.limeGreen : AppColors.teal),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'by ${poll.createdByName} • $timeLabel',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${result.totalVotes} ${result.totalVotes == 1 ? 'vote' : 'votes'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            poll.question,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              color: AppColors.deepTeal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isClosed
                ? 'Order placed — voting is closed. Final results displayed below.'
                : (hasVoted
                    ? 'You voted for "${options[myVoteIndex]}". You can change your vote anytime before order placement.'
                    : 'Tap an option below to cast your vote (1 active vote per member). You can change it anytime.'),
            style: TextStyle(
              fontSize: 12,
              color: isClosed ? AppColors.deepTeal : AppColors.mutedText,
              fontWeight: isClosed ? FontWeight.w600 : FontWeight.w400,
            ),
          ),

          // WINNER OR TIED RESULTS BANNER WHEN CLOSED
          if (isClosed) ...[
            if (result.hasVotes &&
                !result.isTie &&
                result.winningOption != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.lightLime, Color(0xFFE8F5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.limeGreen, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.limeGreen.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('🏆', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.limeGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'WINNING FOOD ITEM',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            result.winningOption!,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.deepTeal,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${result.maxVotes} ${result.maxVotes == 1 ? 'vote' : 'votes'} (${result.winningPercentage}%) • Group Choice',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (result.hasVotes && result.isTie) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.lightIvory, Color(0xFFFFF3E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.goldenOrange, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldenOrange.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('⚖️', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.goldenOrange,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TIED OPTIONS (SPLIT)',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            result.winningOptions.join(' & '),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.deepTeal,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Tied with ${result.maxVotes} ${result.maxVotes == 1 ? 'vote' : 'votes'} each (${result.winningPercentage}%)',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warmIvory,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: AppColors.mutedText,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No votes were cast before order placement.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 14),
          ],

          ...List.generate(options.length, (i) {
            final optionText = options[i];
            final voteCount = poll.getVoteCount(i);
            final percent = poll.getPercentage(i);
            final fraction =
                result.totalVotes == 0 ? 0.0 : voteCount / result.totalVotes;
            final isSelected = myVoteIndex == i;

            final isWinner =
                isClosed && !result.isTie && result.winningIndices.contains(i);
            final isTied =
                isClosed && result.isTie && result.winningIndices.contains(i);
            final isLeading = !isClosed &&
                result.totalVotes > 0 &&
                result.winningIndices.contains(i);

            final borderColor = isWinner
                ? AppColors.limeGreen
                : (isTied
                    ? AppColors.goldenOrange
                    : (isSelected
                        ? AppColors.limeGreen
                        : (isLeading && hasVoted
                            ? AppColors.teal
                            : AppColors.border)));

            final fillColor = isWinner
                ? AppColors.lightLime
                : (isTied
                    ? const Color(0xFFFFF8E1)
                    : (isSelected
                        ? AppColors.lightLime
                        : (isLeading
                            ? AppColors.lightTeal
                            : AppColors.lightIvory)));

            final votersForOption = poll.getVoterNamesForOption(i);

            return Padding(
              padding: EdgeInsets.only(bottom: i == options.length - 1 ? 0 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: isSubmittingThis
                        ? null
                        : () {
                            if (isClosed) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This poll is closed because the group order was placed. Voting and vote changes are disabled.',
                                    style: TextStyle(color: AppColors.white),
                                  ),
                                  backgroundColor: AppColors.deepTeal,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            if (isSelected) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '"$optionText" is already your active vote. Tap another option if you wish to change your vote.',
                                    style: const TextStyle(
                                      color: AppColors.white,
                                    ),
                                  ),
                                  backgroundColor: AppColors.deepTeal,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            _castVote(
                              pollId: pollId,
                              optionIndex: i,
                              optionName: optionText,
                              isVoteChange: hasVoted,
                            );
                          },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.warmIvory,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: borderColor,
                            width: (isWinner || isTied || isSelected)
                                ? 1.8
                                : 1.1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: fraction.clamp(0.0, 1.0),
                                  child: Container(color: fillColor),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isWinner
                                        ? Icons.emoji_events_rounded
                                        : (isTied
                                            ? Icons.balance_rounded
                                            : (isSelected
                                                ? Icons.check_circle_rounded
                                                : (hasVoted || isClosed
                                                    ? Icons.circle_outlined
                                                    : Icons
                                                        .radio_button_unchecked_rounded))),
                                    size: 20,
                                    color: (isWinner || isSelected)
                                        ? AppColors.limeGreen
                                        : (isTied
                                            ? AppColors.goldenOrange
                                            : ((hasVoted || isClosed)
                                                ? AppColors.mutedText
                                                : AppColors.teal)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      optionText,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: (isSelected ||
                                                isWinner ||
                                                isTied ||
                                                isLeading)
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: AppColors.deepTeal,
                                      ),
                                    ),
                                  ),
                                  if (isSubmittingThis)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.teal,
                                      ),
                                    )
                                  else
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isWinner) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.limeGreen,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              '🏆 WINNER',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ] else if (isTied) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.goldenOrange,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              '⚖️ TIED',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ] else if (isLeading &&
                                            result.totalVotes > 0 &&
                                            !isClosed) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.teal.withValues(
                                                alpha: 0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Top',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.goldenOrange,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        if (isSelected) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.lightLime,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: AppColors.limeGreen,
                                              ),
                                            ),
                                            child: const Text(
                                              'Your Vote',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.limeGreen,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          '$voteCount ($percent%)',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: (isWinner || isSelected)
                                                ? AppColors.limeGreen
                                                : (isTied
                                                    ? AppColors.goldenOrange
                                                    : AppColors.deepTeal),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (votersForOption.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 6, top: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.people_outline_rounded,
                            size: 13,
                            color: AppColors.mutedText,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              votersForOption.join(', '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyPollsState(bool isGroupPlaced) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.lightTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGroupPlaced
                    ? Icons.lock_outline_rounded
                    : Icons.how_to_vote_rounded,
                size: 40,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isGroupPlaced ? 'No Polls Recorded' : 'No Polls Yet',
              style: const TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w900,
                color: AppColors.deepTeal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isGroupPlaced
                  ? 'This group order was placed without any active polls.'
                  : 'Polls stay active until the group order is placed. Create a poll to decide dishes together!',
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isGroupPlaced) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _openCreatePollSheet(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Create Food Poll',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusState({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isError = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isError
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.lightTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: isError ? AppColors.error : AppColors.teal,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.deepTeal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePollSheet extends StatefulWidget {
  final String groupId;
  final GroupOrderService service;

  const _CreatePollSheet({
    required this.groupId,
    required this.service,
  });

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  final TextEditingController _questionController = TextEditingController(
    text: 'What should we order?',
  );
  late final List<TextEditingController> _optionControllers;

  bool _isSaving = false;
  String? _errorText;

  static const List<String> _suggestedDishes = [
    'Chicken Biryani',
    'Pizza',
    'Burger',
    'Paneer Butter Masala',
    'Fried Rice',
    'Masala Dosa',
  ];

  @override
  void initState() {
    super.initState();
    _optionControllers = [
      TextEditingController(text: 'Chicken Biryani'),
      TextEditingController(text: 'Pizza'),
      TextEditingController(text: 'Burger'),
    ];
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOptionField([String initialValue = '']) {
    if (_optionControllers.length >= 8) {
      setState(() => _errorText = 'Maximum 8 options allowed per poll.');
      return;
    }
    setState(() {
      _errorText = null;
      _optionControllers.add(TextEditingController(text: initialValue));
    });
  }

  void _removeOptionField(int index) {
    if (_optionControllers.length <= 2) {
      setState(() => _errorText = 'A poll needs at least 2 options.');
      return;
    }
    setState(() {
      _errorText = null;
      final removed = _optionControllers.removeAt(index);
      removed.dispose();
    });
  }

  void _applySuggestion(String dish) {
    final normalized = dish.trim().toLowerCase();
    final alreadyExists = _optionControllers.any(
      (c) => c.text.trim().toLowerCase() == normalized,
    );
    if (alreadyExists) return;

    final emptyController = _optionControllers.cast<TextEditingController?>().firstWhere(
          (c) => c!.text.trim().isEmpty,
          orElse: () => null,
        );

    if (emptyController != null) {
      setState(() {
        _errorText = null;
        emptyController.text = dish;
      });
    } else {
      _addOptionField(dish);
    }
  }

  Future<void> _submitPoll() async {
    if (_isSaving) return;

    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _errorText = 'Please enter a poll question.');
      return;
    }

    final seen = <String>{};
    final options = <String>[];
    for (final controller in _optionControllers) {
      final text = controller.text.trim();
      if (text.isEmpty) continue;
      if (seen.add(text.toLowerCase())) {
        options.add(text);
      }
    }

    if (options.length < 2) {
      setState(
        () => _errorText = 'Please provide at least 2 distinct food options.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await widget.service.createPoll(
        groupId: widget.groupId,
        question: question,
        options: options,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create Group Poll',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: AppColors.deepTeal,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Polls stay active until the group order is placed. Members can change their vote anytime.',
              style: TextStyle(fontSize: 12.5, color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            const Text(
              'Poll Question',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.deepTeal,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _questionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. What should we order?',
                filled: true,
                fillColor: AppColors.warmIvory,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Options',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepTeal,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : () => _addOptionField(),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                  label: const Text(
                    'Add Option',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[index],
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Option ${index + 1}',
                          filled: true,
                          fillColor: AppColors.warmIvory,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.teal,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_optionControllers.length > 2) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed:
                            _isSaving ? null : () => _removeOptionField(index),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.mutedText,
                        ),
                        tooltip: 'Remove option',
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            const Text(
              'Quick Add Popular Dishes',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedDishes
                  .map(
                    (dish) => ActionChip(
                      onPressed: _isSaving ? null : () => _applySuggestion(dish),
                      backgroundColor: AppColors.lightTeal,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      label: Text(
                        '+ $dish',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.goldenOrange,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorText!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitPoll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text(
                        'Launch Poll',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

