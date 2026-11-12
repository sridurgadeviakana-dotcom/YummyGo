import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/services/group_order_service.dart';
import 'package:yummy_go_application/views/group_voting_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;

  const GroupChatScreen({super.key, required this.groupId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final GroupOrderService _service = GroupOrderService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;

  static const List<String> _quickPrompts = [
    'What should we order? 🍽️',
    'I vote for Chicken Biryani!',
    'Anyone up for Pizza or Burger?',
    'Let’s decide in Voting! 👍',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetText]) async {
    if (_isSending) return;
    final text = (presetText ?? _messageController.text).trim();
    if (text.isEmpty) return;

    final previousInput = _messageController.text;
    if (presetText == null) {
      _messageController.clear();
    }

    setState(() => _isSending = true);
    try {
      await _service.sendMessage(
        groupId: widget.groupId,
        message: text,
      );
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (presetText == null && _messageController.text.isEmpty) {
        _messageController.text = previousInput;
      }
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
        setState(() => _isSending = false);
      }
    }
  }

  void _openVoting() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupVotingScreen(groupId: widget.groupId),
      ),
    );
  }

  DateTime _extractTimestamp(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();
    final clientSentAt = data['clientSentAt'];
    if (clientSentAt is Timestamp) return clientSentAt.toDate();
    return DateTime.now();
  }

  String _formatMessageTime(Map<String, dynamic> data) {
    final rawTs = data['createdAt'] ?? data['clientSentAt'];
    if (rawTs is! Timestamp) return 'Sending...';

    final dt = rawTs.toDate().toLocal();
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;

    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final timePart = '$hour12:$minute $period';

    if (isToday) return timePart;
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month, $timePart';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _service.groupStream(widget.groupId),
      builder: (context, groupSnap) {
        if (groupSnap.connectionState == ConnectionState.waiting &&
            !groupSnap.hasData) {
          return Scaffold(
            backgroundColor: AppColors.warmIvory,
            appBar: const CommonAppBar(
              title: 'Group Chat',
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
            ),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            ),
          );
        }

        if (groupSnap.hasError) {
          return Scaffold(
            backgroundColor: AppColors.warmIvory,
            appBar: const CommonAppBar(
              title: 'Group Chat',
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
            ),
            body: _buildStatusState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to Load Chat',
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
              title: 'Group Chat',
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
        final memberUids = groupData['memberUids'] as List<dynamic>? ?? const [];

        if (!isMember) {
          return Scaffold(
            backgroundColor: AppColors.warmIvory,
            appBar: CommonAppBar(
              title: groupName,
              subtitle: 'Group Chat',
              backgroundColor: AppColors.deepTeal,
              foregroundColor: AppColors.white,
            ),
            body: _buildStatusState(
              icon: Icons.lock_outline_rounded,
              title: 'Members Only',
              subtitle:
                  'Only invited members of this group order can view or send chat messages.',
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.warmIvory,
          appBar: CommonAppBar(
            title: groupName,
            subtitle:
                'Group Chat • ${memberUids.isEmpty ? 1 : memberUids.length} members',
            backgroundColor: AppColors.deepTeal,
            foregroundColor: AppColors.white,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  onPressed: _openVoting,
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
                  icon: const Icon(Icons.how_to_vote_rounded, size: 17),
                  label: const Text(
                    'Voting',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _service.messagesStream(widget.groupId),
                  builder: (context, msgSnap) {
                    if (msgSnap.connectionState == ConnectionState.waiting &&
                        !msgSnap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.teal),
                      );
                    }

                    if (msgSnap.hasError) {
                      return _buildStatusState(
                        icon: Icons.wifi_off_rounded,
                        title: 'Could Not Load Messages',
                        subtitle: msgSnap.error.toString(),
                        isError: true,
                      );
                    }

                    final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                      msgSnap.data?.docs ?? const [],
                    );

                    docs.sort((a, b) {
                      final timeA = _extractTimestamp(a.data());
                      final timeB = _extractTimestamp(b.data());
                      return timeB.compareTo(timeA);
                    });

                    if (docs.isEmpty) {
                      return _buildEmptyChatState();
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final senderId = data['senderId']?.toString() ?? '';
                        final senderName =
                            data['senderName']?.toString().trim().isNotEmpty == true
                                ? data['senderName'].toString().trim()
                                : 'Member';
                        final message = data['message']?.toString() ?? '';
                        final isMe = senderId == _service.userId;
                        final timeText = _formatMessageTime(data);

                        return _MessageBubble(
                          senderName: senderName,
                          message: message,
                          timeText: timeText,
                          isMe: isMe,
                        );
                      },
                    );
                  },
                ),
              ),
              _buildMessageInputBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyChatState() {
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
              child: const Icon(
                Icons.forum_rounded,
                size: 40,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Start the Group Conversation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.deepTeal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Decide what to eat together before checking out your group cart.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _quickPrompts
                  .map(
                    (prompt) => ActionChip(
                      onPressed: _isSending ? null : () => _sendMessage(prompt),
                      backgroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      label: Text(
                        prompt,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepTeal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.warmIvory,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.deepTeal,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Message group members...',
                    hintStyle: TextStyle(color: AppColors.mutedText),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: _isSending ? null : () => _sendMessage(),
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Center(
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: AppColors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
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

class _MessageBubble extends StatelessWidget {
  final String senderName;
  final String message;
  final String timeText;
  final bool isMe;

  const _MessageBubble({
    required this.senderName,
    required this.message,
    required this.timeText,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        senderName.isNotEmpty ? senderName[0].toUpperCase() : 'M';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.deepTeal,
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.teal : AppColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe ? null : Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.charcoalBlack.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '$senderName (You)' : senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isMe
                          ? AppColors.white.withValues(alpha: 0.88)
                          : AppColors.goldenOrange,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      color: isMe ? AppColors.white : AppColors.deepTeal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isMe
                          ? AppColors.white.withValues(alpha: 0.76)
                          : AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

