import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/location_service.dart';
import 'package:yummy_go_application/services/resturent_services.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

class DeliveryLocationSelection {
  final String address;
  final String area;
  final Set<String> restaurantIds;
  final Set<String> restaurantNames;

  const DeliveryLocationSelection({
    required this.address,
    required this.area,
    required this.restaurantIds,
    required this.restaurantNames,
  });

  const DeliveryLocationSelection.clear()
    : address = '',
      area = '',
      restaurantIds = const {},
      restaurantNames = const {};
}

class LocationPickerScreen extends StatefulWidget {
  final String? selectedAddress;

  const LocationPickerScreen({super.key, this.selectedAddress});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _searchController = TextEditingController();
  final _locationService = LocationService();
  bool _findingLocation = false;
  bool _findingSavedAddress = false;
  bool _restaurantsLoaded = false;
  String _query = '';
  List<RestaurantModel> _restaurants = [];
  String? _restaurantLoadError;
  StreamSubscription<List<RestaurantModel>>? _restaurantSubscription;

  User? get _user => FirebaseAuth.instance.currentUser;

  CollectionReference<Map<String, dynamic>> get _addressCollection {
    final user = _user;
    if (user == null) {
      throw StateError('Please sign in to view saved addresses.');
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('addresses');
  }

  @override
  void initState() {
    super.initState();
    _restaurantSubscription = RestaurantService().getRestaurants().listen(
      (restaurants) {
        if (!mounted) return;
        setState(() {
          _restaurants = restaurants
              .where((restaurant) => restaurant.isAvailable)
              .toList();
          _restaurantsLoaded = true;
          _restaurantLoadError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _restaurantLoadError = error.toString());
      },
    );
  }

  Future<void> _selectLocation(DeliveryLocationSelection selection) async {
    if (mounted) Navigator.pop(context, selection);
  }

  String _displayAddress(Map<String, dynamic> data) {
    return [data['addressLine'], data['city'], data['postalCode']]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(', ');
  }

  String _matchingArea(String address) {
    final normalizedAddress = _normalizeArea(address);
    final sortedAreas = _areas.toList()
      ..sort((first, second) => second.length.compareTo(first.length));
    for (final area in sortedAreas) {
      final normalizedArea = _normalizeArea(area);
      if (normalizedArea.isNotEmpty &&
          normalizedAddress.contains(normalizedArea)) {
        return area;
      }
    }
    return '';
  }

  String _normalizeArea(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceAll('hitech', 'hitec')
        .replaceAll('hytech', 'hitec');
  }

  List<RestaurantModel> _restaurantsForArea(String area) {
    if (area.isEmpty) return const [];
    final normalizedArea = _normalizeArea(area);
    return _restaurants.where((restaurant) {
      final restaurantArea = _normalizeArea(restaurant.area);
      return restaurantArea.isNotEmpty &&
          (restaurantArea == normalizedArea ||
              restaurantArea.contains(normalizedArea) ||
              normalizedArea.contains(restaurantArea));
    }).toList();
  }

  List<RestaurantModel> _mergeRestaurants(
    List<RestaurantModel> first,
    List<RestaurantModel> second,
  ) {
    return {
      for (final restaurant in first) restaurant.id: restaurant,
      for (final restaurant in second) restaurant.id: restaurant,
    }.values.toList();
  }

  DeliveryLocationSelection _selection({
    required String address,
    required String area,
    required List<RestaurantModel> restaurants,
  }) {
    return DeliveryLocationSelection(
      address: address,
      area: area,
      restaurantIds: restaurants.map((restaurant) => restaurant.id).toSet(),
      restaurantNames: restaurants
          .map((restaurant) => restaurant.name.trim().toLowerCase())
          .toSet(),
    );
  }

  List<String> get _areas {
    final unique = <String, String>{};
    for (final restaurant in _restaurants) {
      final area = restaurant.area.trim();
      if (restaurant.isAvailable && area.isNotEmpty) {
        unique.putIfAbsent(area.toLowerCase(), () => area);
      }
    }
    return unique.values.toList()..sort();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _restaurantSubscription?.cancel();
    super.dispose();
  }

  Future<void> _ensureRestaurantsLoaded() async {
    if (_restaurantsLoaded) return;
    try {
      final restaurants = await RestaurantService().getRestaurants().first;
      final foodSnap = await FirebaseFirestore.instance.collection('food_items').get();

      final approvedRestaurantIdsWithMenu = foodSnap.docs
          .where((doc) {
            final d = doc.data();
            return d['isAvailable'] == null
                ? true
                : (d['isAvailable'] == true ||
                    d['isAvailable'].toString().toLowerCase() == 'true');
          })
          .map((doc) =>
              (doc.data()['restaurantId'] ?? doc.data()['restaurant_id'])
                  ?.toString() ??
              '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final approvedRestaurantNamesWithMenu = foodSnap.docs
          .where((doc) {
            final d = doc.data();
            return d['isAvailable'] == null
                ? true
                : (d['isAvailable'] == true ||
                    d['isAvailable'].toString().toLowerCase() == 'true');
          })
          .map((doc) =>
              (doc.data()['restaurant'] ?? doc.data()['restaurantName'])
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '')
          .where((name) => name.isNotEmpty)
          .toSet();

      if (!mounted) return;
      setState(() {
        _restaurants = restaurants.where((restaurant) {
          if (!restaurant.isApproved) return false;
          final hasMenu = approvedRestaurantIdsWithMenu.contains(restaurant.id) ||
              approvedRestaurantNamesWithMenu.contains(
                restaurant.name.trim().toLowerCase(),
              );
          return hasMenu;
        }).toList();
        _restaurantsLoaded = true;
        _restaurantLoadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _restaurantLoadError = e.toString();
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _findingLocation = true);
    try {
      await _ensureRestaurantsLoaded();
      if (!mounted) return;
      final position = await _locationService.getCurrentLocation();
      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        throw Exception('Could not find an address for your current location.');
      }
      final place = placemarks.first;
      final parts =
          [
                place.name,
                place.subLocality,
                place.locality,
                place.subAdministrativeArea,
                place.administrativeArea,
                place.postalCode,
              ]
              .whereType<String>()
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toList();
      final address = parts.toSet().join(', ');
      if (address.isEmpty) {
        throw Exception('Could not identify your current area.');
      }
      final area = _matchingArea(address);
      final nearbyRestaurants = _locationService.getNearbyRestaurants(
        restaurants: _restaurants,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final selectedRestaurants = _mergeRestaurants(
        _restaurantsForArea(area),
        nearbyRestaurants,
      );
      if (!mounted) return;
      await _selectLocation(
        _selection(
          address: address,
          area: area,
          restaurants: selectedRestaurants,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to get current location: $error', error: true);
    } finally {
      if (mounted) setState(() => _findingLocation = false);
    }
  }

  Future<void> _selectSavedAddress(Map<String, dynamic> data) async {
    if (_findingSavedAddress) return;
    setState(() => _findingSavedAddress = true);
    try {
      await _selectSavedAddressForAddress(data);
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Unable to load restaurants for this address: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _findingSavedAddress = false);
    }
  }

  Future<void> _selectSavedAddressForAddress(Map<String, dynamic> data) async {
    await _ensureRestaurantsLoaded();
    if (!mounted) return;
    final address = _displayAddress(data);
    if (address.isEmpty) {
      _showMessage('This saved address has no address details.', error: true);
      return;
    }

    final area = _matchingArea(address);
    var matchedRestaurants = _restaurantsForArea(area);
    try {
      final locations = await Geocoding().locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final nearby = _locationService.getNearbyRestaurants(
          restaurants: _restaurants,
          latitude: location.latitude,
          longitude: location.longitude,
        );
        matchedRestaurants = _mergeRestaurants(matchedRestaurants, nearby);
      }
    } catch (error) {
      if (matchedRestaurants.isEmpty) {
        if (!mounted) return;
        _showMessage(
          'Unable to find nearby restaurants for this address: $error',
          error: true,
        );
        return;
      }
    }

    if (!mounted) return;
    await _selectLocation(
      _selection(address: address, area: area, restaurants: matchedRestaurants),
    );
  }

  Future<void> _deleteAddress(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.warmIvory,
        title: const Text(
          'Delete saved address?',
          style: TextStyle(color: AppColors.deepTeal),
        ),
        content: const Text('This address will be removed from your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await document.reference.delete();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to delete address: $error', error: true);
    }
  }

  Future<void> _addNewAddress() async {
    final address = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _LocationAddressDialog(),
    );
    if (address == null || !mounted) return;

    try {
      await _addressCollection.add({
        ...address,
        'createdAt': FieldValue.serverTimestamp(),
        'isDefault': false,
      });
      if (!mounted) return;
      _showMessage('Address saved.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to save address: $error', error: true);
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
    final CollectionReference<Map<String, dynamic>> addresses;
    try {
      addresses = _addressCollection;
    } on StateError catch (error) {
      return _errorScaffold(error.message);
    }
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: CommonAppBar(
        title: 'Select Your Location',
        actions: [
          if (widget.selectedAddress != null)
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                const DeliveryLocationSelection.clear(),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(color: AppColors.deepTeal),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'Search saved addresses',
                prefixIcon: const Icon(Icons.search, color: AppColors.teal),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.teal,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _findingLocation ? null : _useCurrentLocation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.deepTeal,
                  backgroundColor: AppColors.lightTeal,
                  side: const BorderSide(color: AppColors.teal),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: _findingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: Text(
                  _findingLocation
                      ? 'Finding current address…'
                      : 'Use Current Location',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addNewAddress,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.deepTeal,
                  side: const BorderSide(color: AppColors.teal),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add New Address'),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
              children: [
                _sectionLabel('SAVED ADDRESSES'),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: addresses.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _errorCard(
                        'Unable to load saved addresses: ${snapshot.error}',
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.teal,
                          ),
                        ),
                      );
                    }
                    final docs = (snapshot.data?.docs ?? []).where((document) {
                      final data = document.data();
                      final text = [
                        data['label'],
                        data['addressLine'],
                        data['city'],
                        data['postalCode'],
                      ].join(' ').toLowerCase();
                      return text.contains(_query.toLowerCase());
                    }).toList();
                    if (docs.isEmpty) {
                      return _emptyCard(
                        _query.isEmpty
                            ? 'No saved addresses yet. Add an address from your profile.'
                            : 'No saved addresses match your search.',
                      );
                    }
                    return Card(
                      color: AppColors.white,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          for (var index = 0; index < docs.length; index++) ...[
                            _savedAddressTile(docs[index]),
                            if (index != docs.length - 1)
                              const Divider(
                                height: 1,
                                indent: 66,
                                endIndent: 12,
                                color: AppColors.border,
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                if (_restaurantLoadError != null) ...[
                  const SizedBox(height: 16),
                  _errorCard(
                    'Nearby restaurant data is unavailable: $_restaurantLoadError',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedAddressTile(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final label = data['label']?.toString() ?? 'Saved address';
    final address = [
      data['addressLine'],
      data['city'],
      data['postalCode'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.lightTeal,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          label.toLowerCase() == 'work'
              ? Icons.work_outline_rounded
              : Icons.home_outlined,
          color: AppColors.deepTeal,
        ),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.deepTeal,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        address.isEmpty ? 'No address details' : address,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: AppColors.deepTeal),
        onSelected: (action) {
          if (action == 'delete') _deleteAddress(document);
          if (action == 'select') {
            _selectSavedAddress(data);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'select', child: Text('Use this address')),
          PopupMenuItem(value: 'delete', child: Text('Delete address')),
        ],
      ),
      onTap: () => _selectSavedAddress(data),
    );
  }

  Widget _sectionLabel(String title) => Text(
    title,
    style: const TextStyle(
      color: AppColors.mutedText,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
    ),
  );

  Widget _emptyCard(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(message, style: const TextStyle(color: AppColors.mutedText)),
  );

  Widget _errorCard(String message) => _emptyCard(message);

  Widget _errorScaffold(String message) => Scaffold(
    backgroundColor: AppColors.warmIvory,
    appBar: const CommonAppBar(
      title: 'Select Your Location',
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.error),
        ),
      ),
    ),
  );
}

class _LocationAddressDialog extends StatefulWidget {
  const _LocationAddressDialog();

  @override
  State<_LocationAddressDialog> createState() => _LocationAddressDialogState();
}

class _LocationAddressDialogState extends State<_LocationAddressDialog> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController(text: 'Home');
  final _addressLine = TextEditingController();
  final _city = TextEditingController();
  final _postalCode = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _addressLine.dispose();
    _city.dispose();
    _postalCode.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.warmIvory,
    surfaceTintColor: AppColors.warmIvory,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add new address',
                  style: TextStyle(
                    color: AppColors.deepTeal,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _field(_label, 'Label (Home, Work)', required: true),
                _field(_addressLine, 'Street address', required: true),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.deepTeal,
                          side: const BorderSide(color: AppColors.teal),
                          minimumSize: const Size.fromHeight(48),
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
                            'addressLine': _addressLine.text.trim(),
                            'city': _city.text.trim(),
                            'postalCode': _postalCode.text.trim(),
                            'phone': _phone.text.trim(),
                          });
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.deepTeal,
                          foregroundColor: AppColors.white,
                          minimumSize: const Size.fromHeight(48),
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
      ),
    ),
  );

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
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
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
