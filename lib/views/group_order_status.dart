import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/services/group_order_service.dart';
import 'package:yummy_go_application/services/payment_service.dart';
import 'package:yummy_go_application/views/order_tracking_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class GroupSplitScreen extends StatefulWidget {
  final String orderName;
  final String orderId;
  final double totalAmount;
  final String orderStatus;
  final List<SplitMember> members;

  const GroupSplitScreen({
    super.key,
    required this.orderName,
    required this.orderId,
    this.totalAmount = 0.0,
    this.orderStatus = 'In Progress',
    this.members = const [],
  });

  static const Color primaryGreen = AppColors.teal;
  static const Color lightGreen = AppColors.lightTeal;
  static const Color darkText = AppColors.charcoalBlack;
  static const Color mutedText = AppColors.mutedText;

  @override
  State<GroupSplitScreen> createState() => _GroupSplitScreenState();
}

class _GroupSplitScreenState extends State<GroupSplitScreen> {
  final GroupOrderService _groupOrderService = GroupOrderService();
  late final RazorpayService _razorpayService;
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService(
      onSuccess: (message) {
        if (!mounted) return;
        setState(() => _isPaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: GroupSplitScreen.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onFailure: (message) {
        if (!mounted) return;
        setState(() => _isPaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  void _payShare(SplitMember member) {
    if (_isPaying) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    // Requirement 8: Members can pay only their own pending share
    if (member.userId != null && member.userId != currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only pay your own pending share.'),
          backgroundColor: Color(0xFFD9531E),
        ),
      );
      return;
    }

    setState(() => _isPaying = true);

    final memberUid = (member.userId != null && member.userId!.isNotEmpty)
        ? member.userId!
        : currentUid;

    _razorpayService.startSplitPayment(
      groupId: widget.orderId,
      memberUserId: memberUid,
      memberName: member.name,
      amountInRupees: member.amount,
    );
  }

  void _shareReminder(BuildContext context, String orderName, List<SplitMember> members) {
    final pending = members.where((m) => !m.isPaid).toList();
    final message = pending
        .map(
          (m) =>
              'Hi ${m.name}! Please pay your split share of '
              '₹${m.amount.toStringAsFixed(2)} for $orderName.',
        )
        .join('\n');

    if (pending.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: message));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pending.isEmpty
              ? 'All members have paid their share!'
              : 'Personalized reminders copied for ${pending.length} pending members.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _groupOrderService.groupStream(widget.orderId),
      builder: (context, snapshot) {
        final groupData = snapshot.data?.data() ?? {};
        final orderName = groupData['groupName']?.toString() ?? widget.orderName;
        final totalAmount =
            (groupData['split']?['total'] as num?)?.toDouble() ??
            widget.totalAmount;

        final rawShares = groupData['splitMembers'];
        List<SplitMember> currentMembers = widget.members;

        if (rawShares is List && rawShares.isNotEmpty) {
          currentMembers = rawShares.whereType<Map>().map((share) {
            final amount = (share['amountDue'] as num?)?.toDouble() ?? 0.0;
            return SplitMember(
              userId: share['userId']?.toString(),
              name: share['name']?.toString() ?? 'Group Member',
              amount: amount,
              isPaid: share['paymentStatus'] == 'paid',
              paymentId: share['paymentId']?.toString(),
            );
          }).toList();
        }

        final pendingCount = currentMembers.where((m) => !m.isPaid).length;
        final isAllPaid = pendingCount == 0 && currentMembers.isNotEmpty;
        final statusLabel = isAllPaid ? 'All Settled 🎉' : widget.orderStatus;

        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final payerId = groupData['paidBy']?.toString() ??
            groupData['createdBy']?.toString() ??
            (groupData['split']?['createdBy']?.toString());
        final isCreatorOrPayer = currentUid != null && currentUid == payerId;

        // Requirement 7: Creator must not see Pay Now after paying full amount
        SplitMember? myUnpaidShare;
        if (!isCreatorOrPayer) {
          for (final m in currentMembers) {
            if (!m.isPaid && m.userId == currentUid) {
              myUnpaidShare = m;
              break;
            }
          }
        }

        return Scaffold(
          backgroundColor: AppColors.warmIvory,
          appBar: const CommonAppBar(
            backgroundColor: AppColors.white,
            title: 'Group Split Bill',
            centerTitle: true,
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    'YummyGo',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrderCard(
                          orderName,
                          totalAmount,
                          statusLabel,
                          isAllPaid,
                          groupData['orderId']?.toString(),
                        ),

                        const SizedBox(height: 18),

                        _buildSectionTitle(
                          icon: Icons.groups_rounded,
                          title: 'Split Overview',
                        ),

                        const SizedBox(height: 10),

                        _buildSplitOverview(currentMembers.length, pendingCount, totalAmount),

                        const SizedBox(height: 20),

                        _buildSectionTitle(
                          icon: Icons.credit_card_rounded,
                          title: 'Payment Status & Pay Share',
                        ),

                        const SizedBox(height: 10),

                        _buildPaymentList(
                          currentMembers,
                          currentUid,
                          isCreatorOrPayer,
                        ),

                        const SizedBox(height: 14),

                        _buildPendingMessage(pendingCount, isAllPaid),

                        const SizedBox(height: 14),

                        if (!isAllPaid)
                          _buildReminderButton(context, orderName, currentMembers),
                      ],
                    ),
                  ),
                ),

                // Sticky Bottom Action Bar for current user if their share is unpaid
                if (myUnpaidShare != null) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Your Share Due',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: GroupSplitScreen.mutedText,
                                ),
                              ),
                              Text(
                                '₹${myUnpaidShare.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.deepTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isPaying ? null : () => _payShare(myUnpaidShare!),
                          icon: const Icon(Icons.payment_rounded, size: 18),
                          label: Text(
                            _isPaying ? 'Processing...' : 'Pay with Razorpay',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GroupSplitScreen.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(
    String orderName,
    double totalAmount,
    String status,
    bool isAllPaid,
    String? realOrderId,
  ) {
    return InkWell(
      onTap: () {
        final targetOrderId = (realOrderId != null && realOrderId.isNotEmpty)
            ? realOrderId
            : widget.orderId;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(
              orderId: targetOrderId,
              groupId: widget.orderId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAF0ED)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE9D6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('🍕', style: TextStyle(fontSize: 34)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: GroupSplitScreen.darkText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Group Order • #${(realOrderId != null && realOrderId.isNotEmpty) ? realOrderId : widget.orderId}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: GroupSplitScreen.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: GroupSplitScreen.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isAllPaid ? AppColors.lightLime : GroupSplitScreen.lightGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isAllPaid
                          ? AppColors.success
                          : GroupSplitScreen.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.near_me_rounded, size: 13, color: GroupSplitScreen.primaryGreen),
                SizedBox(width: 4),
                Text(
                  'Tap to track live order delivery →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: GroupSplitScreen.primaryGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: GroupSplitScreen.primaryGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: GroupSplitScreen.darkText,
          ),
        ),
      ],
    );
  }

  Widget _buildSplitOverview(int memberCount, int pendingCount, double total) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: GroupSplitScreen.lightGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _overviewItem(value: '$memberCount', label: 'Members'),
          _overviewDivider(),
          _overviewItem(
            value: '$pendingCount',
            label: 'Pending',
            valueColor: pendingCount > 0 ? const Color(0xFFD9531E) : GroupSplitScreen.primaryGreen,
          ),
          _overviewDivider(),
          _overviewItem(
            value: '₹${total.toStringAsFixed(0)}',
            label: 'Total Bill',
          ),
        ],
      ),
    );
  }

  Widget _overviewItem({
    required String value,
    required String label,
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor ?? GroupSplitScreen.darkText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _overviewDivider() {
    return Container(width: 1, height: 32, color: AppColors.border);
  }

  Widget _buildPaymentList(
    List<SplitMember> members,
    String? currentUid,
    bool isCreatorOrPayer,
  ) {
    return Column(
      children: members.map((member) {
        final isCurrentUser = member.userId == currentUid;
        return _buildMemberRow(
          member,
          isCurrentUser: isCurrentUser,
          isCreatorOrPayer: isCreatorOrPayer,
        );
      }).toList(),
    );
  }

  Widget _buildMemberRow(
    SplitMember member, {
    bool isCurrentUser = false,
    bool isCreatorOrPayer = false,
  }) {
    final paid = member.isPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: paid ? AppColors.warmIvory : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser && !paid
              ? GroupSplitScreen.primaryGreen.withOpacity(0.5)
              : AppColors.border,
          width: isCurrentUser && !paid ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.lightTeal,
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: GroupSplitScreen.primaryGreen,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GroupSplitScreen.darkText,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.lightTeal,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: GroupSplitScreen.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${member.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: paid ? AppColors.success : AppColors.charcoalBlack,
                  ),
                ),
              ],
            ),
          ),

          if (paid)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lightLime,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 13, color: AppColors.success),
                  SizedBox(width: 4),
                  Text(
                    'Paid',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            )
          else if (isCurrentUser && !isCreatorOrPayer)
            ElevatedButton.icon(
              onPressed: _isPaying ? null : () => _payShare(member),
              icon: const Icon(Icons.payment_rounded, size: 13),
              label: Text(
                'Pay ₹${member.amount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: GroupSplitScreen.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lightOrange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 13, color: AppColors.goldenOrange),
                  SizedBox(width: 4),
                  Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldenOrange,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingMessage(int pendingCount, bool isAllPaid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isAllPaid ? AppColors.lightLime : GroupSplitScreen.lightGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isAllPaid ? Icons.celebration_rounded : Icons.info_rounded,
            size: 18,
            color: isAllPaid ? AppColors.success : GroupSplitScreen.primaryGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAllPaid
                  ? 'All members have paid their share! Split is settled.'
                  : 'Waiting for $pendingCount members to pay their share via Razorpay.',
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: AppColors.deepTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderButton(
    BuildContext context,
    String orderName,
    List<SplitMember> members,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: OutlinedButton(
        onPressed: () => _shareReminder(context, orderName, members),
        style: OutlinedButton.styleFrom(
          foregroundColor: GroupSplitScreen.primaryGreen,
          side: const BorderSide(color: GroupSplitScreen.primaryGreen, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.send_rounded, size: 16),
            SizedBox(width: 8),
            Text(
              'Share Reminder',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class SplitMember {
  final String? userId;
  final String name;
  final double amount;
  final bool isPaid;
  final String? paymentId;

  const SplitMember({
    this.userId,
    required this.name,
    required this.amount,
    required this.isPaid,
    this.paymentId,
  });
}
