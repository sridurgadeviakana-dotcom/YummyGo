import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';
import 'package:yummy_go_application/widgets/split_success_widgets.dart';

class SplitSuccessScreen extends StatelessWidget {
  final double totalAmount;
  final VoidCallback onViewGroupOrder;
  final VoidCallback onGoHome;
  final String groupId;

  const SplitSuccessScreen({
    super.key,
    required this.totalAmount,
    required this.onViewGroupOrder,
    required this.onGoHome,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: CommonAppBar(
        backgroundColor: Colors.transparent,
        title: 'Split Created',
        centerTitle: true,
        onBackPressed: onGoHome,
      ),
      body: Stack(
        children: [
          // Bottom wave
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 100,
            child: CustomPaint(
              painter: BottomWavePainter(),
            ),
          ),

          // Confetti
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: SplitConfettiPainter(),
              ),
            ),
          ),

          // Screen content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),

                          // Success icon
                          const SuccessIconWidget(),

                          const SizedBox(height: 16),

                          // Title
                          const Text(
                            'Split Created\nSuccessfully!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 23,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF171717),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Subtitle
                          const Text(
                            'Your group bill has been split.\n'
                            'Each member can now pay their share.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: AppColors.deepTeal,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Amount card
                          SplitAmountCard(
                            totalAmount: totalAmount,
                          ),

                          const SizedBox(height: 12),

                          // Friends illustration
                          const FriendsIllustrationWidget(),

                          const SizedBox(height: 12),

                          // View group order
                          SplitSuccessButton(
                            title: 'View Group Order',
                            onTap: onViewGroupOrder,
                          ),

                          const SizedBox(height: 8),

                          // Go to home
                          GestureDetector(
                            onTap: onGoHome,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              child: Text(
                                'Go to Home',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.teal,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}