import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/home_provider.dart';
import '../../providers/providers.dart';

/// Pickup / drop location cards overlaid at the top of the map.
/// Each card has a white background, Google Places autocomplete dropdown,
/// and a lock icon. No calendar icon.
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

  List<String> _pickupSuggestions = [];
  List<String> _dropSuggestions = [];
  Timer? _debounce;

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _pickupFocus.dispose();
    _dropFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Places API ──────────────────────────────────────────────────────────

  Future<void> _fetchSuggestions(String query, bool isPickup) async {
    if (query.trim().length < 3) {
      if (mounted) {
        setState(() {
          if (isPickup) {
            _pickupSuggestions = [];
          } else {
            _dropSuggestions = [];
          }
        });
      }
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
    } catch (_) {
      // silently fail — user can still type manually
    }
  }

  void _onChanged(String query, bool isPickup) {
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
      _dropFocus.requestFocus();
    } else {
      _dropCtrl.text = address;
      setState(() => _dropSuggestions = []);
      _dropFocus.unfocus();
      _geocodeAndSave(address, isPickup: false);
      _onConfirm();
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
    } catch (_) {
      // silently fail — map will show default location
    }
  }

  // ── Confirm / find trucks ────────────────────────────────────────────────

  void _onConfirm() {
    final pickup = _pickupCtrl.text.trim();
    final drop = _dropCtrl.text.trim();
    if (pickup.isEmpty || drop.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter pickup and drop locations')),
      );
      return;
    }
    ref
        .read(homeNotifierProvider.notifier)
        .onLocationsSet(pickupAddress: pickup, dropAddress: drop);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Auto-fill pickup field when map pin resolves an address
    ref.listen<String>(pickupAddressProvider, (prev, address) {
      if (address.isNotEmpty && _pickupCtrl.text != address) {
        _pickupCtrl.text = address;
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pickup card
        _LocationCard(
          controller: _pickupCtrl,
          focusNode: _pickupFocus,
          flagColor: const Color(0xFF2E7D32),
          hint: 'Cargo pickup location',
          suggestions: _pickupSuggestions,
          onChanged: (v) => _onChanged(v, true),
          onSuggestionTap: (addr) => _selectSuggestion(addr, true),
          onSubmitted: (_) => _dropFocus.requestFocus(),
        ),

        const SizedBox(height: 6),

        // Drop card
        _LocationCard(
          controller: _dropCtrl,
          focusNode: _dropFocus,
          flagColor: AppColors.statusCancelled,
          hint: 'Cargo drop location',
          suggestions: _dropSuggestions,
          onChanged: (v) => _onChanged(v, false),
          onSuggestionTap: (addr) => _selectSuggestion(addr, false),
          onSubmitted: (_) => _onConfirm(),
        ),

      ],
    );
  }
}

// ── Private stateless card widget ───────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color flagColor;
  final String hint;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSuggestionTap;
  final ValueChanged<String> onSubmitted;

  const _LocationCard({
    required this.controller,
    required this.focusNode,
    required this.flagColor,
    required this.hint,
    required this.suggestions,
    required this.onChanged,
    required this.onSuggestionTap,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Input row — white card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: suggestions.isEmpty
                ? BorderRadius.circular(4)
                : const BorderRadius.vertical(top: Radius.circular(4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Flag icon
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.flag, color: flagColor, size: 22),
              ),

              // Text field — explicit white fill overrides dark theme
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: Color(0xFFAFAFAF),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0, vertical: 14),
                    isDense: true,
                  ),
                ),
              ),

              // Lock icon
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.lock_open,
                    color: Colors.grey.shade400, size: 20),
              ),
            ],
          ),
        ),

        // Suggestions dropdown — attached below the card
        if (suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(4)),
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
              separatorBuilder: (_, i) =>
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  minLeadingWidth: 20,
                  leading: const Icon(Icons.location_on_outlined,
                      color: Color(0xFFAFAFAF), size: 18),
                  title: Text(
                    suggestions[index],
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSuggestionTap(suggestions[index]),
                );
              },
            ),
          ),
      ],
    );
  }
}
