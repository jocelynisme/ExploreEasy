import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:animate_do/animate_do.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import 'dart:math';
import 'place_details_sheet.dart' as pds;
import 'booking_flow.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';

// ------------ PLAN STYLE ------------
enum PlanStyle { foodHeavy, balanced, attractionSeeking, shoppingLover }

class PenangWeatherData {
  static const Map<int, Map<String, dynamic>> seasonalPatterns = {
    1: {
      'condition': 'Partly Cloudy',
      'temp_max': 32,
      'temp_min': 24,
      'rainfall_mm': 70,
      'rain_days': 5,
      'rain_chance': 25,
      'humidity': 70,
      'monsoon': 'northeast',
      'season': 'cool_dry',
    },
    2: {
      'condition': 'Partly Cloudy',
      'temp_max': 33,
      'temp_min': 24,
      'rainfall_mm': 122,
      'rain_days': 9,
      'rain_chance': 15,
      'humidity': 69,
      'monsoon': 'northeast',
      'season': 'cool_dry',
    },
    3: {
      'condition': 'Partly Cloudy',
      'temp_max': 33,
      'temp_min': 25,
      'rainfall_mm': 120,
      'rain_days': 8,
      'rain_chance': 30,
      'humidity': 70,
      'monsoon': 'inter_monsoon',
      'season': 'hot_dry',
    },
    4: {
      'condition': 'Partly Cloudy',
      'temp_max': 33,
      'temp_min': 26,
      'rainfall_mm': 240,
      'rain_days': 11,
      'rain_chance': 40,
      'humidity': 72,
      'monsoon': 'inter_monsoon',
      'season': 'hot_humid',
    },
    5: {
      'condition': 'Scattered Showers',
      'temp_max': 33,
      'temp_min': 26,
      'rainfall_mm': 240,
      'rain_days': 12,
      'rain_chance': 45,
      'humidity': 75,
      'monsoon': 'southwest',
      'season': 'hot_humid',
    },
    6: {
      'condition': 'Partly Cloudy',
      'temp_max': 33,
      'temp_min': 26,
      'rainfall_mm': 170,
      'rain_days': 8,
      'rain_chance': 35,
      'humidity': 73,
      'monsoon': 'southwest',
      'season': 'hot_dry',
    },
    7: {
      'condition': 'Partly Cloudy',
      'temp_max': 32,
      'temp_min': 25,
      'rainfall_mm': 210,
      'rain_days': 9,
      'rain_chance': 35,
      'humidity': 74,
      'monsoon': 'southwest',
      'season': 'warm_humid',
    },
    8: {
      'condition': 'Partly Cloudy',
      'temp_max': 32,
      'temp_min': 25,
      'rainfall_mm': 190,
      'rain_days': 11,
      'rain_chance': 40,
      'humidity': 75,
      'monsoon': 'southwest',
      'season': 'warm_humid',
    },
    9: {
      'condition': 'Scattered Showers',
      'temp_max': 32,
      'temp_min': 25,
      'rainfall_mm': 330,
      'rain_days': 13,
      'rain_chance': 55,
      'humidity': 76,
      'monsoon': 'inter_monsoon',
      'season': 'wet',
    },
    10: {
      'condition': 'Heavy Rain',
      'temp_max': 31,
      'temp_min': 25,
      'rainfall_mm': 342,
      'rain_days': 24,
      'rain_chance': 75,
      'humidity': 76,
      'monsoon': 'northeast',
      'season': 'wet',
    },
    11: {
      'condition': 'Heavy Rain',
      'temp_max': 31,
      'temp_min': 24,
      'rainfall_mm': 230,
      'rain_days': 13,
      'rain_chance': 65,
      'humidity': 75,
      'monsoon': 'northeast',
      'season': 'wet',
    },
    12: {
      'condition': 'Scattered Showers',
      'temp_max': 31,
      'temp_min': 24,
      'rainfall_mm': 140,
      'rain_days': 8,
      'rain_chance': 45,
      'humidity': 72,
      'monsoon': 'northeast',
      'season': 'wet',
    },
  };

  // Enhanced weather condition logic based on meteorological patterns
  static String generateWeatherCondition(
    int month,
    int dayOfMonth, {
    bool enhancedLogic = true,
  }) {
    final pattern = seasonalPatterns[month]!;
    final random = Random(month * 100 + dayOfMonth); // Consistent seed

    if (!enhancedLogic) {
      return pattern['condition'] as String;
    }

    // Enhanced logic considering multiple factors
    final rainChance = pattern['rain_chance'] as int;
    final monsoonType = pattern['monsoon'] as String;
    final season = pattern['season'] as String;
    final randomValue = random.nextInt(100);

    // Monsoon-specific adjustments
    double adjustedRainChance = rainChance.toDouble();

    switch (monsoonType) {
      case 'northeast':
        // Northeast monsoon brings more consistent rain
        if (month == 10 || month == 11) {
          adjustedRainChance *= 1.2; // Peak monsoon months
        }
        break;
      case 'southwest':
        // Southwest monsoon is drier but can have sudden downpours
        if (dayOfMonth % 7 == 0) {
          // Weekly patterns
          adjustedRainChance *= 1.3;
        } else {
          adjustedRainChance *= 0.8;
        }
        break;
      case 'inter_monsoon':
        // Inter-monsoon periods have unpredictable weather
        adjustedRainChance += random.nextInt(20) - 10; // ±10% variation
        break;
    }

    // Season-specific conditions
    if (season == 'wet' && randomValue < adjustedRainChance) {
      if (adjustedRainChance > 70) {
        return random.nextBool() ? 'Heavy Rain' : 'Thunderstorms';
      } else if (adjustedRainChance > 50) {
        return 'Scattered Showers';
      } else {
        return 'Light Rain';
      }
    } else if (season == 'hot_dry') {
      if (randomValue < 20) {
        return 'Hazy';
      } else {
        return random.nextBool() ? 'Sunny' : 'Partly Cloudy';
      }
    } else {
      // Default conditions based on humidity and season
      final humidity = pattern['humidity'] as int;
      if (humidity > 75) {
        return random.nextBool() ? 'Partly Cloudy' : 'Mostly Cloudy';
      } else {
        return random.nextBool() ? 'Partly Cloudy' : 'Sunny';
      }
    }
  }
}

class PlanDayConfig {
  final int attractionsPerDay;
  final int mealsPerDay; // breakfast/lunch/dinner (max 3)
  final int souvenirsPerDay;
  const PlanDayConfig({
    required this.attractionsPerDay,
    required this.mealsPerDay,
    required this.souvenirsPerDay,
  });
}

extension PlanStyleLabel on PlanStyle {
  String get label {
    switch (this) {
      case PlanStyle.foodHeavy:
        return 'Food-heavy';
      case PlanStyle.balanced:
        return 'Balanced';
      case PlanStyle.attractionSeeking:
        return 'Attraction-seeking';
      case PlanStyle.shoppingLover:
        return 'Shopping-lover';
    }
  }

  String get emoji {
    switch (this) {
      case PlanStyle.foodHeavy:
        return '🍜';
      case PlanStyle.balanced:
        return '⚖️';
      case PlanStyle.attractionSeeking:
        return '🏛️';
      case PlanStyle.shoppingLover:
        return '🛍️';
    }
  }
}

class TSPResult {
  final List<LatLng> optimizedPoints;
  final List<String> optimizedNames;
  final double totalDistance;
  final int improvements;

  TSPResult({
    required this.optimizedPoints,
    required this.optimizedNames,
    required this.totalDistance,
    required this.improvements,
  });
}

class PlanStyleCounts {
  final int attractions, meals, shops;
  const PlanStyleCounts({
    required this.attractions,
    required this.meals,
    required this.shops,
  });
}

// Adjust these counts anytime you like:
const Map<PlanStyle, PlanStyleCounts> kPlanCounts = {
  PlanStyle.foodHeavy: PlanStyleCounts(attractions: 1, meals: 4, shops: 1),
  PlanStyle.balanced: PlanStyleCounts(attractions: 2, meals: 2, shops: 2),
  PlanStyle.attractionSeeking: PlanStyleCounts(
    attractions: 4,
    meals: 2,
    shops: 0,
  ),
  PlanStyle.shoppingLover: PlanStyleCounts(attractions: 1, meals: 2, shops: 3),
};

// hold current choice (default balanced)

PlanStyle _selectedPlanStyle = PlanStyle.balanced;

final Map<PlanStyle, String> _styleDescriptions = {
  PlanStyle.foodHeavy: 'More meals (B/L/D), fewer attractions, 1 souvenir stop',
  PlanStyle.balanced: 'Mix of attractions + meals, 1 souvenir stop',
  PlanStyle.attractionSeeking:
      'Max attractions, fewer meals, no souvenir stops',
  PlanStyle.shoppingLover: 'Extra souvenir time, steady attractions + meals',
};

class PlanTripScreen extends StatefulWidget {
  final String userId;
  PlanTripScreen({required this.userId});

  @override
  _PlanTripScreenState createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends State<PlanTripScreen> {
  List<Widget> messages = [
    Text("AI: Hi! Pick a plan, date, state, and areas!"),
  ];
  DateTime? startDate;

  DateTime? endDate;
  List<String> dailyWeather = [];
  final logger = Logger();
  Key mapWidgetKey = UniqueKey();
  Key _markersKey = UniqueKey();
  int? _mapMsgIndex;
  // Store the full attractions catalog for alt-suggestions
  List<Map<String, dynamic>> allAttractions = [];
  // Similar-attraction settings
  static const double kAltAttractionRadiusKm = 2.0; // 2 km
  static const double kOverlapKm = 0.05; // ~50 m (treat as same place)
  double _lastEstimateBand = 0.20; // 10% if exact-only rows used, else 20%
  final Map<String, Map<String, dynamic>> _placeCache = {};
  bool _hasShownExtendedForecastDisclaimer = false;
  bool _hasShownRainReminder = false;

  static const _brand = Color(0xFFD7CCC8);
  static const _brandDark = Color(0xFF6D4C41);
  // in your State class

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String tripTitle = '';

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // Keep all places so we can search alternates by type+radius
  List<Map<String, dynamic>> _allPlaces = [];

  String? selectedState;
  int numberOfTravelers = 2; // Default 2 travelers
  // Add controllers at top
  final TextEditingController _hotelPercentController = TextEditingController();

  bool _preferenceLoaded = false;
  double hotelBudget = 0;
  bool useHotelLevel = true; // toggle state
  int selectedHotelLevel = 3; // default to level 3
  final TextEditingController _hotelManualAmountController =
      TextEditingController();

  static const int kAltAttractionMaxPerStop = 6; // cap how many we show

  Map<String, List<Map<String, dynamic>>> alternateAttractionsByStop = {};
  // Nearby alternates per stop (key = 'd{day}_i{index}')
  Map<String, List<Map<String, dynamic>>> alternateRestaurantsByStop = {};
  Map<String, List<Map<String, dynamic>>> alternateShopsByStop = {};

  // Toggles to render their pins
  bool showAlternateRestaurants = false;
  bool showAlternateShops = false;

  List<Map<String, dynamic>> _allAttractions =
      []; // cache all attractions for alt search

  List<Map<String, dynamic>> suitableHotels = [];
  List<Map<String, dynamic>> alternateHotels = [];
  Map<String, dynamic>? selectedHotel;
  String? selectedRoomType;
  String? previewHotelId;
  bool isRouting = false;
  final MapController _mapController = MapController();
  // Route state (class-level)
  List<List<LatLng>> dailyPoints = [];
  List<List<String>> dailyNames = [];

  int? _itinMsgIndex;
  Key _itinKey = UniqueKey();

  // Pretty km formatting
  String _formatKm(double km) =>
      km < 0.095
          ? '${(km * 1000).round()} m'
          : '${km.toStringAsFixed(km < 10 ? 2 : 1)} km';

  /// TSP Optimization methods
  List<List<double>> _buildDistanceMatrix(List<LatLng> points) {
    final n = points.length;
    final matrix = List.generate(n, (_) => List.filled(n, 0.0));

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (i != j) {
          matrix[i][j] = _calculateDistance(points[i], points[j]);
        }
      }
    }
    return matrix;
  }

  TSPResult _optimizeRoute({
    required List<LatLng> points,
    required List<String> names,
    int? fixedStart = 0,
    bool returnToStart = false,
    int maxIterations = 500,
  }) {
    if (points.length <= 2) {
      return TSPResult(
        optimizedPoints: List.from(points),
        optimizedNames: List.from(names),
        totalDistance:
            points.length == 2 ? _calculateDistance(points[0], points[1]) : 0.0,
        improvements: 0,
      );
    }

    final distanceMatrix = _buildDistanceMatrix(points);
    var bestRoute = List.generate(points.length, (i) => i);
    var bestDistance = _calculateRouteDistance(distanceMatrix, bestRoute);
    var improvements = 0;

    // Generate initial route
    if (fixedStart != null) {
      bestRoute.remove(fixedStart);
      bestRoute.insert(0, fixedStart);
    }

    // 2-opt optimization
    for (int iteration = 0; iteration < maxIterations; iteration++) {
      bool improved = false;

      final startIdx = fixedStart != null ? 1 : 0;
      final endIdx = returnToStart ? bestRoute.length - 1 : bestRoute.length;

      for (int i = startIdx; i < endIdx - 1; i++) {
        for (int j = i + 1; j < endIdx; j++) {
          final newRoute = _perform2OptSwap(bestRoute, i, j);
          final newDistance = _calculateRouteDistance(distanceMatrix, newRoute);

          if (newDistance < bestDistance) {
            bestRoute = newRoute;
            bestDistance = newDistance;
            improvements++;
            improved = true;
          }
        }
      }

      if (!improved) break;
    }

    // If returning to start, add the start point at the end
    if (returnToStart && fixedStart != null) {
      bestRoute.add(fixedStart);
    }

    final optimizedPoints = bestRoute.map((i) => points[i]).toList();
    final optimizedNames = bestRoute.map((i) => names[i]).toList();

    return TSPResult(
      optimizedPoints: optimizedPoints,
      optimizedNames: optimizedNames,
      totalDistance: bestDistance,
      improvements: improvements,
    );
  }

  List<int> _perform2OptSwap(List<int> route, int i, int j) {
    final newRoute = List<int>.from(route);
    int left = i + 1;
    int right = j;

    while (left < right) {
      final temp = newRoute[left];
      newRoute[left] = newRoute[right];
      newRoute[right] = temp;
      left++;
      right--;
    }

    return newRoute;
  }

  double _calculateRouteDistance(
    List<List<double>> distanceMatrix,
    List<int> route,
  ) {
    if (route.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      totalDistance += distanceMatrix[route[i]][route[i + 1]];
    }
    return totalDistance;
  }

  // Recompute a day's total distance from points:
  double _dayTotalKm(List<LatLng> points) {
    double t = 0;
    for (int i = 0; i + 1 < points.length; i++) {
      t += _calculateDistance(points[i], points[i + 1]);
    }
    return t;
  }

  // Bump the itinerary widget so it fully rebuilds
  void _hardRefreshItinerary() {
    _itinKey = UniqueKey();
    if (_itinMsgIndex != null) {
      messages[_itinMsgIndex!] = _buildItineraryMessage();
    }
    setState(() {});
  }

  Widget _buildItineraryMessage() {
    return StatefulBuilder(
      key: _itinKey,
      builder: (context, setSB) {
        if (dailyPoints.isEmpty || dailyNames.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _brand.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.route, color: _brandDark),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Live Itinerary',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _brandDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // One card per day
              for (int d = 0; d < dailyPoints.length; d++)
                _buildItineraryDayCard(context, d),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItineraryDayCard(BuildContext context, int day) {
    final names =
        (day < dailyNames.length) ? dailyNames[day] : const <String>[];
    final points =
        (day < dailyPoints.length) ? dailyPoints[day] : const <LatLng>[];
    if (names.isEmpty || points.isEmpty) return const SizedBox.shrink();

    // Keep your existing logic for leg calculations
    final leg = <double>[];
    for (int i = 0; i + 1 < points.length; i++) {
      leg.add(_calculateDistance(points[i], points[i + 1]));
    }
    final totalKm = _dayTotalKm(points);

    final dateText =
        (startDate != null)
            ? startDate!.add(Duration(days: day)).toString().substring(0, 10)
            : 'Day ${day + 1}';

    final weather = (day < dailyWeather.length) ? dailyWeather[day] : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_brand, _brandDark.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day ${day + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    dateText,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  if (weather != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.cloud, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Weather: $weather',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  // Steps
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: names.length,
                    separatorBuilder:
                        (_, __) => Divider(height: 8, color: Colors.grey[200]),
                    itemBuilder: (_, i) {
                      final isHotel = i == 0;
                      final name = names[i];
                      final String toNext =
                          (i < leg.length)
                              ? '→ ${_formatKm(leg[i])} to next'
                              : '';

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                isHotel
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.blueAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isHotel ? Icons.hotel : Icons.place,
                            color: isHotel ? Colors.green : Colors.blueAccent,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            color: _brandDark,
                          ),
                        ),
                        subtitle:
                            toNext.isEmpty
                                ? null
                                : Text(
                                  toNext,
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                        onTap: () {
                          _openStopUIFromRoute(
                            context: context,
                            day: day,
                            index: i,
                            name: name,
                            latLng: points[i],
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.straighten, color: _brandDark, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Total distance: ${_formatKm(totalKm)}',
                        style: GoogleFonts.poppins(
                          color: _brandDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
      duration: const Duration(milliseconds: 500),
      delay: Duration(milliseconds: day * 100),
    );
  }

  void _openStopUIFromRoute({
    required BuildContext context,
    required int day,
    required int index,
    required String name,
    required LatLng latLng,
  }) {
    final isHotel = index == 0;

    if (isHotel) {
      _openHotelUIFromRoute(
        context: context,
        day: day,
        index: index,
        name: name,
        latLng: latLng,
      );
    } else {
      _openAttractionUIFromRoute(
        context: context,
        day: day,
        index: index,
        name: name,
        latLng: latLng,
      );
    }
  }

  void _openAttractionUIFromRoute({
    required BuildContext context,
    required int day,
    required int index,
    required String name,
    required LatLng latLng,
  }) {
    _openPlaceDetailsSheetByIds(
      day: day,
      index: index,
      name: name,
      latLng: latLng,
    );
  }

  void _openHotelUIFromRoute({
    required BuildContext context,
    required int day,
    required int index,
    required String name,
    required LatLng latLng,
  }) {
    // If your existing details sheet handles hotels too, reuse it:
    _openPlaceDetailsSheetByIds(
      day: day,
      index: index, // 0 = hotel
      name: name,
      latLng: latLng,
    );
  }

  String _norm(String? s) =>
      (s ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Coarse "kind" detector for attractions (museum, temple, park, market, beach...).
  String _placeKind(Map<String, dynamic> place) {
    final name = (place['properties']?['name'] ?? '').toString().toLowerCase();
    final type = (place['properties']?['type'] ?? '').toString().toLowerCase();
    final cat =
        (place['properties']?['category'] ?? '').toString().toLowerCase();

    if (name.contains('museum')) return 'museum';
    if (name.contains('temple') ||
        name.contains('mosque') ||
        name.contains('church'))
      return 'worship';
    if (name.contains('gallery')) return 'gallery';
    if (name.contains('park') || name.contains('garden') || type == 'outdoor')
      return 'park';
    if (name.contains('market') || name.contains('night market'))
      return 'market';
    if (name.contains('mall') || name.contains('komtar')) return 'mall';
    if (name.contains('beach')) return 'beach';
    if (name.contains('mural') || name.contains('street art'))
      return 'street-art';

    if (cat.isNotEmpty) return cat; // fallback to category
    if (type.isNotEmpty) return type; // or type
    return 'other';
  }

  DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Same as above but from a raw name string (used for the base stop)
  String _kindFromName(String rawName) {
    final p = {
      'properties': {'name': rawName},
    };
    return _placeKind(p);
  }

  /// Build alt attractions for every stop (except index 0/hotel)
  void _recomputeAltAttractions() {
    alternateAttractionsByStop.clear();
    if (_allAttractions.isEmpty || dailyPoints.isEmpty) return;

    // Set of already chosen names (avoid suggesting duplicates)
    final chosen = <String>{};
    for (int d = 0; d < dailyNames.length; d++) {
      for (int i = 1; i < dailyNames[d].length; i++) {
        chosen.add(_norm(dailyNames[d][i]));
      }
    }

    for (int d = 0; d < dailyPoints.length; d++) {
      for (int i = 1; i < dailyPoints[d].length; i++) {
        final baseName = dailyNames[d][i];
        final basePt = dailyPoints[d][i];
        final baseKind = _kindFromName(baseName);

        // Find alts of same kind within radius, not already selected
        final candidates = <Map<String, dynamic>>[];
        for (final place in _allAttractions) {
          final nNorm = _norm(place['properties']?['name']);
          if (nNorm.isEmpty ||
              nNorm == _norm(baseName) ||
              chosen.contains(nNorm))
            continue;

          if (_placeKind(place) != baseKind) continue;

          final coords = place['geometry']?['coordinates'];
          if (coords is! List || coords.length < 2) continue;

          final LatLng p = LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          );
          final dist = _calculateDistance(basePt, p);
          if (dist <= kAltAttractionRadiusKm) {
            // store distance to show in the sheet
            place['distanceFromStop'] = dist;
            candidates.add(place);
            if (candidates.length >= kAltAttractionMaxPerStop) break;
          }
        }

        final key = 'd${d}_i${i}';
        alternateAttractionsByStop[key] = candidates;

        debugPrint(
          '🎯 [alts-attraction] $key base="$baseName" kind=$baseKind -> ${candidates.length} suggestions within ${kAltAttractionRadiusKm}km',
        );
      }
    }
  }

  void _clearAltPinsFor({required int day, required int index}) {
    final key = _stopKey(day, index);
    alternateAttractionsByStop.remove(
      key,
    ); // if you have alternates for attractions
    alternateRestaurantsByStop.remove(key);
    alternateShopsByStop.remove(key);

    showAlternateAttractions = alternateAttractionsByStop.isNotEmpty;
    showAlternateRestaurants = alternateRestaurantsByStop.isNotEmpty;
    showAlternateShops = alternateShopsByStop.isNotEmpty;

    _hardRefreshMap(); // your existing "bump key" map refresh
  }

  void _previewAlternateRestaurantsForStop({
    required int day,
    required int index,
    required List<Map<String, dynamic>> list,
  }) {
    // Add distance to each alt (from the tapped stop)
    LatLng? anchor;
    if (day < dailyPoints.length && index < dailyPoints[day].length) {
      anchor = dailyPoints[day][index];
    }

    final key = _stopKey(day, index);
    final sanitized = <Map<String, dynamic>>[];

    for (final p in list) {
      try {
        final coords = p['geometry']?['coordinates'];
        if (coords is! List || coords.length < 2) continue;

        final lon = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        double dKm = 0.0;
        if (anchor != null) {
          dKm = _calculateDistance(anchor, LatLng(lat, lon));
        }

        final copy = Map<String, dynamic>.from(p);
        copy['distanceFromStop'] = dKm;
        sanitized.add(copy);
      } catch (_) {
        /* ignore bad rows */
      }
    }

    setState(() {
      alternateRestaurantsByStop[key] = sanitized;
      showAlternateRestaurants = true;
    });

    debugPrint(
      '🍽️ [preview-rest] day=${day + 1} idx=$index → ${sanitized.length} alts',
    );
    _hardRefreshMap();
  }

  Future<void> _replaceAttractionStop({
    required int day,
    required int index, // index in that day (>=1)
    required Map<String, dynamic> alt,
  }) async {
    debugPrint('🟦 [_replaceAttractionStop] request day=${day + 1} idx=$index');

    // --- validate / extract new coordinates + name ---
    final coords = alt['geometry']?['coordinates'];
    if (coords is! List || coords.length < 2) {
      debugPrint('❌ [_replaceAttractionStop] invalid coordinates in alt');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.error_outline, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Selected place has invalid coordinates',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    final LatLng newPt = LatLng(
      (coords[1] as num).toDouble(),
      (coords[0] as num).toDouble(),
    );
    final String newName =
        (alt['properties']?['name'] ?? 'Attraction').toString();

    // --- duplicate scan across the whole trip (except the slot we’re changing) ---
    final String newNameNorm = _norm(newName);
    const double overlapKm = kOverlapKm; // ~50m
    int? dupDay; // 0-based
    int? dupIndex; // >=1
    String? dupReason; // 'name' | 'location'
    double? dupDistKm;

    for (int d = 0; d < dailyNames.length; d++) {
      final names = (d < dailyNames.length) ? dailyNames[d] : const <String>[];
      final pts = (d < dailyPoints.length) ? dailyPoints[d] : const <LatLng>[];

      for (int i = 1; i < names.length; i++) {
        // ignore the very slot we’re replacing
        if (d == day && i == index) continue;

        // 1) same name?
        if (_norm(names[i]) == newNameNorm) {
          dupDay = d;
          dupIndex = i;
          dupReason = 'name';
          break;
        }

        // 2) nearly the same location?
        if (i < pts.length) {
          final dist = _calculateDistance(pts[i], newPt);
          if (dist < overlapKm) {
            dupDay = d;
            dupIndex = i;
            dupReason = 'location';
            dupDistKm = dist;
            break;
          }
        }
      }
      if (dupDay != null) break;
    }

    // --- if duplicate, ask the user first ---
    if (dupDay != null && dupIndex != null && dupReason != null) {
      final reasonText =
          dupReason == 'name'
              ? 'the same place by name'
              : 'nearly the same location (~${((dupDistKm ?? 0) * 1000).round()} m away)';
      final proceed =
          await showDialog<bool>(
            context: context,
            builder:
                (dialogCtx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: Colors.white,
                  elevation: 8,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _brand.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: _brandDark,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Already in your plan',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _brandDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      '"$newName" is already on Day ${dupDay! + 1} (stop #$dupIndex).\n'
                      'This looks like $reasonText.\n\n'
                      'Do you still want to use it here as well?',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                  actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'No',
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: _brandDark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Use anyway',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
          ) ??
          false;
    }

    // --- perform the replacement (your original logic) ---
    setState(() {
      dailyPoints[day][index] = newPt;
      dailyNames[day][index] = newName;

      // Update the corresponding tripPick (sequence == index, dayIndex == day+1)
      for (final p in tripPicks) {
        if ((p['dayIndex'] ?? -1) == day + 1 &&
            (p['sequence'] ?? -1) == index) {
          p['placeData'] ??= {};
          p['placeData']['name'] = newName;
          p['placeData']['address'] =
              alt['properties']?['address'] ?? p['placeData']['address'];
          p['placeData']['coordinates'] = {
            'lat': newPt.latitude,
            'lon': newPt.longitude,
          };
          p['placeData']['rating'] =
              (alt['properties']?['rating'] as num?)?.toDouble() ?? 0.0;
          p['placeData']['type'] =
              alt['properties']?['type'] ?? p['placeData']['type'];
          p['placeData']['price_level'] =
              alt['properties']?['price_level'] ??
              p['placeData']['price_level'];
          p['placeData']['kind'] =
              alt['properties']?['kind'] ?? p['placeData']['kind'];
          break;
        }
      }
    });

    debugPrint(
      '✅ [_replaceAttractionStop] replaced: day=${day + 1} idx=$index -> "$newName" @ ${newPt.latitude},${newPt.longitude}',
    );
    _clearAltPinsFor(day: day, index: index);
    // Neighborhood changes -> recompute alternates + refresh map
    _recomputeAltAttractions();
    _hardRefreshMap();
    _hardRefreshItinerary();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Replaced stop #$index on Day ${day + 1} with "$newName".',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _brandDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _replaceRestaurantStop({
    required int day,
    required int index, // >=1
    required Map<String, dynamic> alt,
  }) async {
    debugPrint('🟦 [_replaceRestaurantStop] day=${day + 1} idx=$index');

    final coords = alt['geometry']?['coordinates'];
    if (coords is! List || coords.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.error_outline, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Selected restaurant has invalid coordinates',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final LatLng newPt = LatLng(
      (coords[1] as num).toDouble(),
      (coords[0] as num).toDouble(),
    );
    final String newName =
        (alt['properties']?['name'] ?? 'Restaurant').toString();

    // ---- duplicate scan (skip the slot we’re changing) ----
    const double overlapKm = kOverlapKm; // ~50m
    final String newNameNorm = _norm(newName);
    int? dupDay, dupIndex;
    String? dupReason;
    double? dupDistKm;

    for (int d = 0; d < dailyNames.length; d++) {
      final names = (d < dailyNames.length) ? dailyNames[d] : const <String>[];
      final pts = (d < dailyPoints.length) ? dailyPoints[d] : const <LatLng>[];

      for (int i = 1; i < names.length; i++) {
        if (d == day && i == index) continue;

        if (_norm(names[i]) == newNameNorm) {
          dupDay = d;
          dupIndex = i;
          dupReason = 'name';
          break;
        }
        if (i < pts.length) {
          final dist = _calculateDistance(pts[i], newPt);
          if (dist < overlapKm) {
            dupDay = d;
            dupIndex = i;
            dupReason = 'location';
            dupDistKm = dist;
            break;
          }
        }
      }
      if (dupDay != null) break;
    }

    if (dupDay != null && dupIndex != null && dupReason != null) {
      final reasonText =
          dupReason == 'name'
              ? 'the same place by name'
              : 'nearly the same location (~${((dupDistKm ?? 0) * 1000).round()} m away)';
      final proceed =
          await showDialog<bool>(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('Already in your plan'),
                  content: Text(
                    '“$newName” is already on Day ${dupDay! + 1} (stop #$dupIndex).\n'
                    'This looks like $reasonText.\n\nUse here as well?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('No'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Use anyway'),
                    ),
                  ],
                ),
          ) ??
          false;
      if (!proceed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kept your original stop.',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.grey[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
    }

    // ---- apply change ----
    setState(() {
      dailyPoints[day][index] = newPt;

      // preserve "Meal:" prefix if present, otherwise add it
      final oldLabel =
          (day < dailyNames.length && index < dailyNames[day].length)
              ? dailyNames[day][index]
              : '';
      final hasPrefix = oldLabel.toLowerCase().startsWith('meal:');
      dailyNames[day][index] = hasPrefix ? 'Meal: $newName' : 'Meal: $newName';

      for (final p in tripPicks) {
        if ((p['dayIndex'] ?? -1) == day + 1 &&
            (p['sequence'] ?? -1) == index) {
          p['placeData'] ??= {};
          p['placeData']['name'] = newName;
          p['placeData']['address'] =
              alt['properties']?['address'] ?? p['placeData']['address'];
          p['placeData']['coordinates'] = {
            'lat': newPt.latitude,
            'lon': newPt.longitude,
          };
          p['placeData']['category'] = 'restaurant';
          p['placeData']['rating'] =
              (alt['properties']?['rating'] as num?)?.toDouble() ?? 0.0;
          p['placeData']['type'] =
              alt['properties']?['type'] ??
              p['placeData']['type'] ??
              'restaurant';
          p['placeData']['price_level'] =
              alt['properties']?['price_level'] ??
              p['placeData']['price_level'];
          p['placeData']['kind'] =
              alt['properties']?['kind'] ?? p['placeData']['kind'];
          break;
        }
      }

      // 🔎 important: clear leftover preview pins for this slot
      _clearAltPinsFor(day: day, index: index);
    });

    _hardRefreshMap();
    _hardRefreshItinerary();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Updated meal stop #$index on Day ${day + 1}.',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _brandDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _replaceSouvenirStop({
    required int day,
    required int index, // >=1
    required Map<String, dynamic> alt,
  }) async {
    debugPrint('🟦 [_replaceSouvenirStop] day=${day + 1} idx=$index');

    final coords = alt['geometry']?['coordinates'];
    if (coords is! List || coords.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.error_outline, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Selected shop has invalid coordinates',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      return;
    }

    final LatLng newPt = LatLng(
      (coords[1] as num).toDouble(),
      (coords[0] as num).toDouble(),
    );
    final String newName =
        (alt['properties']?['name'] ?? 'Souvenir Shop').toString();

    // Duplicate scan
    const double overlapKm = kOverlapKm;
    final String newNameNorm = _norm(newName);
    int? dupDay, dupIndex;
    String? dupReason;
    double? dupDistKm;

    for (int d = 0; d < dailyNames.length; d++) {
      final names = (d < dailyNames.length) ? dailyNames[d] : const <String>[];
      final pts = (d < dailyPoints.length) ? dailyPoints[d] : const <LatLng>[];
      for (int i = 1; i < names.length; i++) {
        if (d == day && i == index) continue;
        if (_norm(names[i]) == newNameNorm) {
          dupDay = d;
          dupIndex = i;
          dupReason = 'name';
          break;
        }
        if (i < pts.length) {
          final dist = _calculateDistance(pts[i], newPt);
          if (dist < overlapKm) {
            dupDay = d;
            dupIndex = i;
            dupReason = 'location';
            dupDistKm = dist;
            break;
          }
        }
      }
      if (dupDay != null) break;
    }

    if (dupDay != null && dupIndex != null && dupReason != null) {
      final reasonText =
          dupReason == 'name'
              ? 'the same place by name'
              : 'nearly the same location (~${((dupDistKm ?? 0) * 1000).round()} m away)';
      final proceed =
          await showDialog<bool>(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('Already in your plan'),
                  content: Text(
                    '“$newName” is already on Day ${dupDay! + 1} (stop #$dupIndex).\n'
                    'This looks like $reasonText.\n\nUse here as well?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('No'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Use anyway'),
                    ),
                  ],
                ),
          ) ??
          false;
      if (!proceed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kept your original stop.',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.grey[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
    }

    // Apply change
    setState(() {
      dailyPoints[day][index] = newPt;

      final oldLabel =
          (day < dailyNames.length && index < dailyNames[day].length)
              ? dailyNames[day][index]
              : '';
      final hasPrefix = oldLabel.toLowerCase().startsWith('souvenir:');
      dailyNames[day][index] =
          hasPrefix ? 'Souvenir: $newName' : 'Souvenir: $newName';

      for (final p in tripPicks) {
        if ((p['dayIndex'] ?? -1) == day + 1 &&
            (p['sequence'] ?? -1) == index) {
          p['placeData'] ??= {};
          p['placeData']['name'] = newName;
          p['placeData']['address'] =
              alt['properties']?['address'] ?? p['placeData']['address'];
          p['placeData']['coordinates'] = {
            'lat': newPt.latitude,
            'lon': newPt.longitude,
          };
          p['placeData']['category'] = 'souvenir';
          p['placeData']['rating'] =
              (alt['properties']?['rating'] as num?)?.toDouble() ?? 0.0;
          p['placeData']['type'] =
              alt['properties']?['type'] ??
              p['placeData']['type'] ??
              'souvenir';
          p['placeData']['price_level'] =
              alt['properties']?['price_level'] ??
              p['placeData']['price_level'];
          p['placeData']['kind'] =
              alt['properties']?['kind'] ?? p['placeData']['kind'];
          break;
        }
      }

      // 🔎 important: clear leftover preview pins for this slot
      _clearAltPinsFor(day: day, index: index);
    });

    _hardRefreshMap();
    _hardRefreshItinerary();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Updated souvenir stop #$index on Day ${day + 1}.',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _brandDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showAltRestaurantSheet({
    required int day,
    required int index,
    required Map<String, dynamic> alt,
  }) {
    final name = alt['properties']?['name'] ?? 'Unnamed';
    final addr = alt['properties']?['address'];
    final rating = (alt['properties']?['rating'] as num?)?.toDouble();
    final distKm = (alt['distanceFromStop'] as num?)?.toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => Container(
            margin: const EdgeInsets.only(top: 60),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange,
                                    Colors.orange.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.restaurant,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: _brandDark,
                                    ),
                                  ),
                                  if (addr != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      addr.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (rating != null && rating > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.amber[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (distKm != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _brand.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _brand.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: _brandDark,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${distKm.toStringAsFixed(2)} km from current stop",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: _brandDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey[300]!),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.swap_horiz, size: 18),
                                label: Text(
                                  'Replace this meal',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _replaceRestaurantStop(
                                    day: day,
                                    index: index,
                                    alt: alt,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
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
          ).animate().slideY(
            begin: 1,
            duration: const Duration(milliseconds: 300),
          ),
    );
  }

  void _showAltShopSheet({
    required int day,
    required int index,
    required Map<String, dynamic> alt,
  }) {
    final name = alt['properties']?['name'] ?? 'Unnamed';
    final addr = alt['properties']?['address'];
    final rating = (alt['properties']?['rating'] as num?)?.toDouble();
    final distKm = (alt['distanceFromStop'] as num?)?.toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => Container(
            margin: const EdgeInsets.only(top: 60),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple,
                                    Colors.purple.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.shopping_bag,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: _brandDark,
                                    ),
                                  ),
                                  if (addr != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      addr.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (rating != null && rating > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.amber[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (distKm != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _brand.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _brand.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: _brandDark,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${distKm.toStringAsFixed(2)} km from current stop",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: _brandDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey[300]!),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.swap_horiz, size: 18),
                                label: Text(
                                  'Replace this shop',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _replaceSouvenirStop(
                                    day: day,
                                    index: index,
                                    alt: alt,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
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
          ).animate().slideY(
            begin: 1,
            duration: const Duration(milliseconds: 300),
          ),
    );
  }

  void _showAltAttractionSheet({
    required int day,
    required int index,
    required Map<String, dynamic> alt,
  }) {
    final name = alt['properties']?['name'] ?? 'Unnamed';
    final addr = alt['properties']?['address'];
    final rating = (alt['properties']?['rating'] as num?)?.toDouble();
    final distKm = (alt['distanceFromStop'] as num?)?.toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => Container(
            margin: const EdgeInsets.only(top: 60),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red,
                                    Colors.red.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.place,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: _brandDark,
                                    ),
                                  ),
                                  if (addr != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      addr.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (rating != null && rating > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.amber[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (distKm != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _brand.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _brand.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: _brandDark,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${distKm.toStringAsFixed(2)} km from current stop",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: _brandDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey[300]!),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.swap_horiz, size: 18),
                                label: Text(
                                  'Replace this stop',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _replaceAttractionStop(
                                    day: day,
                                    index: index,
                                    alt: alt,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
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
          ).animate().slideY(
            begin: 1,
            duration: const Duration(milliseconds: 300),
          ),
    );
  }

  List<Map<String, dynamic>> tripPicks = [];
  final int targetAttractionsPerDay = 5;

  Map<String, double> newUserPrefs = {
    'Beach': 5.0,
    'City': 5.0,
    'Nature': 5.0,
    'History': 5.0,
  };
  Map<String, Map<String, double>> userPicks = {};
  Map<String, Map<String, double>> userPrefs = {};
  // New budget field and controller
  double? budget;
  final TextEditingController _budgetController = TextEditingController();

  List<String> selectedAreas = [];
  final List<String> penangAreas = [
    'George Town',
    'Tanjung Bungah',
    'Batu Ferringhi', // ← added
    'Bayan Lepas',
    'Balik Pulau',
    'Tanjung Tokong',
    'Butterworth',
  ];

  Map<String, Map<String, double>> userAreaPicks = {};
  bool _isLoading = true;

  // Define areaProfiles
  final Map<String, Map<String, double>> areaProfiles = {
    'George Town': {'City': 9.0, 'History': 9.0, 'Beach': 2.0, 'Nature': 4.0},
    'Tanjung Bungah': {
      'Beach': 8.0,
      'Nature': 5.0,
      'City': 4.0,
      'History': 3.0,
    },
    'Butterworth': {'City': 6.0, 'Nature': 4.0, 'Beach': 2.0, 'History': 4.0},
    'Bayan Lepas': {'City': 7.0, 'Nature': 4.0, 'Beach': 3.0, 'History': 3.0},
    'Tanjung Tokong': {
      'Beach': 7.0,
      'City': 6.0,
      'Nature': 3.0,
      'History': 3.0,
    },
    'Batu Ferringhi': {
      'Beach': 9.0,
      'Nature': 6.0,
      'City': 3.0,
      'History': 2.0,
    },
    'Balik Pulau': {'Nature': 8.0, 'History': 4.0, 'Beach': 2.0, 'City': 2.0},
  };

  Map<String, dynamic>? referenceHotel;
  bool showAlternateHotelPins = false;
  bool showAlternateAttractions = false;
  Map<String, dynamic>? selectedHotelOnMap;
  String _stopKey(int day, int index) => 'd${day}_i$index';

  @override
  void initState() {
    super.initState();
    final stopwatch = Stopwatch()..start();
    _loadAllUserData().then((_) {
      if (mounted) {
        print("⏱ Data loaded in ${stopwatch.elapsedMilliseconds}ms");
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _savePreferences() async {
    try {
      print("🔄 Starting to save preferences: $newUserPrefs");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({'preferences': newUserPrefs}, SetOptions(merge: true));
      print("✅ Preferences saved to Firebase successfully");
    } catch (e) {
      print("❌ Error in _savePreferences: $e");
      rethrow; // Re-throw to handle in the calling function
    }
  }

  Future<void> _loadAllUserData() async {
    bool _preferenceLoaded = false;
    bool hasAreaPicks = false;

    // 🔐 AUTH + wiring snapshot
    final cur = FirebaseAuth.instance.currentUser;
    print(
      "🔐[DEBUG] AUTH | currentUser.uid=${cur?.uid} | isAnon=${cur?.isAnonymous} | email=${cur?.email}",
    );
    print("🧭[DEBUG] widget.userId=${widget.userId}");
    print(
      "🐛[DEBUG] enter _loadAllUserData | field._preferenceLoaded=${this._preferenceLoaded} | local._preferenceLoaded=$_preferenceLoaded",
    );

    try {
      // ========= READ #1: own areaPicks =========
      print("📥[READ#1] GET users/${widget.userId}/areaPicks");
      QuerySnapshot<Map<String, dynamic>> areaPicks;
      try {
        areaPicks =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .collection('areaPicks')
                .get();
        print(
          "✅[READ#1] OK | count=${areaPicks.docs.length} | ids=${areaPicks.docs.map((d) => d.id).toList()}",
        );
      } catch (e) {
        print("❌[READ#1] FAIL users/${widget.userId}/areaPicks -> $e");
        rethrow; // preserve behavior
      }

      hasAreaPicks = areaPicks.docs.isNotEmpty;
      print("🔎 hasAreaPicks = $hasAreaPicks");

      userAreaPicks[widget.userId] = {
        for (var doc in areaPicks.docs)
          doc.id: (doc.data()['days'] as num?)?.toDouble() ?? 0.0,
      };
      print(
        "🐛[DEBUG] userAreaPicks[${widget.userId}] => ${userAreaPicks[widget.userId]}",
      );

      // ========= READ #1b: own picks under each area =========
      userPicks[widget.userId] = {};
      for (var areaDoc in areaPicks.docs) {
        final area = areaDoc.id;
        print("📥[READ#1b] GET users/${widget.userId}/areaPicks/$area/picks");
        try {
          final picks =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('areaPicks')
                  .doc(area)
                  .collection('picks')
                  .get();
          for (var doc in picks.docs) {
            userPicks[widget.userId]![doc.id] =
                (doc.data()['days'] as num?)?.toDouble() ?? 0.0;
          }
          print(
            "✅[READ#1b] OK | area=$area | picks.count=${picks.docs.length}",
          );
        } catch (e) {
          print(
            "❌[READ#1b] FAIL users/${widget.userId}/areaPicks/$area/picks -> $e",
          );
          rethrow; // preserve behavior
        }
      }

      // ========= READ #2: own preferences doc =========
      print("📥[READ#2] GET users/${widget.userId}");
      DocumentSnapshot<Map<String, dynamic>> prefsDoc;
      try {
        prefsDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .get();
        print(
          "✅[READ#2] OK | exists=${prefsDoc.exists} | keys=${prefsDoc.data()?.keys.toList()}",
        );
      } catch (e) {
        print("❌[READ#2] FAIL users/${widget.userId} -> $e");
        rethrow; // preserve behavior
      }

      final rawPrefs = prefsDoc.data()?['preferences'];
      print(
        "🐛[DEBUG] raw preferences type=${rawPrefs.runtimeType} | value=$rawPrefs",
      );

      if (prefsDoc.exists && rawPrefs != null) {
        try {
          newUserPrefs = Map<String, double>.from(rawPrefs);
          _preferenceLoaded = true;
        } catch (e) {
          print("❌[READ#2] preferences type cast failed -> $e | raw=$rawPrefs");
          rethrow; // keep behavior
        }
      }
      print("🔎 _preferenceLoaded = $_preferenceLoaded");

      // ========= READ #3: list all users (other users) =========
      print("📥[READ#3] LIST users/* (may be blocked by rules)");
      QuerySnapshot<Map<String, dynamic>> allUsers;
      try {
        allUsers = await FirebaseFirestore.instance.collection('users').get();
        print("✅[READ#3] OK | totalUsers=${allUsers.docs.length}");
      } catch (e) {
        print("❌[READ#3] FAIL users/* list -> $e");
        rethrow; // preserve behavior identical to your original big try
      }

      // Process other users
      for (var userDoc in allUsers.docs) {
        final userId = userDoc.id;
        if (userId == widget.userId) continue;

        try {
          final prefs = userDoc.data()['preferences'];
          if (prefs != null) {
            userPrefs[userId] = Map<String, double>.from(prefs);
          }

          print("📥[READ#3a] GET users/$userId/areaPicks");
          final otherAreaPicks =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('areaPicks')
                  .get();
          userAreaPicks[userId] = {
            for (var doc in otherAreaPicks.docs)
              doc.id: (doc.data()['days'] as num?)?.toDouble() ?? 0.0,
          };

          userPicks[userId] = {};
          for (var areaDoc in otherAreaPicks.docs) {
            final area = areaDoc.id;
            print("📥[READ#3b] GET users/$userId/areaPicks/$area/picks");
            final picks =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('areaPicks')
                    .doc(area)
                    .collection('picks')
                    .get();
            for (var doc in picks.docs) {
              userPicks[userId]![doc.id] =
                  (doc.data()['days'] as num?)?.toDouble() ?? 0.0;
            }
          }
        } catch (e) {
          print("⚠️ Failed to load other user $userId data: $e");
        }
      }
    } catch (e) {
      print("🚨 Error loading your own user data (bubbled): $e");
      logger.e("Error loading your own user data: $e");
    }

    // Final decision logging
    print(
      "🔎 Final Decision -> _preferenceLoaded=$_preferenceLoaded | hasAreaPicks=$hasAreaPicks",
    );
    if (!_preferenceLoaded && !hasAreaPicks) {
      print(
        "🛑 Asking for preferences because no areaPicks and no preferences!",
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _askPreferences());
    } else {
      print("✅ No need to ask preferences (already loaded something)");
    }
  }

  Future<void> _saveAreaPick(String area, int days) async {
    setState(() {
      userAreaPicks[widget.userId] ??= {};
      userAreaPicks[widget.userId]![area] = days.toDouble();
      // Remove areas with 0 days to keep userAreaPicks clean
      if (days == 0) {
        userAreaPicks[widget.userId]!.remove(area);
      }
    });
    print("📍 Updated local areaPick: $area, $days days");
  }

  Future<List<Map<String, dynamic>>> _loadPlacesFromFirebase(
    List<String> areas,
  ) async {
    List<Map<String, dynamic>> places = [];
    List<String> normalizedAreas =
        areas.map((area) {
          if (area.toLowerCase() == 'georgetown') return 'George Town';
          return area;
        }).toList();

    try {
      for (String area in normalizedAreas) {
        var placesQuery =
            await FirebaseFirestore.instance
                .collection('areas')
                .doc(area)
                .collection('places')
                .get();
        print(
          "🔍 Places query for $area returned ${placesQuery.docs.length} documents",
        );
        placesQuery.docs.forEach((doc) {
          print(
            " - ${doc.id}: ${doc.data()['name']}, category=${doc.data()['category']}",
          );
        });

        places.addAll(
          placesQuery.docs.map((doc) {
            var data = doc.data();
            return {
              'properties': {
                'name': data['name'] ?? 'Unknown',
                'area': area,
                'placeId': doc.id,
                'category': data['category'] ?? '',
                'price_level': data['price_level'] ?? 3,
                'estimated_cost':
                    data['category'] == 'accommodation'
                        ? (data['roomTypes']?['single']?['price']?.toDouble() ??
                            400.0)
                        : (data['price_level'] == 1
                            ? 100.0
                            : data['price_level'] == 2
                            ? 175.0
                            : 400.0),
                'rating': data['rating']?.toDouble() ?? 0.0,
                'address': data['address'] ?? '',
                'user_ratings_total': data['rating'] != null ? 100 : 0,
                'type': data['type'] ?? 'unknown',
                'isOutdoor': data['isOutdoor'] ?? false,
                'hours': data['open_hours'],
                'checkInTime': data['checkInTime'],
                'checkOutTime': data['checkOutTime'],
                // Fix: Properly extract nested maps
                'roomTypes':
                    data['roomTypes'] is Map
                        ? Map<String, dynamic>.from(data['roomTypes'])
                        : null,
                'travelersNo':
                    data['travelersNo'] is Map
                        ? Map<String, dynamic>.from(data['travelersNo'])
                        : null,
                'emptyRoomsByDate':
                    data['emptyRoomsByDate'] is Map
                        ? Map<String, dynamic>.from(data['emptyRoomsByDate'])
                        : null,
              },
              'geometry': {
                'coordinates': [
                  data['coordinates']?.longitude ?? 100.34,
                  data['coordinates']?.latitude ?? 5.42,
                ],
              },
            };
          }),
        );
      }
    } catch (e) {
      print("🚨 Error loading places: $e");
      logger.e("Error loading places: $e");
    }
    print("📍 Loaded ${places.length} places for areas: $normalizedAreas");
    return places;
  }

  List<Map<String, dynamic>> _filterAttractionsByWeather(
    List<Map<String, dynamic>> attractions,
    String weatherCondition,
  ) {
    final weather = weatherCondition.toLowerCase();
    final isRainy =
        weather.contains('rain') ||
        weather.contains('shower') ||
        weather.contains('drizzle') ||
        weather.contains('storm');

    if (!isRainy) {
      // Good weather: return all attractions (indoor + outdoor)
      return attractions;
    }

    // Rainy weather: prioritize indoor attractions
    final indoorAttractions =
        attractions
            .where((place) => !(place['properties']['isOutdoor'] ?? false))
            .toList();

    final outdoorAttractions =
        attractions
            .where((place) => place['properties']['isOutdoor'] ?? false)
            .toList();

    // Strategy: Use indoor attractions first, then add some outdoor if needed
    List<Map<String, dynamic>> filteredAttractions = List.from(
      indoorAttractions,
    );

    // If we don't have enough indoor attractions, carefully add some outdoor ones
    if (filteredAttractions.length < targetAttractionsPerDay) {
      final needMore = targetAttractionsPerDay - filteredAttractions.length;
      final selectedOutdoor = outdoorAttractions.take(needMore).toList();
      filteredAttractions.addAll(selectedOutdoor);
    }

    debugPrint(
      '🌦️ Weather filter for "$weatherCondition": ${indoorAttractions.length} indoor, '
      '${outdoorAttractions.length} outdoor → selected ${filteredAttractions.length} total',
    );

    return filteredAttractions;
  }

  Future<void> _openPlaceDetailsSheetByIds({
    required int day,
    required int index, // 0 = hotel, >=1 = attractions
    required String name,
    required LatLng latLng,
  }) async {
    final bool isHotel = index == 0;
    final String tapName =
        name.replaceFirst(RegExp(r'^(Meal|Souvenir):\s*'), '').trim();

    Map<String, dynamic>? tapped;

    // Find the tapped place
    const hotelCats = {'hotel', 'accommodation', 'lodging', 'stay'};
    const nonHotelCats = {
      'attraction',
      'restaurant',
      'souvenir',
      'shop',
      'cafe',
      'food',
    };

    double bestScore = -1;

    for (final pDyn in _allPlaces) {
      final p = (pDyn is Map) ? pDyn.cast<String, dynamic>() : null;
      if (p == null) continue;

      final props =
          (p['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
      final cat = (props['category'] ?? '').toString().toLowerCase();

      if (isHotel) {
        if (cat.isNotEmpty && !hotelCats.contains(cat)) continue;
      } else {
        if (cat.isNotEmpty && !nonHotelCats.contains(cat)) {}
      }

      final loc = _latLngOf(p);
      if (loc == null) continue;

      final d = _calculateDistance(latLng, loc);
      if (d > kOverlapKm) continue;

      Set<String> words(dynamic v) =>
          v == null
              ? <String>{}
              : _normStr(
                v.toString(),
              ).split(' ').where((w) => w.isNotEmpty).toSet();

      final t = words(tapName);
      final s = words(props['name']);

      double score = t.intersection(s).length.toDouble();

      if (!isHotel) {
        if (name.startsWith('Meal:')) {
          if (cat == 'restaurant' || cat == 'cafe' || cat == 'food')
            score += 0.5;
        } else if (name.startsWith('Souvenir:')) {
          if (cat == 'souvenir' || cat == 'shop' || cat == 'shopping')
            score += 0.5;
        } else {
          if (cat == 'attraction') score += 0.25;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        tapped = p;
      }
    }

    if (tapped == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.error_outline, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isHotel
                      ? 'Could not find this hotel in cache.'
                      : 'Could not find this place in cache.',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final propsDyn = tapped['properties'];
    final props =
        (propsDyn is Map)
            ? propsDyn.cast<String, dynamic>()
            : const <String, dynamic>{};

    String? areaId = (props['areaId'] as String?) ?? (props['area'] as String?);
    String? placeId =
        (props['placeId'] as String?) ??
        (props['place_id'] as String?) ??
        (tapped['id'] as String?) ??
        _keyForPlace(tapped);

    if ((placeId == null || placeId.isEmpty) && areaId != null) {
      final candidateName = (props['name'] ?? name).toString();
      try {
        final q =
            await FirebaseFirestore.instance
                .collection('areas')
                .doc(areaId)
                .collection('places')
                .where('name', isEqualTo: candidateName)
                .limit(1)
                .get();
        if (q.docs.isNotEmpty) placeId = q.docs.first.id;
      } catch (_) {
        /* ignore */
      }
    }

    if (areaId == null || placeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.error_outline, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isHotel
                      ? 'Missing areaId/placeId for this hotel.'
                      : 'Missing areaId/placeId for this place.',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    List<Map<String, dynamic>>? altHotels;
    if (isHotel) {
      double? refPrice;
      if (selectedHotel is Map) {
        final m = (selectedHotel as Map).cast<String, dynamic>();
        final sp =
            (m['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
        final v =
            sp['price'] ??
            sp['nightly'] ??
            sp['minPrice'] ??
            sp['avgPrice'] ??
            sp['pricePerNight'];
        if (v is num) refPrice = v.toDouble();
        if (v is String) {
          final mm = RegExp(r'[\d.]+').firstMatch(v);
          if (mm != null) refPrice = double.tryParse(mm.group(0)!);
        }
      }

      List<Map<String, dynamic>> base =
          alternateHotels.isNotEmpty
              ? List<Map<String, dynamic>>.from(alternateHotels)
              : <Map<String, dynamic>>[];

      if (base.isEmpty) {
        const hotelCats = {'hotel', 'accommodation', 'lodging', 'stay'};

        for (final pDyn in _allPlaces) {
          final p = (pDyn is Map) ? pDyn.cast<String, dynamic>() : null;
          if (p == null) continue;

          final pr =
              (p['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
          final cat = (pr['category'] ?? '').toString().toLowerCase();
          if (cat.isNotEmpty && !hotelCats.contains(cat)) continue;

          final coords = p['geometry']?['coordinates'];
          if (coords is! List || coords.length < 2) {
            debugPrint('⚠️ Invalid coordinates for hotel candidate: $p');
            continue;
          }

          final lon = (coords[0] as num?)?.toDouble();
          final lat = (coords[1] as num?)?.toDouble();
          if (lat == null || lon == null) {
            debugPrint('⚠️ Missing lat/lon for hotel candidate: $p');
            continue;
          }

          final pos = LatLng(lat, lon);
          final dKm = _calculateDistance(latLng, pos);
          if (dKm > 2.0) continue;

          final pid = (pr['placeId'] as String?) ?? (p['id'] as String?);
          if (pid != null && pid == placeId) continue;

          bool priceOk = true;
          if (refPrice != null) {
            double? price;
            final vv =
                pr['price'] ??
                pr['nightly'] ??
                pr['minPrice'] ??
                pr['avgPrice'] ??
                pr['pricePerNight'];
            if (vv is num) price = vv.toDouble();
            if (vv is String) {
              final mm = RegExp(r'[\d.]+').firstMatch(vv);
              if (mm != null) price = double.tryParse(mm.group(0)!);
            }
            priceOk =
                (price != null) &&
                price >= refPrice * 0.80 &&
                price <= refPrice * 1.25;
          }
          if (!priceOk) continue;

          final copy = Map<String, dynamic>.from(p);
          copy['distanceFromAnchor'] = dKm;
          base.add(copy);
        }

        base.sort(
          (a, b) => ((a['distanceFromAnchor'] as num?) ?? 1e9).compareTo(
            (b['distanceFromAnchor'] as num?) ?? 1e9,
          ),
        );
        base = base.take(12).toList();
      }

      altHotels =
          base.isNotEmpty
              ? base
              : null; // Set to null if empty to avoid unnecessary calls
      debugPrint(
        '🏨 [alt-hotels] computed=${altHotels?.length ?? 0}, sample: ${altHotels?.firstOrNull?['properties']?['name'] ?? 'N/A'}',
      );
    }

    await pds.PlaceDetailsSheet.show(
      context,
      areaId: areaId,
      placeId: placeId,
      radiusKm: 2.0,
      onSelectAlternate: (alt) {
        Navigator.of(context).pop();
        final cat =
            (alt['properties']?['category'] ?? '').toString().toLowerCase();
        if (cat == 'restaurant' || cat == 'food' || cat == 'cafe') {
          _replaceRestaurantStop(day: day, index: index, alt: alt);
        } else if (cat == 'souvenir' || cat == 'shop' || cat == 'store') {
          _replaceSouvenirStop(day: day, index: index, alt: alt);
        } else {
          _replaceAttractionStop(day: day, index: index, alt: alt);
        }
      },
      prefetchedAlternateHotels: altHotels,
      onPreviewAlternateHotels: (list) {
        debugPrint('🏨 Previewing ${list.length} alternate hotels');
        setState(() {
          alternateHotels = list;
          showAlternateHotelPins = true;
        });
        _hardRefreshMap();
      },
      onPreviewAlternateRestaurants:
          (list) => _previewAlternateRestaurantsForStop(
            day: day,
            index: index,
            list: list,
          ),
      onPreviewAlternateShops:
          (list) =>
              _previewAlternateShopsForStop(day: day, index: index, list: list),
      onClose: () {
        final stopKey = _stopKey(day, index);
        setState(() {
          alternateRestaurantsByStop.remove(stopKey);
          alternateShopsByStop.remove(stopKey);
          showAlternateRestaurants = alternateRestaurantsByStop.isNotEmpty;
          showAlternateShops = alternateShopsByStop.isNotEmpty;
        });
        _hardRefreshMap();
      },
    );
  }

  void _previewAlternateShopsForStop({
    required int day,
    required int index,
    required List<Map<String, dynamic>> list,
  }) {
    LatLng? anchor;
    if (day < dailyPoints.length && index < dailyPoints[day].length) {
      anchor = dailyPoints[day][index];
    }

    final key = _stopKey(day, index);
    final sanitized = <Map<String, dynamic>>[];

    for (final p in list) {
      try {
        final coords = p['geometry']?['coordinates'];
        if (coords is! List || coords.length < 2) continue;

        final lon = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        double dKm = 0.0;
        if (anchor != null) {
          dKm = _calculateDistance(anchor, LatLng(lat, lon));
        }

        final copy = Map<String, dynamic>.from(p);
        copy['distanceFromStop'] = dKm;
        sanitized.add(copy);
      } catch (_) {
        /* ignore bad rows */
      }
    }

    setState(() {
      alternateShopsByStop[key] = sanitized;
      showAlternateShops = true;
    });

    debugPrint(
      '🛍️ [preview-shops] day=${day + 1} idx=$index → ${sanitized.length} alts',
    );
    _hardRefreshMap();
  }

  Map<String, double> _getAreaSuggestions() {
    Map<String, double> areaScores = {};
    Map<String, double> cbfScores = {};
    Map<String, double> cfScores = {};
    Map<String, double> cfWeights = {};

    const double maxPossibleScore = 8.0 * 8.0 * 4;

    print("📌 Starting Area Suggestion Calculation...");
    print("🔷 Step 1: Content-Based Filtering (CBF)");

    // Step 1: CBF Calculation
    for (var area in penangAreas) {
      var profile = areaProfiles[area] ?? {'Nature': 5.0};
      double rawScore = profile.entries
          .map((e) => (newUserPrefs[e.key] ?? 5.0) * e.value)
          .reduce((a, b) => a + b);
      double cbfScore = (rawScore / maxPossibleScore) * 10;
      cbfScores[area] = cbfScore.clamp(0, 10);

      print(
        "   🧠 $area CBF raw: ${rawScore.toStringAsFixed(2)} → normalized: ${cbfScores[area]!.toStringAsFixed(2)}",
      );
    }

    print("🔷 Step 2: Collaborative Filtering (CF)");

    // Step 2: CF Calculation
    userAreaPicks.forEach((otherId, otherAreaData) {
      if (otherId == widget.userId) return;
      if (userPrefs[otherId] == null) return;

      double similarity = _compareUsers(newUserPrefs, userPrefs[otherId]!);
      print(
        "👥 Comparing with user $otherId → similarity: ${similarity.toStringAsFixed(2)}",
      );

      if (similarity < 0.5) {
        print("   ⚠️ Skipped (similarity too low)");
        return;
      }

      for (var area in penangAreas) {
        double pickedDays = otherAreaData[area] ?? 0;
        if (pickedDays > 0) {
          cfScores[area] = (cfScores[area] ?? 0) + similarity * pickedDays;
          cfWeights[area] = (cfWeights[area] ?? 0) + similarity.abs();

          print(
            "   ✅ $otherId → $area: picked $pickedDays days → CF[$area] += ${similarity.toStringAsFixed(2)} × $pickedDays",
          );
        }
      }
    });

    print("🔷 Step 3: Combine CBF + CF into Final Hybrid Scores");

    // Step 3: Combine
    for (var area in penangAreas) {
      double cbf = cbfScores[area] ?? 0;

      if ((cfWeights[area] ?? 0) > 0) {
        double cf = (cfScores[area]! / cfWeights[area]!).clamp(0, 10);
        areaScores[area] = (0.7 * cf + 0.3 * cbf).clamp(0, 10);
      } else {
        areaScores[area] = (0.5 * cbf).clamp(0, 10); // Penalize unseen areas
      }
    }

    print("📊 Final Area Scores Breakdown:");
    penangAreas.forEach((area) {
      double cbf = cbfScores[area] ?? 0.0;
      double cfScore = cfScores[area] ?? 0.0;
      double cfWeight = cfWeights[area] ?? 0.0;
      double cf = cfWeight > 0 ? (cfScore / cfWeight).clamp(0, 10) : 0;
      double finalScore = areaScores[area]!;

      print(
        '📍 $area → CBF: ${cbf.toStringAsFixed(2)}, CF: ${cf.toStringAsFixed(2)}, Final: ${finalScore.toStringAsFixed(2)}',
      );
    });

    // Log ranked list
    final sorted =
        areaScores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    print("🏆 Area Suggestion Ranking:");
    for (var entry in sorted) {
      print("   ${entry.key}: ${entry.value.toStringAsFixed(2)}");
    }

    return areaScores;
  }

  Map<String, double> _getPickSuggestions(
    List<Map<String, dynamic>> places,
    String weatherCondition,
  ) {
    Map<String, double> scores = {};

    // Weather-based adjustment factors
    final weatherAdjustments = {
      'rain': {
        'Nature': 0.3,
        'Beach': 0.2,
        'History': 1.3,
        'City': 1.1,
        'Food': 1.1,
        'Accommodation': 1.0,
      },
      'moderate rain': {
        'Nature': 0.2,
        'Beach': 0.1,
        'History': 1.4,
        'City': 1.1,
        'Food': 1.2,
        'Accommodation': 1.0,
      },
      'sunny': {
        'Nature': 1.4,
        'Beach': 1.6,
        'History': 0.9,
        'City': 1.0,
        'Food': 1.0,
        'Accommodation': 1.0,
      },
      'cloudy': {
        'Nature': 1.0,
        'Beach': 0.8,
        'History': 1.0,
        'City': 1.0,
        'Food': 1.0,
        'Accommodation': 1.0,
      },
    };

    final adjustments =
        weatherAdjustments[weatherCondition.toLowerCase()] ?? {};
    final isRainy =
        weatherCondition.toLowerCase().contains('rain') ||
        weatherCondition.toLowerCase().contains('shower') ||
        weatherCondition.toLowerCase().contains('drizzle');

    for (var place in places) {
      String category = _categorizePlace(place);
      double baseScore = newUserPrefs[category] ?? 5.0;
      double weatherFactor = adjustments[category] ?? 1.0;

      // Add indoor/outdoor weather bonus/penalty
      final isOutdoor = place['properties']['isOutdoor'] ?? false;
      double indoorOutdoorFactor = 1.0;

      if (isRainy) {
        // Rainy weather: boost indoor places, penalize outdoor
        indoorOutdoorFactor = isOutdoor ? 0.4 : 1.3;
      } else {
        // Good weather: slight boost for outdoor places
        indoorOutdoorFactor = isOutdoor ? 1.2 : 1.0;
      }

      double finalScore = baseScore * weatherFactor * indoorOutdoorFactor;
      scores[place['properties']['name']] = finalScore;

      debugPrint(
        "🌦️ ${place['properties']['name']} | Category: $category | "
        "${isOutdoor ? 'Outdoor' : 'Indoor'} | User Pref: $baseScore × "
        "Weather: $weatherFactor × Indoor/Outdoor: $indoorOutdoorFactor = "
        "${finalScore.toStringAsFixed(2)}",
      );
    }

    return scores;
  }

  void _askPreferences() async {
    final icons = {
      'City': Icons.location_city,
      'Beach': Icons.beach_access,
      'Nature': Icons.park,
      'History': Icons.account_balance,
    };

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          elevation: 8,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _brand.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.favorite_outline,
                  color: _brandDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select What You Like',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _brandDark,
                  ),
                ),
              ),
            ],
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              final filteredPrefs =
                  newUserPrefs.keys
                      .where(
                        (type) => type != 'Food' && type != 'Accommodation',
                      )
                      .toList();

              return SizedBox(
                width: double.maxFinite,
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: filteredPrefs.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 3 / 2,
                  ),
                  itemBuilder: (context, index) {
                    final type = filteredPrefs[index];
                    final isSelected = newUserPrefs[type]! > 7;

                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          newUserPrefs[type] = isSelected ? 5.0 : 8.0;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          gradient:
                              isSelected
                                  ? LinearGradient(
                                    colors: [
                                      _brand,
                                      _brandDark.withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                  : null,
                          color: isSelected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isSelected
                                    ? Colors.transparent
                                    : Colors.grey.shade300,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isSelected ? 0.15 : 0.05,
                              ),
                              blurRadius: isSelected ? 12 : 6,
                              offset: Offset(0, isSelected ? 6 : 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icons[type] ?? Icons.star,
                              size: 32,
                              color: isSelected ? Colors.white : _brandDark,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              type,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isSelected ? Colors.white : _brandDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: () async {
                print("🔘 Confirm button pressed");

                bool hasValidPreferences = newUserPrefs.entries.any(
                  (entry) =>
                      entry.key != 'Food' &&
                      entry.key != 'Accommodation' &&
                      entry.value > 7,
                );

                if (hasValidPreferences) {
                  try {
                    await _savePreferences();
                    print("✅ Preferences saved, about to close dialog...");

                    // Force close dialog with scheduleMicrotask
                    scheduleMicrotask(() {
                      if (Navigator.of(dialogContext).canPop()) {
                        Navigator.of(dialogContext).pop(true);
                        print("✅ Dialog closed via scheduleMicrotask");
                      }
                    });
                  } catch (e) {
                    print("❌ Error saving preferences: $e");
                  }
                } else {
                  // Show snackbar but don't close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.warning_amber_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Please select at least one preference before continuing!',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: _brandDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Confirm',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    // Handle result after dialog closes
    if (result == true && mounted) {
      setState(() {
        messages.add(
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "AI: Preferences saved! Let's plan your trip.",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      });
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double R = 6371;
    final lat1 = point1.latitude * pi / 180;
    final lon1 = point1.longitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final lon2 = point2.longitude * pi / 180;
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<String> _getWeather(
    double lat,
    double lon,
    DateTime date,
    BuildContext context,
  ) async {
    const weatherApiKey = '6e9f5cea7f5047d7a9a83438252702';
    final daysAhead = date.difference(DateTime.now()).inDays + 1;

    // Handle past dates
    if (daysAhead < 1) {
      return "Date in the past.";
    }

    // Use WeatherAPI for 1-3 days
    if (daysAhead <= 3) {
      final weatherUrl =
          'http://api.weatherapi.com/v1/forecast.json?key=$weatherApiKey&q=$lat,$lon&days=$daysAhead&aqi=no&alerts=no';
      try {
        final response = await http.get(Uri.parse(weatherUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final forecastDay = data['forecast']['forecastday'][daysAhead - 1];

          // Pick noon condition
          String condition;
          final hours = (forecastDay['hour'] as List?) ?? [];
          if (hours.isNotEmpty) {
            Map<String, dynamic>? best;
            int bestDiff = 999;
            for (final h in hours) {
              final timeStr = h['time'] as String?;
              if (timeStr != null && timeStr.length >= 16) {
                final hh = int.tryParse(timeStr.substring(11, 13)) ?? 12;
                final diff = (hh - 12).abs();
                if (diff < bestDiff) {
                  bestDiff = diff;
                  best = Map<String, dynamic>.from(h as Map);
                }
              }
            }
            condition = (best?['condition']?['text'] ?? '').toString();
          } else {
            condition =
                (forecastDay['day']?['condition']?['text'] ?? '').toString();
          }

          _showRainReminder(condition, context);
          return condition;
        }
        return "unknown";
      } catch (e) {
        print('Weather Error: $e');
        return "unknown";
      }
    }
    // Use enhanced historical patterns for days 4+
    else {
      print('📊 Using enhanced historical patterns for day $daysAhead');

      final month = date.month;
      final dayOfMonth = date.day;

      // Generate weather using enhanced meteorological logic
      final condition = PenangWeatherData.generateWeatherCondition(
        month,
        dayOfMonth,
        enhancedLogic: true,
      );

      // Get additional context for user information
      final pattern = PenangWeatherData.seasonalPatterns[month]!;
      final monsoonType = pattern['monsoon'] as String;
      final season = pattern['season'] as String;

      print('📊 Generated condition: $condition');
      print(
        '📊 Context: ${_getMonsoonDescription(monsoonType)}, Season: $season',
      );

      // Show enhanced disclaimer with context
      _showEnhancedExtendedForecastDisclaimer(
        context,
        date,
        monsoonType,
        season,
      );

      // Show rain reminder if applicable
      _showRainReminder(condition, context);

      return condition;
    }
  }

  String _getMonsoonDescription(String monsoonType) {
    switch (monsoonType) {
      case 'northeast':
        return 'Northeast Monsoon (Nov-Mar)';
      case 'southwest':
        return 'Southwest Monsoon (May-Sep)';
      case 'inter_monsoon':
        return 'Inter-Monsoon Period';
      default:
        return 'Unknown Season';
    }
  }

  void _showRainReminder(String condition, BuildContext context) {
    final condLower = condition.toLowerCase();
    if (condLower.contains('rain') ||
        condLower.contains('shower') ||
        condLower.contains('drizzle') ||
        condLower.contains('storm')) {
      // Only show once per trip generation
      if (_hasShownRainReminder || !context.mounted) return;

      _hasShownRainReminder = true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.umbrella,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rain expected during your trip! Please bring along an umbrella.',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showEnhancedExtendedForecastDisclaimer(
    BuildContext context,
    DateTime date,
    String monsoonType,
    String season,
  ) {
    // Only show once per trip generation
    if (_hasShownExtendedForecastDisclaimer || !context.mounted) return;

    _hasShownExtendedForecastDisclaimer = true;

    final monsoonDesc = _getMonsoonDescription(monsoonType);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Date out of 3-day range. Weather forecast accuracy may vary.',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  bool _isOpenAt(Map<String, dynamic> place, DateTime when) {
    // Uses 'open_hours' map if available, else returns true (don’t block).
    final oh =
        (place['properties']?['open_hours'] as Map?)?.cast<String, String>();
    if (oh == null) return true;

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayLabel = weekdays[when.weekday - 1];
    final line = oh[dayLabel];
    if (line == null) return true;

    final lower = line.toLowerCase();
    if (lower.contains('closed')) return false;

    // Crude parse: "9:00 AM – 10:00 PM"
    final m = RegExp(
      r'(\d{1,2}):?(\d{2})?\s*(am|pm)\s*[–-]\s*(\d{1,2}):?(\d{2})?\s*(am|pm)',
      caseSensitive: false,
    ).firstMatch(line);
    if (m == null) return true; // don’t block if we can’t parse

    int h1 = int.parse(m.group(1)!);
    int min1 = int.tryParse(m.group(2) ?? '0') ?? 0;
    final p1 = (m.group(3) ?? '').toLowerCase();

    int h2 = int.parse(m.group(4)!);
    int min2 = int.tryParse(m.group(5) ?? '0') ?? 0;
    final p2 = (m.group(6) ?? '').toLowerCase();

    int to24(int h, String p) {
      h = h % 12;
      if (p == 'pm') h += 12;
      return h;
    }

    final start = DateTime(when.year, when.month, when.day, to24(h1, p1), min1);
    var end = DateTime(when.year, when.month, when.day, to24(h2, p2), min2);
    if (!end.isAfter(start)) {
      // crosses midnight → push end to next day
      end = end.add(const Duration(days: 1));
    }
    return !when.isBefore(start) && !when.isAfter(end);
  }

  Map<String, dynamic>? _pickNearestOpenPlace(
    List<Map<String, dynamic>> candidates,
    LatLng anchor,
    DateTime when,
    Set<String> alreadyChosen,
  ) {
    if (candidates.isEmpty) return null;

    // Score: prefer open at 'when', then distance, then rating
    double scoreFor(Map<String, dynamic> p) {
      final n = (p['properties']['name'] as String?) ?? '';
      if (alreadyChosen.contains(n)) return double.negativeInfinity;

      final coords = (p['geometry']?['coordinates'] as List?) ?? [];
      if (coords.length < 2) return double.negativeInfinity;

      final loc = LatLng(
        (coords[1] as num).toDouble(),
        (coords[0] as num).toDouble(),
      );
      final distKm = _calculateDistance(anchor, loc);
      final rating = (p['properties']['rating'] as num?)?.toDouble() ?? 0.0;
      final open = _isOpenAt(p, when);

      // Higher is better: open → +100, closer → smaller penalty, rating adds small boost
      return (open ? 100.0 : 0.0) - distKm * 5.0 + rating;
    }

    candidates.sort((a, b) => scoreFor(b).compareTo(scoreFor(a)));
    final best = candidates.first;
    final bestScore = scoreFor(best);
    return bestScore.isFinite ? best : null;
  }

  List<Map<String, dynamic>> getMealPlan(String plan, int targetRestaurants) {
    if (plan == 'Food-Heavy') {
      return [
        {'type': 'Breakfast', 'time': '10:00 AM'},
        {'type': 'Lunch', 'time': '1:00 PM'},
        {'type': 'Dinner', 'time': '7:00 PM'},
        {'type': 'Snack', 'time': '4:00 PM'},
        {'type': 'Snack', 'time': '6:00 PM'},
      ].take(targetRestaurants).toList();
    } else if (plan == 'Attraction-Seeker') {
      return [
        {'type': 'Breakfast', 'time': '8:00 AM'},
        {'type': 'Lunch', 'time': '12:00 PM'},
        {'type': 'Dinner', 'time': '6:00 PM'},
      ].take(targetRestaurants).toList();
    } else {
      return [
        {'type': 'Breakfast', 'time': '8:00 AM'},
        {'type': 'Lunch', 'time': '12:00 PM'},
        {'type': 'Dinner', 'time': '6:00 PM'},
      ].take(targetRestaurants).toList();
    }
  }

  double _compareUsers(Map<String, double> user1, Map<String, double> user2) {
    // Normalize keys to lowercase
    Map<String, double> normalizedUser1 = {
      for (var e in user1.entries) e.key.toLowerCase(): e.value,
    };
    Map<String, double> normalizedUser2 = {
      for (var e in user2.entries) e.key.toLowerCase(): e.value,
    };

    Set<String> allKeys = normalizedUser1.keys.toSet().union(
      normalizedUser2.keys.toSet(),
    );
    double dot = 0;
    double norm1 = 0;
    double norm2 = 0;

    for (var key in allKeys) {
      double v1 = normalizedUser1[key] ?? 0;
      double v2 = normalizedUser2[key] ?? 0;
      dot += v1 * v2;
      norm1 += v1 * v1;
      norm2 += v2 * v2;
    }

    if (norm1 == 0 || norm2 == 0) return 0;

    double similarity = dot / (sqrt(norm1) * sqrt(norm2));
    return similarity;
  }

  int _sumAreaDays(Map<String, dynamic>? m) {
    if (m == null) return 0;
    return m.values.whereType<num>().fold<int>(0, (s, v) => s + v.toInt());
  }

  int _deriveDaysFromDoc(Map<String, dynamic> data) {
    final int sum = _sumAreaDays(data['areaDays'] as Map<String, dynamic>?);

    int inclusive = 0;
    try {
      if (data['startDate'] != null && data['endDate'] != null) {
        final start = (data['startDate'] as Timestamp).toDate();
        final end = (data['endDate'] as Timestamp).toDate();
        inclusive = end.difference(start).inDays + 1; // ✅ inclusive
      }
    } catch (_) {}

    int days =
        (sum > 0 || inclusive > 0) ? (sum >= inclusive ? sum : inclusive) : 1;
    if (days <= 0) days = 1;
    return days;
  }

  /// Derive "my days" from UI state (prefer selections; else inclusive dates)
  int _deriveMyDays() {
    final int sum = selectedAreas.fold<int>(
      0,
      (s, a) => s + (userAreaPicks[widget.userId]?[a]?.toInt() ?? 0),
    );
    if (sum > 0) return sum;

    if (startDate != null && endDate != null) {
      final d = endDate!.difference(startDate!).inDays + 1; // ✅ inclusive
      if (d > 0) return d;
    }
    return 1;
  }

  String _categorizePlace(Map<String, dynamic> place) {
    final name = (place['properties']['name'] ?? '').toLowerCase();
    final category = (place['properties']['category'] ?? '').toLowerCase();
    final type = (place['properties']['type'] ?? '').toLowerCase();

    if (name.contains('beach') ||
        name.contains('sea') ||
        name.contains('ships')) {
      return 'Beach';
    }
    if (category == 'dining' ||
        name.contains('food court') ||
        name.contains('dining')) {
      return 'Food';
    }
    if (category == 'accommodation') {
      return 'Accommodation';
    }
    if (name.contains('museum') ||
        name.contains('temple') ||
        name.contains('heritage') ||
        name.contains('historic') ||
        name.contains('church') ||
        name.contains('gallery')) {
      return 'History';
    }
    if (name.contains('mall') ||
        name.contains('city') ||
        name.contains('george town') ||
        name.contains('night market') ||
        name.contains('komtar')) {
      return 'City';
    }
    if (name.contains('park') ||
        name.contains('garden') ||
        (category == 'attraction' && type == 'outdoor')) {
      return 'Nature';
    }
    return 'City';
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });

      // Validate immediately after setting dates
      _validateDateRange();
    }
  }

  Widget _buildHotelInfoSheet({
    required Map<String, dynamic> hotel,
    required String label,
    required Color color,
  }) {
    final name = hotel['properties']['name'] ?? 'Unnamed';
    final address = hotel['properties']['address'] ?? 'No address';
    final rating = hotel['properties']['rating']?.toStringAsFixed(1) ?? 'N/A';
    final price = hotel['roomPrice']?.toStringAsFixed(2) ?? 'Unknown';
    final roomType = hotel['selectedRoomType'] ?? 'N/A';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Icon(Icons.hotel, color: color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                label,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: _brandDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: _brandDark,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                address,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bed, color: Colors.blue, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    roomType,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "RM $price",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.amber[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rerouteForNewHotel(
    Map<String, dynamic> hotel, {
    bool closeSheet = false,
    bool reoptimizePerDay = false,
    String source = 'unknown',
  }) async {
    debugPrint(
      '🔄 [_rerouteForNewHotel] source=$source, picked=${hotel['properties']?['name']}',
    );

    final c = hotel['geometry']?['coordinates'];
    if (c is! List || c.length < 2) {
      debugPrint('❌ [_rerouteForNewHotel] invalid coordinates in hotel');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.error_outline, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Selected hotel has invalid coordinates',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (closeSheet) Navigator.of(context).pop();

    // Snapshot before
    final int daysCount = dailyPoints.length;
    final String? oldName = selectedHotel?['properties']?['name'];
    debugPrint(
      '📊 [before] days=$daysCount, selected=$oldName, ref=${referenceHotel?['properties']?['name']}',
    );
    if (daysCount > 0 && dailyPoints[0].isNotEmpty) {
      debugPrint(
        '📍 [before] day1 start=${dailyPoints[0][0].latitude},${dailyPoints[0][0].longitude}',
      );
    }

    // Prepare new values (no rebuild yet)
    final Map<String, dynamic>? oldSelected =
        (selectedHotel != null) ? jsonDecode(jsonEncode(selectedHotel!)) : null;
    final Map<String, dynamic> newSelected = jsonDecode(jsonEncode(hotel));

    final LatLng newStart = LatLng(
      (c[1] as num).toDouble(),
      (c[0] as num).toDouble(),
    );
    final String newName =
        (hotel['properties']?['name'] ?? 'Selected Hotel').toString();

    // Update routes in memory
    List<List<LatLng>> nextPts =
        dailyPoints.map((d) => List<LatLng>.from(d)).toList();
    List<List<String>> nextNms =
        dailyNames.map((d) => List<String>.from(d)).toList();

    for (int d = 0; d < nextPts.length; d++) {
      if (nextPts[d].isNotEmpty) nextPts[d][0] = newStart;
      if (nextNms[d].isNotEmpty) nextNms[d][0] = 'Start at: $newName';

      if (reoptimizePerDay && nextPts[d].length > 2) {
        final pts = nextPts[d];
        final nms = nextNms[d];
        final order = <int>[0];
        final remaining = List<int>.generate(pts.length - 1, (i) => i + 1);
        while (remaining.isNotEmpty) {
          final last = order.last;
          int bestIdx = 0;
          double best = double.infinity;
          for (int i = 0; i < remaining.length; i++) {
            final dist = _calculateDistance(pts[last], pts[remaining[i]]);
            if (dist < best) {
              best = dist;
              bestIdx = i;
            }
          }
          order.add(remaining.removeAt(bestIdx));
        }
        nextPts[d] = [for (final i in order) pts[i]];
        nextNms[d] = [for (final i in order) nms[i]];
      }
    }

    // Recompute alternates around NEW selected, exclude overlaps (<=50m)
    const double overlapKm = 0.05;
    List<Map<String, dynamic>> nextAlts = [];
    for (final h in suitableHotels) {
      final cc = h['geometry']?['coordinates'];
      if (cc is! List || cc.length < 2) continue;
      final LatLng loc = LatLng(
        (cc[1] as num).toDouble(),
        (cc[0] as num).toDouble(),
      );

      final bool isNewSelected = _calculateDistance(loc, newStart) < overlapKm;
      bool isOldSelected = false;
      if (oldSelected?['geometry']?['coordinates'] is List) {
        final oc = oldSelected!['geometry']['coordinates'] as List;
        final LatLng oldStart = LatLng(
          (oc[1] as num).toDouble(),
          (oc[0] as num).toDouble(),
        );
        isOldSelected = _calculateDistance(loc, oldStart) < overlapKm;
      }
      if (isNewSelected || isOldSelected) continue;

      final dist = _calculateDistance(newStart, loc);
      if (dist <= 2.0) {
        h['distanceFromSelected'] = dist;
        nextAlts.add(h);
      }
    }
    debugPrint('🧭 [alts] recomputed => ${nextAlts.length} items');

    // Update day-start entries in tripPicks (sequence == 0)
    final nextTripPicks = tripPicks.map((p) => p).toList();
    for (final pick in nextTripPicks) {
      if ((pick['sequence'] ?? -1) == 0) {
        pick['placeData'] ??= {};
        pick['placeData']['name'] = newName;
        pick['placeData']['address'] =
            newSelected['properties']?['address'] ??
            pick['placeData']['address'];
        pick['placeData']['selectedRoomType'] =
            newSelected['selectedRoomType'] ??
            pick['placeData']['selectedRoomType'];
        pick['placeData']['coordinates'] = {
          'lat': newStart.latitude,
          'lon': newStart.longitude,
        };
      }
    }
    if (nextPts.isNotEmpty) {
      final p0 = nextPts[0];
      debugPrint('🧩 [reroute] day1 len=${p0.length}');
      if (p0.isNotEmpty) {
        debugPrint(
          '🧩 [reroute] day1 start -> ${p0[0].latitude},${p0[0].longitude}',
        );
        if (p0.length > 1) {
          debugPrint(
            '🧩 [reroute] day1 next  -> ${p0[1].latitude},${p0[1].longitude}',
          );
        }
      }
    }

    // Commit everything at once
    setState(() {
      referenceHotel = oldSelected; // old red → purple
      selectedHotel = newSelected; // new red
      selectedRoomType = newSelected['selectedRoomType'] ?? selectedRoomType;

      dailyPoints = nextPts;
      dailyNames = nextNms;
      alternateHotels = nextAlts;
      previewHotelId = null;
      isRouting = false;
    });

    _recomputeAltAttractions();

    // After commit: center + hard refresh
    _mapController.move(newStart, 16);
    debugPrint('🔁 [refresh] replacing messages[_mapMsgIndex] with new map');
    _hardRefreshMap();
    _hardRefreshItinerary();

    // Snapshot after
    debugPrint(
      '✅ [after] selected=$newName, ref=${referenceHotel?['properties']?['name']}',
    );
    if (dailyPoints.isNotEmpty && dailyPoints[0].isNotEmpty) {
      debugPrint(
        '📍 [after] day1 start=${dailyPoints[0][0].latitude},${dailyPoints[0][0].longitude}',
      );
    }
    debugPrint(
      '🧩 [markers] keys bumped => mapKey=$mapWidgetKey, markersKey=$_markersKey',
    );
  }

  void _showAltHotelSelectSheet(Map<String, dynamic> hotel) {
    final name = hotel['properties']?['name'] ?? 'Unnamed';
    final addr = hotel['properties']?['address'];
    final rating = (hotel['properties']?['rating'] as num?)?.toDouble();
    final room = hotel['selectedRoomType'];
    final price = (hotel['roomPrice'] as num?)?.toDouble();

    double? distKm;
    try {
      if (selectedHotel != null &&
          selectedHotel!['geometry']?['coordinates'] is List &&
          hotel['geometry']?['coordinates'] is List) {
        final sc = selectedHotel!['geometry']['coordinates'] as List;
        final hc = hotel['geometry']['coordinates'] as List;
        final sel = LatLng(
          (sc[1] as num).toDouble(),
          (sc[0] as num).toDouble(),
        );
        final alt = LatLng(
          (hc[1] as num).toDouble(),
          (hc[0] as num).toDouble(),
        );
        distKm = _calculateDistance(sel, alt);
      }
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => Container(
            margin: const EdgeInsets.only(top: 60),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue,
                                    Colors.blue.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.hotel,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: _brandDark,
                                    ),
                                  ),
                                  if (addr != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      addr.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (rating != null && rating > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.amber[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (room != null || price != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bed,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${room ?? 'room'} • RM ${price?.toStringAsFixed(2) ?? '-'}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (distKm != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _brand.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _brand.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: _brandDark,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${distKm!.toStringAsFixed(2)} km from current hotel",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: _brandDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey[300]!),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.check, size: 18),
                                label: Text(
                                  'Select this hotel',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  _rerouteForNewHotel(
                                    hotel,
                                    closeSheet: true,
                                    source: 'alt-pin',
                                    reoptimizePerDay: true,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
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
          ).animate().slideY(
            begin: 1,
            duration: const Duration(milliseconds: 300),
          ),
    );
  }

  // Rebuildable map block (toggle + map). Call this whenever we need a fresh instance.
  Widget _buildMapMessage() {
    return StatefulBuilder(
      builder:
          (context, setStateSB) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle row
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text("Show Alternate Hotels"),
                  const Spacer(),
                  Switch(
                    value: showAlternateHotelPins,
                    onChanged: (value) {
                      debugPrint('🧰 [toggle] showAlternateHotelPins=$value');
                      setStateSB(() => showAlternateHotelPins = value);
                      // also update outer if anything else depends on it
                      setState(() {});
                    },
                  ),
                ],
              ),

              const SizedBox(height: 8),

              const SizedBox(height: 6),

              // The actual map (uses keys that we can bump on demand)
              _buildMapWidget(
                dailyPoints: dailyPoints,
                dailyNames: dailyNames,
                showAlternateHotels: showAlternateHotelPins,
              ),
            ],
          ),
    );
  }

  Widget _buildMapWidget({
    required List<List<LatLng>> dailyPoints,
    required List<List<String>> dailyNames,
    bool showAlternateHotels = false,
    bool showAlternateAttractions = false, // <-- add
  }) {
    // Debug logging for map rendering
    print("🗺️ Rendering map markers:");
    if (selectedHotel != null) {
      print(
        "🔴 Selected hotel: ${selectedHotel!['properties']['name']} @ ${selectedHotel!['geometry']['coordinates']}",
      );
    } else {
      print("🔴 No selected hotel.");
    }
    if (referenceHotel != null) {
      print(
        "🟣 Reference hotel: ${referenceHotel!['properties']['name']} @ ${referenceHotel!['geometry']['coordinates']}",
      );
    } else {
      print("🟣 No reference hotel.");
    }

    // --- helper: numbered pin widget ------------------------------------------
    Widget numberedPin({
      required String label, // "H", "1", "2", ...
      required Color color, // day color
      IconData? glyph, // e.g., Icons.hotel for hotel
      bool selected = false, // halo
    }) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.location_on, color: color, size: 34),
          Positioned(
            top: 4,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(blurRadius: 2, color: Colors.black12),
                ],
              ),
              child: FittedBox(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (glyph != null) ...[
                      Icon(glyph, size: 12, color: Colors.grey.shade800),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.0,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // Validate coordinates to prevent duplicates
    final selectedHotelCoords =
        selectedHotel != null &&
                selectedHotel!['geometry'] != null &&
                selectedHotel!['geometry']['coordinates'] != null &&
                (selectedHotel!['geometry']['coordinates'] as List).length >= 2
            ? LatLng(
              (selectedHotel!['geometry']['coordinates'][1] as num).toDouble(),
              (selectedHotel!['geometry']['coordinates'][0] as num).toDouble(),
            )
            : null;

    final referenceHotelCoords =
        referenceHotel != null &&
                referenceHotel!['geometry'] != null &&
                referenceHotel!['geometry']['coordinates'] != null &&
                (referenceHotel!['geometry']['coordinates'] as List).length >= 2
            ? LatLng(
              (referenceHotel!['geometry']['coordinates'][1] as num).toDouble(),
              (referenceHotel!['geometry']['coordinates'][0] as num).toDouble(),
            )
            : null;

    // Check if coordinates are the same to avoid duplicate pins
    bool isSameLocation =
        selectedHotelCoords != null &&
        referenceHotelCoords != null &&
        selectedHotelCoords.latitude.toStringAsFixed(6) ==
            referenceHotelCoords.latitude.toStringAsFixed(6) &&
        selectedHotelCoords.longitude.toStringAsFixed(6) ==
            referenceHotelCoords.longitude.toStringAsFixed(6);

    print("🔍 Is same location (selected vs reference): $isSameLocation");

    String mapKey =
        "selected:${selectedHotel?['geometry']['coordinates'].toString()}_ref:${referenceHotel?['geometry']['coordinates'].toString()}_toggle:${showAlternateHotels}_${DateTime.now().millisecondsSinceEpoch}";

    print("🔁 FlutterMap rebuilt with mapKey: $mapKey");

    print("🧷 Adding red marker at: $selectedHotelCoords");
    print("🧷 Adding purple marker at: $referenceHotelCoords");

    bool isSameName =
        selectedHotel != null &&
        referenceHotel != null &&
        selectedHotel?['properties']['name'] ==
            referenceHotel?['properties']['name'];

    print(
      "🌀 FULL REBUILD: selected=${selectedHotel?['properties']['name']}, reference=${referenceHotel?['properties']['name']}",
    );

    // Day color palette (used for lines + pins)
    final List<Color> dayColors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
    ];

    return FadeIn(
      duration: Duration(seconds: 1),
      child: Container(
        height: 300,
        child: Stack(
          children: [
            // Map takes full space
            FlutterMap(
              key: mapWidgetKey,
              mapController: _mapController,
              options: MapOptions(
                center:
                    dailyPoints.isNotEmpty && dailyPoints[0].isNotEmpty
                        ? dailyPoints[0][0]
                        : LatLng(5.42, 100.34),
                zoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=ALV6LKZZ0EkzYYOnnBuC',
                  subdomains: const ['a', 'b', 'c'],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: dailyPoints[0],
                      strokeWidth: 4.0,
                      color: dayColors[0 % dayColors.length],
                    ),
                    if (dailyPoints.length > 1)
                      Polyline(
                        points: dailyPoints[1],
                        strokeWidth: 4.0,
                        color: dayColors[1 % dayColors.length],
                      ),
                    if (dailyPoints.length > 2)
                      Polyline(
                        points: dailyPoints[2],
                        strokeWidth: 4.0,
                        color: dayColors[2 % dayColors.length],
                      ),
                  ],
                ),
                if (previewHotelId != null)
                  CircleLayer(
                    circles: [
                      for (final h in alternateHotels)
                        if ((h['properties']['name'] ?? '') == previewHotelId)
                          CircleMarker(
                            point: LatLng(
                              (h['geometry']['coordinates'][1] as num)
                                  .toDouble(),
                              (h['geometry']['coordinates'][0] as num)
                                  .toDouble(),
                            ),
                            radius: 40,
                            useRadiusInMeter: false,
                            color: Colors.blue.withOpacity(0.18),
                            borderStrokeWidth: 1.5,
                            borderColor: Colors.blue.withOpacity(0.35),
                          ),
                    ],
                  ),
                MarkerLayer(
                  key: _markersKey,
                  markers: [
                    // 1) ALTERNATE BLACK PINS FIRST (read-only)
                    if (showAlternateHotels)
                      ...alternateHotels
                          .map<Marker?>((hotel) {
                            final coords = hotel['geometry']?['coordinates'];
                            if (coords is! List || coords.length < 2)
                              return null;

                            final LatLng hotelCoords = LatLng(
                              (coords[1] as num).toDouble(),
                              (coords[0] as num).toDouble(),
                            );

                            const double overlapKm = 0.05;
                            final bool overlapsSelected =
                                selectedHotelCoords != null &&
                                _calculateDistance(
                                      hotelCoords,
                                      selectedHotelCoords!,
                                    ) <
                                    overlapKm;
                            final bool overlapsReference =
                                referenceHotelCoords != null &&
                                _calculateDistance(
                                      hotelCoords,
                                      referenceHotelCoords!,
                                    ) <
                                    overlapKm;
                            if (overlapsSelected || overlapsReference)
                              return null;

                            return Marker(
                              key: ValueKey(
                                "marker-alt-${hotel['properties']?['name']}",
                              ),
                              point: hotelCoords,
                              width: 30,
                              height: 30,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _showAltHotelSelectSheet(hotel),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.black87,
                                  size: 28,
                                ),
                              ),
                            );
                          })
                          .whereType<Marker>()
                          .toList(),

                    // 2) REFERENCE (PURPLE) — CLICKABLE
                    if (referenceHotel != null &&
                        referenceHotelCoords != null &&
                        (!isSameLocation || !isSameName))
                      Marker(
                        key: ValueKey(
                          "marker-reference-${referenceHotel!['properties']['name']}",
                        ),
                        point: referenceHotelCoords!,
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            print(
                              "🟣 [tap ref-pin] ${referenceHotel!['properties']?['name']}",
                            );
                            showModalBottomSheet(
                              context: context,
                              builder:
                                  (_) => _buildHotelInfoSheet(
                                    hotel: referenceHotel!,
                                    label: "Previous Hotel",
                                    color: Colors.purple,
                                  ),
                            );
                          },
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.purple,
                            size: 36,
                          ),
                        ),
                      ),

                    // 3) SELECTED (RED) — CLICKABLE & ALWAYS LAST
                    if (selectedHotel != null && selectedHotelCoords != null)
                      Marker(
                        key: ValueKey(
                          "marker-selected-${selectedHotel!['properties']['name']}",
                        ),
                        point: selectedHotelCoords!,
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            print(
                              "🔴 [tap selected-pin] ${selectedHotel!['properties']?['name']}",
                            );
                            showModalBottomSheet(
                              context: context,
                              builder:
                                  (_) => _buildHotelInfoSheet(
                                    hotel: selectedHotel!,
                                    label: "Selected Hotel",
                                    color: Colors.red,
                                  ),
                            );
                          },
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 36,
                          ),
                        ),
                      ),

                    // 1.5) ALTERNATE ATTRACTIONS (ORANGE) — clickable
                    if (showAlternateAttractions &&
                        alternateAttractionsByStop.isNotEmpty)
                      ...alternateAttractionsByStop.entries.expand((entry) {
                        final parts = entry.key.split('_');
                        final day = int.tryParse(parts[0].substring(1)) ?? 0;
                        final idx = int.tryParse(parts[1].substring(1)) ?? 1;

                        return entry.value.map<Marker?>((place) {
                          final coords = place['geometry']?['coordinates'];
                          if (coords is! List || coords.length < 2) return null;
                          final LatLng p = LatLng(
                            (coords[1] as num).toDouble(),
                            (coords[0] as num).toDouble(),
                          );

                          final alreadyChosenHere = dailyPoints[day].any(
                            (dp) => (_calculateDistance(dp, p) < kOverlapKm),
                          );
                          if (alreadyChosenHere) return null;

                          return Marker(
                            key: ValueKey(
                              'marker-alt-attraction-${place['properties']?['name']}-${entry.key}',
                            ),
                            point: p,
                            width: 26,
                            height: 26,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap:
                                  () => _showAltAttractionSheet(
                                    day: day,
                                    index: idx,
                                    alt: place,
                                  ),
                              child: const Icon(
                                Icons.place,
                                color: Colors.orangeAccent,
                                size: 22,
                              ),
                            ),
                          );
                        }).whereType<Marker>();
                      }).toList(),

                    // 1.6) ALTERNATE RESTAURANTS (GREEN) — clickable
                    if (showAlternateRestaurants &&
                        alternateRestaurantsByStop.isNotEmpty)
                      ...alternateRestaurantsByStop.entries.expand((entry) {
                        final parts = entry.key.split('_');
                        final day = int.tryParse(parts[0].substring(1)) ?? 0;
                        final idx = int.tryParse(parts[1].substring(1)) ?? 1;

                        return entry.value.map<Marker?>((place) {
                          final coords = place['geometry']?['coordinates'];
                          if (coords is! List || coords.length < 2) return null;

                          final LatLng p = LatLng(
                            (coords[1] as num).toDouble(),
                            (coords[0] as num).toDouble(),
                          );

                          // avoid duplicates on same stop
                          final alreadyChosenHere = dailyPoints[day].any(
                            (dp) => (_calculateDistance(dp, p) < kOverlapKm),
                          );
                          if (alreadyChosenHere) return null;

                          return Marker(
                            key: ValueKey(
                              'marker-alt-restaurant-${place['properties']?['name']}-${entry.key}',
                            ),
                            point: p,
                            width: 26,
                            height: 26,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap:
                                  () => _showAltRestaurantSheet(
                                    day: day,
                                    index: idx,
                                    alt: place,
                                  ),
                              child: const Icon(
                                Icons.restaurant,
                                color: Colors.green,
                                size: 22,
                              ),
                            ),
                          );
                        }).whereType<Marker>();
                      }).toList(),

                    // 1.7) ALTERNATE SHOPS (BLUE) — clickable
                    if (showAlternateShops && alternateShopsByStop.isNotEmpty)
                      ...alternateShopsByStop.entries.expand((entry) {
                        final parts = entry.key.split('_');
                        final day = int.tryParse(parts[0].substring(1)) ?? 0;
                        final idx = int.tryParse(parts[1].substring(1)) ?? 1;

                        return entry.value.map<Marker?>((place) {
                          final coords = place['geometry']?['coordinates'];
                          if (coords is! List || coords.length < 2) return null;

                          final LatLng p = LatLng(
                            (coords[1] as num).toDouble(),
                            (coords[0] as num).toDouble(),
                          );

                          final alreadyChosenHere = dailyPoints[day].any(
                            (dp) => (_calculateDistance(dp, p) < kOverlapKm),
                          );
                          if (alreadyChosenHere) return null;

                          return Marker(
                            key: ValueKey(
                              'marker-alt-shop-${place['properties']?['name']}-${entry.key}',
                            ),
                            point: p,
                            width: 26,
                            height: 26,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap:
                                  () => _showAltShopSheet(
                                    day: day,
                                    index: idx,
                                    alt: place,
                                  ),
                              child: const Icon(
                                Icons.shopping_bag,
                                color: Colors.blue,
                                size: 22,
                              ),
                            ),
                          );
                        }).whereType<Marker>();
                      }).toList(),

                    // 3a) HOTEL PINS PER DAY (index 0) — labeled "H" in day color
                    for (int day = 0; day < dailyPoints.length; day++)
                      if (dailyPoints[day].isNotEmpty)
                        if (!((selectedHotelCoords != null &&
                                _calculateDistance(
                                      dailyPoints[day][0],
                                      selectedHotelCoords!,
                                    ) <
                                    0.05) ||
                            (referenceHotelCoords != null &&
                                _calculateDistance(
                                      dailyPoints[day][0],
                                      referenceHotelCoords!,
                                    ) <
                                    0.05)))
                          Marker(
                            key: ValueKey('marker-day${day + 1}-hotel'),
                            point: dailyPoints[day][0],
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                final hotelName =
                                    (day < dailyNames.length &&
                                            dailyNames[day].isNotEmpty)
                                        ? dailyNames[day][0]
                                        : 'Hotel';
                                _openPlaceDetailsSheetByIds(
                                  day: day,
                                  index: 0,
                                  name: hotelName,
                                  latLng: dailyPoints[day][0],
                                );
                              },
                              child: numberedPin(
                                label: 'H',
                                color: dayColors[day % dayColors.length],
                                glyph: Icons.hotel,
                              ),
                            ),
                          ),

                    // 3b) NUMBERED ATTRACTION PINS (1..N) in day color
                    for (int day = 0; day < dailyPoints.length; day++)
                      for (int i = 1; i < dailyPoints[day].length; i++)
                        Marker(
                          key: ValueKey('marker-day${day + 1}-stop$i'),
                          point: dailyPoints[day][i],
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final name =
                                  (day < dailyNames.length &&
                                          i < dailyNames[day].length)
                                      ? dailyNames[day][i]
                                      : 'Stop $i';
                              final pos = dailyPoints[day][i];
                              _openPlaceDetailsSheetByIds(
                                day: day,
                                index: i,
                                name: name,
                                latLng: pos,
                              );
                            },
                            child: numberedPin(
                              label: '$i',
                              color: dayColors[day % dayColors.length],
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),

            // Legend positioned on top of the map
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Legend',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    _buildLegendItem(
                      Icons.location_on,
                      Colors.red,
                      'Selected Hotel',
                    ),
                    _buildLegendItem(
                      Icons.location_on,
                      Colors.purple,
                      'Previous Hotel',
                    ),
                    _buildLegendItem(
                      Icons.location_on,
                      Colors.black87,
                      'Alternative Hotels',
                    ),

                    // Add day-specific legend items if needed
                    for (int i = 0; i < dailyPoints.length && i < 3; i++)
                      _buildLegendItem(
                        Icons.circle,
                        dayColors[i % dayColors.length],
                        'Day ${i + 1}',
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

  // Helper method to build legend items
  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _normStr(String? s) =>
      (s ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();

  // put inside State<PlanTripScreen>
  void _hardRefreshMap() {
    debugPrint('🗺️ [hardRefresh] Bumping keys and replacing map message');
    _markersKey = UniqueKey();
    mapWidgetKey = UniqueKey();

    if (_mapMsgIndex != null) {
      // Replace the stored map widget with a new one so it rebuilds
      messages[_mapMsgIndex!] = _buildMapMessage();
    }
    setState(() {}); // trigger rebuild
  }

  bool _stringHasAny(String s, List<String> needles) {
    final t = s.toLowerCase();
    for (final n in needles) {
      if (t.contains(n.toLowerCase())) return true;
    }
    return false;
  }

  Set<String> _typesFromDoc(Map<String, dynamic> p) {
    final props = (p['properties'] ?? {}) as Map<String, dynamic>;
    final a = (props['googleTypes'] ?? props['types'] ?? const []) as List?;
    return (a ?? const []).map((e) => e.toString().toLowerCase()).toSet();
  }

  String _nameOf(Map<String, dynamic> p) =>
      ((p['properties'] ?? {})['name'] ?? '').toString();

  LatLng? _latLngOf(Map<String, dynamic> p) {
    final coords = (p['geometry']?['coordinates']);
    if (coords is! List || coords.length < 2) return null;
    return LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
  }

  // category heuristics (works even if curated docs didn't stamp 'category')
  bool _isRestaurantDoc(Map<String, dynamic> p) {
    final props = (p['properties'] ?? {}) as Map<String, dynamic>;
    final cat =
        (props['category'] ?? props['type'] ?? '').toString().toLowerCase();
    if (cat == 'accommodation' || cat == 'attraction' || cat == 'souvenir')
      return false;

    final t = _typesFromDoc(p);
    if (t.contains('restaurant') ||
        t.contains('cafe') ||
        t.contains('bakery') ||
        t.contains('food'))
      return true;

    final name = _nameOf(p).toLowerCase();
    return _stringHasAny(name, [
      'restaurant',
      'cafe',
      'kopitiam',
      'bakery',
      'bistro',
      'mamak',
      'nasi',
      'mee',
      'laksa',
      'char kway',
      'char koay',
      'cendol',
      'sate',
      'thai',
      'seafood',
    ]);
  }

  bool _isSouvenirDoc(Map<String, dynamic> p) {
    final props = (p['properties'] ?? {}) as Map<String, dynamic>;
    final cat =
        (props['category'] ?? props['type'] ?? '').toString().toLowerCase();
    if (cat == 'restaurant' || cat == 'accommodation') return false;

    final t = _typesFromDoc(p);
    // exclude general groceries/convenience
    if (t.contains('convenience_store') ||
        t.contains('supermarket') ||
        t.contains('grocery_or_supermarket'))
      return false;

    if (t.contains('souvenir_store') || t.contains('gift_shop')) return true;

    final name = _nameOf(p).toLowerCase();
    // common Penang souvenir cues
    return _stringHasAny(name, [
      'souvenir',
      'gift',
      'handicraft',
      'craft',
      'batik',
      'chocolate',
      'nutmeg',
      'tau sar piah',
      'white coffee',
    ]);
  }

  static const Map<int, String> accommodationLevels = {
    1: "1-2 Star Hotels (Budget)",
    2: "2-3 Star Hotels (Standard)",
    3: "3-4 Star Hotels (Comfort)",
    4: "4-5 Star Hotels (Premium)",
    5: "5 Star Hotels (Luxury)",
  };

  // Define rating ranges for each level
  static const Map<int, Map<String, double>> ratingRanges = {
    1: {'min': 1.0, 'max': 2.5}, // 1-2 star range
    2: {'min': 2.0, 'max': 3.5}, // 2-3 star range
    3: {'min': 3.0, 'max': 4.5}, // 3-4 star range
    4: {'min': 4.0, 'max': 5.0}, // 4-5 star range
    5: {'min': 4.5, 'max': 5.0}, // 5 star range
  };

  // Modified selectSuitableRoomType function
  String? selectSuitableRoomType({
    required Map<String, dynamic> travelersNo,
    required Map<String, dynamic> roomTypes,
    required int travelers,
    required double
    hotelRating, // Changed from accommodationBudget to hotelRating
    required int selectedLevel, // Add selected level parameter
  }) {
    print(
      "💡 Travelers: $travelers | Hotel Rating: $hotelRating | Selected Level: $selectedLevel",
    );

    // Get rating range for selected level
    final ratingRange = ratingRanges[selectedLevel];
    if (ratingRange == null) {
      print("❌ Invalid hotel level: $selectedLevel");
      return null;
    }

    final minRating = ratingRange['min']!;
    final maxRating = ratingRange['max']!;

    // Check if hotel rating falls within selected level range
    if (hotelRating < minRating || hotelRating > maxRating) {
      print(
        "❌ Hotel rating $hotelRating not in range $minRating-$maxRating for level $selectedLevel",
      );
      return null;
    }

    // ✅ Case 1: More than 2 travelers → Only consider family room
    if (travelers > 2) {
      int capacity = (travelersNo['family'] as num?)?.toInt() ?? 0;
      print("🏠 Family Room → Capacity: $capacity, Rating: $hotelRating");
      if (travelers <= capacity) return 'family';
      return null;
    }

    // ✅ Case 2: 2 or fewer travelers → Prefer single, fallback to family
    int singleCapacity = (travelersNo['single'] as num?)?.toInt() ?? 0;
    print("🛏️ Single Room → Capacity: $singleCapacity, Rating: $hotelRating");
    if (travelers <= singleCapacity) {
      return 'single';
    }

    // fallback to family room if single is not suitable
    int familyCapacity = (travelersNo['family'] as num?)?.toInt() ?? 0;
    print(
      "🏠 Family Room (fallback) → Capacity: $familyCapacity, Rating: $hotelRating",
    );
    if (travelers <= familyCapacity) {
      return 'family';
    }

    return null;
  }

  List<DateTime> _buildMealSlots(DateTime dayDate, int count) {
    final List<DateTime> base = [
      DateTime(dayDate.year, dayDate.month, dayDate.day, 12, 30), // lunch
      DateTime(dayDate.year, dayDate.month, dayDate.day, 19, 30), // dinner
      DateTime(
        dayDate.year,
        dayDate.month,
        dayDate.day,
        9,
        0,
      ), // breakfast (fallback)
      DateTime(
        dayDate.year,
        dayDate.month,
        dayDate.day,
        15,
        0,
      ), // tea (fallback)
    ];
    return base.take(count.clamp(0, base.length)).toList();
  }

  // A single canonical key we’ll use everywhere
  String _keyForPlace(Map<String, dynamic> place) {
    final props = (place['properties'] as Map?) ?? const {};
    final coords = (place['geometry']?['coordinates'] as List?) ?? const [];
    final lat = coords.length >= 2 ? (coords[1] as num?)?.toDouble() : null;
    final lon = coords.length >= 2 ? (coords[0] as num?)?.toDouble() : null;

    final raw =
        (props['place_id'] ??
                props['google_place_id'] ??
                props['id'] ??
                props['name'])
            ?.toString();

    if (raw != null && raw.isNotEmpty) return raw;

    // Fallback: synth key from name+coords (stable enough)
    final name = (props['name'] ?? 'unknown').toString();
    return '$name@${lat?.toStringAsFixed(5)},${lon?.toStringAsFixed(5)}';
  }

  // Centralized cache writer
  void _cachePlace(Map<String, dynamic> place) {
    final key = _keyForPlace(place);
    _placeCache[key] = place; // ensure _placeCache is Map<String, Map>
  }

  Future<void> _generateTripPlan(BuildContext context) async {
    debugPrint("🛠️DEBUG: 🚀 Entering _generateTripPlan function");
    debugPrint("🚀 Generating trip");

    debugPrint(
      "🛠️DEBUG: Checking input conditions: selectedAreas=${selectedAreas.isEmpty}, startDate=$startDate, endDate=$endDate, budget=$budget",
    );
    if (selectedAreas.isEmpty ||
        startDate == null ||
        endDate == null ||
        budget == null ||
        budget! < 80 ||
        tripTitle.trim().isEmpty ||
        numberOfTravelers <= 0 ||
        numberOfTravelers != numberOfTravelers.toInt()) {
      // Add this line
      debugPrint("🛠️DEBUG: ❌ Missing or invalid inputs, returning early");

      // Build specific error message based on what's missing
      List<String> missingInputs = [];
      // Check for decimal travelers
      if (numberOfTravelers != numberOfTravelers.toInt()) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.white,
                elevation: 8,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Invalid Number of Travelers',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _brandDark,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    'Number of travelers must be a whole number. You cannot have ${numberOfTravelers.toString()} travelers.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: _brandDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'OK',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
        );
        return;
      }
      if (tripTitle.trim().isEmpty) {
        missingInputs.add("Trip title");
      } else if (tripTitle.trim().length < 3) {
        missingInputs.add("Invalid trip title (minimum 3 characters)");
      }

      if (selectedAreas.isEmpty) {
        missingInputs.add("areas");
      }

      if (startDate == null || endDate == null) {
        missingInputs.add("travel dates");
      }

      if (numberOfTravelers <= 0) {
        missingInputs.add("number of travelers (minimum 1)");
      }

      if (budget! < 0) {
        // Special handling for negative budget - show specific popup
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.white,
                elevation: 8,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Invalid Budget',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _brandDark,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    'Budget cannot be negative. Please enter a positive amount.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: _brandDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'OK',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
        );
      } else if (budget! < 80) {
        // Special handling for negative budget - show specific popup
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.white,
                elevation: 8,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Invalid Budget',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _brandDark,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    'Minimum budget amount is RM80',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: _brandDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'OK',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
        );
      }
    }

    try {
      debugPrint("🛠️DEBUG: Loading places from Firebase");
      final curatedPlaces = await _loadPlacesFromFirebase(selectedAreas);
      // 🆕 cache all
      _placeCache.clear();
      for (final p in curatedPlaces) {
        _cachePlace(p);
      }

      debugPrint("🛠️DEBUG: ✅ Loaded ${curatedPlaces.length} places total");
      _allPlaces = curatedPlaces; // for alt-attraction scan

      if (curatedPlaces.isEmpty) {
        debugPrint("🛠️DEBUG: ❌ No places found, returning early");
        setState(() {
          messages.add(const Text("AI: No valid places found!"));
        });
        return;
      }

      final int days = endDate!.difference(startDate!).inDays + 1;

      final counts = kPlanCounts[_selectedPlanStyle]!;
      final targetAttractionsPerDay = counts.attractions;
      final targetMealsPerDay =
          counts.meals; // you’ll use this when inserting meals
      final targetSouvenirPerDay =
          counts.shops; // you’ll use this when inserting shops

      dailyNames = List.generate(days, (_) => []);
      dailyPoints = List.generate(days, (_) => []);

      dailyWeather = [];
      tripPicks.clear();

      // --- Step 1: Select suitable hotel ---
      debugPrint("🛠️DEBUG: Filtering accommodations");
      var accommodations =
          curatedPlaces
              .where(
                (p) =>
                    (p['properties']['category']?.toLowerCase() ==
                        'accommodation'),
              )
              .toList();

      debugPrint("🛠️DEBUG: Found ${accommodations.length} accommodations");
      if (accommodations.isEmpty) {
        debugPrint("🛠️DEBUG: ❌ No accommodations found, returning early");
        setState(() {
          messages.add(const Text("AI: No accommodation found!"));
        });
        return;
      }

      num nights = endDate!.difference(startDate!).inDays;
      if (nights <= 0) nights = 1;

      double hotelPercent =
          double.tryParse(_hotelPercentController.text) ?? 40.0;
      final roomCaps = numberOfTravelers > 2 ? familyRoomCaps : singleRoomCaps;
      debugPrint(
        "🛠️DEBUG: 🎯 Travelers: $numberOfTravelers → Using ${numberOfTravelers > 2 ? 'familyRoomCaps' : 'singleRoomCaps'}",
      );

      double accommodationBudget;
      debugPrint(
        "🛠️DEBUG: Type of selectedHotelLevel: ${selectedHotelLevel.runtimeType}",
      );
      if (useHotelLevel && selectedHotelLevel != null) {
        if (selectedHotelLevel is! num) {
          debugPrint(
            "🛠️🚨DEBUG: selectedHotelLevel is not a num: ${selectedHotelLevel.runtimeType}",
          );
          setState(() {
            messages.add(const Text("AI: Invalid hotel level selected."));
          });
          return;
        }
        accommodationBudget = roomCaps[selectedHotelLevel! as num] ?? 400.0;
      } else {
        accommodationBudget = (budget ?? 0) * (hotelPercent / 100);
      }

      double budgetPerNight = accommodationBudget / nights;
      debugPrint(
        "🛠️DEBUG: Accommodation budget: $accommodationBudget, Budget per night: $budgetPerNight",
      );

      List<Map<String, dynamic>> suitableHotels = [];
      debugPrint(
        "🛠️DEBUG: Starting hotel filtering for ${accommodations.length} accommodations",
      );

      for (var hotel in accommodations) {
        var roomTypes = hotel['properties']['roomTypes'];
        var travelersNo = hotel['properties']['travelersNo'];
        var hotelRating =
            (hotel['properties']['rating'] as num?)?.toDouble() ?? 0.0;

        debugPrint(
          "🛠️DEBUG: Checking hotel: ${hotel['properties']['name']}, Rating: $hotelRating",
        );

        if (roomTypes == null || travelersNo == null) {
          debugPrint(
            "🛠️DEBUG: ⚠️ Skipping hotel due to null roomTypes or travelersNo",
          );
          continue;
        }

        // Check if hotel rating matches selected level
        final ratingRange = ratingRanges[selectedHotelLevel];
        if (ratingRange == null) {
          debugPrint("🛠️DEBUG: ❌ Invalid hotel level: $selectedHotelLevel");
          continue;
        }

        final minRating = ratingRange['min']!;
        final maxRating = ratingRange['max']!;

        if (hotelRating < minRating || hotelRating > maxRating) {
          debugPrint(
            "🛠️DEBUG: ❌ Hotel rating $hotelRating not in range $minRating-$maxRating",
          );
          continue;
        }

        String? roomType = selectSuitableRoomType(
          travelersNo: Map<String, dynamic>.from(travelersNo),
          roomTypes: Map<String, dynamic>.from(roomTypes),
          travelers: numberOfTravelers,
          hotelRating: hotelRating,
          selectedLevel: selectedHotelLevel,
        );

        debugPrint("🛠️DEBUG: Selected room type: $roomType");

        if (roomType != null) {
          double price = roomTypes[roomType]['price']?.toDouble() ?? 0;
          debugPrint(
            "🛠️DEBUG: ✅ Hotel matches level $selectedHotelLevel criteria, adding to suitableHotels",
          );

          hotel['selectedRoomType'] = roomType;
          hotel['roomPrice'] = price;
          hotel['hotelRating'] = hotelRating;
          suitableHotels.add(hotel);
        } else {
          debugPrint("🛠️DEBUG: ⚠️ No suitable room type found for hotel");
        }
      }

      debugPrint(
        "🛠️✅DEBUG: Completed hotel filtering, Total suitable hotels: ${suitableHotels.length}",
      );
      for (var hotel in suitableHotels) {
        debugPrint(
          "🛠️✅DEBUG: Suitable Hotel: ${hotel['properties']['name']} - Room: ${hotel['selectedRoomType']}, Price: ${hotel['roomPrice']}",
        );
      }

      if (suitableHotels.isEmpty) {
        debugPrint(
          "🛠️DEBUG: ❌ No suitable hotels found for level $selectedHotelLevel, returning early",
        );
        setState(() {
          messages.add(
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.hotel, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "AI: No hotels found matching the selected level or budget.",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });

        return;
      }

      debugPrint(
        "🛠️✅DEBUG: Selecting random hotel from ${suitableHotels.length} options",
      );
      Map<String, dynamic> selectedHotel;
      String selectedRoomType;
      double selectedHotelPrice;
      LatLng hotelLocation;
      String hotelName;

      try {
        final random = Random();
        selectedHotel = suitableHotels[random.nextInt(suitableHotels.length)];
        referenceHotel ??= selectedHotel;

        selectedRoomType = selectedHotel['selectedRoomType'] as String;
        selectedHotelPrice = selectedHotel['roomPrice'] as double;

        if (selectedHotel['geometry'] == null ||
            selectedHotel['geometry']['coordinates'] == null ||
            (selectedHotel['geometry']['coordinates'] as List).length < 2) {
          debugPrint(
            "🛠️🚨DEBUG: Invalid coordinates for selected hotel: ${selectedHotel['properties']['name']}",
          );
          setState(() {
            messages.add(
              const Text("AI: Selected hotel has invalid coordinates."),
            );
          });
          return;
        }

        hotelLocation = LatLng(
          (selectedHotel['geometry']['coordinates'][1] as num).toDouble(),
          (selectedHotel['geometry']['coordinates'][0] as num).toDouble(),
        );
        hotelName = selectedHotel['properties']['name'] as String;

        debugPrint(
          "🛠️✅DEBUG: 🏨 Selected Hotel: $hotelName, Room Type: $selectedRoomType, Price: $selectedHotelPrice",
        );

        // Build alternate hotels ≤ 2km
        List<Map<String, dynamic>> alternateHotels = [];
        for (var hotel in suitableHotels) {
          if (hotel['properties']['name'] == hotelName) continue;
          try {
            if (hotel['geometry'] == null ||
                hotel['geometry']['coordinates'] == null ||
                (hotel['geometry']['coordinates'] as List).length < 2) {
              debugPrint(
                "🛠️🚨DEBUG: Invalid coordinates for hotel: ${hotel['properties']['name']}",
              );
              continue;
            }
            LatLng loc = LatLng(
              (hotel['geometry']['coordinates'][1] as num).toDouble(),
              (hotel['geometry']['coordinates'][0] as num).toDouble(),
            );
            double dist = _calculateDistance(hotelLocation, loc);
            if (dist <= 2.0) {
              hotel['distanceFromSelected'] = dist;
              alternateHotels.add(hotel);
            }
          } catch (e) {
            debugPrint(
              "🛠️🚨DEBUG: Error calculating distance for ${hotel['properties']['name']}: $e",
            );
          }
        }
        debugPrint(
          "🛠️✅DEBUG: 📍 Alternate Hotels within 2km: ${alternateHotels.length} found",
        );

        setState(() {
          this.selectedHotel = selectedHotel;
          this.selectedRoomType = selectedRoomType;
          this.suitableHotels = suitableHotels;
          this.alternateHotels = alternateHotels;
        });
      } catch (e) {
        debugPrint("🛠️🚨DEBUG: Error in hotel selection: $e");
        setState(() {
          messages.add(Text("AI: Error selecting hotel — $e"));
        });
        return;
      }

      // --- Step 2: Attractions ---
      debugPrint("🛠️DEBUG: Filtering attractions");
      var attractions =
          curatedPlaces
              .where(
                (p) =>
                    (p['properties']['category']?.toLowerCase() ==
                        'attraction'),
              )
              .toList();

      final restaurants = curatedPlaces.where(_isRestaurantDoc).toList();
      final souvenirs = curatedPlaces.where(_isSouvenirDoc).toList();

      debugPrint("🛠️DEBUG: Found ${attractions.length} attractions");
      allAttractions = List<Map<String, dynamic>>.from(attractions);

      if (attractions.isEmpty) {
        debugPrint("🛠️DEBUG: ❌ No attractions found, returning early");
        setState(() {
          messages.add(const Text("AI: No attractions found!"));
        });
        return;
      }

      debugPrint(
        "🛠️DEBUG: Starting daily planning for $days days with TSP optimization",
      );
      for (num i = 0; i < days; i++) {
        String weather = await _getWeather(
          hotelLocation.latitude,
          hotelLocation.longitude,
          startDate!.add(Duration(days: i.toInt())),
          context,
        );

        debugPrint("🛠️DEBUG: Weather for day ${i + 1}: $weather");
        dailyWeather.add(weather);
      }

      // Group attractions by area
      Map<String, List<Map<String, dynamic>>> areaAttractions = {};
      for (var place in attractions) {
        String area = place['properties']['area'] ?? '';
        areaAttractions[area] ??= [];
        areaAttractions[area]!.add(place);
      }

      // Group restaurants & souvenir shops by area
      final Map<String, List<Map<String, dynamic>>> areaRestaurants = {};
      final Map<String, List<Map<String, dynamic>>> areaShops = {};
      for (var p in curatedPlaces) {
        final cat =
            (p['properties']['category'] ?? '').toString().toLowerCase();
        final area = (p['properties']['area'] ?? '').toString();
        if (area.isEmpty) continue;
        if (cat == 'restaurant') {
          (areaRestaurants[area] ??= []).add(p);
        } else if (cat == 'souvenir') {
          (areaShops[area] ??= []).add(p);
        }
      }

      // day → area mapping
      List<String> dayToArea = [];
      for (final area in selectedAreas) {
        num daysForArea = userAreaPicks[widget.userId]?[area]?.toInt() ?? 0;
        for (num i = 0; i < daysForArea; i++) {
          dayToArea.add(area);
        }
      }

      // Assign attractions per day with TSP optimization
      Set<String> selectedPlaceNames = {};
      for (num day = 0; day < days; day++) {
        String areaOfDay = dayToArea[day.toInt()];

        String weather = dailyWeather[day.toInt()];

        // Temporary lists for building the route
        List<String> tempNames = [];
        List<LatLng> tempCoords = [];

        final hotelKey = _keyForPlace(selectedHotel);
        _cachePlace(selectedHotel);

        // Start with hotel
        tempNames.add("Start at: $hotelName");
        tempCoords.add(hotelLocation);

        // Add hotel to tripPicks
        tripPicks.add({
          'placeData': {
            'place_id': hotelKey,
            'name': hotelName,
            'address': selectedHotel['properties']['address'] ?? '',
            'category': 'accommodation',
            'coordinates': {
              'lat': hotelLocation.latitude,
              'lon': hotelLocation.longitude,
            },
            'days': 1.0,
            'rating': selectedHotel['properties']['rating']?.toDouble() ?? 0.0,
            'type': selectedHotel['properties']['type'] ?? 'unknown',
            'user_ratings_total':
                selectedHotel['properties']['user_ratings_total'] ?? 0,
            'price_level': selectedHotel['properties']['price_level'] ?? 3,
            'selectedRoomType': selectedRoomType,
          },
          'area': selectedAreas.first,
          'dayIndex': day + 1,
          'sequence': 0,
        });

        // Select attractions for this day
        var todaysAttractions = areaAttractions[areaOfDay] ?? [];
        var availableAttractions =
            todaysAttractions.where((a) {
              String name = a['properties']['name'];
              return !selectedPlaceNames.contains(name);
            }).toList();
        var weatherFilteredAttractions = _filterAttractionsByWeather(
          availableAttractions,
          weather,
        );

        final pickScores = _getPickSuggestions(
          weatherFilteredAttractions,
          weather,
        );
        weatherFilteredAttractions.sort((a, b) {
          final aScore = pickScores[a['properties']['name']] ?? 0;
          final bScore = pickScores[b['properties']['name']] ?? 0;
          return bScore.compareTo(aScore);
        });

        var selectedAttractions =
            weatherFilteredAttractions.take(targetAttractionsPerDay).toList();

        // Add weather adaptation message
        final isRainy = weather.toLowerCase().contains('rain');
        if (isRainy) {
          debugPrint(
            '🌧️ Day ${day + 1}: Prioritizing indoor activities due to $weather',
          );
        }

        // Add selected attractions to temporary lists
        for (var attraction in selectedAttractions) {
          String name = attraction['properties']['name'];
          LatLng location = LatLng(
            (attraction['geometry']['coordinates'][1] as num).toDouble(),
            (attraction['geometry']['coordinates'][0] as num).toDouble(),
          );
          tempNames.add(name);
          tempCoords.add(location);
          selectedPlaceNames.add(name);
        }

        // 🚀 TSP OPTIMIZATION - Optimize the route starting from hotel
        if (tempCoords.length > 2) {
          debugPrint(
            "🎯 Optimizing route for day ${day + 1} with ${tempCoords.length} stops",
          );

          final tspResult = _optimizeRoute(
            points: tempCoords,
            names: tempNames,
            fixedStart: 0, // Hotel stays at position 0
            returnToStart: false, // Don't return to hotel
            maxIterations: 300,
          );

          debugPrint(
            "✅ TSP optimization complete: ${tspResult.improvements} improvements, total distance: ${tspResult.totalDistance.toStringAsFixed(2)}km",
          );

          // Use optimized route
          tempNames = tspResult.optimizedNames;
          tempCoords = tspResult.optimizedPoints;
        }

        // Add meals using nearest neighbor from optimized route
        final restaurantsToday = List<Map<String, dynamic>>.from(
          areaRestaurants[areaOfDay] ?? const [],
        );
        final mealSlots = _buildMealSlots(
          DateTime(
            startDate!.year,
            startDate!.month,
            startDate!.day,
          ).add(Duration(days: day.toInt())),
          targetMealsPerDay,
        );

        for (final when in mealSlots) {
          if (tempNames.where((s) => s.startsWith('Meal:')).length >=
              targetMealsPerDay)
            break;

          final anchor =
              tempCoords.isNotEmpty ? tempCoords.last : hotelLocation;
          final pick = _pickNearestOpenPlace(
            restaurantsToday,
            anchor,
            when,
            selectedPlaceNames,
          );

          if (pick != null) {
            final name = (pick['properties']['name'] ?? 'Restaurant') as String;
            final coords = (pick['geometry']['coordinates'] as List);
            final loc = LatLng(
              (coords[1] as num).toDouble(),
              (coords[0] as num).toDouble(),
            );

            tempNames.add('Meal: $name');
            tempCoords.add(loc);
            selectedPlaceNames.add(name);
          }
        }

        // Add souvenir shops
        final shopsToday = List<Map<String, dynamic>>.from(
          areaShops[areaOfDay] ?? const [],
        );
        for (int s = 0; s < targetSouvenirPerDay; s++) {
          final anchor =
              tempCoords.isNotEmpty ? tempCoords.last : hotelLocation;
          final when = DateTime(
            startDate!.year,
            startDate!.month,
            startDate!.day,
          ).add(Duration(days: day.toInt(), hours: 17));

          final pick = _pickNearestOpenPlace(
            shopsToday,
            anchor,
            when,
            selectedPlaceNames,
          );
          if (pick != null) {
            final name =
                (pick['properties']['name'] ?? 'Souvenir Shop') as String;
            final coords = (pick['geometry']['coordinates'] as List);
            final loc = LatLng(
              (coords[1] as num).toDouble(),
              (coords[0] as num).toDouble(),
            );

            tempNames.add('Souvenir: $name');
            tempCoords.add(loc);
            selectedPlaceNames.add(name);
          }
        }

        // Store the optimized route for this day
        dailyNames[day.toInt()] = tempNames;
        dailyPoints[day.toInt()] = tempCoords;

        // Add remaining places to tripPicks with correct sequence
        for (int i = 1; i < tempNames.length; i++) {
          final placeName = tempNames[i];
          final location = tempCoords[i];

          // Find the original place data to get proper details
          Map<String, dynamic>? placeData;
          String category = 'attraction';

          if (placeName.startsWith('Meal:')) {
            category = 'restaurant';
            final actualName = placeName.substring(6).trim();
            try {
              placeData = restaurantsToday.firstWhere(
                (p) => p['properties']['name'] == actualName,
              );
            } catch (e) {
              placeData = null;
            }
          } else if (placeName.startsWith('Souvenir:')) {
            category = 'souvenir';
            final actualName = placeName.substring(10).trim();
            try {
              placeData = shopsToday.firstWhere(
                (p) => p['properties']['name'] == actualName,
              );
            } catch (e) {
              placeData = null;
            }
          } else {
            try {
              placeData = selectedAttractions.firstWhere(
                (p) => p['properties']['name'] == placeName,
              );
            } catch (e) {
              placeData = null;
            }
          }

          final placeKey =
              placeData != null
                  ? _keyForPlace(placeData)
                  : 'generated_${DateTime.now().millisecondsSinceEpoch}';
          if (placeData != null) _cachePlace(placeData);

          tripPicks.add({
            'placeData': {
              'place_id': placeKey,
              'name': placeName,
              'address': placeData?['properties']?['address'] ?? '',
              'category': category,
              'coordinates': {
                'lat': location.latitude,
                'lon': location.longitude,
              },
              'days':
                  category == 'restaurant'
                      ? 0.2
                      : (category == 'souvenir' ? 0.15 : 1.0),
              'rating':
                  (placeData?['properties']?['rating'] as num?)?.toDouble() ??
                  0.0,
              'type': placeData?['properties']?['type'] ?? category,
              'user_ratings_total':
                  placeData?['properties']?['user_ratings_total'] ?? 0,
              'price_level': placeData?['properties']?['price_level'] ?? 2,
            },
            'area': areaOfDay,
            'dayIndex': day + 1,
            'sequence': i,
          });
        }

        debugPrint("🛠️✅DEBUG: Day ${day + 1} optimized route:");
        for (int i = 0; i < tempNames.length; i++) {
          debugPrint("🛠️✅DEBUG:   ${i}. ${tempNames[i]}");
        }
        debugPrint("🛠️✅DEBUG: ────────────────────────────────────────────");
      }

      // Build alternates now that routes are ready
      _recomputeAltAttractions();

      // 👉 Add/refresh Live Itinerary + Map widgets
      if (_itinMsgIndex == null) {
        setState(() {
          _itinMsgIndex = messages.length;
          messages.add(_buildItineraryMessage()); // live panel
        });
      } else {
        _hardRefreshItinerary(); // bumps key + setState()
      }

      // Replace this section in your _generateTripPlan function:
      setState(() {
        // Fix for map regeneration issue
        if (_mapMsgIndex == null) {
          // First time generating - add new map
          _mapMsgIndex = messages.length;
          messages.add(_buildMapMessage());
        } else {
          // Subsequent times - replace existing map
          messages[_mapMsgIndex!] = _buildMapMessage();
        }
      });

      // Add this after your trip generation is complete
      final rainyDays =
          dailyWeather
              .where(
                (w) =>
                    w.toLowerCase().contains('rain') ||
                    w.toLowerCase().contains('shower'),
              )
              .length;

      if (rainyDays > 0) {
        messages.add(
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.umbrella, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "🌧️ Weather Alert: $rainyDays day(s) with rain expected. Indoor activities prioritized automatically!",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("🛠️🚨DEBUG: Error generating trip: $e");
      setState(() {
        messages.add(Text("AI: Error generating trip — $e"));
      });
    }
  }

  // 🛏️ Max prices for single room by level
  static const Map<int, double> singleRoomCaps = {
    1: 80.0,
    2: 120.0,
    3: 200.0,
    4: 400.0,
    5: 600.0,
  };

  // 🏠 Max prices for family room by level
  static const Map<int, double> familyRoomCaps = {
    1: 150.0,
    2: 250.0,
    3: 400.0,
    4: 800.0,
    5: 1200.0,
  };

  bool isFuzzyMatch(String name1, String name2) {
    name1 = name1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
    name2 = name2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();

    List<String> words1 = name1.split(' ');
    List<String> words2 = name2.split(' ');

    int matchCount = words1.where((word) => words2.contains(word)).length;

    double matchRatio = matchCount / words1.length;

    return matchRatio >= 0.6; // e.g., 60% matching words
  }

  Future<void> _showBookingPrompt() async {
    try {
      if (tripPicks.isEmpty ||
          startDate == null ||
          endDate == null ||
          budget == null) {
        print("⚠️ No trip data to save or missing required fields");
        if (mounted) {
          setState(() {
            messages.add(
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "AI: Generate a trip plan with all details first!",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        }
        return;
      }

      // Only show booking prompt if hotel is selected
      if (selectedHotel != null) {
        // Prep values for the prompt
        final userId = widget.userId;
        final start = startDate!;
        final end = endDate!;
        final travelers = numberOfTravelers;
        final city =
            (selectedAreas.isNotEmpty) ? selectedAreas.first : 'Penang';

        double? pricePerNight;
        if (selectedHotel != null && selectedHotel!['roomPrice'] != null) {
          pricePerNight = (selectedHotel!['roomPrice'] as num?)?.toDouble();
        }

        // Build areaDays for trip creation later
        final Map<String, int> areaDays = {};
        userAreaPicks[userId]?.forEach((area, days) {
          if (selectedAreas.contains(area) && days > 0) {
            areaDays[area] = days.toInt();
          }
        });

        // Normalize hotel for booking prompt
        final coords =
            (selectedHotel!['geometry']?['coordinates'] as List?) ??
            [null, null];
        final normalizedHotel = <String, dynamic>{
          'id':
              selectedHotel!['id'] ??
              selectedHotel!['placeId'] ??
              selectedHotel!['properties']?['id'],
          'properties': {
            'name':
                selectedHotel!['properties']?['name'] ??
                selectedHotel!['name'] ??
                'Selected accommodation',
            'address':
                selectedHotel!['properties']?['address'] ??
                selectedHotel!['address'] ??
                '',
            'phone':
                selectedHotel!['properties']?['phone'] ??
                selectedHotel!['phone'] ??
                '',
            // IMPORTANT: Include the availability data
            'emptyRoomsByDate':
                selectedHotel!['emptyRoomsByDate'] ??
                selectedHotel!['properties']?['emptyRoomsByDate'] ??
                {},
          },
          'geometry': {
            'coordinates': [
              (coords.isNotEmpty ? coords[0] : selectedHotel!['lng']) ?? 0.0,
              (coords.length > 1 ? coords[1] : selectedHotel!['lat']) ?? 0.0,
            ],
          },
        };

        // Create trip payload with all data needed for saving later
        final tripPayload = <String, dynamic>{
          'userId': userId,
          'city': city,
          'adults': travelers,
          'checkIn': _fmtYmd(start),
          'checkOut': _fmtYmd(end),
          'pricePerNight': pricePerNight,

          // Additional data needed for trip creation
          'title': (tripTitle.isNotEmpty ? tripTitle : 'Trip to Penang'),
          'startDate': start,
          'endDate': end,
          'budget': budget,
          'areaDays': areaDays,
          'numberOfTravelers': travelers,
          'tripPicks': tripPicks,
          'dailyWeather': dailyWeather,
        };

        // Show booking prompt with callback
        await showBookingPromptBottomSheet(
          context: context,
          trip: tripPayload,
          hotel: normalizeHotelFromAny(normalizedHotel),
          isSandbox: true,
          saveTripCallback: _saveTripToFirebase, // Pass the save function
        );
      } else {
        // No hotel selected, save trip directly
        await _saveTripToFirebase();
        print("ℹ️ No selectedHotel — saved trip without booking prompt.");
      }
    } catch (e) {
      print("🚨 Error in booking prompt: $e");
      if (mounted) {
        setState(() {
          messages.add(
            Text("AI: Error preparing booking prompt—check logs! ($e)"),
          );
        });
      }
    }
  }

  Future<String> _saveTripToFirebase([Map<String, dynamic>? tripData]) async {
    print(
      "🟦 _saveTripToFirebase called with keys: ${tripData?.keys.toList()}",
    );

    final userId = tripData?['userId'] ?? widget.userId;
    final start = (tripData?['startDate'] as DateTime?) ?? startDate!;
    final end = (tripData?['endDate'] as DateTime?) ?? endDate!;
    print(
      "🟦 _saveTripToFirebase inputs → userId=$userId start=$start end=$end",
    );

    // --- Create trip doc ---
    final tripRef = FirebaseFirestore.instance.collection('trips').doc();
    final tripId = tripRef.id;
    print("🟦 New tripRef.id = $tripId");
    try {
      // Use passed data or fall back to current state
      final userId = tripData?['userId'] ?? widget.userId;
      final start = (tripData?['startDate'] as DateTime?) ?? startDate!;
      final end = (tripData?['endDate'] as DateTime?) ?? endDate!;
      final travelers = tripData?['numberOfTravelers'] ?? numberOfTravelers;
      final title = tripData?['title'] ?? tripTitle; // was 'Trip to Penang'

      final city =
          tripData?['city'] ??
          ((selectedAreas.isNotEmpty) ? selectedAreas.first : 'Penang');
      final budget = tripData?['budget'] ?? this.budget;
      final areaDays =
          (tripData?['areaDays'] as Map<String, int>?) ?? <String, int>{};
      final picks = (tripData?['tripPicks'] as List?) ?? tripPicks;
      final weather = (tripData?['dailyWeather'] as List?) ?? dailyWeather;

      // Calculate accommodation expense
      double accommodationExpense = 0.0;
      double? pricePerNight = tripData?['pricePerNight'] as double?;
      if (pricePerNight != null) {
        int nights = end.difference(start).inDays;
        if (nights <= 0) nights = 1;
        accommodationExpense = pricePerNight * nights;
      }

      // --- Create trip doc ---
      final tripRef = FirebaseFirestore.instance.collection('trips').doc();
      final tripId = tripRef.id;

      await tripRef.set({
        'ownerId': userId,
        'collaboratorIds': [],
        'title': title,
        'startDate': Timestamp.fromDate(start),
        'endDate': Timestamp.fromDate(end),
        'budget': budget,
        'accommodationExpense': accommodationExpense,
        'areaDays': areaDays,
        'accommodationPercent':
            budget != null && budget! > 0
                ? ((accommodationExpense / budget!) * 100).clamp(0, 100)
                : 0.0,
        'numberOfTravelers': travelers,
        'createdAt': Timestamp.now(),
      });

      // Persist user area picks
      for (final entry in areaDays.entries) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('areaPicks')
            .doc(entry.key)
            .set({'days': entry.value});
      }

      print("✅ Trip document created successfully.");

      // --- Batch itinerary + weather ---
      final batch = FirebaseFirestore.instance.batch();

      // Sort picks: dayIndex then sequence
      final sortedPicks = List<Map<String, dynamic>>.from(picks);
      sortedPicks.sort((a, b) {
        final dayA = a['dayIndex'] ?? 0;
        final dayB = b['dayIndex'] ?? 0;
        if (dayA != dayB) return dayA.compareTo(dayB);
        final seqA = a['sequence'] ?? 0;
        final seqB = b['sequence'] ?? 0;
        return seqA.compareTo(seqB);
      });

      for (var pick in sortedPicks) {
        final placeData = pick['placeData'] as Map<String, dynamic>;
        var area = pick['area'] as String;
        final dayIndex = pick['dayIndex'] as int;
        final placeName = placeData['name'];

        print("Processing place: $placeName, area: $area");

        // Your existing place matching logic
        final placeQuery =
            await FirebaseFirestore.instance
                .collection('areas')
                .doc(area)
                .collection('places')
                .where('name', isEqualTo: placeName)
                .limit(1)
                .get();

        DocumentSnapshot<Map<String, dynamic>>? matchedDoc;
        if (placeQuery.docs.isEmpty) {
          // Your existing fuzzy matching logic...
          final allPlacesQuery =
              await FirebaseFirestore.instance
                  .collection('areas')
                  .doc(area)
                  .collection('places')
                  .get();

          for (final doc in allPlacesQuery.docs) {
            final firestoreName = (doc.data()['name'] ?? '').toString();
            if (isFuzzyMatch(firestoreName, placeName)) {
              matchedDoc = doc;
              break;
            }
          }

          if (matchedDoc == null) {
            await FirebaseFirestore.instance.collection('unmatched_places').add(
              {
                'name': placeName,
                'intendedArea': area,
                'timestamp': Timestamp.now(),
              },
            );
            continue;
          }
        } else {
          matchedDoc = placeQuery.docs.first;
        }

        final placeId = matchedDoc.id;
        final isOutdoor =
            (placeData['type']?.toString().toLowerCase() == 'outdoor');

        final itemRef = tripRef.collection('itinerary').doc();
        batch.set(itemRef, {
          'placeId': placeId,
          'placeName': placeName,
          'tripId': tripId,
          'area': area,
          'isOutdoor': isOutdoor,
          'date': Timestamp.fromDate(start.add(Duration(days: dayIndex - 1))),
          'sequence': pick['sequence'] ?? 0,
        });
      }

      // Save weather
      final days = end.difference(start).inDays + 1;
      for (int i = 0; i < days && i < weather.length; i++) {
        final weatherRef = tripRef.collection('weather').doc();
        batch.set(weatherRef, {
          'date': start
              .add(Duration(days: i))
              .toIso8601String()
              .substring(0, 10),
          'condition': weather[i],
        });
      }

      await batch.commit();
      print("✅ Subcollections saved successfully.");

      if (mounted) {
        setState(() {
          messages.add(
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_brand, _brandDark.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "AI: Trip, itinerary, and weather saved successfully!",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Trip saved successfully!",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: _brandDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return tripId;
    } catch (e) {
      print("🚨 Error saving to Firebase: $e");
      if (mounted) {
        setState(() {
          messages.add(
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "AI: Error saving trip—check logs! ($e)",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      }
      rethrow;
    }
  }

  String _fmtYmd(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  bool _isTripPlanReady() {
    return selectedAreas.isNotEmpty &&
        startDate != null &&
        endDate != null &&
        budget != null &&
        tripTitle.trim().isNotEmpty &&
        numberOfTravelers > 0;
  }

  /// Calculates the Jaccard similarity between two sets of areas (places visited)
  double _calculateAreaSimilarity(
    Map<String, int> currentUserAreaDays,
    Map<String, int> otherUserAreaDays,
  ) {
    // Convert the keys to sets (areas visited by both users)
    Set<String> currentUserAreas = currentUserAreaDays.keys.toSet();
    Set<String> otherUserAreas = otherUserAreaDays.keys.toSet();

    // Calculate intersection and union of areas
    Set<String> intersection = currentUserAreas.intersection(otherUserAreas);
    Set<String> union = currentUserAreas.union(otherUserAreas);

    // Jaccard similarity formula: intersection size / union size
    return intersection.length / union.length;
  }

  double _travellerWeight(int mine, int theirs) {
    final diff = (mine - theirs).abs();
    if (diff == 0) return 1.00;
    if (diff == 1) return 0.60; // was 0.85
    return 0.40; // was 0.70
  }

  double _dayCountWeight(int mine, int theirs) {
    final diff = (mine - theirs).abs();
    if (diff == 0) return 1.00;
    if (diff == 1) return 0.90;
    if (diff == 2) return 0.80;
    return 0.70;
  }

  /// Helper method to check if a user overspent by querying expenses subcollection
  Future<bool> _didUserOverspend(String tripId, double budget) async {
    try {
      if (budget <= 0) {
        print("🛠️ Debug: Invalid budget for trip $tripId");
        return false;
      }

      // Query all expenses for this trip
      var expensesQuery =
          await FirebaseFirestore.instance
              .collection('trips')
              .doc(tripId)
              .collection('expenses')
              .get();

      double totalExpenses = 0.0;

      // Sum up all expenses
      for (var expenseDoc in expensesQuery.docs) {
        var expenseData = expenseDoc.data();
        double amount = (expenseData['amount'] as num?)?.toDouble() ?? 0.0;

        // Optional: Filter by currency if needed
        String currency = expenseData['currency'] ?? 'MYR';
        if (currency == 'MYR') {
          totalExpenses += amount;
        }

        print(
          "🛠️ Debug: Expense - Category: ${expenseData['category']}, Amount: $amount $currency",
        );
      }

      // Define overspent threshold (e.g., 10% over budget)
      double overspentThreshold = budget * 1.10; // 10% tolerance

      bool overspent = totalExpenses > overspentThreshold;

      print(
        "🛠️ Debug: Trip $tripId - Budget: $budget, Total Expenses: $totalExpenses, Overspent: $overspent",
      );

      return overspent;
    } catch (e) {
      print("🛠️ Debug: Error checking overspent status for trip $tripId: $e");
      return false; // Default to not overspent if error
    }
  }

  bool _isOutlierMAD(
    double value,
    List<double> allValues, {
    double threshold = 3.5,
  }) {
    if (allValues.length <= 2) return false;

    List<double> sorted = [...allValues]..sort();
    double median(List<double> xs) {
      if (xs.isEmpty) return 0;
      final n = xs.length;
      final mid = n ~/ 2;
      return n.isOdd ? xs[mid] : (xs[mid - 1] + xs[mid]) / 2;
    }

    final med = median(sorted);
    final absDevs = sorted.map((v) => (v - med).abs()).toList()..sort();
    final mad = median(absDevs);
    if (mad == 0) return false;

    final mz = 0.6745 * (value - med).abs() / mad;
    return mz > threshold;
  }

  Future<double> _estimateBudgetForUser(String userId) async {
    const double kDefaultPPD = 200.0; // ✅ fallback = RM 200 per person per day

    try {
      // Build current user's area profile from selections
      if (selectedAreas.isEmpty) {
        final myDays0 = _deriveMyDays();
        final myTrav0 = numberOfTravelers <= 0 ? 1 : numberOfTravelers;
        return kDefaultPPD * myTrav0 * (myDays0 <= 0 ? 1 : myDays0);
      }

      final Map<String, int> currentUserAreaDays = {
        for (final area in selectedAreas)
          if ((userAreaPicks[widget.userId]?[area] ?? 0) > 0)
            area: (userAreaPicks[widget.userId]?[area] ?? 0).toInt(),
      };

      final int myDays = _deriveMyDays();
      final int myTravellers = numberOfTravelers <= 0 ? 1 : numberOfTravelers;
      debugPrint("CF: my traveler count = $myTravellers, myDays = $myDays");

      // Pull all trips
      final snap = await FirebaseFirestore.instance.collection('trips').get();
      final rows = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final double budget = (data['budget'] as num?)?.toDouble() ?? 0.0;
        if (budget <= 0) continue;

        final int theirDays = _deriveDaysFromDoc(data);
        final int theirTrav = (data['numberOfTravelers'] as num?)?.toInt() ?? 1;

        // Overspend filter
        bool overspent = false;
        try {
          overspent = await _didUserOverspend(doc.id, budget);
        } catch (_) {
          overspent = false;
        }
        if (overspent) continue;

        // Area overlap (Jaccard)
        double baseSim = 1.0;
        if (data['areaDays'] is Map && currentUserAreaDays.isNotEmpty) {
          final theirs =
              (data['areaDays'] as Map).keys.map((e) => e.toString()).toSet();
          final mine = currentUserAreaDays.keys.toSet();
          final uni = theirs.union(mine).length;
          final inter = theirs.intersection(mine).length;
          baseSim = uni == 0 ? 0.0 : inter / uni;
          if (baseSim == 0.0) continue;
        }

        rows.add({
          'tripId': doc.id,
          'ownerId': (data['ownerId'] ?? '').toString(),
          'budget': budget,
          'days': theirDays,
          'numberOfTravelers': theirTrav,
          'similarity': baseSim,
        });
      }

      debugPrint("✅ CF per-trip candidates: ${rows.length}");

      // ✅ Fallback when no trips at all: use RM200/day/traveler
      if (rows.isEmpty) {
        return kDefaultPPD * myTravellers * (myDays <= 0 ? 1 : myDays);
      }

      // ✅ MAD outlier filtering on per-person-per-day
      {
        final allPpd =
            rows.map((r) {
              final b = (r['budget'] as num).toDouble();
              final t = (r['numberOfTravelers'] as num).toInt();
              final d = (r['days'] as num).toInt();
              final tt = t <= 0 ? 1 : t;
              final dd = d <= 0 ? 1 : d;
              return b / tt / dd;
            }).toList();

        // remove rows whose ppd is an outlier by MAD
        rows.removeWhere((r) {
          final b = (r['budget'] as num).toDouble();
          final t = (r['numberOfTravelers'] as num).toInt();
          final d = (r['days'] as num).toInt();
          final tt = t <= 0 ? 1 : t;
          final dd = d <= 0 ? 1 : d;
          final ppd = b / tt / dd;
          return _isOutlierMAD(ppd, allPpd);
        });
        debugPrint("✂️ after MAD filtering: ${rows.length} rows remain");
      }

      // Exact-first by (travellers, days)
      final exactRows =
          rows
              .where(
                (r) =>
                    (r['numberOfTravelers'] ?? 0) == myTravellers &&
                    (r['days'] ?? 0) == myDays,
              )
              .toList();

      List<Map<String, dynamic>> used =
          exactRows.length >= 2 ? exactRows : rows;
      _lastEstimateBand = exactRows.length >= 2 ? 0.10 : 0.20;
      if (exactRows.length >= 2) {
        debugPrint("🎯 CF: using exact matches only (${exactRows.length})");
      }

      // Your existing percentile trimming (kept)
      if (used.length >= 6) {
        final ppdList =
            used.map((r) {
                final b = (r['budget'] as num).toDouble();
                final t = (r['numberOfTravelers'] as num).toInt().clamp(1, 999);
                final d = (r['days'] as num).toInt().clamp(1, 999);
                return b / t / d;
              }).toList()
              ..sort();

        double p10 = ppdList[(ppdList.length * 0.10).floor()];
        double p90 = ppdList[(ppdList.length * 0.90).floor()];

        final trimmed =
            used.where((r) {
              final b = (r['budget'] as num).toDouble();
              final t = (r['numberOfTravelers'] as num).toInt().clamp(1, 999);
              final d = (r['days'] as num).toInt().clamp(1, 999);
              final ppd = b / t / d;
              return ppd >= p10 && ppd <= p90;
            }).toList();

        if (trimmed.length >= 3) {
          used = trimmed;
          debugPrint("✂️ trimmed outliers: kept ${used.length}/${rows.length}");
        }
      }

      // Weighted mean of per-person-per-day
      double weightedSum = 0.0, totalWeight = 0.0;
      for (final r in used) {
        final int theirTrav = (r['numberOfTravelers'] as int?) ?? 1;
        final int theirDays = (r['days'] as int?) ?? 1;
        final double b = (r['budget'] as num?)?.toDouble() ?? 0.0;
        final double baseSim = (r['similarity'] as num?)?.toDouble() ?? 0.0;
        if (b <= 0) continue;

        final double ppd =
            b /
            (theirTrav <= 0 ? 1 : theirTrav) /
            (theirDays <= 0 ? 1 : theirDays);
        final double travW = _travellerWeight(myTravellers, theirTrav);
        final double dayW = _dayCountWeight(myDays, theirDays);
        final double w = baseSim * travW * dayW;

        weightedSum += ppd * w;
        totalWeight += w;

        debugPrint(
          "🧮 CF row -> trip:${r['tripId']} | owner:${r['ownerId']} | "
          "theirTrav:$theirTrav | theirDays:$theirDays | budget:${b.toStringAsFixed(2)} | "
          "pp/day:${ppd.toStringAsFixed(2)} | baseSim:${baseSim.toStringAsFixed(3)} | "
          "travW:${travW.toStringAsFixed(2)} | dayW:${dayW.toStringAsFixed(2)} | w:${w.toStringAsFixed(3)}",
        );
      }

      if (totalWeight == 0.0) {
        // fallback: unweighted mean if we still have data
        if (used.isNotEmpty) {
          final avgPPD =
              used
                  .map((r) {
                    final b = (r['budget'] as num).toDouble();
                    final t = (r['numberOfTravelers'] as num).toInt();
                    final d = (r['days'] as num).toInt();
                    return b / (t <= 0 ? 1 : t) / (d <= 0 ? 1 : d);
                  })
                  .fold<double>(0.0, (s, v) => s + v) /
              used.length;
          final tot = avgPPD * myTravellers * (myDays <= 0 ? 1 : myDays);
          return (tot > 0)
              ? tot
              : kDefaultPPD * myTravellers * (myDays <= 0 ? 1 : myDays);
        }

        // if somehow nothing usable → default
        return kDefaultPPD * myTravellers * (myDays <= 0 ? 1 : myDays);
      }

      final ppd = weightedSum / totalWeight;
      final totalEstimate = ppd * myTravellers * (myDays <= 0 ? 1 : myDays);

      // ✅ final safety fallback if negative/zero for any reason
      if (totalEstimate <= 0) {
        return kDefaultPPD * myTravellers * (myDays <= 0 ? 1 : myDays);
      }

      debugPrint(
        "🛠️ Debug: Weighted sum: ${weightedSum.toStringAsFixed(2)} | Total weight: ${totalWeight.toStringAsFixed(2)}",
      );
      debugPrint(
        "✅ CF result -> perPersonPerDay:${ppd.toStringAsFixed(2)} | myTravellers:$myTravellers | myDays:$myDays | total:${totalEstimate.toStringAsFixed(2)}",
      );

      return totalEstimate;
    } catch (e) {
      debugPrint("CF error: $e");
      // ✅ on any error, return RM200/day/traveler fallback
      final myDays = _deriveMyDays();
      final myTravellers = numberOfTravelers <= 0 ? 1 : numberOfTravelers;
      return kDefaultPPD * myTravellers * (myDays <= 0 ? 1 : myDays);
    }
  }

  void _validateDateRange() {
    if (startDate == null || endDate == null) return;

    int selectedTripDays = endDate!.difference(startDate!).inDays + 1;
    int requiredTripDays = 0;
    for (var area in selectedAreas) {
      requiredTripDays += (userAreaPicks[widget.userId]?[area] ?? 0).toInt();
    }

    if (selectedTripDays != requiredTripDays && requiredTripDays > 0) {
      // Show validation error immediately
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              elevation: 8,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Date Range Mismatch',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _brandDark,
                      ),
                    ),
                  ),
                ],
              ),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  'Your areas require $requiredTripDays day(s), but your selected dates cover $selectedTripDays day(s).\n\nPlease adjust your dates or area days.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Clear the conflicting dates
                    setState(() {
                      startDate = null;
                      endDate = null;
                    });
                  },
                  child: Text('Clear Dates'),
                ),
              ],
            ),
      );
    }
  }

  List<Map<String, dynamic>> _filterOutliers(
    List<Map<String, dynamic>> trips, {
    double madThreshold = 3.5,
  }) {
    if (trips.length <= 2) return trips; // too few to filter

    final budgets = trips.map((t) => t['budget'] as num).toList()..sort();

    num _median(List<num> xs) {
      if (xs.isEmpty) return 0;
      final n = xs.length;
      final mid = n ~/ 2;
      return n.isOdd ? xs[mid] : (xs[mid - 1] + xs[mid]) / 2;
    }

    final med = _median(budgets);

    final absDevs = budgets.map((b) => (b - med).abs()).toList()..sort();
    final mad = _median(absDevs);
    if (mad == 0) return trips;

    bool isOutlier(num b) {
      final mz = 0.6745 * (b - med).abs() / mad;
      return mz > madThreshold;
    }

    return trips.where((t) => !isOutlier(t['budget'] as num)).toList();
  }

  Widget _buildBudgetEstimationWidget() {
    if (selectedAreas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Budget Estimation",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: _brandDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Please select areas first to see budget estimation.",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                "Budget Estimation",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: _brandDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<double>(
            future: _estimateBudgetForUser(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Calculating...",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                );
              } else if (snapshot.hasError) {
                return Text(
                  "Error calculating estimate: ${snapshot.error}",
                  style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
                );
              } else {
                final estimatedBudget = snapshot.data ?? 0.0;
                if (estimatedBudget == 0.0) {
                  return Text(
                    "No similar trips found. Consider RM300–500 per day as a starting point.",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.blue[800],
                    ),
                  );
                } else {
                  final band = _lastEstimateBand;
                  final lower = estimatedBudget * (1 - band);
                  final upper = estimatedBudget * (1 + band);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          "Suggested Range: RM ${lower.toStringAsFixed(0)} - RM ${upper.toStringAsFixed(0)}",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.green[800],
                          ),
                        ),
                      ),
                      if (band == 0.10) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Based on exact matches (same travellers & days).",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ],
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // UPDATED MAIN BUILD METHOD - UI Components with ItineraryTab Styling
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        body: Center(
          child: CircularProgressIndicator(color: _brandDark, strokeWidth: 3),
        ),
      );
    }

    // Keep your existing postFrameCallback logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_preferenceLoaded) {
        bool hasValidPreferences = newUserPrefs.entries.any(
          (entry) =>
              entry.key != 'Food' &&
              entry.key != 'Accommodation' &&
              entry.value > 7,
        );
        if (!hasValidPreferences) {
          _askPreferences();
        }
        _preferenceLoaded = true;
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          'Plan Your Trip',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            shadows: [
              Shadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _brandDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _brandDark),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Trip Title Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [Colors.white, _brand.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _brand.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.edit_note_rounded,
                              color: _brandDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Trip Title',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _brandDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.poppins(),
                        decoration: InputDecoration(
                          hintText: 'e.g. Family Holiday in Penang 🎉',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _brand, width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a trip title';
                          }
                          if (v.length < 3) {
                            return 'Title too short';
                          }
                          return null;
                        },
                        onChanged: (v) => setState(() => tripTitle = v.trim()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Areas Section
              Text(
                'Choose Areas:',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  color: _brandDark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: () {
                  final suggestions = _getAreaSuggestions();
                  final sortedSuggestions =
                      suggestions.entries.toList()..sort(
                        (a, b) => b.value.compareTo(a.value),
                      ); // Sort by score descending

                  return sortedSuggestions.map((entry) {
                    final area = entry.key;
                    final score = entry.value;

                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 40) / 2,
                      child: Card(
                        elevation: 2,
                        child: CheckboxListTile(
                          title: Text('$area (${score.toStringAsFixed(1)})'),
                          value: selectedAreas.contains(area),
                          onChanged: (bool? value) async {
                            if (value == true) {
                              int? selectedDays = await showDialog<int>(
                                context: context,
                                builder: (context) {
                                  int tempDays = 1;
                                  return AlertDialog(
                                    title: Text('Days for $area'),
                                    content: StatefulBuilder(
                                      builder:
                                          (context, setState) => Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'Select number of days:',
                                              ),
                                              Slider(
                                                value: tempDays.toDouble(),
                                                min: 1,
                                                max: 5,
                                                divisions: 4,
                                                label: '$tempDays',
                                                onChanged: (value) {
                                                  setState(() {
                                                    tempDays = value.toInt();
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                    ),
                                    actions: [
                                      TextButton(
                                        child: const Text('Confirm'),
                                        onPressed:
                                            () => Navigator.of(
                                              context,
                                            ).pop(tempDays),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (selectedDays != null) {
                                setState(() {
                                  selectedAreas.add(area);
                                  _saveAreaPick(area, selectedDays);
                                });
                                // Validate date range immediately after area change
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _validateDateRange();
                                });
                              }
                            } else {
                              setState(() {
                                selectedAreas.remove(area);
                                _saveAreaPick(area, 0);
                              });
                              // Validate after removing area too
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _validateDateRange();
                              });
                            }
                          },
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    );
                  }).toList();
                }(),
              ),
              const SizedBox(height: 20),

              // Date Range Card - Updated to use brand colors
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Color(0xFFBCAAA4).withOpacity(0.1),
                      ], // Lighter brown variant
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(
                          0xFFBCAAA4,
                        ).withOpacity(0.3), // Lighter brown
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: Color(0xFF5D4037),
                      ), // Darker brown
                    ),
                    title: Text(
                      (startDate == null || endDate == null)
                          ? 'Pick a Date Range'
                          : 'Dates: ${startDate!.toString().substring(0, 10)} to ${endDate!.toString().substring(0, 10)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        color: _brandDark,
                      ),
                    ),
                    onTap: () => _selectDateRange(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Travelers Card - Updated to use brand colors
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Color(0xFFA1887F).withOpacity(0.1),
                      ], // Medium brown variant
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(
                                0xFFA1887F,
                              ).withOpacity(0.3), // Medium brown
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.group,
                              color: Color(0xFF4E342E),
                            ), // Dark brown
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Number of Travelers',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _brandDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(),
                        decoration: InputDecoration(
                          hintText: 'e.g. 2',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Color(0xFFA1887F),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        onChanged: (value) {
                          setState(() {
                            numberOfTravelers = int.tryParse(value) ?? 2;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Budget Card - Updated to use brand colors
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Color(0xFF8D6E63).withOpacity(0.1),
                      ], // Medium-dark brown variant
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF8D6E63).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.monetization_on,
                              color: Color(0xFF3E2723), // Very dark brown
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Budget Planning',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _brandDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(),
                        decoration: InputDecoration(
                          labelText: 'Enter Budget (MYR)',
                          labelStyle: GoogleFonts.poppins(),
                          hintText: 'e.g. 2000',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Color(0xFF8D6E63),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        onChanged: (value) {
                          setState(() {
                            budget = double.tryParse(value) ?? 0.0;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildBudgetEstimationWidget(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Plan Style Card - Updated to use brand colors
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Color(0xFF795548).withOpacity(0.1),
                      ], // Another brown variant
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF795548).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.style, color: Color(0xFF3E2723)),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Plan Style',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _brandDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            PlanStyle.values.map((style) {
                              final isSelected = _selectedPlanStyle == style;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                child: ChoiceChip(
                                  label: Text(
                                    '${style.emoji} ${style.label}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : _brandDark,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: Color(0xFF795548),
                                  backgroundColor: Colors.grey[100],
                                  onSelected: (sel) {
                                    if (sel) {
                                      setState(
                                        () => _selectedPlanStyle = style,
                                      );
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFFE8DDD4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _styleDescriptions[_selectedPlanStyle]!,
                          style: GoogleFonts.poppins(
                            color: _brandDark,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Budget Mode Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [Colors.white, _brand.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _brand.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.hotel, color: _brandDark),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Budget Mode',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _brandDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ToggleButtons(
                          isSelected: [useHotelLevel, !useHotelLevel],
                          onPressed: (index) {
                            setState(() {
                              useHotelLevel = index == 0;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          fillColor: _brand,
                          selectedColor: _brandDark,
                          color: Colors.grey[600],
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                'Hotel Level',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                'Budget Level',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (useHotelLevel)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose Hotel Level (1–5 Stars)',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                color: _brandDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: _brand,
                                thumbColor: _brandDark,
                                overlayColor: _brand.withOpacity(0.2),
                              ),
                              child: Slider(
                                value: selectedHotelLevel.toDouble(),
                                min: 1,
                                max: 5,
                                divisions: 4,
                                label: selectedHotelLevel.toString(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedHotelLevel = value.toInt();
                                  });
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _brand.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                accommodationLevels[selectedHotelLevel] ?? '',
                                style: GoogleFonts.poppins(
                                  color: _brandDark,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enter Hotel Budget (MYR)',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                color: _brandDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _hotelManualAmountController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.poppins(),
                              decoration: InputDecoration(
                                hintText: 'e.g. 600',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _brand,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isTripPlanReady()
                              ? () => _generateTripPlan(context)
                              : null,
                      icon: Icon(Icons.auto_awesome, size: 20),
                      label: Text(
                        'Generate Itinerary',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isTripPlanReady() ? _brandDark : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _isTripPlanReady() ? 3 : 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          tripPicks.isNotEmpty ||
                                  userAreaPicks[widget.userId]?.isNotEmpty ==
                                      true
                              ? () => _showBookingPrompt()
                              : null,
                      icon: Icon(Icons.save, size: 20),
                      label: Text(
                        'Save Trip',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            tripPicks.isNotEmpty ||
                                    userAreaPicks[widget.userId]?.isNotEmpty ==
                                        true
                                ? Color(
                                  0xFF8D6E63,
                                ) // Brown variant for save button
                                : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation:
                            tripPicks.isNotEmpty ||
                                    userAreaPicks[widget.userId]?.isNotEmpty ==
                                        true
                                ? 3
                                : 1,
                      ),
                    ),
                  ),
                ],
              ),

              // Selected Hotel Display - Updated colors
              if (selectedHotel != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Selected Hotel:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: _brandDark,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFE8DDD4),
                          Color(0xFFD7CCC8),
                        ], // Light to medium brand colors
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _brandDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.check_circle, color: Colors.white),
                      ),
                      title: Text(
                        selectedHotel!['properties']['name'],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _brandDark,
                        ),
                      ),
                      subtitle: Text(
                        "Room: $selectedRoomType — RM ${selectedHotel!['roomPrice']}",
                        style: GoogleFonts.poppins(color: Color(0xFF5D4037)),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Trip Messages Section (Live Itinerary)
              Text(
                'Your Trip Plan:',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  color: _brandDark,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      messages.where((message) {
                        // Filter out AI conversational messages
                        if (message is Text) {
                          return !message.data!.startsWith('AI:');
                        } else if (message is Container) {
                          // Check if container contains AI text
                          final child = message.child;
                          if (child is Text) {
                            return !child.data!.startsWith('AI:');
                          }
                        }
                        return true; // Keep non-AI messages
                      }).length,
                  itemBuilder: (context, index) {
                    final filteredMessages =
                        messages.where((message) {
                          // Same filtering logic
                          if (message is Text) {
                            return !message.data!.startsWith('AI:');
                          } else if (message is Container) {
                            final child = message.child;
                            if (child is Text) {
                              return !child.data!.startsWith('AI:');
                            }
                          }
                          return true;
                        }).toList();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: filteredMessages[index],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

extension TimesExtension on int {
  void times(void Function(int) action) {
    for (int i = 0; i < this; i++) {
      action(i);
    }
  }
}
