
import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class GroupOrderScreen extends StatelessWidget {
  const GroupOrderScreen({super.key});

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        centerTitle: true,
        title: 'Group Order',
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.groups_rounded,
                    size: 75,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Good Food, Great Company!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Order together, share your favourites '
                    'and split the bill easily.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'What would you like to do?',
              style: TextStyle(
                color: AppColors.deepTeal,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            _optionCard(
              icon: Icons.add_circle_outline_rounded,
              title: 'Create a Group',
              subtitle:
                  'Start a new group order and invite your friends.',
              buttonText: 'Create Group',
              onTap: () {
                _showMessage(
                  context,
                  'Create Group feature will be connected next.',
                );
              },
            ),

            const SizedBox(height: 16),

            _optionCard(
              icon: Icons.group_add_rounded,
              title: 'Join a Group',
              subtitle:
                  'Enter your invitation code and join your friends.',
              buttonText: 'Join Group',
              onTap: () {
                _showMessage(
                  context,
                  'Join Group feature will be connected next.',
                );
              },
            ),

            const SizedBox(height: 28),

            const Text(
              'How it works',
              style: TextStyle(
                color: AppColors.deepTeal,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            _step(Icons.group, 'Create or Join',
                'Start a group or join using an invitation.'),
            _step(Icons.restaurant_menu, 'Choose Food',
                'Everyone adds their favourite dishes.'),
            _step(Icons.shopping_cart, 'Live Cart',
                'See everyone’s food selections.'),
            _step(Icons.receipt_long, 'Split the Bill',
                'Choose equal, item-based or custom splitting.'),
            _step(Icons.payment, 'Pay Individually',
                'Each member pays their own share.'),
            _step(Icons.check_circle, 'Place Order',
                'Confirm the order after payment requirements are met.'),
          ],
        ),
      ),
    );
  }

  Widget _optionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 38, color: AppColors.teal),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.deepTeal,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onTap,
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.teal.withOpacity(0.12),
            child: Icon(icon, color: AppColors.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepTeal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
