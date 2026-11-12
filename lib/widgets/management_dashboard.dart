import 'package:flutter/material.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class ManagementDashboardStat {
  final String label;
  final String value;
  final IconData icon;

  const ManagementDashboardStat({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class ManagementDashboardSection {
  final String label;
  final IconData icon;
  final String description;
  final List<String> features;

  const ManagementDashboardSection({
    required this.label,
    required this.icon,
    required this.description,
    this.features = const [],
  });
}

class ManagementDashboard extends StatefulWidget {
  final String role;
  final String title;
  final String subtitle;
  final List<ManagementDashboardStat> stats;
  final List<ManagementDashboardSection> sections;

  const ManagementDashboard({
    super.key,
    required this.role,
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.sections,
  });

  @override
  State<ManagementDashboard> createState() => _ManagementDashboardState();
}

class _ManagementDashboardState extends State<ManagementDashboard> {
  int _selectedSection = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: CommonAppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.restaurant_rounded, color: AppColors.teal),
            const SizedBox(width: 8),
            const Text(
              'YummyGo',
              style: TextStyle(
                color: AppColors.deepTeal,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lightTeal,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.role,
                style: const TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _selectedSection,
          children: [
            _buildOverview(context),
            for (var index = 1; index < widget.sections.length; index++)
              _buildSection(context, widget.sections[index]),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedSection,
        onDestinationSelected: (index) {
          setState(() => _selectedSection = index);
        },
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.lightTeal,
        destinations: [
          for (final item in widget.sections)
            NavigationDestination(
              icon: Icon(item.icon),
              label: item.label,
            ),
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context) {
    return ListView(
      key: const PageStorageKey<String>('management-dashboard-overview'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.subtitle,
          style: const TextStyle(color: AppColors.mutedText, height: 1.4),
        ),
        const SizedBox(height: 22),
        const _DashboardSectionTitle(
          title: 'Overview',
          subtitle: 'Your business at a glance',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 560 ? 4 : 2;
            final cardWidth =
                (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final stat in widget.stats)
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(stat: stat),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 25),
        const _DashboardSectionTitle(
          title: 'Quick actions',
          subtitle: 'Go to a workspace section',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 560 ? 3 : 2;
            final cardWidth =
                (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var index = 1; index < widget.sections.length; index++)
                  SizedBox(
                    width: cardWidth,
                    child: _QuickActionCard(
                      section: widget.sections[index],
                      onTap: () => setState(() => _selectedSection = index),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        const _SetupNotice(),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    ManagementDashboardSection section,
  ) {
    return ListView(
      key: PageStorageKey<String>('management-section-${section.label}'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          section.label,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          section.description,
          style: const TextStyle(color: AppColors.mutedText, height: 1.4),
        ),
        const SizedBox(height: 20),
        for (final feature in section.features)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(
                      color: AppColors.deepTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.mutedText),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const _SetupNotice(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => setState(() => _selectedSection = 0),
          icon: const Icon(Icons.dashboard_outlined),
          label: const Text('Back to overview'),
        ),
      ],
    );
  }
}

class _DashboardSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DashboardSectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final ManagementDashboardStat stat;

  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, color: AppColors.teal, size: 23),
          const SizedBox(height: 15),
          Text(
            stat.value,
            style: const TextStyle(
              color: AppColors.deepTeal,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            stat.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final ManagementDashboardSection section;
  final VoidCallback onTap;

  const _QuickActionCard({required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(section.icon, color: AppColors.teal, size: 23),
              const Spacer(),
              Text(
                section.label,
                style: const TextStyle(
                  color: AppColors.deepTeal,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Open workspace',
                style: TextStyle(color: AppColors.mutedText, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightOrange,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.deepTeal, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dashboard preview. Live data and management actions will be '
              'connected after account roles and permissions are configured.',
              style: TextStyle(
                color: AppColors.deepTeal,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
