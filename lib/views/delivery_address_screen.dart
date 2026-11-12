import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yummy_go_application/Appconstants/app_colors.dart';
import 'package:yummy_go_application/models/address_model.dart';
import 'package:yummy_go_application/models/returent_model.dart';
import 'package:yummy_go_application/services/address_service.dart';
import 'package:yummy_go_application/widgets/address_osm_picker.dart';
import 'package:yummy_go_application/widgets/common_app_bar.dart';

enum OrderType { individual, group, manageOnly }

/// Common Delivery Address Screen for Individual and Group Orders.
/// Displays saved addresses for instant selection, and provides clean address entry without maps.
class DeliveryAddressScreen extends StatefulWidget {
  final OrderType orderType;
  final AddressModel? initialAddress;
  final String? groupId;

  const DeliveryAddressScreen({
    super.key,
    this.orderType = OrderType.individual,
    this.initialAddress,
    this.groupId,
  });

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  final AddressService _addressService = AddressService();
  final User? _user = FirebaseAuth.instance.currentUser;

  // Form State
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _houseController = TextEditingController();
  final _streetController = TextEditingController();
  final _areaController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _instructionsController = TextEditingController();

  String _selectedLabel = 'Home';
  bool _saveForFuture = true;
  bool _isDefault = false;

  // Selected Coordinates
  double _selectedLatitude = 17.4442;
  double _selectedLongitude = 78.3845;
  bool _showMapPicker = false;
  bool _isLocatingGps = false;

  // UI Modes: 'saved' (pick from saved) vs 'new' (add/edit form)
  bool _isAddingOrEditing = false;
  String? _editingAddressId;
  AddressModel? _selectedAddress;
  bool _isSubmitting = false;

  final List<String> _quickInstructionChips = [
    'Leave at door',
    'Avoid calling',
    'Don\'t ring bell',
    'Leave with security',
    'Call upon arrival',
  ];

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.initialAddress;

    // Prefill user details from Auth
    if (_user != null) {
      _nameController.text = _user?.displayName ?? '';
      final rawPhone = _user?.phoneNumber ?? '';
      _phoneController.text = rawPhone.replaceAll('+91', '').trim();
    }

    if (widget.initialAddress != null) {
      _selectedLatitude = widget.initialAddress!.latitude;
      _selectedLongitude = widget.initialAddress!.longitude;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _houseController.dispose();
    _streetController.dispose();
    _areaController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _populateFormForEdit(AddressModel address) {
    setState(() {
      _isAddingOrEditing = true;
      _editingAddressId = address.id;
      _nameController.text = address.receiverName;
      _phoneController.text = address.receiverPhone;
      _houseController.text = address.houseFlatNo;
      _streetController.text = address.street;
      _areaController.text = address.area;
      _pincodeController.text = address.pincode;
      _landmarkController.text = address.landmark;
      _instructionsController.text = address.deliveryInstructions;
      _selectedLabel = address.label;
      _isDefault = address.isDefault;
      _selectedLatitude = address.latitude;
      _selectedLongitude = address.longitude;
    });
  }

  void _resetFormForNew() {
    setState(() {
      _isAddingOrEditing = true;
      _editingAddressId = null;
      _nameController.text = _user?.displayName ?? '';
      final rawPhone = _user?.phoneNumber ?? '';
      _phoneController.text = rawPhone.replaceAll('+91', '').trim();
      _houseController.clear();
      _streetController.clear();
      _areaController.clear();
      _pincodeController.clear();
      _landmarkController.clear();
      _instructionsController.clear();
      _selectedLabel = 'Home';
      _isDefault = false;
      _saveForFuture = true;
    });
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Receiver name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-+]'), '').replaceFirst(RegExp(r'^91'), '').replaceFirst(RegExp(r'^0'), '');
    if (cleaned.length != 10) {
      return 'Mobile number must be exactly 10 digits';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return 'Enter valid 10-digit mobile number (starts with 6-9)';
    }
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validatePincode(String? value) {
    final cleaned = (value ?? '').trim();
    if (cleaned.isEmpty) {
      return 'Pincode is required';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(cleaned)) {
      return 'Enter valid 6-digit pincode';
    }
    return null;
  }

  Future<void> _reverseGeocodeAndFill(double lat, double lng) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty || !mounted) return;
      final place = placemarks.first;

      final streetParts = [
        place.thoroughfare,
        place.street,
      ]
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final areaParts = [
        place.subLocality,
        place.locality,
        place.subAdministrativeArea,
      ]
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      final rawPin = (place.postalCode ?? '').replaceAll(RegExp(r'\D'), '');

      setState(() {
        if (_streetController.text.trim().isEmpty && streetParts.isNotEmpty) {
          _streetController.text = streetParts.first;
        }
        if (_areaController.text.trim().isEmpty && areaParts.isNotEmpty) {
          _areaController.text = areaParts.take(2).join(', ');
        }
        if (_pincodeController.text.trim().isEmpty && rawPin.length == 6) {
          _pincodeController.text = rawPin;
        }
      });
    } catch (_) {
      // Offline / unsupported geocoding fallback - keep coordinates cleanly.
    }
  }

  Future<void> _useCurrentGps() async {
    setState(() => _isLocatingGps = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable device GPS / location services.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to detect GPS location.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos != null && mounted) {
        final lat = pos.latitude;
        final lng = pos.longitude;
        setState(() {
          _selectedLatitude = lat;
          _selectedLongitude = lng;
        });
        await _reverseGeocodeAndFill(lat, lng);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery location updated from device GPS!'),
            backgroundColor: AppColors.teal,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to detect GPS right now. Enter address manually.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocatingGps = false);
    }
  }

  Future<void> _handleSaveAndConfirm() async {
    final uid = _user?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to manage addresses.')),
      );
      return;
    }

    if (_isAddingOrEditing) {
      // Validate form
      if (!_formKey.currentState!.validate()) {
        return;
      }

      // Resolve exact coordinates for this delivery location so it displays accurately in map routes
      if (_selectedLatitude == 0.0 && _selectedLongitude == 0.0 ||
          (_selectedLatitude == 17.4442 && _selectedLongitude == 78.3845)) {
        final fullAddressText =
            '${_areaController.text} ${_streetController.text} ${_landmarkController.text} ${_pincodeController.text}';
        final resolved = RestaurantModel.findCoordinatesForText(fullAddressText);
        if (resolved != null) {
          _selectedLatitude = resolved[0];
          _selectedLongitude = resolved[1];
        } else {
          _selectedLatitude = 17.4442;
          _selectedLongitude = 78.3845;
        }
      }

      setState(() => _isSubmitting = true);

      final cleanPhone = _phoneController.text.replaceAll(RegExp(r'[\s\-+]'), '').replaceFirst(RegExp(r'^91'), '').replaceFirst(RegExp(r'^0'), '');

      final addressToSave = AddressModel(
        id: _editingAddressId ?? '',
        userId: uid,
        receiverName: _nameController.text.trim(),
        receiverPhone: cleanPhone,
        houseFlatNo: _houseController.text.trim(),
        street: _streetController.text.trim(),
        area: _areaController.text.trim(),
        pincode: _pincodeController.text.trim(),
        landmark: _landmarkController.text.trim(),
        deliveryInstructions: _instructionsController.text.trim(),
        label: _selectedLabel,
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
        isDefault: _isDefault,
      );

      try {
        String savedId = addressToSave.id;
        final shouldSaveToProfile = widget.orderType == OrderType.manageOnly ||
            _saveForFuture ||
            _editingAddressId != null;
        if (shouldSaveToProfile) {
          savedId = await _addressService.saveAddress(addressToSave);
        }

        final confirmedAddress = addressToSave.copyWith(id: savedId);

        setState(() {
          _isSubmitting = false;
          _selectedAddress = confirmedAddress;
          _isAddingOrEditing = false;
        });

        if (widget.orderType != OrderType.manageOnly && mounted) {
          Navigator.pop(context, confirmedAddress);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address saved successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving address: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    } else {
      // User selected an existing saved address
      if (_selectedAddress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a delivery address or add a new one.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (mounted) {
        Navigator.pop(context, _selectedAddress);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _user?.uid ?? '';
    final isGroup = widget.orderType == OrderType.group;
    final isManageOnly = widget.orderType == OrderType.manageOnly;

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: CommonAppBar(
        title: isManageOnly
            ? 'Manage Addresses'
            : isGroup
                ? 'Group Delivery Address'
                : 'Delivery Address',
        subtitle: isGroup
            ? 'Where should the group order be delivered?'
            : 'Select or add your food drop-off point',
        actions: [
          if (!_isAddingOrEditing)
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.teal),
              label: const Text('Add New', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
              onPressed: _resetFormForNew,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Order context banner
            if (isGroup)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.groups_rounded, color: AppColors.teal, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This address will be shared with the delivery partner for your group order.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.deepTeal, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _isAddingOrEditing
                  ? _buildAddOrEditAddressForm()
                  : _buildSavedAddressesList(uid),
            ),

            // Bottom Confirmation Bar
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedAddressesList(String uid) {
    return StreamBuilder<List<AddressModel>>(
      stream: _addressService.streamAddresses(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.teal));
        }

        final addresses = snapshot.data ?? [];

        // Auto-select default or first address if none chosen
        if (_selectedAddress == null && addresses.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedAddress = addresses.first;
              });
            }
          });
        }

        if (addresses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_off_rounded, size: 48, color: AppColors.teal),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No saved addresses yet',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.deepTeal),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Add your delivery address to order delicious food directly to your doorstep.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepTeal,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: const Text('Add Delivery Address', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _resetFormForNew,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Saved Addresses',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.deepTeal),
                ),
                Text(
                  '${addresses.length} saved',
                  style: const TextStyle(fontSize: 11, color: AppColors.mutedText, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Add New Address Card
            InkWell(
              onTap: _resetFormForNew,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.teal, width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded, color: AppColors.teal, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '+ Add New Address',
                            style: TextStyle(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            'Enter house/flat, street, area & pincode details',
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.teal),
                  ],
                ),
              ),
            ),

            ...addresses.map((address) {
              final isSelected = _selectedAddress?.id == address.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? AppColors.teal : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.teal.withOpacity(0.12),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedAddress = address;
                    });
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.lightTeal : AppColors.warmIvory,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                address.label.toLowerCase() == 'home'
                                    ? Icons.home_rounded
                                    : address.label.toLowerCase() == 'work'
                                        ? Icons.work_rounded
                                        : Icons.location_on_rounded,
                                size: 18,
                                color: isSelected ? AppColors.teal : AppColors.deepTeal,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        address.label.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: AppColors.deepTeal,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (address.isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.lightLime,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'DEFAULT',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '${address.receiverName} • ${address.receiverPhone}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.mutedText, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            Radio<String>(
                              value: address.id,
                              groupValue: _selectedAddress?.id,
                              activeColor: AppColors.teal,
                              onChanged: (_) {
                                setState(() {
                                  _selectedAddress = address;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Formatted address text
                        Text(
                          address.formattedAddress,
                          style: const TextStyle(fontSize: 13, color: AppColors.deepTeal, height: 1.3),
                        ),

                        // Instructions
                        if (address.deliveryInstructions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.notes_rounded, size: 14, color: AppColors.mutedText),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Note: "${address.deliveryInstructions}"',
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.mutedText),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 10),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 6),

                        // Action buttons (Edit, Delete, Set Default)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!address.isDefault)
                              TextButton(
                                onPressed: () async {
                                  await _addressService.setDefaultAddress(uid, address.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Set as default address.')),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Set as Default', style: TextStyle(fontSize: 11, color: AppColors.teal)),
                              ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.deepTeal),
                              tooltip: 'Edit Address',
                              onPressed: () => _populateFormForEdit(address),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                              tooltip: 'Delete Address',
                              onPressed: () => _confirmDeleteAddress(address),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildAddOrEditAddressForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _editingAddressId != null ? 'Edit Delivery Address' : 'Add Delivery Address',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.deepTeal),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  onPressed: () => setState(() => _isAddingOrEditing = false),
                  label: const Text('Saved Addresses', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Clean address banner (No maps required)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.lightTeal,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.teal.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_on_rounded, color: AppColors.teal, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enter your delivery address details below. Saved addresses will be stored for quick checkout.',
                      style: TextStyle(
                        color: AppColors.deepTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Address Label / Type Selection Chips
            const Text(
              'Save Address As:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.deepTeal),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['Home', 'Work', 'Other'].map((label) {
                final isSelected = _selectedLabel == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          label == 'Home'
                              ? Icons.home_rounded
                              : label == 'Work'
                                  ? Icons.work_rounded
                                  : Icons.location_on_rounded,
                          size: 15,
                          color: isSelected ? AppColors.white : AppColors.deepTeal,
                        ),
                        const SizedBox(width: 4),
                        Text(label),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedLabel = label);
                    },
                    selectedColor: AppColors.deepTeal,
                    backgroundColor: AppColors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.deepTeal,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 3. Receiver Contact Details Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Receiver Contact Details',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.deepTeal),
                  ),
                  const SizedBox(height: 12),
                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    validator: _validateName,
                    decoration: InputDecoration(
                      labelText: 'Receiver Name *',
                      hintText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_rounded, size: 20, color: AppColors.teal),
                      filled: true,
                      fillColor: AppColors.warmIvory,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Mobile Field (10-digit Indian Mobile Validation)
                  TextFormField(
                    controller: _phoneController,
                    validator: _validateMobile,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number *',
                      hintText: '10-digit number (e.g. 9876543210)',
                      counterText: '',
                      prefixIcon: const Icon(Icons.phone_android_rounded, size: 20, color: AppColors.teal),
                      prefixText: '+91 ',
                      prefixStyle: const TextStyle(color: AppColors.deepTeal, fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: AppColors.warmIvory,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. House & Street Address Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Address Details',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.deepTeal),
                  ),
                  const SizedBox(height: 12),
                  // House/Flat/Block
                  TextFormField(
                    controller: _houseController,
                    validator: (v) => _validateRequired(v, 'House / Flat number'),
                    decoration: InputDecoration(
                      labelText: 'House / Flat / Block / Floor No. *',
                      hintText: 'e.g. Flat 402, Sai Residency',
                      prefixIcon: const Icon(Icons.apartment_rounded, size: 20, color: AppColors.teal),
                      filled: true,
                      fillColor: AppColors.warmIvory,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Street / Road
                  TextFormField(
                    controller: _streetController,
                    validator: (v) => _validateRequired(v, 'Street name'),
                    decoration: InputDecoration(
                      labelText: 'Street / Road / Colony *',
                      hintText: 'e.g. Road No. 12, Banjara Hills',
                      prefixIcon: const Icon(Icons.signpost_rounded, size: 20, color: AppColors.teal),
                      filled: true,
                      fillColor: AppColors.warmIvory,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Area / Locality
                  TextFormField(
                    controller: _areaController,
                    validator: (v) => _validateRequired(v, 'Area / Locality'),
                    decoration: InputDecoration(
                      labelText: 'Area / Locality / Suburb *',
                      hintText: 'e.g. Hitech City / Madhapur',
                      prefixIcon: const Icon(Icons.map_rounded, size: 20, color: AppColors.teal),
                      filled: true,
                      fillColor: AppColors.warmIvory,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Pincode (6-digit postal code)
                  TextFormField(
                    controller: _pincodeController,
                    validator: _validatePincode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Pincode *',
                      hintText: '6-digit pincode (e.g. 500081)',
                      counterText: '',
                      prefixIcon: const Icon(Icons.local_post_office_rounded, size: 20, color: AppColors.teal),
                      filled: true,
                      fillColor: AppColors.warmIvory,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Landmark (Optional)
                  TextFormField(
                    controller: _landmarkController,
                    decoration: InputDecoration(
                      labelText: 'Nearby Landmark (Optional)',
                      hintText: 'e.g. Opposite Metro Pillar 104',
                      prefixIcon: const Icon(Icons.flag_rounded, size: 20, color: AppColors.teal),
                      filled: true,
                      fillColor: AppColors.warmIvory,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pin on Map & GPS Location for Map Routes
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.teal.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pin_drop_rounded, size: 18, color: AppColors.teal),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Map Route Coordinates',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: AppColors.deepTeal,
                                ),
                              ),
                            ),
                            Text(
                              '${_selectedLatitude.toStringAsFixed(4)}, ${_selectedLongitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.deepTeal,
                                  side: const BorderSide(color: AppColors.deepTeal),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                icon: _isLocatingGps
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal),
                                      )
                                    : const Icon(Icons.my_location_rounded, size: 16),
                                label: const Text('Use Current GPS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                onPressed: _isLocatingGps ? null : _useCurrentGps,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.deepTeal,
                                  foregroundColor: AppColors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                icon: Icon(_showMapPicker ? Icons.map_rounded : Icons.explore_rounded, size: 16),
                                label: Text(
                                  _showMapPicker ? 'Hide Map' : 'Select on Map',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  setState(() => _showMapPicker = !_showMapPicker);
                                },
                              ),
                            ),
                          ],
                        ),
                        if (_showMapPicker) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AddressOsmPicker(
                              initialLatitude: _selectedLatitude,
                              initialLongitude: _selectedLongitude,
                              height: 220,
                              onLocationChanged: (loc) {
                                setState(() {
                                  _selectedLatitude = loc.latitude;
                                  _selectedLongitude = loc.longitude;
                                });
                                _reverseGeocodeAndFill(loc.latitude, loc.longitude);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Delivery Instructions Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Instructions for Rider',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.deepTeal),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _quickInstructionChips.map((chipText) {
                      final isAdded = _instructionsController.text.contains(chipText);
                      return FilterChip(
                        label: Text(chipText, style: TextStyle(fontSize: 11, color: isAdded ? AppColors.white : AppColors.deepTeal)),
                        selected: isAdded,
                        selectedColor: AppColors.teal,
                        backgroundColor: AppColors.warmIvory,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              if (_instructionsController.text.isEmpty) {
                                _instructionsController.text = chipText;
                              } else if (!_instructionsController.text.contains(chipText)) {
                                _instructionsController.text += ', $chipText';
                              }
                            } else {
                              _instructionsController.text = _instructionsController.text
                                  .replaceAll('$chipText, ', '')
                                  .replaceAll(', $chipText', '')
                                  .replaceAll(chipText, '')
                                  .trim();
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _instructionsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Additional delivery instructions (e.g. Gate code, pet at door)...',
                      filled: true,
                      fillColor: AppColors.warmIvory,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 6. Checkboxes: Save for future & Make default
            if (widget.orderType != OrderType.manageOnly)
              CheckboxListTile(
                value: _saveForFuture,
                onChanged: (val) => setState(() => _saveForFuture = val ?? true),
                title: const Text('Save address to my profile for future orders', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.deepTeal)),
                activeColor: AppColors.teal,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            CheckboxListTile(
              value: _isDefault,
              onChanged: (val) => setState(() => _isDefault = val ?? false),
              title: const Text('Make this my default delivery address', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.deepTeal)),
              activeColor: AppColors.teal,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoalBlack.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isAddingOrEditing && _selectedAddress != null) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Delivering to: ${_selectedAddress!.label} (${_selectedAddress!.receiverName})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.deepTeal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepTeal,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.navigation_rounded, size: 20),
              label: Text(
                _isSubmitting
                    ? 'Saving Address...'
                    : _isAddingOrEditing
                        ? widget.orderType == OrderType.manageOnly
                            ? (_editingAddressId != null ? 'Update Address' : 'Save Address')
                            : (_editingAddressId != null ? 'Update & Deliver Here' : 'Save & Deliver Here')
                        : widget.orderType == OrderType.manageOnly
                            ? 'Close'
                            : 'Deliver to this Address',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (widget.orderType == OrderType.manageOnly && !_isAddingOrEditing) {
                        Navigator.pop(context);
                      } else {
                        _handleSaveAndConfirm();
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAddress(AddressModel address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Address?'),
        content: Text('Are you sure you want to remove "${address.formattedAddress}" from your saved addresses?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && _user?.uid != null) {
      await _addressService.deleteAddress(_user!.uid, address.id);
      if (_selectedAddress?.id == address.id) {
        setState(() => _selectedAddress = null);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address deleted.')),
        );
      }
    }
  }
}

