import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  print("✅ Firebase initialized successfully");

  final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: 'admin@gmail.com',
    password: 'Admin123',
  );
  print('👤 Seeder signed in: ${cred.user?.uid}');

  await seedAllPenangAreas();
  await runCategorization();

  print("🎉 Seeding completed!");
}

/* =================== CONFIG =================== */

const String apiKey = 'AIzaSyDMJnOsTzbY7Cz7EGjnmvhDhyEPQOlJWxA';

// Updated regions with reduced radius and bounds
const List<Map<String, dynamic>> _penangRegions = [
  // {
  //   'state': 'Penang',
  //   'area': 'George Town',
  //   'lat': 5.4141619,
  //   'lon': 100.3287352,
  //   'radius': 3000, // Reduced from 5000
  //   'bounds': {
  //     'north': 5.435,
  //     'south': 5.395,
  //     'east': 100.345,
  //     'west': 100.315,
  //   },
  //   'addressVariations': ['george town', 'georgetown', 'penang'],
  // },
  // {
  //   'state': 'Penang',
  //   'area': 'Tanjung Tokong',
  //   'lat': 5.4509926,
  //   'lon': 100.3056236,
  //   'radius': 2500,
  //   'bounds': {
  //     'north': 5.465,
  //     'south': 5.435,
  //     'east': 100.320,
  //     'west': 100.290,
  //   },
  //   'addressVariations': [
  //     'tanjung tokong',
  //     'tg tokong',
  //     'tokong',
  //     'seri tanjung pinang',
  //   ],
  // },
  // {
  //   'state': 'Penang',
  //   'area': 'Tanjung Bungah',
  //   'lat': 5.4648,
  //   'lon': 100.2814,
  //   'radius': 2500, // Reduced
  //   'bounds': {
  //     'north': 5.480,
  //     'south': 5.450,
  //     'east': 100.295,
  //     'west': 100.265,
  //   },
  //   'addressVariations': ['tanjung bungah', 'tg bungah', 'bungah'],
  // },
  // {
  //   'state': 'Penang',
  //   'area': 'Butterworth',
  //   'lat': 5.4082015,
  //   'lon': 100.3697208,
  //   'radius': 4000,
  //   'bounds': {
  //     'north': 5.430,
  //     'south': 5.385,
  //     'east': 100.390,
  //     'west': 100.350,
  //   },
  //   'addressVariations': ['butterworth', 'seberang perai'],
  // },
  // {
  //   'state': 'Penang',
  //   'area': 'Bayan Lepas',
  //   'lat': 5.2948137,
  //   'lon': 100.2595968,
  //   'radius': 4000,
  //   'bounds': {
  //     'north': 5.315,
  //     'south': 5.275,
  //     'east': 100.285,
  //     'west': 100.235,
  //   },
  //   'addressVariations': ['bayan lepas', 'bayanlepas'],
  // },
  // {
  //   'state': 'Penang',
  //   'area': 'Balik Pulau',
  //   'lat': 5.3214,
  //   'lon': 100.2210,
  //   'radius': 4000,
  //   'bounds': {
  //     'north': 5.350,
  //     'south': 5.290,
  //     'east': 100.250,
  //     'west': 100.190,
  //   },
  //   'addressVariations': ['balik pulau', 'balikpulau'],
  // },
  {
    'state': 'Penang',
    'area': 'Batu Ferringhi',
    'lat': 5.4736,
    'lon': 100.2484,
    'radius': 3000,
    'bounds': {
      'north': 5.490,
      'south': 5.455,
      'east': 100.265,
      'west': 100.230,
    },
    'addressVariations': ['batu ferringhi', 'ferringhi'],
  },
];

const Map<String, String> _categories = {
  // Google "type"       -> our category
  'tourist_attraction': 'attraction',
  'lodging': 'accommodation',
  'restaurant': 'restaurant', // NEW
  'cafe':
      'restaurant', // we’ll keep it under restaurant; you can drop later if needed
  'store': 'souvenir', // we’ll filter out non-souvenir stores below
};

/* =================== QUALITY & GEO THRESHOLDS =================== */

// ADD: per-category quality bars (tuned safe defaults)
class QualityThresholds {
  final double minAttractionRating;
  final int minAttractionReviews;
  final double attractionBoundsRadiusFactor;
  final double hotelBoundsRadiusFactor;
  final double attractionStrictFactor;
  final double hotelStrictFactor;

  // NEW:
  final double minRestaurantRating;
  final int minRestaurantReviews;
  final double minSouvenirRating;
  final int minSouvenirReviews;

  const QualityThresholds({
    this.minAttractionRating = 3.5,
    this.minAttractionReviews = 10,
    this.attractionBoundsRadiusFactor = 0.9,
    this.hotelBoundsRadiusFactor = 0.8,
    this.attractionStrictFactor = 0.6,
    this.hotelStrictFactor = 0.5,

    this.minRestaurantRating = 3.8, // NEW
    this.minRestaurantReviews = 20, // NEW
    this.minSouvenirRating = 3.8, // NEW
    this.minSouvenirReviews = 8, // NEW (souvenir kiosks are often small)
  });
}

const QualityThresholds kThresholds = QualityThresholds();

bool _isAttractionCategory(String category) => category == 'attraction';
bool _isRestaurantCategory(String category) => category == 'restaurant';
bool _isSouvenirCategory(String category) => category == 'souvenir';

/* =================== HYBRID VALIDATION FUNCTIONS =================== */

/// Check if address contains area name variations
bool addressContainsArea(String? address, List<String> variations) {
  final addressLower = (address ?? '').toLowerCase();
  if (addressLower.isEmpty) return false;
  for (final v in variations) {
    if (addressLower.contains(v.toLowerCase())) return true;
  }
  return false;
}

// ADD: simple type guards
bool _isFoodServiceTypes(Set<String> t) =>
    t.contains('restaurant') ||
    t.contains('cafe') ||
    t.contains('bar') ||
    t.contains('bakery');

bool _isShoppingMall(Set<String> t) => t.contains('shopping_mall');

// ADD: souvenir name keywords (case-insensitive). You can expand later.
final RegExp _souvenirNameRx = RegExp(
  r'(souvenir|souvenier|gift|handicraft|craft|batik|local product|local products|chocolate|cocoa|nutmeg|tau\s*sar|white coffee|ghee\s*hiang|him\s*heang)',
  caseSensitive: false,
);

// ADD: decide if a store looks like a souvenir/local-product shop (NOT restaurants or malls)
bool isSouvenirCandidate({required String name, required Set<String> types}) {
  if (_isFoodServiceTypes(types)) return false; // exclude eateries
  if (_isShoppingMall(types)) return false; // exclude malls
  if (_souvenirNameRx.hasMatch(name))
    return true; // name hints souvenirs/local product
  // Also accept clothing_store ONLY if the name hints at craft/batik/etc.
  if (types.contains('clothing_store') && _souvenirNameRx.hasMatch(name))
    return true;
  return false;
}

/// Check if coordinates are within defined bounds
bool isWithinBounds(double lat, double lng, Map<String, dynamic>? bounds) {
  if (bounds == null) return true;
  return lat >= bounds['south'] &&
      lat <= bounds['north'] &&
      lng >= bounds['west'] &&
      lng <= bounds['east'];
}

/// Calculate distance between two points in meters
double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
  const double earthRadius = 6371000; // Earth radius in meters
  final double dLat = _degreesToRadians(lat2 - lat1);
  final double dLng = _degreesToRadians(lng2 - lng1);

  final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLng / 2) *
          sin(dLng / 2);

  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _degreesToRadians(double degrees) {
  return degrees * pi / 180;
}

String determinePlaceType(Set<String> types) {
  final typeSet = types.map((e) => e.toString().toLowerCase()).toSet();
  if (typeSet.contains('park') ||
      typeSet.contains('beach') ||
      typeSet.contains('natural_feature')) {
    return 'outdoor';
  }
  if (typeSet.contains('museum') ||
      typeSet.contains('art_gallery') ||
      typeSet.contains('shopping_mall') ||
      typeSet.contains('restaurant')) {
    return 'indoor';
  }
  return 'unknown'; // Default for unclassified
}

/// Hybrid validation: combines address, bounds, and distance checks
bool validatePlaceForArea({
  required String placeName,
  required String placeAddress,
  required String vicinity,
  required double lat,
  required double lng,
  required Map<String, dynamic> region,
  required String category, // NEW
  Map<String, dynamic>? details, // NEW (for quality pre-filter)
  QualityThresholds thresholds = kThresholds,
}) {
  final String targetArea = region['area'];
  final List<String> addressVariations = List<String>.from(
    region['addressVariations'] ?? [],
  );
  final fullAddress = '$placeAddress $vicinity'.toLowerCase();

  print("🔍 Validating $placeName for $targetArea [$category]");
  print("   Address: $fullAddress");
  print("   Coords: ($lat, $lng)");

  // STEP 1: Quality pre-filter (attractions only)
  // STEP 1: Category-specific quality pre-filter
  {
    final rating = (details?['rating'] as num?)?.toDouble() ?? 0.0;
    final reviews = (details?['user_ratings_total'] as num?)?.toInt() ?? 0;

    if (_isAttractionCategory(category)) {
      if (rating < thresholds.minAttractionRating ||
          reviews < thresholds.minAttractionReviews) {
        print(
          "   ❌ Quality fail [attraction]: rating=$rating, reviews=$reviews",
        );
        return false;
      }
      print("   ✅ Quality OK [attraction]: rating=$rating, reviews=$reviews");
    } else if (_isRestaurantCategory(category)) {
      if (rating < thresholds.minRestaurantRating ||
          reviews < thresholds.minRestaurantReviews) {
        print(
          "   ❌ Quality fail [restaurant]: rating=$rating, reviews=$reviews",
        );
        return false;
      }
      print("   ✅ Quality OK [restaurant]: rating=$rating, reviews=$reviews");
    } else if (_isSouvenirCategory(category)) {
      if (rating < thresholds.minSouvenirRating ||
          reviews < thresholds.minSouvenirReviews) {
        print("   ❌ Quality fail [souvenir]: rating=$rating, reviews=$reviews");
        return false;
      }
      print("   ✅ Quality OK [souvenir]: rating=$rating, reviews=$reviews");
    }
  }

  // STEP 2: Three-tier geographic validation

  // Method 1: Address contains area
  if (addressContainsArea(fullAddress, addressVariations)) {
    print("   ✅ Address match found");
    return true;
  } else {
    print("   ℹ️ No address match; checking bounds + distance…");
  }

  // Method 2: Bounds + distance
  final regionLat = (region['lat'] as num).toDouble();
  final regionLng = (region['lon'] as num).toDouble();
  final maxRadius = (region['radius'] as num).toDouble();
  final inRect = isWithinBounds(lat, lng, region['bounds']);
  final distance = calculateDistance(lat, lng, regionLat, regionLng);

  final boundsFactor =
      _isAttractionCategory(category)
          ? thresholds.attractionBoundsRadiusFactor
          : thresholds.hotelBoundsRadiusFactor;

  if (inRect && distance <= maxRadius * boundsFactor) {
    print(
      "   ✅ Bounds+distance OK: inRect=$inRect, "
      "distance=${distance.toInt()}m ≤ ${(maxRadius * boundsFactor).toInt()}m",
    );
    return true;
  }

  // Method 3: Strict distance only
  final strictFactor =
      _isAttractionCategory(category)
          ? thresholds.attractionStrictFactor
          : thresholds.hotelStrictFactor;
  final strictRadius = maxRadius * strictFactor;

  if (distance <= strictRadius) {
    print(
      "   ✅ Strict distance OK: ${distance.toInt()}m ≤ ${strictRadius.toInt()}m",
    );
    return true;
  }

  print(
    "   ❌ Failed all geo methods. distance=${distance.toInt()}m, "
    "allowed2=${(maxRadius * boundsFactor).toInt()}m, strict=${strictRadius.toInt()}m",
  );
  return false;
}

/// Find the most appropriate area for a misplaced place
String? findBestAreaForPlace(double lat, double lng, String address) {
  String? bestArea;
  double minDistance = double.infinity;

  for (final region in _penangRegions) {
    final regionLat = (region['lat'] as num).toDouble();
    final regionLng = (region['lon'] as num).toDouble();
    final distance = calculateDistance(lat, lng, regionLat, regionLng);

    // Check if address matches this area
    final addressVariations = List<String>.from(
      region['addressVariations'] ?? [],
    );
    if (addressContainsArea(address, addressVariations)) {
      return region['area']; // Return immediately if address matches
    }

    // Track closest area as fallback
    if (distance < minDistance) {
      minDistance = distance;
      bestArea = region['area'];
    }
  }

  return bestArea;
}

/* =================== EXISTING HELPER FUNCTIONS =================== */

String _indefArticle(String noun) {
  final s = noun.trim().toLowerCase();
  if (s.isEmpty) return 'a';
  const vowels = {'a', 'e', 'i', 'o', 'u'};
  return vowels.contains(s[0]) ? 'an' : 'a';
}

String _weekdayLabel(int weekday) =>
    const [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][weekday];

String _niceNoun({
  required String category,
  String? mappedKind,
  String? primaryType,
  Set<String>? googleTypes,
}) {
  if (mappedKind != null) {
    switch (mappedKind) {
      case 'museum':
        return 'museum';
      case 'temple':
        return 'temple';
      case 'park':
        return 'park';
      case 'beach':
        return 'beach';
      case 'shopping':
        return 'shopping area';
      case 'family':
        return 'family attraction';
      case 'hotel':
        return 'hotel';
    }
  }
  if (category == 'accommodation') return 'hotel';
  if (primaryType == 'tourist_attraction') return 'landmark';
  return 'attraction';
}

String _titleCase(String s) {
  if (s.trim().isEmpty) return s;
  return s
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return word;
        final lettersOnly = word.replaceAll(RegExp(r'[^A-Za-z]'), '');
        final isAcronym =
            lettersOnly.length >= 3 && lettersOnly == lettersOnly.toUpperCase();
        if (isAcronym) return word;

        final match = RegExp(
          r'(^[^A-Za-z]*)([A-Za-z])([^A-Za-z]*$)',
        ).firstMatch(word);
        if (match == null) return word;

        final core = word.replaceAll(RegExp(r'^[^A-Za-z]+|[^A-Za-z]+$'), '');
        final head = core.substring(0, 1).toUpperCase();
        final tail = core.length > 1 ? core.substring(1).toLowerCase() : '';
        return '${match.group(1)!}$head$tail${match.group(3)!}';
      })
      .join(' ');
}

String generateFallbackDescription({
  required String name,
  required String area,
  required String category,
  String? mappedKind,
  String? primaryType,
  Map<String, dynamic>? details,
  Map<String, String>? openHoursMap,
}) {
  details ??= const {};
  final rating = (details['rating'] as num?)?.toDouble();
  final reviews = (details['user_ratings_total'] as num?)?.toInt() ?? 0;
  final openNow = details['opening_hours']?['open_now'] == true;

  final noun = _niceNoun(
    category: category,
    mappedKind: mappedKind,
    primaryType: primaryType,
  );
  final article = _indefArticle(noun);

  final parts = <String>[];
  parts.add('${_titleCase(name)} is $article $noun in $area.');

  if (rating != null && rating > 0) {
    final r = rating.toStringAsFixed(rating == rating.roundToDouble() ? 0 : 1);
    parts.add(
      reviews > 0 ? 'Rated $r/5 from $reviews Google reviews.' : 'Rated $r/5.',
    );
  }

  if (openNow == true) {
    final today = _weekdayLabel(DateTime.now().weekday);
    final todayHours = openHoursMap?[today];
    parts.add(todayHours != null ? 'Hours today: $todayHours.' : 'Open now.');
  }

  return parts.join(' ');
}

String buildPhotoUrl(String ref, {int maxWidth = 800}) =>
    'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&photo_reference=$ref&key=$apiKey';

Future<Map<String, dynamic>?> fetchPlaceDetails(String placeId) async {
  final fields = [
    'name',
    'formatted_address',
    'rating',
    'user_ratings_total',
    'price_level',
    'types',
    'opening_hours',
    'website',
    'international_phone_number',
    'photos',
    'editorial_summary',
    'url',
  ].join(',');

  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=$fields&key=$apiKey',
  );
  final resp = await http.get(url);
  if (resp.statusCode != 200) return null;
  final data = jsonDecode(resp.body);
  if (data['status'] == 'OK') return (data['result'] as Map<String, dynamic>);
  return null;
}

String? kindFromTypes(List types) {
  final t = types.map((e) => e.toString().toLowerCase()).toSet();
  if (t.contains('restaurant') || t.contains('cafe') || t.contains('bar'))
    return 'restaurant';
  if (t.contains('museum') || t.contains('art_gallery')) return 'museum';
  if (t.contains('hindu_temple') ||
      t.contains('mosque') ||
      t.contains('church') ||
      t.contains('synagogue') ||
      t.contains('place_of_worship'))
    return 'temple';
  if (t.contains('park') || t.contains('botanical_garden')) return 'park';
  if (t.contains('beach')) return 'beach';
  if (t.contains('shopping_mall') || t.contains('department_store'))
    return 'shopping'; // still used by attractions bucket if ever needed

  // Souvenir heuristic by name/type will be applied earlier; here we only label if we want:
  if (t.contains('clothing_store')) return 'souvenir';

  if (t.contains('zoo') ||
      t.contains('aquarium') ||
      t.contains('amusement_park') ||
      t.contains('theme_park'))
    return 'family';
  return null;
}

Map<String, Map<String, int>> _generateRoomAvailability() {
  final Map<String, Map<String, int>> availability = {};
  final random = Random();
  final startDate = DateTime.now().add(const Duration(days: 1));
  final endDate = startDate.add(const Duration(days: 365));
  final peak = {12, 1, 7, 8};
  final mid = {6, 11};

  for (
    var d = startDate;
    d.isBefore(endDate);
    d = d.add(const Duration(days: 1))
  ) {
    final key = d.toIso8601String().substring(0, 10);
    int baseSingle = 10, baseFamily = 6;
    if (peak.contains(d.month)) {
      baseSingle = (baseSingle * 0.5).round();
      baseFamily = (baseFamily * 0.5).round();
    } else if (mid.contains(d.month)) {
      baseSingle = (baseSingle * 0.75).round();
      baseFamily = (baseFamily * 0.75).round();
    }
    availability[key] = {
      'single': (baseSingle + random.nextInt(5) - 2).clamp(0, 10),
      'family': (baseFamily + random.nextInt(5) - 2).clamp(0, 6),
    };
  }
  return availability;
}

/* =================== IMPROVED SEEDING WITH HYBRID VALIDATION =================== */

Future<void> seedAllPenangAreas() async {
  final Map<String, int> globalUnmapped = {};
  final Map<String, Set<String>> duplicateTracker = {};
  final Map<String, String> rejectedPlaces =
      {}; // Track rejected places and suggested areas

  for (final region in _penangRegions) {
    final areaUnmapped = await _seedOneAreaWithValidation(
      region: region,
      duplicateTracker: duplicateTracker,
      rejectedPlaces: rejectedPlaces,
    );

    areaUnmapped.forEach((k, v) {
      globalUnmapped[k] = (globalUnmapped[k] ?? 0) + v;
    });
  }

  print('🧭 Global unmapped types across all areas: $globalUnmapped');
  print('🔍 Total duplicates prevented: ${duplicateTracker.length}');
  print('📍 Total places rejected for wrong area: ${rejectedPlaces.length}');

  // Log some rejected place suggestions
  rejectedPlaces.forEach((placeName, suggestedArea) {
    print('📋 Suggested: Move "$placeName" to $suggestedArea');
  });
}

Future<List<Map<String, dynamic>>> _placesTextSearch({
  required String query,
  required String? locationBias, // e.g. "circle:2500@5.45099,100.30562"
}) async {
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/place/textsearch/json'
    '?query=${Uri.encodeQueryComponent(query)}'
    '${locationBias != null ? '&locationbias=${Uri.encodeQueryComponent(locationBias)}' : ''}'
    '&key=$apiKey',
  );

  final resp = await http.get(url);
  if (resp.statusCode != 200) return const [];
  final data = jsonDecode(resp.body);
  if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS')
    return const [];
  final results =
      (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  return results;
}

Future<void> _processOnePlaceResult({
  required Map<String, dynamic> result,
  required Map<String, dynamic> region,
  required String googleType, // 'tourist_attraction' | 'lodging'
  required String area,
  required DocumentReference areaRef,
  required Map<String, Set<String>> duplicateTracker,
  required Set<String> seen,
  required Map<String, int> unmappedTypeSamples,
  required Map<String, String> rejectedPlaces,
  required void Function() incValid,
  required void Function() incRejected,
  required void Function() incDuplicate,
}) async {
  final placeId = result['place_id']?.toString();
  if (placeId == null || placeId.isEmpty) return;
  if (!seen.add(placeId)) return;

  // cross-area duplicate tracking
  if (duplicateTracker.containsKey(placeId)) {
    duplicateTracker[placeId]!.add(area);
    incDuplicate();
    return;
  } else {
    duplicateTracker[placeId] = {area};
  }

  final placeLat =
      (result['geometry']?['location']?['lat'] as num?)?.toDouble() ?? 0.0;
  final placeLng =
      (result['geometry']?['location']?['lng'] as num?)?.toDouble() ?? 0.0;

  final details = await fetchPlaceDetails(placeId);
  final category = _categories[googleType]!;
  final name = (result['name'] ?? details?['name'] ?? 'Unnamed').toString();
  final vicinity = (result['vicinity'] ?? '').toString();
  final address =
      (((details?['formatted_address'] as String?) ??
              (vicinity.isNotEmpty ? vicinity : 'Unknown address')))
          .toString();

  // HYBRID VALIDATION (now category-aware + quality prefilter)
  final isValid = validatePlaceForArea(
    placeName: name,
    placeAddress: address,
    vicinity: vicinity,
    lat: placeLat,
    lng: placeLng,
    region: region,
    category: category,
    details: details,
  );

  if (!isValid) {
    incRejected();

    final betterArea = findBestAreaForPlace(
      placeLat,
      placeLng,
      '$address $vicinity',
    );
    if (betterArea != null && betterArea != area) {
      rejectedPlaces[name] = betterArea;
    }
    return;
  }

  // ---- build doc (same as your original) ----
  final nearbyTypes = ((result['types'] as List?) ?? const []).cast();
  final detailsTypes = ((details?['types'] as List?) ?? const []).cast();
  final typesCombined =
      {
        ...nearbyTypes.map((e) => e.toString()),
        ...detailsTypes.map((e) => e.toString()),
      }.toList();
  final primaryType =
      nearbyTypes.isNotEmpty
          ? nearbyTypes.first.toString()
          : (detailsTypes.isNotEmpty ? detailsTypes.first.toString() : null);
  final typesSet = typesCombined.map((e) => e.toString().toLowerCase()).toSet();

  // If Google type was 'store' but our desired category is 'souvenir', enforce souvenir rules:
  if (category == 'souvenir') {
    // Name-based + type-based filter:
    final ok = isSouvenirCandidate(name: name, types: typesSet);
    if (!ok) {
      print("   ❌ Not a souvenir/local-product shop (filtered out)");
      incRejected();
      return;
    }
  }

  // If category is 'restaurant', allow both 'restaurant' and 'cafe' as inputs. Already handled by _categories map.
  // (If you want to exclude 'cafe', add a guard here to drop cafe-only hits.)

  final mappedKind =
      (category == 'accommodation')
          ? 'hotel'
          : (category == 'restaurant')
          ? 'restaurant'
          : (category == 'souvenir')
          ? 'souvenir'
          : kindFromTypes(typesCombined);

  if (category == 'attraction' && mappedKind == null) {
    for (final t in typesCombined) {
      final k = t.toString().toLowerCase();
      if (k != 'tourist_attraction' &&
          k != 'point_of_interest' &&
          k != 'establishment') {
        unmappedTypeSamples[k] = (unmappedTypeSamples[k] ?? 0) + 1;
      }
    }
  }

  final weekdayText =
      (details?['opening_hours']?['weekday_text'] as List?)?.cast();
  Map<String, String>? openHoursMap;
  if (weekdayText != null && weekdayText.isNotEmpty) {
    openHoursMap = {};
    for (final line in weekdayText) {
      final s = line.toString();
      final idx = s.indexOf(':');
      if (idx > 0) {
        openHoursMap[s.substring(0, idx).trim()] = s.substring(idx + 1).trim();
      }
    }
  }

  final photos =
      ((details?['photos'] ?? result['photos']) as List?) ?? const [];
  final photoRefs = <String>[];
  final photoAttributions = <String>[];
  for (final p in photos.take(6)) {
    final map = (p as Map);
    final ref = map['photo_reference']?.toString();
    if (ref != null) photoRefs.add(ref);
    final attrs =
        (map['html_attributions'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    photoAttributions.addAll(attrs);
  }
  final photoUrls = photoRefs.map((r) => buildPhotoUrl(r)).toList();

  final placeType = determinePlaceType(typesSet);

  String description;
  final editorial = details?['editorial_summary'];
  if (editorial is Map) {
    final overview =
        (editorial['overview'] ?? editorial['description'])?.toString();
    description =
        (overview != null && overview.trim().isNotEmpty)
            ? overview.trim()
            : generateFallbackDescription(
              name: name,
              area: area,
              category: category,
              mappedKind: (category == 'accommodation') ? 'hotel' : mappedKind,
              primaryType: primaryType,
              details: details,
              openHoursMap: openHoursMap,
            );
  } else {
    description = generateFallbackDescription(
      name: name,
      area: area,
      category: category,
      mappedKind: (category == 'accommodation') ? 'hotel' : mappedKind,
      primaryType: primaryType,
      details: details,
      openHoursMap: openHoursMap,
    );
  }

  final doc = <String, dynamic>{
    'placeId': placeId,
    'name': name,
    'area': area,
    'category': category,
    'type': placeType, // Add this line
    'description': description,
    'coordinates': GeoPoint(placeLat, placeLng),
    'address': address,
    'googleTypes': typesCombined,
    if (primaryType != null) 'primaryType': primaryType,
    if (category == 'restaurant') 'kind': 'restaurant',
    if (category == 'souvenir') 'kind': 'souvenir',
    if (category == 'accommodation') 'kind': 'hotel',
    'photoRefs': photoRefs,
    'photoAttributions': photoAttributions.toSet().toList(),
    if (photoUrls.isNotEmpty) 'primaryPhotoUrl': photoUrls.first,
    if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
    'rating': (details?['rating'] as num?)?.toDouble() ?? 0.0,
    'user_ratings_total':
        (details?['user_ratings_total'] as num?)?.toInt() ?? 0,
    'price_level': (details?['price_level'] as int?) ?? 3,
    'openingHours': {
      'openNow': details?['opening_hours']?['open_now'],
      'weekdayText': weekdayText,
    },
    if (openHoursMap != null) 'open_hours': openHoursMap,
    'website': details?['website'],
    'phone': details?['international_phone_number'],
    'mapsUrl': details?['url'],
    'source': 'google_places',
    'lastUpdated': FieldValue.serverTimestamp(),
  };

  if (category == 'accommodation') {
    doc.addAll({
      'travelersNo': {'single': 2, 'family': 4},
      'roomTypes': {
        'single': {'price': 200.0},
        'family': {'price': 400.0},
      },
      'emptyRoomsByDate': _generateRoomAvailability(),
      'checkInTime': '15:00',
      'checkOutTime': '12:00',
    });
  }

  try {
    await areaRef
        .collection('places')
        .doc(placeId)
        .set(doc, SetOptions(merge: true));
    final kindSuffix =
        (category == 'attraction' && mappedKind != null) ? '/$mappedKind' : '';
    print('✅ Valid $area → $name (${_categories[googleType]}$kindSuffix)');
    incValid();
  } catch (e) {
    print('❌ Firestore write failed $area/$placeId: $e');
  }
}

Future<Map<String, int>> _seedOneAreaWithValidation({
  required Map<String, dynamic> region,
  required Map<String, Set<String>> duplicateTracker,
  required Map<String, String> rejectedPlaces,
}) async {
  const nearbyUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  final String area = region['area'];
  final double lat = (region['lat'] as num).toDouble();
  final double lon = (region['lon'] as num).toDouble();
  final int radius = (region['radius'] as num).toInt();

  print('🔍 Seeding $area (radius: ${radius}m) with hybrid validation');

  final areaRef = FirebaseFirestore.instance.collection('areas').doc(area);
  await areaRef.set({
    'state': region['state'],
    'area': area,
    'lastSeededAt': FieldValue.serverTimestamp(),
    'bounds': region['bounds'],
    'addressVariations': region['addressVariations'],
  }, SetOptions(merge: true));

  final seen = <String>{};
  final Map<String, int> unmappedTypeSamples = {};
  int validPlaces = 0;
  int rejectedCount = 0;
  int duplicateCount = 0;

  // --- Text Search first (only for attractions) ---
  // Higher precision results by relevance/quality
  {
    final queries = <String>[
      'tourist attractions $area Penang',
      'things to do in $area Penang',
      '$area Penang attractions',
    ];
    final locationBias =
        'circle:${radius}@${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}';

    for (final q in queries) {
      final textResults = await _placesTextSearch(
        query: q,
        locationBias: locationBias,
      );
      if (textResults.isEmpty) continue;

      for (final r in textResults) {
        await _processOnePlaceResult(
          result: r,
          region: region,
          googleType: 'tourist_attraction',
          area: area,
          areaRef: areaRef,
          duplicateTracker: duplicateTracker,
          seen: seen,
          unmappedTypeSamples: unmappedTypeSamples,
          rejectedPlaces: rejectedPlaces,
          incValid: () => validPlaces++,
          incRejected: () => rejectedCount++,
          incDuplicate: () => duplicateCount++,
        );
      }
    }
  }

  {
    final locationBias =
        'circle:${radius}@${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}';
    final souvenirQueries = <String>[
      'souvenir shop $area Penang',
      'handicraft shop $area Penang',
      'batik shop $area Penang',
      'local product shop $area Penang',
      'gift shop $area Penang',
      'chocolate shop $area Penang',
      'nutmeg shop $area Penang',
    ];

    for (final q in souvenirQueries) {
      final textResults = await _placesTextSearch(
        query: q,
        locationBias: locationBias,
      );
      for (final r in textResults) {
        await _processOnePlaceResult(
          result: r,
          region: region,
          googleType: 'store', // we coerce to souvenir via the guard above
          area: area,
          areaRef: areaRef,
          duplicateTracker: duplicateTracker,
          seen: seen,
          unmappedTypeSamples: unmappedTypeSamples,
          rejectedPlaces: rejectedPlaces,
          incValid: () => validPlaces++,
          incRejected: () => rejectedCount++,
          incDuplicate: () => duplicateCount++,
        );
      }
    }
  }

  {
    final locationBias =
        'circle:${radius}@${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}';
    final restaurantQueries = <String>[
      'best restaurants in $area Penang',
      'local food restaurant $area Penang',
      'seafood restaurant $area Penang',
    ];

    for (final q in restaurantQueries) {
      final textResults = await _placesTextSearch(
        query: q,
        locationBias: locationBias,
      );
      for (final r in textResults) {
        await _processOnePlaceResult(
          result: r,
          region: region,
          googleType: 'restaurant',
          area: area,
          areaRef: areaRef,
          duplicateTracker: duplicateTracker,
          seen: seen,
          unmappedTypeSamples: unmappedTypeSamples,
          rejectedPlaces: rejectedPlaces,
          incValid: () => validPlaces++,
          incRejected: () => rejectedCount++,
          incDuplicate: () => duplicateCount++,
        );
      }
    }
  }

  // --- Nearby Search (your existing approach) ---
  for (final googleType in _categories.keys) {
    String? nextPageToken;
    int attempts = 0;

    do {
      final qp = {
        'location': '$lat,$lon',
        'radius': radius.toString(),
        'type': googleType,
        'key': apiKey,
        if (nextPageToken != null) 'pagetoken': nextPageToken!,
      };
      final uri = Uri.parse(nearbyUrl).replace(queryParameters: qp);
      final resp = await http.get(uri);

      if (resp.statusCode != 200) {
        print('❌ Nearby error $area [$googleType]: ${resp.statusCode}');
        break;
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = (body['results'] as List?) ?? const [];
      nextPageToken = body['next_page_token'];

      if (results.isEmpty) break;

      for (final r in results) {
        await _processOnePlaceResult(
          result: (r as Map<String, dynamic>),
          region: region,
          googleType: googleType,
          area: area,
          areaRef: areaRef,
          duplicateTracker: duplicateTracker,
          seen: seen,
          unmappedTypeSamples: unmappedTypeSamples,
          rejectedPlaces: rejectedPlaces,
          incValid: () => validPlaces++,
          incRejected: () => rejectedCount++,
          incDuplicate: () => duplicateCount++,
        );
      }

      if (nextPageToken != null) {
        await Future.delayed(const Duration(seconds: 3));
      }
      attempts++;
    } while (nextPageToken != null && attempts < 3);
  }

  print(
    '🎯 $area summary: $validPlaces valid, $rejectedCount rejected, $duplicateCount duplicates',
  );
  print('🔎 Unmapped types in $area: $unmappedTypeSamples');
  print('✅ Finished $area with hybrid validation\n');
  return unmappedTypeSamples;
}

/* =================== EXISTING POST-PROCESSING =================== */

Future<void> runCategorization() async {
  for (final r in _penangRegions) {
    await categorizeAccommodations(r['state'], r['area']);
  }
}

Future<void> categorizeAccommodations(String state, String area) async {
  print("📋 Categorizing accommodations in $state, $area...");
  try {
    final places =
        await FirebaseFirestore.instance
            .collection('areas')
            .doc(area)
            .collection('places')
            .where('category', isEqualTo: 'accommodation')
            .get();

    for (final doc in places.docs) {
      final data = doc.data();
      final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
      final userRatings = (data['user_ratings_total'] as num?)?.toInt() ?? 0;

      int priceLevel;
      double estimatedCost;
      if (rating == 0.0 || userRatings < 20) {
        priceLevel = 3;
        estimatedCost = 400.0;
      } else if (rating <= 3.5) {
        priceLevel = 2;
        estimatedCost = 200.0;
      } else if (rating <= 4.2) {
        priceLevel = 3;
        estimatedCost = 400.0;
      } else if (rating <= 4.6) {
        priceLevel = 4;
        estimatedCost = 800.0;
      } else {
        priceLevel = 5;
        estimatedCost = 1500.0;
      }

      await doc.reference.update({
        'price_level': priceLevel,
        'estimated_cost': estimatedCost,
      });
      print("✅ Updated ${data['name']}: Level $priceLevel, MYR $estimatedCost");
    }
  } catch (e) {
    print("🚨 Error categorizing accommodations: $e");
  }
}
