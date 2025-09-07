// lib/scripts/categorize_accommodations.dart
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

// Helper functions
List<String> _extractAmenities(String name, int priceLevel) {
  final List<String> amenities = ['Wi-Fi', 'Air Conditioning'];
  final nameLower = name.toLowerCase();

  // Base amenities by price level
  if (priceLevel >= 3) {
    amenities.addAll(['TV', '24-hour Reception']);
  }
  if (priceLevel >= 4) {
    amenities.addAll(['Room Service', 'Concierge']);
  }
  if (priceLevel >= 5) {
    amenities.addAll(['Spa Services', 'Fitness Center']);
  }

  // Infer from name
  if (nameLower.contains('resort') || nameLower.contains('beach')) {
    amenities.add('Swimming Pool');
  }
  if (nameLower.contains('spa')) {
    amenities.add('Spa Services');
  }
  if (nameLower.contains('business')) {
    amenities.add('Business Center');
  }

  return amenities.toSet().toList(); // Remove duplicates
}

String _determineHotelClass(String name, double rating, int priceLevel) {
  final nameLower = name.toLowerCase();

  if (nameLower.contains('resort')) return 'Resort';
  if (nameLower.contains('boutique')) return 'Boutique Hotel';
  if (nameLower.contains('inn') || nameLower.contains('guesthouse'))
    return 'Inn';
  if (nameLower.contains('hostel') || nameLower.contains('backpack'))
    return 'Hostel';
  if (priceLevel >= 5 || rating >= 4.5) return 'Luxury Hotel';
  if (priceLevel >= 4 || rating >= 4.0) return 'Upscale Hotel';
  if (priceLevel <= 2) return 'Budget Hotel';
  return 'Standard Hotel';
}

bool _isBeachfront(String address, String name) {
  final combined = '$address $name'.toLowerCase();
  return combined.contains('batu ferringhi') ||
      combined.contains('beach') ||
      combined.contains('seafront') ||
      combined.contains('tanjung bungah');
}

bool _isCityCenter(String address) {
  final addressLower = address.toLowerCase();
  return addressLower.contains('george town') ||
      addressLower.contains('georgetown') ||
      addressLower.contains('lebuh');
}

double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
  const double earthRadius = 6371000;
  final double dLat = (lat2 - lat1) * pi / 180;
  final double dLng = (lng2 - lng1) * pi / 180;
  final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

Future<void> categorizeAccommodations(String state, String area) async {
  print("📋 Categorizing accommodations in $state, $area...");
  try {
    var places =
        await FirebaseFirestore.instance
            .collection('areas')
            .doc(area)
            .collection('places')
            .where('category', isEqualTo: 'accommodation')
            .get();

    for (var doc in places.docs) {
      var data = doc.data();
      double rating = (data['rating'] as num?)?.toDouble() ?? 3.0;
      String category = (data['category'] ?? '').toLowerCase();
      int userRatings = (data['user_ratings_total'] as num?)?.toInt() ?? 0;
      String address = data['address'] ?? '';
      String name = data['name'] ?? 'Unknown';

      // Get coordinates if available
      final coords = data['coordinates'] as GeoPoint?;
      final lat = coords?.latitude ?? 0.0;
      final lng = coords?.longitude ?? 0.0;

      int priceLevel;
      double estimatedCost;

      // Price level logic (your existing logic)
      if (category.contains('hostel') || rating <= 3.5 || userRatings < 100) {
        priceLevel = 1;
        estimatedCost = 100.0;
      } else if (rating <= 3.9 ||
          category.contains('guesthouse') ||
          name.contains('Tune') ||
          name.contains('SO Hotel')) {
        priceLevel = 2;
        estimatedCost = 200.0;
      } else if (rating <= 4.2 || userRatings > 500) {
        priceLevel = 3;
        estimatedCost = 400.0;
      } else if (rating <= 4.6) {
        priceLevel = 4;
        estimatedCost = 800.0;
      } else {
        priceLevel = 5;
        estimatedCost = 1500.0;
      }

      // Dynamic room pricing (your existing logic)
      double singlePrice, familyPrice;
      switch (priceLevel) {
        case 1:
          singlePrice = 80.0;
          familyPrice = 150.0;
          break;
        case 2:
          singlePrice = 120.0;
          familyPrice = 250.0;
          break;
        case 3:
          singlePrice = 200.0;
          familyPrice = 400.0;
          break;
        case 4:
          singlePrice = 400.0;
          familyPrice = 800.0;
          break;
        case 5:
          singlePrice = 600.0;
          familyPrice = 1200.0;
          break;
        default:
          singlePrice = 200.0;
          familyPrice = 400.0;
      }

      // NEW: Enhanced amenities and details
      final amenities = _extractAmenities(name, priceLevel);
      final hotelClass = _determineHotelClass(name, rating, priceLevel);
      final isBeachfront = _isBeachfront(address, name);
      final isCityCenter = _isCityCenter(address);

      // Check if near airport (Penang Airport coordinates)
      final isNearAirport =
          lat != 0.0 && lng != 0.0
              ? _calculateDistance(lat, lng, 5.2971, 100.2769) <= 5000
              : false;

      await doc.reference.update({
        'price_level': priceLevel,
        'estimated_cost': estimatedCost,
        'roomTypes': {
          'single': {'price': singlePrice, 'amenities': amenities},
          'family': {
            'price': familyPrice,
            'amenities': [...amenities, 'Extra Bed'],
          },
        },
        // NEW FIELDS:
        'hotelClass': hotelClass,
        'amenities': amenities,
        'policies': {
          'cancellation':
              priceLevel >= 4
                  ? 'Free cancellation up to 48 hours'
                  : 'Free cancellation up to 24 hours',
          'children': 'Children allowed',
          'pets': priceLevel >= 4 ? 'Pets allowed with fee' : 'No pets allowed',
          'smoking': 'Non-smoking property',
        },
        'location': {
          'beachfront': isBeachfront,
          'cityCenter': isCityCenter,
          'nearAirport': isNearAirport,
        },
        'wifi': {
          'available': true,
          'free': priceLevel <= 3,
          'areas':
              priceLevel >= 3
                  ? ['Lobby', 'Rooms', 'Restaurant']
                  : ['Lobby', 'Rooms'],
        },
        'parking': {
          'available': true,
          'free': priceLevel <= 2,
          'type': 'Self-parking',
        },
        'languages': ['English', 'Malay', 'Chinese'],
        'paymentMethods':
            priceLevel >= 3
                ? ['Cash', 'Credit Card', 'Debit Card', 'Digital Wallet']
                : ['Cash', 'Credit Card'],
      });

      print(
        "✅ Updated $name: $hotelClass, Level $priceLevel, MYR $estimatedCost",
      );
    }
  } catch (e) {
    print("🚨 Error categorizing $state, $area: $e");
  }
}

Future<void> runForAllStates() async {
  var statesAndAreas = {
    'Penang': [
      'George Town',
      'Tanjung Bungah',
      'Buttterworth',
      'Tanjung Tokong',
      'Balik Pulau',
      'Bayan Lepas',
      'Batu Ferringhi',
    ],
  };

  for (var state in statesAndAreas.keys) {
    for (var area in statesAndAreas[state]!) {
      await categorizeAccommodations(state, area);
    }
  }
  print("🎉 All accommodations categorized!");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    print("✅ Firebase initialized successfully");
    await runForAllStates();
    print("🎉 Categorization completed!");
  } catch (e) {
    print("🚨 Error during initialization or categorization: $e");
  }
}
