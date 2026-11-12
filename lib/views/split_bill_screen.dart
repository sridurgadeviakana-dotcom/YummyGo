import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yummy_go_application/views/customer_home_screen.dart';
import 'package:yummy_go_application/views/group_order_status.dart';
import 'package:yummy_go_application/views/split_success_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';
import 'package:yummy_go_application/widgets/split_bottombutoon_widget.dart';
import 'package:yummy_go_application/widgets/split_membercard_widget.dart';
import 'package:yummy_go_application/widgets/split_method_widget.dart';
import 'package:yummy_go_application/widgets/split_totalcard_widget.dart';

import '../Appconstants/app_colors.dart';
import '../services/group_order_service.dart';

enum SplitType { equal, itemBased, custom }

class GroupSplitBillScreen extends StatefulWidget {
  final String groupId;
  final double totalamount;

  const GroupSplitBillScreen({
    super.key,
    required this.groupId,
    required this.totalamount,
  });

  @override
  State<GroupSplitBillScreen> createState() => _GroupSplitBillScreenState();
}

class _GroupSplitBillScreenState extends State<GroupSplitBillScreen> {
  final GroupOrderService service = GroupOrderService();

  SplitType selectedType = SplitType.equal;

  final Map<String, TextEditingController> customControllers = {};

  @override
  void dispose() {
    for (final controller in customControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  double _getAmount({
    required String memberId,
    required double equalShare,
    required Map<String, double> itemShares,
  }) {
    switch (selectedType) {
      case SplitType.equal:
        return equalShare;

      case SplitType.itemBased:
        return itemShares[memberId] ?? 0;

      case SplitType.custom:
        return double.tryParse(customControllers[memberId]?.text ?? '') ?? 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'Split Your Bill',
        subtitle: 'Group Payment Split',
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border,
          ),
        ),
      ),
      body: StreamBuilder(
        stream: service.membersStream(widget.groupId),
        builder: (context, memberSnapshot) {
          if (memberSnapshot.hasError) {
            return const Center(child: Text('Unable to load group members.'));
          }

          if (memberSnapshot.connectionState == ConnectionState.waiting ||
              !memberSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = memberSnapshot.data!.docs;

          return StreamBuilder(
            stream: service.cartStream(widget.groupId),
            builder: (context, cartSnapshot) {
              if (cartSnapshot.hasError) {
                return const Center(child: Text('Unable to load group cart.'));
              }

              if (cartSnapshot.connectionState == ConnectionState.waiting ||
                  !cartSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = cartSnapshot.data!.docs;

              double total = 0;

              for (final item in items) {
                final data = item.data();

                final price = (data['price'] as num?)?.toDouble() ?? 0;

                final quantity = (data['quantity'] as num?)?.toInt() ?? 0;

                total += price * quantity;
              }

              final equalShare = members.isEmpty ? 0.0 : total / members.length;

              final Map<String, double> itemShares = {
                for (final member in members) member.id: 0.0,
              };

              for (final item in items) {
                final data = item.data();

                final owner = data['addedBy']?.toString();

                final price = (data['price'] as num?)?.toDouble() ?? 0;

                final quantity = (data['quantity'] as num?)?.toInt() ?? 0;

                final itemAmount = price * quantity;

                if (owner != null && itemShares.containsKey(owner)) {
                  itemShares[owner] = itemShares[owner]! + itemAmount;
                }
              }

              for (final member in members) {
                customControllers.putIfAbsent(
                  member.id,
                  () => TextEditingController(
                    text: equalShare.toStringAsFixed(2),
                  ),
                );
              }

              double customTotal = 0;

              for (final member in members) {
                customTotal +=
                    double.tryParse(customControllers[member.id]?.text ?? '') ??
                    0;
              }

              final customIsValid = (customTotal - total).abs() < 0.01;

              final canContinue =
                  members.isNotEmpty &&
                  items.isNotEmpty &&
                  (selectedType != SplitType.custom || customIsValid);

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        SplitTotalCard(
                          total: total,
                          memberCount: members.length,
                        ),

                        const SizedBox(height: 25),

                        Text(
                          'Choose Split Method',
                          style: TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 14),

                        SplitMethodCard(
                          title: 'Equal Split',
                          subtitle: 'Everyone pays the same amount',
                          icon: Icons.people_alt_rounded,
                          isSelected: selectedType == SplitType.equal,
                          onTap: () {
                            setState(() {
                              selectedType = SplitType.equal;
                            });
                          },
                        ),

                        SplitMethodCard(
                          title: 'Item-Based Split',
                          subtitle: 'Everyone pays for their own food',
                          icon: Icons.restaurant_menu_rounded,
                          isSelected: selectedType == SplitType.itemBased,
                          onTap: () {
                            setState(() {
                              selectedType = SplitType.itemBased;
                            });
                          },
                        ),

                        SplitMethodCard(
                          title: 'Custom Split',
                          subtitle: 'Enter each member’s amount',
                          icon: Icons.tune_rounded,
                          isSelected: selectedType == SplitType.custom,
                          onTap: () {
                            setState(() {
                              selectedType = SplitType.custom;
                            });
                          },
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'Member Contributions',
                          style: TextStyle(
                            color: AppColors.deepTeal,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        ...members.map((member) {
                          final data = member.data();

                          final name = (data['name'] ?? 'Customer').toString();

                          final amount = _getAmount(
                            memberId: member.id,
                            equalShare: equalShare,
                            itemShares: itemShares,
                          );

                          return SplitMemberCard(
                            name: name,
                            amount: amount,
                            isCustom: selectedType == SplitType.custom,
                            controller: customControllers[member.id],
                            onAmountChanged: (_) {
                              setState(() {});
                            },
                          );
                        }),

                        if (selectedType == SplitType.custom) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Allocated Amount',
                                  style: TextStyle(
                                    color: AppColors.deepTeal,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '₹${customTotal.toStringAsFixed(2)} / '
                                  '₹${total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: customIsValid
                                        ? Colors.green
                                        : AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (!customIsValid)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 5),
                                    child: Text(
                                      'Custom amounts must equal the total bill.',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
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

                  SplitBottomButton(
                    label: 'Review Split',
                    enabled: canContinue,
                    onPressed: () {
                      _showSplitSummary(
                        members: members,
                        total: total,
                        equalShare: equalShare,
                        itemShares: itemShares,
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showSplitSummary({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> members,
    required double total,
    required double equalShare,
    required Map<String, double> itemShares,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Split Summary',
                  style: TextStyle(
                    color: AppColors.deepTeal,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Check everyone’s contribution',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),

                const SizedBox(height: 16),

                ...members.map((member) {
                  final data = member.data();

                  final name = (data['name'] ?? 'Customer').toString();

                  final amount = _getAmount(
                    memberId: member.id,
                    equalShare: equalShare,
                    itemShares: itemShares,
                  );

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.warmIvory,
                      child: Icon(Icons.person_rounded, color: AppColors.teal),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        color: AppColors.deepTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppColors.deepTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),

                const Divider(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Bill',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '₹${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppColors.deepTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final shares = members.map((member) {
                        final amount = _getAmount(
                          memberId: member.id,
                          equalShare: equalShare,
                          itemShares: itemShares,
                        );
                        return {
                          'userId': member.id,
                          'name': (member.data()['name'] ?? 'Customer')
                              .toString(),
                          'amountDue': amount,
                        };
                      }).toList();

                      try {
                        await service.createGroupSplit(
                          groupId: widget.groupId,
                          splitType: selectedType.name,
                          total: total,
                          memberShares: shares,
                        );
                        if (!mounted) return;
                        if (!bottomSheetContext.mounted) return;
                        Navigator.pop(bottomSheetContext);

                        final splitMembers = shares.map((share) {
                          final isPayer = share['userId'] == service.userId;
                          return SplitMember(
                            userId: share['userId'] as String?,
                            name: share['name']! as String,
                            amount: share['amountDue']! as double,
                            isPaid: isPayer,
                          );
                        }).toList();

                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SplitSuccessScreen(
                              totalAmount: total,
                              groupId: widget.groupId,
                              onViewGroupOrder: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => GroupSplitScreen(
                                      orderName: 'Group order',
                                      orderId: widget.groupId,
                                      totalAmount: total,
                                      orderStatus: 'Split created',
                                      members: splitMembers,
                                    ),
                                  ),
                                );
                              },
                              onGoHome: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const CustomerHomeScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Unable to save split: $error'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Confirm Split',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
