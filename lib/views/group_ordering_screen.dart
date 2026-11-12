import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yummy_go_application/Appconstants/app_images.dart';

import '../../Appconstants/app_colors.dart';
import '../../services/group_order_service.dart';
import 'group_room_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class GroupOrderingScreen extends StatelessWidget {
  const GroupOrderingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'Group Ordering',
        centerTitle: true,
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Image.network(
                    AppImages.groupBanner,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.bottomLeft,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.deepTeal.withOpacity(0.9),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                    ),
                    child: const Text(
                      'Good Food.\nGreat Friends.\nOne Shared Order!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Order together, save together!',
              style: TextStyle(
                color: AppColors.deepTeal,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invite your friends, add favourite food and split the bill.',
              style: TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 25),
            _actionCard(
              context,
              title: 'Create a Group',
              subtitle: 'Start a new group order',
              image: AppImages.friendsDining,
              icon: Icons.group_add_rounded,
              color: AppColors.deepTeal,
              screen: const CreateGroupScreen(),
            ),
            const SizedBox(height: 16),
            _actionCard(
              context,
              title: 'Join a Group',
              subtitle: 'Enter 6-character Group Code',
              image: AppImages.groupBanner,
              icon: Icons.groups_rounded,
              color: AppColors.teal,
              screen: const JoinGroupScreen(),
            ),
            const SizedBox(height: 24),
            _myGroupsSection(context, GroupOrderService()),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people_alt_rounded,
                    color: AppColors.teal,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Invite up to 9 friends. Maximum 10 members including you.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _myGroupsSection(BuildContext context, GroupOrderService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Groups',
          style: TextStyle(
            color: AppColors.deepTeal,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: service.userGroupsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Unable to load your groups: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.error),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final groups = [...snapshot.data!]
              ..sort((first, second) {
                final firstCreatedAt = first.data()?['createdAt'] as Timestamp?;
                final secondCreatedAt =
                    second.data()?['createdAt'] as Timestamp?;
                return (secondCreatedAt?.millisecondsSinceEpoch ?? 0).compareTo(
                  firstCreatedAt?.millisecondsSinceEpoch ?? 0,
                );
              });

            if (groups.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: AppColors.teal, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No group orders yet. Tap "Create a Group" to start one, or join using the Group Code from a friend.',
                        style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                for (final group in groups) ...[
                  Material(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.lightTeal,
                        child: Icon(
                          Icons.groups_rounded,
                          color: AppColors.teal,
                        ),
                      ),
                      title: Text(
                        group.data()['groupName']?.toString() ?? 'Group order',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepTeal,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        'Code: ${group.data()['inviteCode'] ?? ''}'
                        ' · ${group.data()['memberCount'] ?? 1} members'
                        ' · ${group.data()['status'] ?? 'open'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 11,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.teal,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => GroupRoomScreen(groupId: group.id),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 9),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String image,
    required IconData icon,
    required Color color,
    required Widget screen,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      child: Container(
        height: 125,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
              child: Image.network(
                image,
                width: 115,
                height: 125,
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 25),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.deepTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _service = GroupOrderService();
  bool _loading = false;

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) {
      _message('Please enter a group name.');
      return;
    }

    setState(() => _loading = true);

    try {
      final id = await _service.createGroup(_nameController.text);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupRoomScreen(groupId: id)),
      );
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'Create Group',
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                AppImages.friendsDining,
                width: double.infinity,
                height: 210,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 25),
            Text(
              'Bring everyone together!',
              style: TextStyle(
                color: AppColors.deepTeal,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter group name',
                filled: true,
                fillColor: AppColors.white,
                prefixIcon: Icon(Icons.group, color: AppColors.teal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Maximum members: 10 (including you)',
              style: TextStyle(color: AppColors.mutedText),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepTeal,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Create Group'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _codeController = TextEditingController();
  final _service = GroupOrderService();
  bool _loading = false;

  Future<void> _join() async {
    final text = _codeController.text.trim();
    if (text.isEmpty) {
      _message('Please enter the 6-character Group Code.');
      return;
    }

    setState(() => _loading = true);

    try {
      final id = await _service.joinGroup(text);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupRoomScreen(groupId: id)),
      );
    } catch (e) {
      _message(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'Join with Group Code',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                AppImages.groupBanner,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Join Your Friend\'s Order',
              style: TextStyle(
                color: AppColors.deepTeal,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the 6-character Group Code shared by the group creator.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 2.5,
                color: AppColors.deepTeal,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 7K2X9P',
                hintStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  letterSpacing: 1.0,
                  fontSize: 14,
                  color: AppColors.mutedText,
                ),
                prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.teal),
                filled: true,
                fillColor: AppColors.white,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: AppColors.mutedText),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Private order: Only invited friends with this Code can see and enter.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _join,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
                      )
                    : const Text('Join with Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
