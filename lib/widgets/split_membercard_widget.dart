import 'package:flutter/material.dart';

import '../../Appconstants/app_colors.dart';

class SplitMemberCard extends StatelessWidget {
  final String name;
  final double amount;
  final bool isCustom;
  final TextEditingController? controller;
  final ValueChanged<String>? onAmountChanged;

  const SplitMemberCard({
    super.key,
    required this.name,
    required this.amount,
    this.isCustom = false,
    this.controller,
    this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'Customer' : name.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.teal,
            child: Text(
              displayName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                color: AppColors.deepTeal,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (isCustom)
            SizedBox(
              width: 115,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.end,
                onChanged: onAmountChanged,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.warmIvory,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            )
          else
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: AppColors.deepTeal,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}