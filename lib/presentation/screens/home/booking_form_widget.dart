import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/api_constants.dart';
import '../../providers/home_provider.dart';
import '../../providers/providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Suggestion entry model — used for "Locate on map", nearby places, and
// Google autocomplete results, rendered uniformly in the dropdown.
// ─────────────────────────────────────────────────────────────────────────────

enum _EntryKind { mapLocate, nearby, search }

class _SuggestionEntry {
  final _EntryKind kind;
  final String label;
  final LatLng? latLng; // present for nearby (avoids re-geocode)

  const _SuggestionEntry({
    required this.kind,
    required this.label,
    this.latLng,
  });
}

class _NearbyPlace {
  final String label;
  final LatLng latLng;
  const _NearbyPlace(this.label, this.latLng);
}

class BookingFormWidget extends ConsumerStatefulWidget {
  const BookingFormWidget({super.key});

  @override
  ConsumerState<BookingFormWidget> createState() => _BookingFormWidgetState();
}

class _BookingFormWidgetState extends ConsumerState<BookingFormWidget> {
  final _pickupCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();
  final _pickupFocus = FocusNode();
  final _dropFocus = FocusNode();

  bool _pickupLocked = false;
  bool _dropLocked = false;

  List<String> _pickupSuggestions = [];
  List<String> _dropSuggestions = [];
  List<_NearbyPlace> _nearbyPlaces = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _pickupFocus.addListener(_onPickupFocusChange);
    _dropFocus.addListener(_onDropFocusChange);
  }

  void _onPickupFocusChange() {
    if (_pickupFocus.hasFocus) {
      ref.read(activeLocationFieldProvider.notifier).state = true;
      _loadNearbyPlaces();
    }
    setState(() {}); // rebuild so dropdown reflects new focus state
  }

  void _onDropFocusChange() {
    if (_dropFocus.hasFocus) {
      ref.read(activeLocationFieldProvider.notifier).state = false;
      _loadNearbyPlaces();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _pickupFocus.dispose();
    _dropFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Lock / unlock ─────────────────────────────────────────────────────────

  void _onPickupLockTap() {
    if (_pickupLocked) {
      setState(() {
        _pickupLocked = false;
        _dropLocked = false;
      });
      ref.read(pickupAddressProvider.notifier).state = '';
      ref.read(pickupLatLngProvider.notifier).state = null;
      ref.read(dropAddressProvider.notifier).state = '';
      ref.read(dropLatLngProvider.notifier).state = null;
      _dropCtrl.clear();
      _pickupCtrl.clear();
      ref.read(activeLocationFieldProvider.notifier).state = true;
      ref.read(homeNotifierProvider.notifier).goToIdle();
      ref.read(panToMyLocationProvider.notifier).state++;
      _pickupFocus.requestFocus();
    } else {
      if (_pickupCtrl.text.trim().isEmpty) return;
      setState(() => _pickupLocked = true);
      ref.read(activeLocationFieldProvider.notifier).state = false;
      _pickupFocus.unfocus();
      _dropFocus.requestFocus();
    }
  }

  void _onDropLockTap() {
    if (_dropLocked) {
      setState(() => _dropLocked = false);
      ref.read(dropAddressProvider.notifier).state = '';
      ref.read(dropLatLngProvider.notifier).state = null;
      _dropCtrl.clear();
      ref.read(activeLocationFieldProvider.notifier).state = false;
      ref.read(homeNotifierProvider.notifier).goToIdle();
      ref.read(panToMyLocationProvider.notifier).state++;
      _dropFocus.requestFocus();
    } else {
      if (_dropCtrl.text.trim().isEmpty) return;
      setState(() => _dropLocked = true);
      _dropFocus.unfocus();
      _showVehicles();
    }
  }

  void _showVehicles() {
    final pickup = _pickupCtrl.text.trim();
    final drop = _dropCtrl.text.trim();
    if (pickup.isEmpty || drop.isEmpty) return;
    ref.read(homeNotifierProvider.notifier).onLocationsSet(
      pickupAddress: pickup,
      dropAddress: drop,
    );
  }

  // ── Nearby places (cached for widget lifetime) ────────────────────────────

  Future<void> _loadNearbyPlaces() async {
    if (_nearbyPlaces.isNotEmpty) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '${pos.latitude},${pos.longitude}',
          'radius': 2000,
          'key': ApiConstants.googleMapsApiKey,
        },
      );
      final results = (response.data['results'] as List?) ?? [];
      final places = <_NearbyPlace>[];
      for (final r in results.take(2)) {
        final name = r['name'] as String? ?? '';
        final vicinity = r['vicinity'] as String? ?? '';
        final loc = r['geometry']?['location'];
        if (loc == null || name.isEmpty) continue;
        final lat = (loc['lat'] as num?)?.toDouble();
        final lng = (loc['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        places.add(_NearbyPlace(
          vicinity.isEmpty ? name : '$name, $vicinity',
          LatLng(lat, lng),
        ));
      }
      if (mounted) setState(() => _nearbyPlaces = places);
    } catch (e) {
      debugPrint('[nearbyPlaces] $e');
    }
  }

  // ── Places autocomplete ───────────────────────────────────────────────────

  Future<void> _fetchSuggestions(String query, bool isPickup) async {
    if (query.trim().length < 3) {
      setState(() {
        if (isPickup) {
          _pickupSuggestions = [];
        } else {
          _dropSuggestions = [];
        }
      });
      return;
    }
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get(
        ApiConstants.placesAutocomplete,
        queryParameters: {
          'input': query,
          'key': ApiConstants.googleMapsApiKey,
          'components': 'country:in',
          'types': 'geocode',
          'language': 'en',
        },
      );
      final predictions = (response.data['predictions'] as List?) ?? [];
      final suggestions =
          predictions.map((p) => p['description'] as String).toList();
      if (mounted) {
        setState(() {
          if (isPickup) {
            _pickupSuggestions = suggestions;
          } else {
            _dropSuggestions = suggestions;
          }
        });
      }
    } catch (_) {}
  }

  void _onChanged(String query, bool isPickup) {
    if (isPickup && _pickupLocked) return;
    if (!isPickup && _dropLocked) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(query, isPickup);
    });
  }

  // ── Suggestion tap handlers ───────────────────────────────────────────────

  void _onEntryTap(_SuggestionEntry entry, bool isPickup) {
    switch (entry.kind) {
      case _EntryKind.mapLocate:
        _onMapLocate(isPickup);
      case _EntryKind.nearby:
        _onNearbyTap(entry, isPickup);
      case _EntryKind.search:
        _selectSuggestion(entry.label, isPickup);
    }
  }

  void _onMapLocate(bool isPickup) {
    if (isPickup) {
      _pickupFocus.unfocus();
      ref.read(activeLocationFieldProvider.notifier).state = true;
      setState(() => _pickupSuggestions = []);
    } else {
      _dropFocus.unfocus();
      ref.read(activeLocationFieldProvider.notifier).state = false;
      setState(() => _dropSuggestions = []);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Move the map to set ${isPickup ? "pickup" : "drop"} location, '
          'then tap the lock icon',
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onNearbyTap(_SuggestionEntry entry, bool isPickup) {
    final latLng = entry.latLng;
    if (latLng == null) return;
    if (isPickup) {
      _pickupCtrl.text = entry.label;
      setState(() => _pickupSuggestions = []);
      ref.read(pickupAddressProvider.notifier).state = entry.label;
      ref.read(pickupLatLngProvider.notifier).state = latLng;
      ref.read(activeLocationFieldProvider.notifier).state = false;
      _dropFocus.requestFocus();
    } else {
      _dropCtrl.text = entry.label;
      setState(() => _dropSuggestions = []);
      ref.read(dropAddressProvider.notifier).state = entry.label;
      ref.read(dropLatLngProvider.notifier).state = latLng;
      _dropFocus.unfocus();
    }
  }

  void _selectSuggestion(String address, bool isPickup) {
    if (isPickup) {
      _pickupCtrl.text = address;
      setState(() => _pickupSuggestions = []);
      _geocodeAndSave(address, isPickup: true);
      ref.read(activeLocationFieldProvider.notifier).state = false;
      _dropFocus.requestFocus();
    } else {
      _dropCtrl.text = address;
      setState(() => _dropSuggestions = []);
      _dropFocus.unfocus();
      _geocodeAndSave(address, isPickup: false);
    }
  }

  Future<void> _geocodeAndSave(String address, {required bool isPickup}) async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'address': address,
          'key': ApiConstants.googleMapsApiKey,
          'region': 'in',
        },
      );
      final results = (response.data['results'] as List?) ?? [];
      if (results.isEmpty) return;
      final loc = results[0]['geometry']['location'];
      final latLng = LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
      if (isPickup) {
        ref.read(pickupLatLngProvider.notifier).state = latLng;
        ref.read(pickupAddressProvider.notifier).state = address;
      } else {
        ref.read(dropLatLngProvider.notifier).state = latLng;
        ref.read(dropAddressProvider.notifier).state = address;
      }
    } catch (_) {}
  }

  // ── Build entries list (locate-on-map + nearby OR typed results) ──────────

  List<_SuggestionEntry> _entriesFor(bool isPickup) {
    final entries = <_SuggestionEntry>[];
    final typed = isPickup ? _pickupSuggestions : _dropSuggestions;
    if (typed.isNotEmpty) {
      entries.addAll(typed.map(
        (s) => _SuggestionEntry(kind: _EntryKind.search, label: s),
      ));
    } else {
      entries.addAll(_nearbyPlaces.map(
        (p) => _SuggestionEntry(
          kind: _EntryKind.nearby,
          label: p.label,
          latLng: p.latLng,
        ),
      ));
    }
    entries.add(const _SuggestionEntry(
      kind: _EntryKind.mapLocate,
      label: 'Locate on map',
    ));
    return entries;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // When returning to idle after a booking cancel/exit, reset locks + fields.
    ref.listen<HomeState>(homeNotifierProvider, (prev, next) {
      if (next == HomeState.idle &&
          prev != null &&
          prev != HomeState.idle &&
          prev != HomeState.selectingTrucks) {
        setState(() {
          _pickupLocked = false;
          _dropLocked = false;
          _pickupSuggestions = [];
          _dropSuggestions = [];
        });
        _pickupCtrl.clear();
        _dropCtrl.clear();
      }
    });

    // Auto-fill fields when map pin reverse-geocodes an address.
    ref.listen<String>(pickupAddressProvider, (prev, address) {
      if (!_pickupLocked && _pickupCtrl.text != address) {
        _pickupCtrl.text = address;
      }
    });
    ref.listen<String>(dropAddressProvider, (prev, address) {
      if (!_dropLocked && _dropCtrl.text != address) {
        _dropCtrl.text = address;
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LocationCard(
          controller: _pickupCtrl,
          focusNode: _pickupFocus,
          isFocused: _pickupFocus.hasFocus,
          iconAsset: 'assets/images/source.png',
          hint: 'Pickup from',
          isLocked: _pickupLocked,
          entries: _entriesFor(true),
          onChanged: (v) => _onChanged(v, true),
          onEntryTap: (e) => _onEntryTap(e, true),
          onSubmitted: (_) => _dropFocus.requestFocus(),
          onLockTap: _onPickupLockTap,
        ),
        const SizedBox(height: 6),
        _LocationCard(
          controller: _dropCtrl,
          focusNode: _dropFocus,
          isFocused: _dropFocus.hasFocus,
          iconAsset: 'assets/images/destination.png',
          hint: 'Drop off cargo',
          isLocked: _dropLocked,
          entries: _entriesFor(false),
          onChanged: (v) => _onChanged(v, false),
          onEntryTap: (e) => _onEntryTap(e, false),
          onSubmitted: (_) {},
          onLockTap: _onDropLockTap,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final String iconAsset;
  final String hint;
  final bool isLocked;
  final List<_SuggestionEntry> entries;
  final ValueChanged<String> onChanged;
  final ValueChanged<_SuggestionEntry> onEntryTap;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onLockTap;

  const _LocationCard({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.iconAsset,
    required this.hint,
    required this.isLocked,
    required this.entries,
    required this.onChanged,
    required this.onEntryTap,
    required this.onSubmitted,
    required this.onLockTap,
  });

  IconData _iconFor(_EntryKind kind) {
    switch (kind) {
      case _EntryKind.mapLocate:
        return Icons.add_location_alt_outlined;
      case _EntryKind.nearby:
        return Icons.near_me_outlined;
      case _EntryKind.search:
        return Icons.location_on_outlined;
    }
  }

  Color _iconColorFor(_EntryKind kind) {
    switch (kind) {
      case _EntryKind.mapLocate:
        return const Color(0xFF1976D2); // distinct blue
      case _EntryKind.nearby:
        return const Color(0xFF388E3C); // soft green
      case _EntryKind.search:
        return const Color(0xFFAFAFAF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDropdown = isFocused && !isLocked && entries.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isLocked ? const Color(0xFFF5F5F5) : Colors.white,
            borderRadius: showDropdown
                ? const BorderRadius.vertical(top: Radius.circular(6))
                : BorderRadius.circular(6),
            border: isLocked ? Border.all(color: Colors.black, width: 1.5) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Image.asset(iconAsset, width: 24, height: 24),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: isLocked,
                  style: TextStyle(
                    color: isLocked ? Colors.black54 : Colors.black87,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                        color: Color(0xFFAFAFAF), fontSize: 14),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
                    isDense: true,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onLockTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    isLocked ? Icons.lock : Icons.lock_open,
                    color: isLocked ? Colors.green : Colors.grey.shade400,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDropdown)
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isMap = entry.kind == _EntryKind.mapLocate;
                return ListTile(
                  dense: true,
                  minLeadingWidth: 20,
                  tileColor:
                      isMap ? const Color(0xFFF4F8FF) : null,
                  leading: Icon(
                    _iconFor(entry.kind),
                    color: _iconColorFor(entry.kind),
                    size: 18,
                  ),
                  title: Text(
                    entry.label,
                    style: TextStyle(
                      color: isMap
                          ? const Color(0xFF1976D2)
                          : Colors.black87,
                      fontSize: 13,
                      fontWeight:
                          isMap ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onEntryTap(entry),
                );
              },
            ),
          ),
      ],
    );
  }
}
