import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:yummy_go_application/models/address_model.dart';

class AddressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userAddressesCol(String userId) {
    return _firestore.collection('users').doc(userId).collection('addresses');
  }

  /// Stream of user's saved addresses, sorted with default address first
  Stream<List<AddressModel>> streamAddresses(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return _userAddressesCol(userId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AddressModel.fromFirestore(doc))
          .toList();

      list.sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
      });
      return list;
    }).handleError((error) {
      debugPrint('AddressService streamAddresses error: $error');
      return <AddressModel>[];
    });
  }

  /// Get user's default address or first saved address for fast checkout
  Future<AddressModel?> getDefaultOrFirstAddress(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final snap = await _userAddressesCol(userId).get();
      if (snap.docs.isEmpty) return null;

      final addresses =
          snap.docs.map((d) => AddressModel.fromFirestore(d)).toList();

      for (final a in addresses) {
        if (a.isDefault) return a;
      }
      return addresses.first;
    } catch (e) {
      debugPrint('AddressService getDefaultAddress error: $e');
      return null;
    }
  }

  /// Save or update an address document.
  /// If set as default, removes isDefault on all other addresses of this user.
  Future<String> saveAddress(AddressModel address) async {
    final col = _userAddressesCol(address.userId);
    final docRef = address.id.isNotEmpty ? col.doc(address.id) : col.doc();

    if (address.isDefault) {
      try {
        final existingDefaults =
            await col.where('isDefault', isEqualTo: true).get();
        for (final doc in existingDefaults.docs) {
          if (doc.id != docRef.id) {
            await doc.reference.update({
              'isDefault': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (e) {
        debugPrint('AddressService unsetting old default error: $e');
      }
    }

    final data = address.toMap();
    data['id'] = docRef.id;
    if (address.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));
    return docRef.id;
  }

  /// Delete an address
  Future<void> deleteAddress(String userId, String addressId) async {
    await _userAddressesCol(userId).doc(addressId).delete();
  }

  /// Set an address as default
  Future<void> setDefaultAddress(String userId, String addressId) async {
    final col = _userAddressesCol(userId);
    final all = await col.get();
    for (final doc in all.docs) {
      final isDef = doc.id == addressId;
      if (doc.data()['isDefault'] != isDef) {
        await doc.reference.update({
          'isDefault': isDef,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}

