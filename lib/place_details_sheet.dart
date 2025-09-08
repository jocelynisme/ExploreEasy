import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class PlaceDetailsSheet {
  PlaceDetailsSheet._();

  static Future<void> show(
    BuildContext context, {
    required String areaId,
    required String placeId,
    Map<String, dynamic>? embeddedPlaceData, // Add this parameter
    double radiusKm = 2.0,
    void Function(Map<String, dynamic> alt)? onSelectAlternate,
    List<Map<String, dynamic>>? prefetchedAlternateHotels,
    void Function(List<Map<String, dynamic>> hotels)? onPreviewAlternateHotels,
    void Function(List<Map<String, dynamic>>)? onPreviewAlternateRestaurants,
    void Function(List<Map<String, dynamic>>)? onPreviewAlternateShops,
    VoidCallback? onClose,
    Set<String>? selectedPlaceNames,
  }) {
    // Validate required parameters
    if (areaId.trim().isEmpty) {
      debugPrint('❌ PlaceDetailsSheet: areaId is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot show details: Area ID missing'),
          backgroundColor: Colors.red,
        ),
      );
      return Future.value();
    }

    if (placeId.trim().isEmpty) {
      debugPrint('❌ PlaceDetailsSheet: placeId is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot show details: Place ID missing'),
          backgroundColor: Colors.red,
        ),
      );
      return Future.value();
    }

    debugPrint(
      '✅ PlaceDetailsSheet: Opening with areaId="$areaId", placeId="$placeId"',
    );

    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => _PlaceDetailsBody(
            hostContext: context,
            areaId: areaId,
            placeId: placeId,
            embeddedPlaceData: embeddedPlaceData, // Pass the embedded data
            radiusKm: radiusKm,
            onSelectAlternate: onSelectAlternate,
            prefetchedAlternateHotels: prefetchedAlternateHotels,
            onPreviewAlternateHotels: onPreviewAlternateHotels,
            onPreviewAlternateRestaurants: onPreviewAlternateRestaurants,
            onPreviewAlternateShops: onPreviewAlternateShops,
            selectedPlaceNames: selectedPlaceNames,
          ),
    ).whenComplete(() {
      debugPrint('🏁 PlaceDetailsSheet closed');
      onClose?.call();
    });
  }
}

class _PlaceDetailsBody extends StatefulWidget {
  final BuildContext hostContext; // NEW
  final String areaId;
  final String placeId;
  final double radiusKm;
  final void Function(Map<String, dynamic> alt)? onSelectAlternate;
  final Set<String>? selectedPlaceNames;
  final List<Map<String, dynamic>>? prefetchedAlternateHotels; // NEW
  final void Function(List<Map<String, dynamic>> hotels)?
  onPreviewAlternateHotels; // NEW
  final void Function(List<Map<String, dynamic>>)?
  onPreviewAlternateRestaurants;
  final void Function(List<Map<String, dynamic>>)? onPreviewAlternateShops;
  final Map<String, dynamic>? embeddedPlaceData;

  const _PlaceDetailsBody({
    super.key,
    required this.hostContext, // NEW
    required this.areaId,
    required this.placeId,
    this.radiusKm = 2.0,
    this.onSelectAlternate,
    this.prefetchedAlternateHotels, // NEW
    this.onPreviewAlternateHotels, // NEW
    this.onPreviewAlternateRestaurants,
    this.onPreviewAlternateShops,
    this.selectedPlaceNames,
    this.embeddedPlaceData,
  });

  @override
  State<_PlaceDetailsBody> createState() => _PlaceDetailsBodyState();
}

class _PlaceDetailsBodyState extends State<_PlaceDetailsBody> {
  bool _previewSent = false;
  String? _previewForPlaceId;
  static const _weekdayOrder = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late final DocumentReference<Map<String, dynamic>> _placeRef;

  @override
  void initState() {
    super.initState();
    _placeRef = FirebaseFirestore.instance
        .collection('areas')
        .doc(widget.areaId)
        .collection('places')
        .doc(widget.placeId);
  }

  // --- helpers ---------------------------------------------------------------
  bool _isPlaceSelected(String placeName) {
    if (widget.selectedPlaceNames == null) return false;

    // Normalize place name (remove prefixes like "Meal:", "Souvenir:")
    final normalizedName =
        placeName
            .replaceFirst(RegExp(r'^(Meal|Souvenir):\s*'), '')
            .trim()
            .toLowerCase();

    return widget.selectedPlaceNames!.any(
      (selected) =>
          selected.toLowerCase().contains(normalizedName) ||
          normalizedName.contains(selected.toLowerCase()),
    );
  }

  bool _isHotelCategory(String? cat) {
    final c = (cat ?? '').toLowerCase();
    return c == 'hotel' ||
        c == 'accommodation' ||
        c == 'lodging' ||
        c == 'stay';
  }

  bool _isRestaurantCategory(String? cat) {
    final c = (cat ?? '').toLowerCase();
    return c == 'restaurant' || c == 'cafe' || c == 'food';
  }

  bool _isSouvenirCategory(String? cat) {
    final c = (cat ?? '').toLowerCase();
    return c == 'souvenir' || c == 'shop' || c == 'shopping' || c == 'store';
  }

  double? _extractPrice(Map<String, dynamic> data) {
    final v =
        data['price'] ??
        data['nightly'] ??
        data['minPrice'] ??
        data['avgPrice'] ??
        data['pricePerNight'];
    if (v is num) return v.toDouble();
    if (v is String) {
      final m = RegExp(r'[\d.]+').firstMatch(v);
      if (m != null) return double.tryParse(m.group(0)!);
    }
    return null;
  }

  Future<List<_SimilarItem>> _fetchAlternateHotels({
    required String areaId,
    required String excludePlaceId,
    required double originLat,
    required double originLon,
    required double radiusKm,
    double? refPrice, // optional similarity filter
  }) async {
    // Pull hotels (any of the common categories)
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('areas')
        .doc(areaId)
        .collection('places')
        .where(
          'category',
          whereIn: ['hotel', 'accommodation', 'lodging', 'stay'],
        );

    final snap = await q.get();
    final out = <_SimilarItem>[];

    for (final doc in snap.docs) {
      if (doc.id == excludePlaceId) continue;

      final data = doc.data();
      final gp = data['coordinates'];
      if (gp is! GeoPoint) continue;
      final lat = gp.latitude;
      final lon = gp.longitude;

      final dist = _haversineKm(originLat, originLon, lat, lon);
      if (dist > radiusKm) continue;

      // Optional price similarity: −20%..+25% around current hotel
      if (refPrice != null) {
        final altPrice = _extractPrice(data);
        if (altPrice == null) continue;
        if (altPrice < refPrice * 0.80 || altPrice > refPrice * 1.25) continue;
      }

      final name = (data['name'] ?? 'Unnamed').toString();
      final rating = (data['rating'] as num?)?.toDouble();
      final address = (data['address'] as String?);
      final photoUrlsDyn = (data['photoUrls'] as List?) ?? const [];
      final primary = data['primaryPhotoUrl'] as String?;
      final imageFromData = data['image'] as String?; // Add this line
      final photos =
          photoUrlsDyn
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
      final image =
          photos.isNotEmpty ? photos.first : (primary ?? imageFromData);

      out.add(
        _SimilarItem(
          areaId: areaId,
          placeId: doc.id,
          name: name,
          address: address,
          rating: rating,
          distanceKm: dist,
          imageUrl: image,
          raw: data,
          lat: lat,
          lon: lon,
        ),
      );
    }

    out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return out.take(6).toList();
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

  Future<List<_SimilarItem>> _fetchNearbyByCategories({
    required String areaId,
    required String excludePlaceId,
    required double originLat,
    required double originLon,
    required double radiusKm,
    required List<String> categories,
  }) async {
    final cats = categories.map((e) => e.toLowerCase()).toSet().toList();
    if (cats.isEmpty) return const <_SimilarItem>[];

    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('areas')
        .doc(areaId)
        .collection('places')
        .where('category', whereIn: cats); // Firestore <=10 values OK

    final snap = await q.get();
    final out = <_SimilarItem>[];

    for (final doc in snap.docs) {
      if (doc.id == excludePlaceId) continue;

      final data = doc.data();

      // coordinates can be GeoPoint (preferred) or [lon,lat]
      final geo = data['coordinates'];
      double? lat, lon;
      if (geo is GeoPoint) {
        lat = geo.latitude;
        lon = geo.longitude;
      } else if (geo is List && geo.length >= 2) {
        final n0 = geo[0], n1 = geo[1];
        if (n0 is num && n1 is num) {
          lon = n0.toDouble();
          lat = n1.toDouble();
        }
      }
      if (lat == null || lon == null) continue;

      final dist = _haversineKm(originLat, originLon, lat, lon);
      if (dist > radiusKm) continue;

      final name = (data['name'] ?? 'Unnamed').toString();
      final rating = (data['rating'] as num?)?.toDouble();
      final address = (data['address'] as String?);
      final photoUrlsDyn = (data['photoUrls'] as List?) ?? const [];
      final primary = data['primaryPhotoUrl'] as String?;
      final imageFromData = data['image'] as String?; // Add this line
      final photos =
          photoUrlsDyn
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
      final image =
          photos.isNotEmpty ? photos.first : (primary ?? imageFromData);

      out.add(
        _SimilarItem(
          areaId: areaId,
          placeId: doc.id,
          name: name,
          address: address,
          rating: rating,
          distanceKm: dist,
          imageUrl: image,
          raw: data,
          lat: lat,
          lon: lon,
        ),
      );
    }

    out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return out.take(6).toList();
  }

  Future<List<_SimilarItem>> _fetchSimilar({
    required String areaId,
    required String excludePlaceId,
    required double originLat,
    required double originLon,
    required String? kind,
    required double radiusKm,
  }) async {
    // Pull all attractions in the same area (filtered by kind when present)
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('areas')
        .doc(areaId)
        .collection('places')
        .where('category', isEqualTo: 'attraction');

    if (kind != null && kind.trim().isNotEmpty) {
      q = q.where('kind', isEqualTo: kind);
    }

    final snap = await q.get();
    final out = <_SimilarItem>[];

    for (final doc in snap.docs) {
      if (doc.id == excludePlaceId) continue;

      final data = doc.data();
      final geo = data['coordinates'];
      if (geo is! GeoPoint) continue;

      final lat = geo.latitude;
      final lon = geo.longitude;

      final dist = _haversineKm(originLat, originLon, lat, lon);
      if (dist > radiusKm) continue;

      final name = (data['name'] ?? 'Unnamed').toString();
      final rating = (data['rating'] as num?)?.toDouble();
      final address = (data['address'] as String?);
      final photoUrlsDyn = (data['photoUrls'] as List?) ?? const [];
      final primary = data['primaryPhotoUrl'] as String?;
      final imageFromData = data['image'] as String?; // Add this line
      final photos =
          photoUrlsDyn
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
      final image =
          photos.isNotEmpty ? photos.first : (primary ?? imageFromData);

      out.add(
        _SimilarItem(
          areaId: areaId,
          placeId: doc.id,
          name: name,
          address: address,
          rating: rating,
          distanceKm: dist,
          imageUrl: image,
          raw: data,
          lat: lat,
          lon: lon,
        ),
      );
    }

    out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    // cap to 6 like we did for hotels
    return out.take(6).toList();
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchTel(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _placeRef.get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Place not found.'),
          );
        }

        final data = snap.data!.data()!;
        final String name = (data['name'] ?? 'Unnamed').toString();
        final String? address = (data['address'] as String?);
        final double? rating = (data['rating'] as num?)?.toDouble();
        final int userRatings =
            (data['user_ratings_total'] as num?)?.toInt() ?? 0;
        final String? description = data['description'] as String?;
        final List<dynamic> photoUrlsDyn =
            (data['photoUrls'] as List?) ?? const [];
        final List<String> photoUrls =
            photoUrlsDyn.map((e) => e.toString()).toList();
        final String? primaryPhotoUrl = data['primaryPhotoUrl'] as String?;
        final String? website = data['website'] as String?;
        final String? phone = data['phone'] as String?;
        final String? mapsUrl = data['mapsUrl'] as String?;
        final String? kind = (data['kind'] as String?);
        final String? primaryType = data['primaryType'] as String?;
        final Map<String, dynamic>? openHours =
            (data['open_hours'] as Map?)?.cast<String, dynamic>();
        final GeoPoint? coords = data['coordinates'] as GeoPoint?;

        final images =
            photoUrls.isNotEmpty
                ? photoUrls
                : (primaryPhotoUrl != null ? [primaryPhotoUrl] : <String>[]);

        final lat = coords?.latitude ?? 0.0;
        final lon = coords?.longitude ?? 0.0;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Header images -----------------------------------------------------
                    if (images.isNotEmpty)
                      SizedBox(
                        height: 220,
                        child: PageView.builder(
                          itemCount: images.length.clamp(1, 6),
                          itemBuilder:
                              (_, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  images[i],
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => Container(
                                        color: Colors.grey.shade200,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                        ),
                                      ),
                                ),
                              ),
                        ),
                      ),

                    const SizedBox(height: 12),
                    // --- Title + chips -----------------------------------------------------
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (kind != null && kind.isNotEmpty)
                          Chip(
                            label: Text(kind),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (primaryType != null && primaryType.isNotEmpty)
                          const SizedBox(width: 6),
                        if (primaryType != null && primaryType.isNotEmpty)
                          Chip(
                            label: Text(primaryType),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (rating != null) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text('${rating.toStringAsFixed(1)}'),
                          const SizedBox(width: 8),
                          Text('($userRatings)'),
                        ],
                      ],
                    ),
                    if (address != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.place, size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(child: Text(address)),
                        ],
                      ),
                    ],
                    if (description != null &&
                        description.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(description),
                    ],

                    // --- Opening hours -----------------------------------------------------
                    if (openHours != null && openHours.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Opening hours',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      ..._weekdayOrder.map((d) {
                        final v = openHours[d] ?? openHours[d.substring(0, 3)];
                        if (v == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              SizedBox(width: 90, child: Text(d)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(v.toString())),
                            ],
                          ),
                        );
                      }),
                    ],

                    // --- Quick actions -----------------------------------------------------
                    // Replace the Quick actions section in place_details_sheet.dart with this enhanced version:

                    // --- Quick actions -----------------------------------------------------
                    const SizedBox(height: 14),
                    Builder(
                      builder: (context) {
                        final isSelected = _isPlaceSelected(name);

                        return Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (website != null && website.isNotEmpty)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.public),
                                label: const Text('Website'),
                                onPressed: () => _launchExternal(website),
                              ),
                            if (phone != null && phone.isNotEmpty)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.call),
                                label: const Text('Call'),
                                onPressed: () => _launchTel(phone),
                              ),
                            if (mapsUrl != null && mapsUrl.isNotEmpty)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.map),
                                label: const Text('Open in Maps'),
                                onPressed: () => _launchExternal(mapsUrl),
                              ),
                            // Add "Use instead" button if callback is provided
                            if (widget.onSelectAlternate != null)
                              ElevatedButton.icon(
                                icon: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.swap_horiz,
                                ),
                                label: Text(
                                  isSelected
                                      ? 'Already selected'
                                      : 'Use instead',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isSelected ? Colors.grey : Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed:
                                    isSelected
                                        ? null
                                        : () {
                                          // Create the alternate data structure from current place
                                          final alt = {
                                            'properties': {
                                              'name': name,
                                              'address': address ?? '',
                                              'category':
                                                  data['category'] ??
                                                  'attraction',
                                              'rating': rating ?? 0.0,
                                              'kind': kind,
                                              'type': data['type'],
                                              'price_level':
                                                  data['price_level'],
                                              // For hotels, include room data if available
                                              if (data['roomTypes'] != null)
                                                'roomTypes': data['roomTypes'],
                                              if (data['travelersNo'] != null)
                                                'travelersNo':
                                                    data['travelersNo'],
                                              if (data['emptyRoomsByDate'] !=
                                                  null)
                                                'emptyRoomsByDate':
                                                    data['emptyRoomsByDate'],
                                            },
                                            'geometry': {
                                              'coordinates': [lon, lat],
                                            },
                                            'placeId': widget.placeId,
                                            'areaId': widget.areaId,
                                          };

                                          //   debugPrint('🔄 [MainView] Using place instead: ${alt['properties']['name']}');
                                          widget.onSelectAlternate?.call(alt);
                                        },
                              ),
                          ],
                        );
                      },
                    ),

                    // --- Similar / Alternate section --------------------------------------
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Builder(
                          builder: (_) {
                            final catStr =
                                (data['category'] ?? data['primaryType'] ?? '')
                                    .toString();
                            final isHotel = _isHotelCategory(catStr);
                            return Text(
                              isHotel
                                  ? 'Alternate hotels nearby'
                                  : 'Similar nearby',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '≤ ${widget.radiusKm.toStringAsFixed(0)} km',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Builder(
                      builder: (_) {
                        final catStr =
                            (data['category'] ?? data['primaryType'] ?? '')
                                .toString();
                        final bool isHotel = _isHotelCategory(catStr);
                        final bool isRestaurant = _isRestaurantCategory(catStr);
                        final bool isSouvenir = _isSouvenirCategory(catStr);

                        // Title row above already printed; this is just the list area.

                        // If hotel + prefetched list → use it and trigger preview
                        final pref = widget.prefetchedAlternateHotels;
                        if (isHotel && pref != null && pref.isNotEmpty) {
                          // Convert prefetched hotels to the expected format for preview
                          final listForPreview =
                              pref.map((h) {
                                final hp =
                                    (h['properties'] as Map?)
                                        ?.cast<String, dynamic>() ??
                                    {};
                                final coords = h['geometry']?['coordinates'];
                                return {
                                  'properties': {
                                    'name':
                                        (hp['name'] ?? 'Unnamed').toString(),
                                    'address': hp['address'] ?? '',
                                    'category': 'hotel',
                                    'rating':
                                        (hp['rating'] as num?)?.toDouble() ??
                                        0.0,
                                  },
                                  'geometry': {
                                    'coordinates':
                                        coords is List ? coords : [0.0, 0.0],
                                  },
                                  'distanceFromTapped':
                                      (h['distanceFromAnchor'] as num?)
                                          ?.toDouble() ??
                                      0.0,
                                };
                              }).toList();

                          // Trigger preview callback if not already sent
                          if (!_previewSent ||
                              _previewForPlaceId != widget.placeId) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              debugPrint(
                                '🏨 Triggering onPreviewAlternateHotels with ${listForPreview.length} items',
                              );
                              widget.onPreviewAlternateHotels?.call(
                                listForPreview,
                              );
                            });
                            _previewSent = true;
                            _previewForPlaceId = widget.placeId;
                          }

                          return SizedBox(
                            height: 240,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: pref.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(width: 12),
                              itemBuilder: (_, i) {
                                final h = pref[i];
                                final hp =
                                    (h['properties'] as Map?)
                                        ?.cast<String, dynamic>() ??
                                    const {};
                                final name =
                                    (hp['name'] ?? 'Unnamed').toString();
                                final coords = h['geometry']?['coordinates'];
                                final dist =
                                    (h['distanceFromAnchor'] as num?)
                                        ?.toDouble();
                                final img =
                                    (hp['image'] ?? hp['primaryPhotoUrl'])
                                        ?.toString();

                                print("🏨 DEBUG Hotel #$i data structure:");
                                print("  h keys: ${h.keys.toList()}");
                                print(
                                  "  h['properties'] keys: ${hp.keys.toList()}",
                                );
                                print("  hp['photoUrls']: ${hp['photoUrls']}");
                                print(
                                  "  hp['primaryPhotoUrl']: ${hp['primaryPhotoUrl']}",
                                );
                                print("  hp['image']: ${hp['image']}");
                                print("  Final img value: $img");
                                print("  img == null: ${img == null}");
                                print("  img.isEmpty: ${img?.isEmpty}");

                                return _SimilarCard(
                                  item: _SimilarItem(
                                    areaId: widget.areaId,
                                    placeId:
                                        (hp['placeId'] as String?) ??
                                        (h['id'] as String?) ??
                                        '',
                                    name: name,
                                    address: (hp['address'] as String?),
                                    rating: (hp['rating'] as num?)?.toDouble(),
                                    distanceKm: dist ?? 0.0,
                                    imageUrl: img,
                                    raw: hp,
                                    lat:
                                        (coords is List && coords.length >= 2)
                                            ? (coords[1] as num).toDouble()
                                            : 0,
                                    lon:
                                        (coords is List && coords.length >= 2)
                                            ? (coords[0] as num).toDouble()
                                            : 0,
                                  ),
                                  onView: () {
                                    // Extract and validate placeId
                                    final placeId =
                                        (hp['placeId'] as String?) ??
                                        (h['id'] as String?) ??
                                        (h['placeId'] as String?) ??
                                        '';

                                    // Debug logging to see what we're getting
                                    print(
                                      "🔍 DEBUG: Attempting to view hotel details",
                                    );
                                    print("   - hp keys: ${hp.keys.toList()}");
                                    print("   - h keys: ${h.keys.toList()}");
                                    print(
                                      "   - hp['placeId']: ${hp['placeId']}",
                                    );
                                    print("   - h['id']: ${h['id']}");
                                    print("   - h['placeId']: ${h['placeId']}");
                                    print("   - Final placeId: '$placeId'");
                                    print(
                                      "   - placeId.isEmpty: ${placeId.isEmpty}",
                                    );

                                    if (placeId.isEmpty) {
                                      print(
                                        "❌ ERROR: Empty placeId, cannot open details sheet",
                                      );
                                      ScaffoldMessenger.of(
                                        widget.hostContext,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Cannot view details: Hotel ID missing',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    Navigator.of(
                                      widget.hostContext,
                                      rootNavigator: true,
                                    ).pop();
                                    WidgetsBinding.instance.addPostFrameCallback((
                                      _,
                                    ) {
                                      PlaceDetailsSheet.show(
                                        widget.hostContext,
                                        areaId: widget.areaId,
                                        placeId:
                                            placeId, // Use validated placeId
                                        radiusKm: widget.radiusKm,
                                        onSelectAlternate:
                                            widget.onSelectAlternate,
                                        prefetchedAlternateHotels: pref,
                                        onPreviewAlternateHotels:
                                            widget.onPreviewAlternateHotels,
                                        onPreviewAlternateRestaurants:
                                            widget
                                                .onPreviewAlternateRestaurants,
                                        onPreviewAlternateShops:
                                            widget.onPreviewAlternateShops,
                                      );
                                    });
                                  },
                                  onUseInstead:
                                      widget.onSelectAlternate == null
                                          ? null
                                          : () {
                                            // Pass the complete hotel data structure
                                            final alt =
                                                Map<String, dynamic>.from(
                                                  h,
                                                ); // Use the full hotel object

                                            // Ensure the properties include all necessary data
                                            alt['properties'] =
                                                Map<String, dynamic>.from(hp);
                                            alt['geometry'] = {
                                              'coordinates': coords,
                                            };
                                            alt['distanceFromTapped'] =
                                                dist ?? 0.0;

                                            debugPrint(
                                              '🏨 [PlaceDetailsSheet] Passing hotel alt with keys: ${alt.keys.toList()}',
                                            );
                                            debugPrint(
                                              '🏨 [PlaceDetailsSheet] Hotel properties keys: ${alt['properties'].keys.toList()}',
                                            );
                                            debugPrint(
                                              '🏨 [PlaceDetailsSheet] roomTypes available: ${alt['properties']['roomTypes'] != null}',
                                            );
                                            debugPrint(
                                              '🏨 [PlaceDetailsSheet] travelersNo available: ${alt['properties']['travelersNo'] != null}',
                                            );

                                            widget.onSelectAlternate?.call(alt);
                                          },
                                );
                              },
                            ),
                          );
                        }

                        // Non-hotel categories (existing logic)
                        final Future<List<_SimilarItem>> future =
                            isHotel
                                ? _fetchAlternateHotels(
                                  areaId: widget.areaId,
                                  excludePlaceId: widget.placeId,
                                  originLat: lat,
                                  originLon: lon,
                                  radiusKm: widget.radiusKm,
                                )
                                : isRestaurant
                                ? _fetchNearbyByCategories(
                                  areaId: widget.areaId,
                                  excludePlaceId: widget.placeId,
                                  originLat: lat,
                                  originLon: lon,
                                  radiusKm: widget.radiusKm,
                                  categories: const [
                                    'restaurant',
                                    'cafe',
                                    'food',
                                  ],
                                )
                                : isSouvenir
                                ? _fetchNearbyByCategories(
                                  areaId: widget.areaId,
                                  excludePlaceId: widget.placeId,
                                  originLat: lat,
                                  originLon: lon,
                                  radiusKm: widget.radiusKm,
                                  categories: const [
                                    'souvenir',
                                    'shop',
                                    'store',
                                    'shopping',
                                  ],
                                )
                                : _fetchSimilar(
                                  areaId: widget.areaId,
                                  excludePlaceId: widget.placeId,
                                  originLat: lat,
                                  originLon: lon,
                                  kind: kind,
                                  radiusKm: widget.radiusKm,
                                );

                        final emptyMsg =
                            isHotel
                                ? 'No alternate hotels within ${widget.radiusKm.toStringAsFixed(0)} km.'
                                : isRestaurant
                                ? 'No similar restaurants within ${widget.radiusKm.toStringAsFixed(0)} km.'
                                : isSouvenir
                                ? 'No similar shops within ${widget.radiusKm.toStringAsFixed(0)} km.'
                                : 'No similar attractions within ${widget.radiusKm.toStringAsFixed(0)} km.';

                        final altCategory =
                            isHotel
                                ? 'hotel'
                                : isRestaurant
                                ? 'restaurant'
                                : isSouvenir
                                ? 'souvenir'
                                : 'attraction';

                        return FutureBuilder<List<_SimilarItem>>(
                          future: future,
                          builder: (context, simSnap) {
                            if (simSnap.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final items =
                                simSnap.data ?? const <_SimilarItem>[];
                            if (items.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  emptyMsg,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              );
                            }

                            final listForPreview =
                                items.map((it) {
                                  return {
                                    'properties': {
                                      'name': it.name,
                                      'address': it.address ?? '',
                                      'category': altCategory,
                                      'rating': it.rating ?? 0.0,
                                    },
                                    'geometry': {
                                      'coordinates': [it.lon, it.lat],
                                    },
                                    'distanceFromTapped': it.distanceKm,
                                  };
                                }).toList();

                            if (!_previewSent ||
                                _previewForPlaceId != widget.placeId) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (isRestaurant) {
                                  widget.onPreviewAlternateRestaurants?.call(
                                    listForPreview,
                                  );
                                } else if (isSouvenir) {
                                  widget.onPreviewAlternateShops?.call(
                                    listForPreview,
                                  );
                                }
                              });
                              _previewSent = true;
                              _previewForPlaceId = widget.placeId;
                            }

                            return SizedBox(
                              height: 240,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: items.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(width: 12),
                                itemBuilder:
                                    (_, i) => _SimilarCard(
                                      item: items[i],
                                      isSelected: _isPlaceSelected(
                                        items[i].name,
                                      ), // NEW
                                      onView: () {
                                        Navigator.of(
                                          widget.hostContext,
                                          rootNavigator: true,
                                        ).pop();
                                        WidgetsBinding.instance.addPostFrameCallback((
                                          _,
                                        ) {
                                          PlaceDetailsSheet.show(
                                            widget.hostContext,
                                            areaId: items[i].areaId,
                                            placeId: items[i].placeId,
                                            radiusKm: widget.radiusKm,
                                            onSelectAlternate:
                                                widget
                                                    .onSelectAlternate, // ✅ THIS WAS ALREADY CORRECT
                                            onPreviewAlternateRestaurants:
                                                widget
                                                    .onPreviewAlternateRestaurants, // ✅ ADD THIS
                                            onPreviewAlternateShops:
                                                widget
                                                    .onPreviewAlternateShops, // ✅ ADD THIS
                                            // ✅ ADD THIS TOO
                                          );
                                        });
                                      },
                                      onUseInstead:
                                          widget.onSelectAlternate == null
                                              ? null
                                              : () {
                                                final it = items[i];
                                                final alt = {
                                                  'properties': {
                                                    'name': it.name,
                                                    'address': it.address ?? '',
                                                    'category': altCategory,
                                                    'rating': it.rating ?? 0.0,
                                                    'kind': it.raw['kind'],
                                                  },
                                                  'geometry': {
                                                    'coordinates': [
                                                      it.lon,
                                                      it.lat,
                                                    ],
                                                  },
                                                  'distanceFromTapped':
                                                      it.distanceKm,
                                                };
                                                widget.onSelectAlternate?.call(
                                                  alt,
                                                );
                                              },
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- small models & cards ----------------------------------------------------

class _SimilarItem {
  final String areaId;
  final String placeId;
  final String name;
  final String? address;
  final double? rating;
  final double distanceKm;
  final String? imageUrl;
  final Map<String, dynamic> raw;
  final double lat;
  final double lon;

  _SimilarItem({
    required this.areaId,
    required this.placeId,
    required this.name,
    required this.address,
    required this.rating,
    required this.distanceKm,
    required this.imageUrl,
    required this.raw,
    required this.lat,
    required this.lon,
  });
}

// Fix the _SimilarCard widget to prevent overflow
class _SimilarCard extends StatelessWidget {
  final _SimilarItem item;
  final VoidCallback? onView;
  final VoidCallback? onUseInstead;
  final bool isSelected; // NEW

  const _SimilarCard({
    super.key,
    required this.item,
    this.onView,
    this.onUseInstead,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section - fixed height
            SizedBox(
              height: 100, // Reduced from 120 to save space
              width: double.infinity,
              child:
                  item.imageUrl == null
                      ? Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image, size: 32),
                      )
                      : Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image),
                            ),
                      ),
            ),

            // Content section - use Expanded to take remaining space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  8,
                ), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:
                      MainAxisSize.min, // Important: minimize space usage
                  children: [
                    // Title
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14, // Slightly smaller
                      ),
                    ),

                    const SizedBox(height: 3), // Reduced spacing
                    // Rating and distance row
                    Row(
                      children: [
                        if (item.rating != null) ...[
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber,
                          ), // Smaller icon
                          const SizedBox(width: 2),
                          Text(
                            item.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                            ), // Smaller text
                          ),
                          const SizedBox(width: 6),
                        ],
                        const Icon(
                          Icons.near_me,
                          size: 14,
                          color: Colors.grey,
                        ), // Smaller icon
                        const SizedBox(width: 2),
                        Text(
                          '${item.distanceKm.toStringAsFixed(2)} km',
                          style: const TextStyle(fontSize: 12), // Smaller text
                        ),
                      ],
                    ),

                    // Address - only show if there's space
                    if ((item.address ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Flexible(
                        // Use Flexible instead of fixed height
                        child: Text(
                          item.address!,
                          maxLines: 1, // Reduced from 2 to save space
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11, // Smaller text
                          ),
                        ),
                      ),
                    ],

                    const Spacer(), // Push buttons to bottom
                    // Buttons - make them smaller
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onView,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ), // Smaller padding
                              minimumSize: const Size(
                                0,
                                32,
                              ), // Smaller minimum height
                            ),
                            child: const Text(
                              'View',
                              style: TextStyle(fontSize: 12), // Smaller text
                            ),
                          ),
                        ),
                        const SizedBox(width: 6), // Reduced spacing
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onUseInstead,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ), // Smaller padding
                              minimumSize: const Size(
                                0,
                                32,
                              ), // Smaller minimum height
                            ),
                            child: const Text(
                              'Use instead',
                              style: TextStyle(fontSize: 12), // Smaller text
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
