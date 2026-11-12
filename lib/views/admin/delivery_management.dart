import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/delivery_partner_model.dart';
import 'package:yummy_go_application/services/admin_service.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({super.key});

  @override
  State<DeliveryManagementScreen> createState() =>
      _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen> {
  final AdminService _adminService = AdminService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'Delivery Fleet Management',
      ),
      body: StreamBuilder<List<DeliveryPartnerModel>>(
        stream: _adminService.streamDeliveryPartners(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.teal));
          }

          final partners = snapshot.data ?? [];
          if (partners.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delivery_dining_rounded,
                    size: 64,
                    color: AppColors.mutedText.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No delivery partners registered yet',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: partners.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final partner = partners[index];
              final isApproved = partner.status == 'approved';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.lightLime,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.electric_moped_rounded,
                            color: AppColors.limeGreen,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                partner.name,
                                style: const TextStyle(
                                  color: AppColors.deepTeal,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${partner.vehicleType} ${partner.vehicleNumber.isNotEmpty ? '• ${partner.vehicleNumber}' : ''}',
                                style: const TextStyle(
                                  color: AppColors.mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: partner.isAvailable
                                ? AppColors.lightLime
                                : AppColors.lightOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            partner.isAvailable ? 'ONLINE' : 'OFFLINE',
                            style: TextStyle(
                              color: partner.isAvailable
                                  ? AppColors.success
                                  : AppColors.error,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat('Rating', '★ ${partner.rating.toStringAsFixed(1)}'),
                        _buildStat('Deliveries', '${partner.totalDeliveries}'),
                        _buildStat('Total Earnings', '₹${partner.earnings.toStringAsFixed(0)}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (partner.phone.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.phone_rounded, size: 14, color: AppColors.mutedText),
                              const SizedBox(width: 4),
                              Text(
                                partner.phone,
                                style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                              ),
                            ],
                          )
                        else
                          const SizedBox(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isApproved ? AppColors.lightOrange : AppColors.lightLime,
                            foregroundColor: isApproved ? AppColors.error : AppColors.success,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          onPressed: () async {
                            await _adminService.setDeliveryPartnerStatus(
                              partner.id,
                              isApproved ? 'suspended' : 'approved',
                            );
                          },
                          child: Text(
                            isApproved ? 'Suspend Partner' : 'Approve Partner',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.mutedText, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
