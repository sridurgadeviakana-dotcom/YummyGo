import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yummy_go_application/models/address_model.dart';
import 'package:yummy_go_application/providers/auth_providers.dart';
import 'package:yummy_go_application/services/address_service.dart';

/// Provider for AddressService instance.
final addressServiceProvider = Provider<AddressService>((ref) {
  return AddressService();
});

/// Stream of saved addresses for the current user.
final userAddressesStreamProvider = StreamProvider<List<AddressModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const []);
  }
  return ref.watch(addressServiceProvider).streamAddresses(user.uid);
});

/// Notifier for currently selected delivery address for active order checkout.
class SelectedDeliveryAddressNotifier extends Notifier<AddressModel?> {
  @override
  AddressModel? build() => null;

  set state(AddressModel? value) => super.state = value;
  void select(AddressModel? address) => state = address;
  void clear() => state = null;
}

/// Currently selected delivery address for active order checkout.
final selectedDeliveryAddressProvider =
    NotifierProvider<SelectedDeliveryAddressNotifier, AddressModel?>(
  SelectedDeliveryAddressNotifier.new,
);

/// Resolved default address (prefers explicitly selected, then default, then first saved).
final effectiveDeliveryAddressProvider = Provider<AddressModel?>((ref) {
  final selected = ref.watch(selectedDeliveryAddressProvider);
  if (selected != null) return selected;

  final addresses = ref.watch(userAddressesStreamProvider).asData?.value ?? const [];
  for (final a in addresses) {
    if (a.isDefault) return a;
  }
  return addresses.isNotEmpty ? addresses.first : null;
});

