import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/order_model.dart';
import 'package:yummy_go_application/services/cart_service.dart';
import 'package:yummy_go_application/services/order_service.dart';
import 'package:yummy_go_application/views/cart_screen.dart';
import 'package:yummy_go_application/views/customer/customer_home_screen.dart';
import 'package:yummy_go_application/views/order_tracking_screen.dart';
import 'package:yummy_go_application/views/resturent_menu_screen.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _saving = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _user;
    if (user == null) {
      _showMessage('Please sign in again to update your profile.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await user.updateDisplayName(_nameController.text.trim());
      await user.reload();
      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Unable to update your name.', error: true);
    } catch (error) {
      _showMessage('Unable to update your name: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.deepTeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'Personal Details',
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: user?.email ?? '',
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.deepTeal,
                    ),
                    child: _saving
                        ? const CircularProgressIndicator()
                        : const Text('Save changes'),
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

class SavedAddressesScreen extends StatelessWidget {
  const SavedAddressesScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _addresses {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Please sign in to manage addresses.');
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('addresses');
  }

  Future<void> _addAddress(BuildContext context) async {
    final address = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _AddressEditorDialog(),
    );
    if (address == null || !context.mounted) return;

    try {
      await _addresses.add({
        ...address,
        'createdAt': FieldValue.serverTimestamp(),
        'isDefault': false,
      });
      if (!context.mounted) return;
      _message(context, 'Address saved.');
    } catch (error) {
      if (!context.mounted) return;
      _message(context, 'Unable to save address: $error', error: true);
    }
  }

  Future<void> _deleteAddress(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> address,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete address?'),
        content: const Text('This saved address will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await address.reference.delete();
      if (!context.mounted) return;
      _message(context, 'Address deleted.');
    } catch (error) {
      if (!context.mounted) return;
      _message(context, 'Unable to delete address: $error', error: true);
    }
  }

  void _message(BuildContext context, String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : AppColors.deepTeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CollectionReference<Map<String, dynamic>> addressCollection;
    try {
      addressCollection = _addresses;
    } on StateError catch (error) {
      return _ProfileErrorScreen(message: error.message);
    }

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'Saved Addresses',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAddress(context),
        backgroundColor: AppColors.deepTeal,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: addressCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ProfileErrorContent(
              message: 'Unable to load saved addresses: ${snapshot.error}',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            );
          }
          final addresses = snapshot.data?.docs ?? [];
          if (addresses.isEmpty) {
            return const _ProfileEmptyContent(
              icon: Icons.location_on_outlined,
              title: 'No saved addresses',
              message: 'Add an address to make future deliveries easier.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: addresses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final document = addresses[index];
              final data = document.data();
              final line =
                  [data['addressLine'], data['city'], data['postalCode']]
                      .where(
                        (part) => part != null && part.toString().isNotEmpty,
                      )
                      .join(', ');
              return Card(
                color: AppColors.white,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightTeal,
                    child: Icon(Icons.home_rounded, color: AppColors.teal),
                  ),
                  title: Text(
                    data['label']?.toString() ?? 'Address',
                    style: const TextStyle(
                      color: AppColors.deepTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    [
                      line,
                      if ((data['phone']?.toString() ?? '').isNotEmpty)
                        data['phone'].toString(),
                    ].where((part) => part.isNotEmpty).join('\n'),
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete address',
                    onPressed: () => _deleteAddress(context, document),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddressEditorDialog extends StatefulWidget {
  const _AddressEditorDialog();

  @override
  State<_AddressEditorDialog> createState() => _AddressEditorDialogState();
}

class _AddressEditorDialogState extends State<_AddressEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController(text: 'Home');
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _postalCode = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _address.dispose();
    _city.dispose();
    _postalCode.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.warmIvory,
      surfaceTintColor: AppColors.warmIvory,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.deepTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Add saved address',
                      style: TextStyle(
                        color: AppColors.deepTeal,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _field(_label, 'Label (Home, Work)', required: true),
                      _field(_address, 'Street address', required: true),
                      _field(_city, 'City / area', required: true),
                      _field(
                        _postalCode,
                        'Postal code',
                        required: true,
                        keyboardType: TextInputType.number,
                      ),
                      _field(
                        _phone,
                        'Contact phone (optional)',
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.deepTeal,
                        side: const BorderSide(color: AppColors.teal),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.pop(context, {
                          'label': _label.text.trim(),
                          'addressLine': _address.text.trim(),
                          'city': _city.text.trim(),
                          'postalCode': _postalCode.text.trim(),
                          'phone': _phone.text.trim(),
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.deepTeal,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Save address'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.deepTeal),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.mutedText),
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
        ),
        validator: required
            ? (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null
            : null,
      ),
    );
  }
}

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _ProfileErrorScreen(
        message: 'Please sign in to view your orders.',
      );
    }

    final orderService = OrderService();

    return StreamBuilder<List<OrderModel>>(
      stream: orderService.streamCustomerOrders(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.warmIvory,
            appBar: const CommonAppBar(
              title: 'My Orders',
            ),
            body: _ProfileErrorContent(
              message: 'Unable to load orders: ${snapshot.error}',
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.warmIvory,
            appBar: CommonAppBar(
              title: 'My Orders',
            ),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            ),
          );
        }

        final allOrders = snapshot.data ?? [];
        final activeOrders = allOrders.where((o) => o.isActive).toList();
        final deliveredOrders = allOrders.where((o) => o.isDelivered || !o.isActive).toList();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: AppColors.warmIvory,
            appBar: CommonAppBar(
              title: 'My Orders',
              bottom: TabBar(
                labelColor: AppColors.deepTeal,
                unselectedLabelColor: AppColors.mutedText,
                indicatorColor: AppColors.teal,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Active Orders'),
                        if (activeOrders.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.teal,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${activeOrders.length}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Past Orders'),
                        if (deliveredOrders.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${deliveredOrders.length}',
                              style: const TextStyle(
                                color: AppColors.deepTeal,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildActiveOrdersList(context, activeOrders),
                _buildDeliveredOrdersList(context, deliveredOrders),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveOrdersList(BuildContext context, List<OrderModel> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.delivery_dining_outlined,
                  size: 44,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Active Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepTeal,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'You have no orders currently in progress.\nExplore top restaurants and satisfy your cravings!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.mutedText, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepTeal,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.restaurant_rounded, size: 18),
                label: const Text(
                  'Browse Restaurants',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildActiveOrderCard(context, order);
      },
    );
  }

  Widget _buildActiveOrderCard(BuildContext context, OrderModel order) {
    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    switch (order.orderStatus.toLowerCase()) {
      case 'placed':
        statusColor = AppColors.goldenOrange;
        statusBg = AppColors.lightOrange;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'confirmed':
        statusColor = AppColors.teal;
        statusBg = AppColors.lightTeal;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'preparing':
        statusColor = AppColors.deepTeal;
        statusBg = AppColors.lightTeal;
        statusIcon = Icons.soup_kitchen_rounded;
        break;
      case 'ready_for_pickup':
        statusColor = Colors.purple.shade700;
        statusBg = Colors.purple.shade50;
        statusIcon = Icons.inventory_2_rounded;
        break;
      case 'out_for_delivery':
      case 'on_the_way':
      case 'picked_up':
        statusColor = AppColors.success;
        statusBg = AppColors.lightLime;
        statusIcon = Icons.delivery_dining_rounded;
        break;
      default:
        statusColor = AppColors.teal;
        statusBg = AppColors.lightTeal;
        statusIcon = Icons.fastfood_rounded;
        break;
    }

    final itemsSummary = order.items.isNotEmpty
        ? order.items.map((i) => '${i.quantity}x ${i.name}').join(', ')
        : 'Food Items';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepTeal.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Restaurant Name & Live Status Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.lightTeal,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    color: AppColors.teal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepTeal,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: order.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Order ID #${order.id} copied!'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppColors.teal,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Order #${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id}',
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 12, color: AppColors.teal),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        order.statusDisplay,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Items and Details
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppColors.mutedText, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        itemsSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepTeal,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (order.deliveryAddress.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppColors.mutedText, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.deliveryAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.lightLime,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 12, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            'Paid via Razorpay',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.deepTeal,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Button: Track Live Order (Reordering locked until delivery)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepTeal,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderTrackingScreen(
                        orderId: order.id,
                        groupId: order.groupId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.navigation_rounded, size: 16),
                label: const Text(
                  'Track Live Order',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveredOrdersList(BuildContext context, List<OrderModel> orders) {
    if (orders.isEmpty) {
      return const _ProfileEmptyContent(
        icon: Icons.receipt_long_rounded,
        title: 'No past orders',
        message: 'Your completed orders will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        final dateStr = order.createdAt != null
            ? MaterialLocalizations.of(context).formatShortDate(order.createdAt!)
            : 'Delivered';

        final itemsCount = order.items.isNotEmpty
            ? '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}'
            : 'Items';

        return Card(
          color: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        order.restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepTeal,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.lightLime,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            'Delivered',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Order #${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id} • $dateStr • $itemsCount',
                  style: const TextStyle(color: AppColors.mutedText, fontSize: 11.5),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.deepTeal,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.deepTeal,
                            side: const BorderSide(color: AppColors.border, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderTrackingScreen(
                                  orderId: order.id,
                                  groupId: order.groupId,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Details',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          onPressed: () => _handleReorder(context, order),
                          icon: const Icon(Icons.replay_rounded, size: 14),
                          label: const Text(
                            'Reorder',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // REORDER / ORDER AGAIN HANDLER
  void _handleReorder(BuildContext context, OrderModel order) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final activeOrder = await OrderService().getActiveUserOrder(uid);
      if (activeOrder != null) {
        if (context.mounted) {
          final shortId = activeOrder.id.length > 8
              ? activeOrder.id.substring(0, 8).toUpperCase()
              : activeOrder.id;
          final type = activeOrder.isGroupOrder ? 'group' : 'individual';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You have an active $type order in progress (#$shortId • ${activeOrder.statusDisplay}). You can place a new order once your current order is delivered.',
              ),
              backgroundColor: AppColors.goldenOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    if (order.items.isEmpty) {
      if (order.restaurantId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantMenuScreen(
              restaurantId: order.restaurantId,
              restaurantName: order.restaurantName,
              rating: 4.5,
            ),
          ),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
          (route) => false,
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.warmIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Order Again from ${order.restaurantName}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepTeal,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose how you want to order again:',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(modalContext);
                    await _reorderItemsToCart(context, order);
                  },
                  icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 20),
                  label: Text('Repeat Order (${order.items.length} items • ₹${order.totalAmount.toStringAsFixed(0)})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(modalContext);
                    if (order.restaurantId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RestaurantMenuScreen(
                            restaurantId: order.restaurantId,
                            restaurantName: order.restaurantName,
                            rating: 4.5,
                          ),
                        ),
                      );
                    } else {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.restaurant_menu_rounded, size: 20),
                  label: const Text('View Restaurant Menu'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepTeal,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

  Future<void> _reorderItemsToCart(BuildContext context, OrderModel order) async {
    final cartService = CartService();
    try {
      await cartService.clearCart();
      for (final item in order.items) {
        await cartService.addToCart(
          foodId: item.id.isNotEmpty
              ? item.id
              : 'food_${DateTime.now().millisecondsSinceEpoch}_${item.name.hashCode.abs()}',
          foodName: item.name,
          image: item.image,
          price: item.price,
          restaurantId: order.restaurantId,
          restaurantName: order.restaurantName,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Items from ${order.restaurantName} added to cart!'),
          backgroundColor: AppColors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reorder: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class ProfileHelpScreen extends StatefulWidget {
  const ProfileHelpScreen({super.key});

  @override
  State<ProfileHelpScreen> createState() => _ProfileHelpScreenState();
}

class _ProfileHelpScreenState extends State<ProfileHelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Please sign in to contact support.', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('support_requests')
          .add({
            'message': _messageController.text.trim(),
            'email': user.email,
            'status': 'open',
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      _messageController.clear();
      _showMessage('Your support request has been sent.');
    } catch (error) {
      _showMessage('Unable to send your request: $error', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessage(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : AppColors.deepTeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'Help & Support',
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Frequently asked questions',
            style: TextStyle(
              color: AppColors.deepTeal,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const _HelpQuestion(
            question: 'How do I join a group order?',
            answer: 'Open Group Orders, choose Join a Group, and enter the invitation code shared by the group creator.',
          ),
          const _HelpQuestion(
            question: 'Where are my saved foods?',
            answer: 'Open Favorite Foods from your profile to view your saved dishes and restaurants.',
          ),
          const _HelpQuestion(
            question: 'How do I update my profile?',
            answer: 'Choose Personal Details from your profile to update your display name.',
          ),
          const SizedBox(height: 20),
          // const Text(
          //   'Send us a message',
          //   style: TextStyle(
          //     color: AppColors.deepTeal,
          //     fontSize: 18,
          //     fontWeight: FontWeight.w800,
          //   ),
          // ),
          // const SizedBox(height: 8),
          // Form(
          //   key: _formKey,
          //   child: TextFormField(
          //     controller: _messageController,
          //     minLines: 4,
          //     maxLines: 7,
          //     maxLength: 1000,
          //     decoration: const InputDecoration(
          //       hintText: 'Tell us how we can help',
          //       filled: true,
          //       fillColor: AppColors.white,
          //       border: OutlineInputBorder(),
          //     ),
          //     validator: (value) => value == null || value.trim().length < 5
          //         ? 'Please enter at least 5 characters.'
          //         : null,
          //   ),
          // ),
          const SizedBox(height: 10),
          
        ],
      ),
    );
  }
}

class _HelpQuestion extends StatelessWidget {
  final String question;
  final String answer;

  const _HelpQuestion({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontWeight: FontWeight.w700,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  void _showMessage(
    BuildContext context,
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.deepTeal,
      ),
    );
  }

  Future<void> _sendVerification(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage(context, 'Please sign in again.', error: true);
      return;
    }
    try {
      await user.sendEmailVerification();
      if (!context.mounted) return;
      _showMessage(context, 'Verification email sent to ${user.email ?? ''}.');
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) return;
      _showMessage(
        context,
        error.message ?? 'Unable to send verification email.',
        error: true,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(
        context,
        'Unable to send verification email: $error',
        error: true,
      );
    }
  }

  Future<void> _resetPassword(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      _showMessage(
        context,
        'This account does not have an email address.',
        error: true,
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!context.mounted) return;
      _showMessage(context, 'Password reset link sent to $email.');
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) return;
      _showMessage(
        context,
        error.message ?? 'Unable to send reset link.',
        error: true,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'Unable to send reset link: $error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: 'Settings',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppColors.white,
            child: ListTile(
              leading: const Icon(
                Icons.verified_user_outlined,
                color: AppColors.teal,
              ),
              title: const Text('Email verification'),
              subtitle: Text(
                user?.emailVerified == true
                    ? 'Your email is verified.'
                    : 'Your email is not verified.',
              ),
              trailing: user?.emailVerified == true
                  ? const Icon(Icons.check_circle, color: AppColors.success)
                  : TextButton(
                      onPressed: () => _sendVerification(context),
                      child: const Text('Verify'),
                    ),
            ),
          ),
          Card(
            color: AppColors.white,
            child: ListTile(
              leading: const Icon(
                Icons.lock_reset_rounded,
                color: AppColors.teal,
              ),
              title: const Text('Reset password'),
              subtitle: const Text('Receive a password reset link by email'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _resetPassword(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileEmptyContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ProfileEmptyContent({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.teal),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.deepTeal,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileErrorContent extends StatelessWidget {
  final String message;

  const _ProfileErrorContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.error),
        ),
      ),
    );
  }
}

class _ProfileErrorScreen extends StatelessWidget {
  final String message;

  const _ProfileErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: const CommonAppBar(
        title: '',
      ),
      body: _ProfileErrorContent(message: message),
    );
  }
}
