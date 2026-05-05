import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/api_constants.dart';
import '../../providers/home_provider.dart';
import '../../providers/providers.dart';

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
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) {
        ref.read(activeLocationFieldProvider.notifier).state = true;
      }
    });
    _dropFocus.addListener(() {
      if (_dropFocus.hasFocus) {
        ref.read(activeLocationFieldProvider.notifier).state = false;
      }
    });
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
      // Unlock — reset both locations and go back to idle map view
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
      // Signal map to pan back to current GPS location
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
      // Unlock drop — go back to idle so vehicle sheet disappears
      setState(() => _dropLocked = false);
      ref.read(dropAddressProvider.notifier).state = '';
      ref.read(dropLatLngProvider.notifier).state = null;
      _dropCtrl.clear();
      ref.read(activeLocationFieldProvider.notifier).state = false;
      ref.read(homeNotifierProvider.notifier).goToIdle();
      // Signal map to pan back to current GPS location
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
      final suggestions = predictions.map((p) => p['description'] as String).toList();
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
      // Don't auto-show vehicles — wait for user to tap lock icon
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Auto-fill fields when map pin reverse-geocodes an address
    ref.listen<String>(pickupAddressProvider, (prev, address) {
      if (address.isNotEmpty && _pickupCtrl.text != address && !_pickupLocked) {
        _pickupCtrl.text = address;
      }
    });
    ref.listen<String>(dropAddressProvider, (prev, address) {
      if (address.isNotEmpty && _dropCtrl.text != address && !_dropLocked) {
        _dropCtrl.text = address;
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Pickup card ──
        _LocationCard(
          controller: _pickupCtrl,
          focusNode: _pickupFocus,
          iconAsset: 'assets/images/source.png',
          hint: 'Pickup from',
          isLocked: _pickupLocked,
          suggestions: _pickupSuggestions,
          onChanged: (v) => _onChanged(v, true),
          onSuggestionTap: (addr) => _selectSuggestion(addr, true),
          onSubmitted: (_) => _dropFocus.requestFocus(),
          onLockTap: _onPickupLockTap,
        ),

        const SizedBox(height: 6),

        // ── Drop card ──
        _LocationCard(
          controller: _dropCtrl,
          focusNode: _dropFocus,
          iconAsset: 'assets/images/destination.png',
          hint: 'Drop off cargo',
          isLocked: _dropLocked,
          suggestions: _dropSuggestions,
          onChanged: (v) => _onChanged(v, false),
          onSuggestionTap: (addr) => _selectSuggestion(addr, false),
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
  final String iconAsset;
  final String hint;
  final bool isLocked;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSuggestionTap;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onLockTap;

  const _LocationCard({
    required this.controller,
    required this.focusNode,
    required this.iconAsset,
    required this.hint,
    required this.isLocked,
    required this.suggestions,
    required this.onChanged,
    required this.onSuggestionTap,
    required this.onSubmitted,
    required this.onLockTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Input row
        Container(
          decoration: BoxDecoration(
            color: isLocked ? const Color(0xFFF5F5F5) : Colors.white,
            borderRadius: suggestions.isEmpty
                ? BorderRadius.circular(6)
                : const BorderRadius.vertical(top: Radius.circular(6)),
            border: isLocked
                ? Border.all(color: Colors.black, width: 1.5)
                : null,
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
              // Location type icon
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Image.asset(iconAsset, width: 24, height: 24),
              ),

              // Text field
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
                    hintStyle: const TextStyle(color: Color(0xFFAFAFAF), fontSize: 14),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
                    isDense: true,
                  ),
                ),
              ),

              // Lock / unlock icon button
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

        // Suggestions dropdown
        if (suggestions.isNotEmpty && !isLocked)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
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
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) => ListTile(
                dense: true,
                minLeadingWidth: 20,
                leading: const Icon(Icons.location_on_outlined, color: Color(0xFFAFAFAF), size: 18),
                title: Text(
                  suggestions[index],
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onSuggestionTap(suggestions[index]),
              ),
            ),
          ),
      ],
    );
  }
}
