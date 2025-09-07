import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'my_trips_screen.dart';
import 'main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> _resolvePendingBookingNotification({
  required String receiverUid,
  required String tripId,
  required String bookingId,
  bool alsoEmitConfirmed = true,
  String? tripTitle,
  String? hotelName,
}) async {
  final pendingId = 'booking_pending_${tripId}_$bookingId';
  final notifRef = FirebaseFirestore.instance
      .collection('notifications')
      .doc(pendingId);

  try {
    await notifRef.update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    debugPrint("⚠️ resolvePending: couldn't update $pendingId → $e");
  }

  if (alsoEmitConfirmed) {
    final confirmedId = 'booking_confirmed_${tripId}_$bookingId';
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(confirmedId)
        .set({
          'type': 'booking_confirmed',
          'status': 'new',
          'senderId': receiverUid,
          'receiverId': receiverUid,
          'tripId': tripId,
          'tripTitle': tripTitle ?? 'Your trip',
          'hotelName': hotelName ?? 'Accommodation',
          'createdAt': FieldValue.serverTimestamp(),
          'message':
              'Trip • ${tripTitle ?? 'Your trip'}\nYour booking at ${hotelName ?? 'Accommodation'} is confirmed.',
          'action': 'open_booking',
          'actionPayload': {'tripId': tripId, 'bookingId': bookingId},
        });
  }
}

Future<void> _emitBookingPendingNotification({
  required String receiverUid,
  required String tripId,
  required String tripTitle,
  required Map<String, dynamic> hotelNormalized,
  required DateTime checkIn,
  required DateTime checkOut,
  String? bookingId,
  int adults = 1,
  bool isSandbox = true,
  double? pricePerNight,
}) async {
  debugPrint("🟪 [Notif] ENTER emit booking_pending");
  debugPrint(
    "🟪 [Notif] receiverUid=$receiverUid tripId=$tripId bookingId=${bookingId ?? '(null)'} tripTitle='$tripTitle'",
  );
  final authUid = FirebaseAuth.instance.currentUser?.uid;
  debugPrint("🟪 [Notif] current auth uid: ${authUid ?? '(none)'}");

  final checkInStr =
      '${checkIn.year}-${checkIn.month.toString().padLeft(2, '0')}-${checkIn.day.toString().padLeft(2, '0')}';
  final checkOutStr =
      '${checkOut.year}-${checkOut.month.toString().padLeft(2, '0')}-${checkOut.day.toString().padLeft(2, '0')}';
  final hotelName =
      (hotelNormalized['properties']?['name'] ?? 'Accommodation').toString();

  if (authUid == null || authUid != receiverUid) {
    debugPrint(
      "⚠️ [Notif] auth uid mismatch (auth=$authUid, receiver=$receiverUid). Write may fail Firestore rules.",
    );
  }

  final id =
      (bookingId != null && bookingId.isNotEmpty)
          ? 'booking_pending_${tripId}_$bookingId'
          : null;

  final notifRef =
      id == null
          ? FirebaseFirestore.instance.collection('notifications').doc()
          : FirebaseFirestore.instance.collection('notifications').doc(id);

  try {
    if (id != null) {
      final exists = await notifRef.get();
      debugPrint("🟪 [Notif] using fixed id='$id' exists=${exists.exists}");
      if (exists.exists) {
        debugPrint("🟪 [Notif] same id already exists → skip");
        return;
      }
    } else {
      debugPrint("🟪 [Notif] generating random id: ${notifRef.id}");
    }
  } catch (e, st) {
    debugPrint("⚠️ [Notif] pre-check failed: $e\n$st");
  }

  final payload = {
    'type': 'booking_pending',
    'status': 'new',
    'senderId': receiverUid,
    'receiverId': receiverUid,
    'tripId': tripId,
    'tripTitle': tripTitle,
    'bookingId': bookingId,
    'hotelName': hotelName,
    'checkIn': checkInStr,
    'checkOut': checkOutStr,
    'message': 'Trip • $tripTitle\nYour booking at $hotelName is pending.',
    'createdAt': FieldValue.serverTimestamp(),
    'action': 'open_booking',
    'actionPayload': {
      'tripId': tripId,
      'bookingId': bookingId,
      'checkIn': checkInStr,
      'checkOut': checkOutStr,
      'adults': adults,
      'isSandbox': isSandbox,
      'pricePerNight': pricePerNight,
      'hotel': {
        'id': hotelNormalized['id'],
        'properties': {
          'name': hotelNormalized['properties']?['name'],
          'address': hotelNormalized['properties']?['address'],
          'primaryPhotoUrl': hotelNormalized['properties']?['primaryPhotoUrl'],
          'area': hotelNormalized['properties']?['area'],
          'placeDocPath': hotelNormalized['properties']?['placeDocPath'],
        },
        'geometry': hotelNormalized['geometry'],
      },
    },
  };

  debugPrint("🟪 [Notif] write path: ${notifRef.path}");
  debugPrint(
    "🟪 [Notif] hotelNormalized.id=${hotelNormalized['id']} placeDocPath=${hotelNormalized['properties']?['placeDocPath']}",
  );

  try {
    await notifRef.set(payload);
    debugPrint("✅ [Notif] booking_pending written.");
  } on FirebaseException catch (e, st) {
    debugPrint("🚨 [Notif] FirebaseException: ${e.code} ${e.message}\n$st");
    rethrow;
  } catch (e, st) {
    debugPrint("🚨 [Notif] Unknown error: $e\n$st");
    rethrow;
  }

  debugPrint("🟪 [Notif] EXIT emit booking_pending");
}

Future<void> backfillBookingHotel({
  required String tripId,
  required String bookingId,
}) async {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('bookings')
      .doc(bookingId);

  final snap = await ref.get();
  if (!snap.exists) return;

  final m = snap.data()!;
  final hotel =
      (m['hotel'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};

  if ((hotel['id'] ?? '').toString().isNotEmpty &&
      (hotel['primaryPhotoUrl'] ?? '').toString().isNotEmpty) {
    return;
  }

  final resolved = await ensureResolvedHotel({
    'id': hotel['id'],
    'properties': {
      'name': hotel['name'],
      'address': hotel['address'],
      'placeDocPath': hotel['placeDocPath'],
      'area': hotel['area'],
      'primaryPhotoUrl': hotel['primaryPhotoUrl'],
    },
    'geometry': {
      'coordinates': [hotel['lng'], hotel['lat']],
    },
  });

  final coords =
      (resolved['geometry']?['coordinates'] as List?) ?? const [null, null];

  final newHotelMap = {
    'id': resolved['id'],
    'name': resolved['properties']?['name'],
    'address': resolved['properties']?['address'],
    'lat': coords.length > 1 ? coords[1] : null,
    'lng': coords.isNotEmpty ? coords[0] : null,
    if ((resolved['properties']?['placeDocPath'] ?? '').toString().isNotEmpty)
      'placeDocPath': resolved['properties']['placeDocPath'],
    if ((resolved['properties']?['area'] ?? '').toString().isNotEmpty)
      'area': resolved['properties']['area'],
    if ((resolved['properties']?['primaryPhotoUrl'] ?? '')
        .toString()
        .isNotEmpty)
      'primaryPhotoUrl': resolved['properties']['primaryPhotoUrl'],
  };

  await ref.update({'hotel': newHotelMap});
}

Map<String, dynamic> _hotelFromPlaceDoc(
  DocumentSnapshot<Map<String, dynamic>> d,
) {
  final m = d.data() ?? {};
  final props = (m['properties'] as Map?) ?? {};
  final double? lat =
      (m['lat'] as num?)?.toDouble() ?? (props['lat'] as num?)?.toDouble();
  final double? lng =
      (m['lng'] as num?)?.toDouble() ?? (props['lng'] as num?)?.toDouble();

  return {
    'id': m['id'] ?? props['placeId'] ?? d.id,
    'properties': {
      'name': props['name'] ?? m['name'] ?? 'Accommodation',
      'address': props['address'] ?? m['address'] ?? '',
      'phone': props['phone'] ?? m['phone'],
      'website': props['website'] ?? m['website'],
      'rating':
          (props['rating'] ?? m['rating']) is num
              ? (props['rating'] ?? m['rating']).toDouble()
              : null,
      'reviews': props['reviews'] ?? m['reviews'],
      'priceLevel': props['priceLevel'] ?? m['priceLevel'],
      'checkInTime': props['checkInTime'] ?? m['checkInTime'],
      'checkOutTime': props['checkOutTime'] ?? m['checkOutTime'],
      'primaryPhotoUrl': props['primaryPhotoUrl'] ?? m['primaryPhotoUrl'],
      'photoUrls': (props['photoUrls'] as List?)?.cast<String>() ?? const [],
      'amenities': (props['amenities'] as List?)?.cast<String>() ?? const [],
      'roomTypes':
          (props['roomTypes'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          <String, dynamic>{},
      'emptyRoomsByDate':
          (props['emptyRoomsByDate'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          <String, dynamic>{},
      'placeId': props['placeId'] ?? m['id'] ?? d.id,
      'area': d.reference.parent.parent?.id,
      'placeDocPath': d.reference.path,
    },
    'geometry': {
      'coordinates': [(lng ?? 0.0).toDouble(), (lat ?? 0.0).toDouble()],
    },
  };
}

Future<Map<String, dynamic>> ensureResolvedHotel(
  Map<String, dynamic> raw,
) async {
  final props = (raw['properties'] as Map?) ?? {};
  final name = (props['name'] ?? raw['name'])?.toString();
  final addr = (props['address'] ?? raw['address'])?.toString();
  final placeId = (props['placeId'] ?? raw['placeId'] ?? raw['id'])?.toString();

  bool _isRich(Map m) {
    final p = (m['properties'] as Map?) ?? {};
    final hasPrimary = ((p['primaryPhotoUrl'] ?? '') as String).isNotEmpty;
    final hasList =
        (p['photoUrls'] is List) && (p['photoUrls'] as List).isNotEmpty;
    return (m['id'] ?? p['placeId']) != null && (hasPrimary || hasList);
  }

  if (_isRich(raw)) {
    debugPrint("🔎 ensureResolvedHotel: already rich (has photos).");
    return raw;
  }

  debugPrint(
    "🔎 ensureResolvedHotel: need hydration. "
    "name='$name' placeId='${placeId ?? '(null)'}' "
    "area='${props['area']}' placeDocPath='${props['placeDocPath']}'",
  );

  final docPath = props['placeDocPath']?.toString();
  if (docPath != null && docPath.startsWith('/areas/')) {
    try {
      final doc = await FirebaseFirestore.instance.doc(docPath).get();
      if (doc.exists) {
        debugPrint("✅ ensureResolvedHotel: loaded via placeDocPath");
        return _normalizeFromPlaceDoc(doc);
      }
    } catch (e) {
      debugPrint("⚠️ ensureResolvedHotel: placeDocPath load failed: $e");
    }
  }

  if (placeId != null && placeId.isNotEmpty) {
    try {
      final byId =
          await FirebaseFirestore.instance
              .collectionGroup('places')
              .where('id', isEqualTo: placeId)
              .limit(1)
              .get();
      if (byId.docs.isNotEmpty) {
        debugPrint(
          "✅ ensureResolvedHotel: found by collectionGroup 'id' == placeId",
        );
        return _normalizeFromPlaceDoc(byId.docs.first);
      }

      final byProps =
          await FirebaseFirestore.instance
              .collectionGroup('places')
              .where('properties.placeId', isEqualTo: placeId)
              .limit(1)
              .get();
      if (byProps.docs.isNotEmpty) {
        debugPrint(
          "✅ ensureResolvedHotel: found by collectionGroup properties.placeId",
        );
        return _normalizeFromPlaceDoc(byProps.docs.first);
      }
    } catch (e) {
      debugPrint("⚠️ ensureResolvedHotel: collectionGroup(placeId) failed: $e");
    }
  }

  final likelyAreas =
      <String>[
        (props['area'] ?? '').toString(),
        'George Town',
        'Tanjung Bungah',
        'Batu Ferringhi',
        'Bayan Lepas',
        'Butterworth',
        'Ayer Itam',
        'Tanjung Tokong',
      ].where((s) => s.isNotEmpty).toSet().toList();

  for (final area in likelyAreas) {
    try {
      final q =
          await FirebaseFirestore.instance
              .collection('areas')
              .doc(area)
              .collection('places')
              .where('name', isEqualTo: name)
              .limit(1)
              .get();
      if (q.docs.isNotEmpty) {
        debugPrint("✅ ensureResolvedHotel: exact name match in area '$area'");
        return _normalizeFromPlaceDoc(q.docs.first, area: area);
      }
    } catch (e) {
      debugPrint(
        "⚠️ ensureResolvedHotel: exact name match failed in '$area': $e",
      );
    }
  }

  try {
    final coords =
        (raw['geometry']?['coordinates'] as List?)?.cast<num>() ??
        const <num>[];
    final lng =
        coords.isNotEmpty
            ? coords[0].toDouble()
            : (props['lng'] as num?)?.toDouble();
    final lat =
        coords.length > 1
            ? coords[1].toDouble()
            : (props['lat'] as num?)?.toDouble();

    double _haversine(double lat1, double lon1, double lat2, double lon2) {
      const R = 6371000.0;
      final dLat = (lat2 - lat1) * (3.1415926535 / 180);
      final dLon = (lon2 - lon1) * (3.1415926535 / 180);
      final a =
          (math.sin(dLat / 2) * math.sin(dLat / 2)) +
          math.cos(lat1 * (3.1415926535 / 180)) *
              math.cos(lat2 * (3.1415926535 / 180)) *
              (math.sin(dLon / 2) * math.sin(dLon / 2));
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return R * c;
    }

    final scanAreas =
        likelyAreas.isNotEmpty
            ? likelyAreas
            : [
              'George Town',
              'Tanjung Bungah',
              'Batu Ferringhi',
              'Bayan Lepas',
              'Butterworth',
              'Balik Pulau',
              'Tanjung Tokong',
            ];

    DocumentSnapshot<Map<String, dynamic>>? best;
    double bestScore = double.infinity;

    for (final area in scanAreas) {
      final all =
          await FirebaseFirestore.instance
              .collection('areas')
              .doc(area)
              .collection('places')
              .get();
      for (final d in all.docs) {
        final m = d.data();
        final p = (m['properties'] as Map?) ?? {};
        double score = 1e12;
        if (lat != null && lng != null) {
          final plat = (m['lat'] ?? p['lat']) as num? ?? 0;
          final plng = (m['lng'] ?? p['lng']) as num? ?? 0;
          score = _haversine(
            lat.toDouble(),
            lng.toDouble(),
            plat.toDouble(),
            plng.toDouble(),
          );
        } else if (name != null) {
          final docName =
              (p['name'] ?? m['name'] ?? '').toString().toLowerCase();
          final want = name.toLowerCase();
          final mismatch =
              (docName.contains(want) || want.contains(docName)) ? 0 : 10;
          score = (docName.length - want.length).abs() + mismatch.toDouble();
        }
        if (score < bestScore) {
          bestScore = score;
          best = d;
        }
      }
    }

    if (best != null && (bestScore < 150 || name != null)) {
      debugPrint(
        "✅ ensureResolvedHotel: picked best candidate (score=$bestScore)",
      );
      return _normalizeFromPlaceDoc(best);
    }
  } catch (e) {
    debugPrint("⚠️ ensureResolvedHotel: nearest/fuzzy step failed: $e");
  }

  debugPrint("⚪ ensureResolvedHotel: returning raw-normalized (no photos).");
  return normalizeHotelFromAny(raw);
}

Map<String, dynamic> _normalizeFromPlaceDoc(
  DocumentSnapshot<Map<String, dynamic>> doc, {
  String? area,
}) {
  final m = doc.data() ?? {};
  final p = (m['properties'] as Map?) ?? {};

  List<String> _stringList(dynamic v) {
    if (v == null) return const [];
    if (v is List)
      return v
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    return const [];
  }

  final photosCandidates = <List<String>>[
    _stringList(p['photoUrls']),
    _stringList(p['photos']),
    _stringList(p['images']),
    _stringList(p['gallery']),
    _stringList(m['photoUrls']),
    _stringList(m['photos']),
    _stringList(m['images']),
    _stringList(m['gallery']),
  ];
  final photoUrls = photosCandidates.firstWhere(
    (lst) => lst.isNotEmpty,
    orElse: () => const <String>[],
  );

  final primaryPhotoUrl =
      (p['primaryPhotoUrl'] ??
              m['primaryPhotoUrl'] ??
              (photoUrls.isNotEmpty ? photoUrls.first : null))
          ?.toString();

  final double? lat =
      (m['lat'] as num?)?.toDouble() ?? (p['lat'] as num?)?.toDouble();
  final double? lng =
      (m['lng'] as num?)?.toDouble() ?? (p['lng'] as num?)?.toDouble();

  final id = m['id'] ?? p['placeId'] ?? doc.id;
  final resolvedArea = area ?? doc.reference.parent.parent?.id;

  return {
    'id': id,
    'properties': {
      'name': p['name'] ?? m['name'] ?? 'Accommodation',
      'address': p['address'] ?? m['address'] ?? '',
      'phone': p['phone'] ?? m['phone'],
      'website': p['website'] ?? m['website'],
      'rating':
          ((p['rating'] ?? m['rating']) is num)
              ? (p['rating'] ?? m['rating']).toDouble()
              : null,
      'reviews': p['reviews'] ?? m['reviews'],
      'priceLevel': p['priceLevel'] ?? m['priceLevel'],
      'checkInTime': p['checkInTime'] ?? m['checkInTime'],
      'checkOutTime': p['checkOutTime'] ?? m['checkOutTime'],
      'primaryPhotoUrl': primaryPhotoUrl,
      'photoUrls': photoUrls,
      'roomTypes': (p['roomTypes'] as Map?) ?? const {},
      'emptyRoomsByDate': (p['emptyRoomsByDate'] as Map?) ?? const {},
      'placeId': p['placeId'] ?? m['id'] ?? doc.id,
      'area': resolvedArea,
      'placeDocPath': '/areas/$resolvedArea/places/${doc.id}',
      'mapsUrl': p['mapsUrl'] ?? m['mapsUrl'],
      'lat': lat,
      'lng': lng,
    },
    'geometry': {
      'coordinates': [(lng ?? 0.0).toDouble(), (lat ?? 0.0).toDouble()],
    },
  };
}

Map<String, dynamic> _mergePlaceIntoHotel(
  Map<String, dynamic> base,
  Map<String, dynamic> placeDoc, {
  required String placeId,
  required String areaFromPath,
  required String placeDocPath,
}) {
  final bProps =
      (base['properties'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
      {};
  final pProps =
      (placeDoc['properties'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v),
      ) ??
      {};

  final mergedProps = {
    ...bProps,
    ...pProps,
    'placeId': placeId,
    'area': areaFromPath,
    'placeDocPath': placeDocPath,
    if (placeDoc['name'] != null && pProps['name'] == null)
      'name': placeDoc['name'],
    if (placeDoc['address'] != null && pProps['address'] == null)
      'address': placeDoc['address'],
  };

  final bCoords =
      (base['geometry']?['coordinates'] as List?) ?? const [null, null];
  final lat =
      (placeDoc['lat'] as num?)?.toDouble() ??
      (pProps['lat'] as num?)?.toDouble() ??
      (bCoords.length > 1 ? (bCoords[1] as num?)?.toDouble() : null);
  final lng =
      (placeDoc['lng'] as num?)?.toDouble() ??
      (pProps['lng'] as num?)?.toDouble() ??
      (bCoords.isNotEmpty ? (bCoords[0] as num?)?.toDouble() : null);

  return {
    'id': placeId,
    'properties': mergedProps,
    'geometry': {
      'coordinates': [(lng ?? 0.0).toDouble(), (lat ?? 0.0).toDouble()],
    },
  };
}

Future<void> setStatusAndOpenMyTrips(
  BuildContext context, {
  required String tripId,
  required String status,
}) async {
  if (tripId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Missing tripId', style: GoogleFonts.poppins()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    return;
  }

  try {
    final trips = FirebaseFirestore.instance.collection('trips');

    await trips.doc(tripId).update({
      'accommodation.bookingStatus': status,
      if (status == 'PENDING') 'accommodation.bookingId': FieldValue.delete(),
    });

    final snap = await trips.doc(tripId).get();
    if (!snap.exists) {
      debugPrint('❌ trips/$tripId does not exist or not readable.');
    }
    final data = snap.data();
    var userId = (data?['userId'] ?? '').toString().trim();

    if (userId.isEmpty) {
      userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      debugPrint(
        "⚠️ Trip missing 'userId'. Falling back to Auth uid: ${userId.isEmpty ? '(none)' : userId}",
      );
    }

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot resolve userId for this trip',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainScreen(userId: userId, initialIndex: 2),
      ),
      (route) => false,
    );
  } catch (e) {
    debugPrint('setStatus+openMyTrips failed: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed: $e', style: GoogleFonts.poppins()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

Map<String, dynamic> normalizeHotelFromAny(Map<String, dynamic> h) {
  // ---- 1) NAME / ADDRESS fallbacks
  final propsIn = (h['properties'] as Map?) ?? {};
  final name =
      (propsIn['name'] ?? h['name'] ?? h['title'] ?? h['hotelName'])
          ?.toString();
  final address =
      (propsIn['address'] ??
              h['address'] ??
              h['formatted_address'] ??
              h['vicinity'])
          ?.toString();

  // ---- 2) PHONE / WEBSITE
  final phone =
      (propsIn['phone'] ?? h['phone'] ?? h['formatted_phone_number'])
          ?.toString();
  final website = (propsIn['website'] ?? h['website'])?.toString();

  // ---- 3) RATING / REVIEWS / PRICE LEVEL
  final rating =
      (propsIn['rating'] ?? h['rating']) is num
          ? (propsIn['rating'] ?? h['rating']) as num
          : null;
  final reviews =
      (propsIn['reviews'] ?? h['user_ratings_total'] ?? h['reviews']);
  final priceLv = (propsIn['priceLevel'] ?? h['price_level']);

  // ---- 4) CHECK-IN/OUT
  final checkInTime = propsIn['checkInTime'] ?? h['checkInTime'];
  final checkOutTime = propsIn['checkOutTime'] ?? h['checkOutTime'];

  // ---- 5) PHOTOS / MAPS
  final primaryPhotoUrl = propsIn['primaryPhotoUrl'] ?? h['primaryPhotoUrl'];
  final mapsUrl = propsIn['mapsUrl'] ?? h['mapsUrl'];
  final placeId = propsIn['placeId'] ?? h['placeId'] ?? h['id'];

  // ---- 6) ROOM TYPES / AVAILABILITY / COST
  final roomTypes = propsIn['roomTypes'] ?? h['roomTypes'] ?? {};
  final emptyRoomsByDate =
      propsIn['emptyRoomsByDate'] ?? h['emptyRoomsByDate'] ?? {};
  final estimatedCost = propsIn['estimated_cost'] ?? h['estimated_cost'];

  // ---- 7) COORDINATES (handle multiple shapes)
  double? lat;
  double? lng;

  final coords = h['coordinates'];
  if (coords != null) {
    try {
      final gpLat = (coords.latitude ?? coords['latitude']) as double?;
      final gpLng = (coords.longitude ?? coords['longitude']) as double?;
      lat ??= gpLat;
      lng ??= gpLng;
    } catch (_) {}
  }

  final geometry = h['geometry'] as Map?;
  if (geometry != null) {
    final loc = geometry['location'] as Map?;
    if (loc != null) {
      lat ??= (loc['lat'] as num?)?.toDouble();
      lng ??= (loc['lng'] as num?)?.toDouble();
    }
    final gc = geometry['coordinates'];
    if (gc is List && gc.length >= 2) {
      final c0 = (gc[0] as num?)?.toDouble();
      final c1 = (gc[1] as num?)?.toDouble();
      if (c0 != null && c1 != null) {
        lng ??= c0;
        lat ??= c1;
      }
    }
  }

  lat ??= (h['lat'] as num?)?.toDouble();
  lng ??= (h['lng'] as num?)?.toDouble();
  lat ??= (propsIn['lat'] as num?)?.toDouble();
  lng ??= (propsIn['lng'] as num?)?.toDouble();

  if (lat == null &&
      lng == null &&
      h['coords'] is List &&
      (h['coords'] as List).length >= 2) {
    final arr = (h['coords'] as List);
    lat = (arr[0] as num?)?.toDouble();
    lng = (arr[1] as num?)?.toDouble();
  }

  if (lat == null || lng == null) {
    debugPrint(
      '⚠️ normalizeHotelFromAny: missing coordinates in input: ${h.keys}',
    );
  }

  // ---- 8) ID
  final id = placeId ?? h['id'] ?? h['docId'] ?? h['refId'];

  // ---- build normalized object
  return {
    'id': id,
    'properties': {
      'name': name ?? 'Accommodation',
      'address': address ?? '',
      'phone': phone,
      'website': website,
      'rating': (rating is num) ? rating.toDouble() : null,
      'reviews': reviews,
      'priceLevel': priceLv,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'primaryPhotoUrl': primaryPhotoUrl,
      'mapsUrl': mapsUrl,
      'placeId': placeId,
      'roomTypes': roomTypes,
      'emptyRoomsByDate': emptyRoomsByDate,
      'estimated_cost': (estimatedCost as num?)?.toDouble(),
    },
    'geometry': {
      'coordinates': [(lng ?? 0.0).toDouble(), (lat ?? 0.0).toDouble()],
    },
  };
}

Future<String> _createPendingBooking({
  required String tripId,
  required String userId,
  required Map<String, dynamic> hotel,
  required DateTime checkIn,
  required DateTime checkOut,
  required int adults,
  required double? pricePerNight,
  String? roomType,
}) async {
  if (tripId.trim().isEmpty) {
    throw StateError('Empty tripId passed to _createPendingBooking');
  }

  String fmtLocalYmd(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  int nights = checkOut.difference(checkIn).inDays;
  if (nights < 1) nights = 1;

  final perNight = (pricePerNight ?? 0).toDouble();
  final total = (perNight * nights).toDouble();

  final resolvedHotel = await ensureResolvedHotel(hotel);

  final coords =
      (resolvedHotel['geometry']?['coordinates'] as List?) ??
      const [null, null];
  final hotelMap = {
    'id': resolvedHotel['id'],
    'name': resolvedHotel['properties']?['name'],
    'address': resolvedHotel['properties']?['address'],
    'lat': coords.length > 1 ? coords[1] : null,
    'lng': coords.isNotEmpty ? coords[0] : null,
    if ((resolvedHotel['properties']?['placeDocPath'] ?? '')
        .toString()
        .isNotEmpty)
      'placeDocPath': resolvedHotel['properties']['placeDocPath'],
    if ((resolvedHotel['properties']?['area'] ?? '').toString().isNotEmpty)
      'area': resolvedHotel['properties']['area'],
    if ((resolvedHotel['properties']?['primaryPhotoUrl'] ?? '')
        .toString()
        .isNotEmpty)
      'primaryPhotoUrl': resolvedHotel['properties']['primaryPhotoUrl'],
  };

  final ref =
      FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .collection('bookings')
          .doc();

  debugPrint("🟦 _createPendingBooking: /trips/$tripId/bookings/${ref.id}");

  await ref.set({
    'tripId': tripId,
    'userId': userId,
    'status': 'PENDING',
    'hotel': hotelMap,
    'checkIn': fmtLocalYmd(checkIn),
    'checkOut': fmtLocalYmd(checkOut),
    'guests': adults,
    'pricePerNight': perNight,
    'nights': nights,
    'totalPrice': total,
    'currency': 'MYR',
    'roomType': roomType,
    'createdAt': FieldValue.serverTimestamp(),
  });

  return ref.id;
}

Future<void> onSaveTripPressed({
  required BuildContext context,
  required Map<String, dynamic> trip,
  required Map<String, dynamic> selectedHotel,
  required bool isSandbox,
}) async {
  debugPrint('🧩 RAW selectedHotel keys: ${selectedHotel.keys.toList()}');
  debugPrint(
    '🧩 RAW selectedHotel sample: '
    'name=${selectedHotel['name']} '
    'props.name=${selectedHotel['properties']?['name']} '
    'address=${selectedHotel['address']} '
    'coords=${selectedHotel['coordinates']} '
    'geometry=${selectedHotel['geometry']} '
    'placeId=${selectedHotel['placeId']}',
  );

  final hotel = normalizeHotelFromAny(selectedHotel);

  debugPrint(
    '✅ NORMALIZED hotel: '
    'name=${hotel['properties']?['name']} '
    'address=${hotel['properties']?['address']} '
    'coords=${hotel['geometry']?['coordinates']}',
  );

  await showBookingPromptBottomSheet(
    context: context,
    trip: trip,
    hotel: hotel,
    isSandbox: isSandbox,
  );
}

Future<void> showBookingPromptBottomSheet({
  required BuildContext context,
  required Map<String, dynamic> trip,
  required Map<String, dynamic> hotel,
  required bool isSandbox,
  Future<String> Function(Map<String, dynamic>)? saveTripCallback,
}) async {
  debugPrint("🟦 [Sheet] ENTER showBookingPromptBottomSheet");
  debugPrint("🟦 [Sheet] trip keys: ${trip.keys.toList()}");
  debugPrint(
    "🟦 [Sheet] hotel keys: ${hotel.keys.toList()}  (props? ${hotel['properties'] != null}, geom? ${hotel['geometry'] != null})",
  );
  debugPrint(
    "🟦 [Sheet] isSandbox=$isSandbox  has saveTripCallback? ${saveTripCallback != null}",
  );

  final h =
      (hotel['properties'] is Map && hotel['geometry'] is Map)
          ? hotel
          : normalizeHotelFromAny(hotel);
  debugPrint(
    "🟦 [Sheet] normalized hotel props keys: ${(h['properties'] as Map?)?.keys.toList()}",
  );
  debugPrint(
    "🟦 [Sheet] normalized hotel name=${h['properties']?['name']} address=${h['properties']?['address']} primaryPhotoUrl=${h['properties']?['primaryPhotoUrl']} id=${h['id']}",
  );

  final inDate =
      DateTime.tryParse(trip['checkIn'] ?? '') ??
      DateTime.now().add(const Duration(days: 7));
  final outDate =
      DateTime.tryParse(trip['checkOut'] ?? '') ??
      inDate.add(const Duration(days: 2));
  final adults = (trip['adults'] as int?) ?? 1;
  final tripId = (trip['id'] ?? trip['tripId'] ?? '').toString();
  final userId = (trip['userId'] ?? '').toString();

  debugPrint(
    "🟦 [Sheet] derived in=$inDate out=$outDate adults=$adults tripId='$tripId' userId='$userId'",
  );

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      debugPrint("🟦 [Sheet] builder() invoked");
      return _GlassSheet(
        child: Padding(
          padding: MediaQuery.of(
            context,
          ).viewInsets.add(const EdgeInsets.all(16)),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(
                    Icons.hotel_rounded,
                    color: const Color(0xFF6D4C41),
                  ),
                  title: Text(
                    h['properties']?['name'] ?? 'Selected accommodation',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: const Color(0xFF6D4C41),
                    ),
                  ),
                  subtitle: Text(
                    _dateRangeText(inDate, outDate),
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  tileColor: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "Would you like to book the accommodation now?",
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.lock_rounded, size: 20),
                    label: Text(
                      'Book in app now',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4C41),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      debugPrint("🟦 [Sheet] CTA=Book now tapped");
                      Navigator.of(context).pop();

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder:
                            (_) => const _ProcessingDialog(
                              text: 'Loading hotel details…',
                            ),
                      );
                      Map<String, dynamic> resolved = h;
                      try {
                        resolved = await ensureResolvedHotel(h);
                        debugPrint(
                          "🟦 [Sheet] resolved primary=${resolved['properties']?['primaryPhotoUrl']}, photos=${(resolved['properties']?['photoUrls'] as List?)?.length ?? 0}",
                        );
                      } catch (e) {
                        debugPrint(
                          "⚠️ [Sheet] ensureResolvedHotel failed: $e — using fallback",
                        );
                      }
                      if (context.mounted) Navigator.of(context).pop();

                      debugPrint(
                        "🟦 [Sheet] Pushing AccommodationBookingPage (resolved)",
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => AccommodationBookingPage(
                                tripId: tripId,
                                userId: userId,
                                hotel: resolved,
                                initialAdults: adults,
                                initialCheckIn: inDate,
                                initialCheckOut: outDate,
                                isSandbox: isSandbox,
                                pricePerNightHint:
                                    (trip['pricePerNight'] as num?)
                                        ?.toDouble() ??
                                    160.0,
                                saveTripCallback: saveTripCallback,
                                tripPayload: trip,
                              ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.skip_next_rounded, size: 20),
                    label: Text(
                      'Skip for now',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6D4C41),
                      side: const BorderSide(color: Color(0xFF6D4C41)),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      debugPrint("🟦 [Sheet] CTA=Skip tapped");
                      try {
                        Navigator.of(context).pop();

                        var id =
                            (trip['id'] ?? trip['tripId'] ?? '')
                                .toString()
                                .trim();
                        debugPrint("🟦 [Skip] initial tripId='$id'");
                        if (id.isEmpty) {
                          debugPrint(
                            "🟦 [Skip] tripId empty; saveTripCallback? ${saveTripCallback != null}",
                          );
                          if (saveTripCallback == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Missing trip — please save the trip first.',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  backgroundColor: const Color(0xFF6D4C41),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (_) => const _ProcessingDialog(
                                  text: 'Saving your trip…',
                                ),
                          );
                          try {
                            id = await saveTripCallback!(trip);
                            trip['id'] = id;
                            debugPrint("✅ [Skip] trip saved -> id=$id");
                          } catch (e, st) {
                            debugPrint(
                              "🚨 [Skip] saveTripCallback failed: $e\n$st",
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not save trip: $e',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          if (context.mounted) Navigator.of(context).pop();
                        }

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder:
                              (_) => const _ProcessingDialog(
                                text: 'Creating pending booking…',
                              ),
                        );

                        final uid =
                            FirebaseAuth.instance.currentUser?.uid ??
                            (trip['userId'] ?? '').toString();
                        debugPrint(
                          "🟦 [Skip] uid='$uid'  tripId='$id'  adults=$adults  isSandbox=$isSandbox",
                        );
                        debugPrint(
                          "🟦 [Skip] h.id=${h['id']}  h.props.name=${h['properties']?['name']}  photo=${h['properties']?['primaryPhotoUrl']}",
                        );

                        String pendingBookingId = '';
                        try {
                          pendingBookingId = await _createPendingBooking(
                            tripId: id,
                            userId: uid,
                            hotel: h,
                            checkIn: inDate,
                            checkOut: outDate,
                            adults: adults,
                            pricePerNight:
                                (trip['pricePerNight'] as num?)?.toDouble(),
                            roomType: null,
                          );
                          debugPrint(
                            "✅ [Skip] pending booking created: $pendingBookingId",
                          );
                        } catch (e, st) {
                          debugPrint(
                            "🚨 [Skip] _createPendingBooking failed: $e\n$st",
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to create pending booking: $e',
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
                          return;
                        }

                        try {
                          await FirebaseFirestore.instance
                              .collection('trips')
                              .doc(id)
                              .update({
                                'accommodation.bookingStatus': 'PENDING',
                                'accommodation.bookingId': pendingBookingId,
                              });
                          debugPrint(
                            "✅ [Skip] trips/$id updated: bookingStatus=PENDING, bookingId=$pendingBookingId",
                          );
                        } catch (e, st) {
                          debugPrint("🚨 [Skip] update trip failed: $e\n$st");
                        }

                        String tripTitle = (trip['title'] ?? '').toString();
                        if (tripTitle.isEmpty) {
                          try {
                            final tSnap =
                                await FirebaseFirestore.instance
                                    .collection('trips')
                                    .doc(id)
                                    .get();
                            tripTitle =
                                (tSnap.data()?['title'] ?? 'Your trip')
                                    .toString();
                            debugPrint(
                              "🟦 [Skip] fetched trip title: '$tripTitle'",
                            );
                          } catch (e, st) {
                            debugPrint(
                              "⚠️ [Skip] could not fetch trip title: $e\n$st",
                            );
                            tripTitle = 'Your trip';
                          }
                        }

                        try {
                          debugPrint(
                            "🟦 [Skip] Emitting booking_pending notif…",
                          );
                          await _emitBookingPendingNotification(
                            receiverUid: uid,
                            tripId: id,
                            tripTitle: tripTitle,
                            hotelNormalized: h,
                            checkIn: inDate,
                            checkOut: outDate,
                            bookingId: pendingBookingId,
                            adults: adults,
                            isSandbox: isSandbox,
                            pricePerNight:
                                (trip['pricePerNight'] as num?)?.toDouble(),
                          );
                          debugPrint(
                            "✅ [Skip] booking_pending notification emitted.",
                          );
                        } catch (e, st) {
                          debugPrint(
                            "🚨 [Skip] emit notification failed: $e\n$st",
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not create notification: $e',
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
                        }

                        if (!context.mounted) return;
                        Navigator.of(context).pop();

                        debugPrint(
                          "🟦 [Skip] Navigating to MainScreen(MyTrips)",
                        );
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder:
                                (_) => MainScreen(userId: uid, initialIndex: 2),
                          ),
                          (route) => false,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Booking saved as PENDING and linked to your trip.',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: const Color(0xFF6D4C41),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      } catch (e, st) {
                        debugPrint("🚨 [Skip] outer error: $e\n$st");
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to skip: $e',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    },
  );

  debugPrint("🟦 [Sheet] EXIT showBookingPromptBottomSheet");
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.title, required this.url, required this.icon});
  final String title;
  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6D4C41)),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: const Color(0xFF6D4C41),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.open_in_new_rounded, color: Color(0xFF6D4C41)),
      onTap:
          () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Colors.white.withOpacity(0.9),
    );
  }
}

class _CallTile extends StatelessWidget {
  const _CallTile({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.call_rounded, color: Color(0xFF6D4C41)),
      title: Text(
        'Call',
        style: GoogleFonts.poppins(
          color: const Color(0xFF6D4C41),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(phone, style: GoogleFonts.poppins(color: Colors.black54)),
      trailing: const Icon(Icons.open_in_new_rounded, color: Color(0xFF6D4C41)),
      onTap:
          () => launchUrl(
            Uri.parse('tel:$phone'),
            mode: LaunchMode.externalApplication,
          ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Colors.white.withOpacity(0.9),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48,
        height: 5,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD7CCC8),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _ProcessingDialog extends StatelessWidget {
  const _ProcessingDialog({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: const Color(0xFF6D4C41)),
          const SizedBox(height: 16),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: const Color(0xFF6D4C41),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

String _dateRangeText(DateTime inD, DateTime outD) {
  String d(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  return '${d(inD)} → ${d(outD)}';
}

class AccommodationBookingPage extends StatefulWidget {
  const AccommodationBookingPage({
    super.key,
    required this.tripId,
    required this.userId,
    required this.hotel,
    required this.initialCheckIn,
    required this.initialCheckOut,
    required this.initialAdults,
    required this.isSandbox,
    required this.pricePerNightHint,
    this.saveTripCallback,
    this.tripPayload,
  });

  final String tripId;
  final String userId;
  final Map<String, dynamic> hotel;
  final DateTime initialCheckIn;
  final DateTime initialCheckOut;
  final int initialAdults;
  final bool isSandbox;
  final double pricePerNightHint;
  final Future<String> Function(Map<String, dynamic>)? saveTripCallback;
  final Map<String, dynamic>? tripPayload;

  @override
  State<AccommodationBookingPage> createState() =>
      _AccommodationBookingPageState();
}

class _AccommodationBookingPageState extends State<AccommodationBookingPage> {
  late DateTime checkIn = widget.initialCheckIn;
  late DateTime checkOut = widget.initialCheckOut;
  late int adults = widget.initialAdults;
  late double pricePerNight = widget.pricePerNightHint;
  late String _tripId = widget.tripId;
  String? selectedRoomKey;

  int get nights => (checkOut.difference(checkIn).inDays).clamp(1, 60);
  double get total => (pricePerNight * nights).toDouble();

  String _fmtLocalYmd(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  final _formKey = GlobalKey<FormState>();
  final _cardNameCtrl = TextEditingController();
  final _cardNoCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint(
      "🟦 BookingPage.init tripId=${widget.tripId} "
      "saveTripCallback? ${widget.saveTripCallback != null} "
      "tripPayload? ${widget.tripPayload != null}",
    );
  }

  @override
  void dispose() {
    _cardNameCtrl.dispose();
    _cardNoCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  List<String> _collectAmenities(Map props) {
    final set = <String>{};
    final hotelAm = (props['amenities'] as List?)?.cast<String>() ?? const [];
    set.addAll(hotelAm.map((e) => e.trim()).where((e) => e.isNotEmpty));
    final roomTypes = (props['roomTypes'] as Map?) ?? {};
    for (final rt in roomTypes.values) {
      final am = (rt as Map?)?['amenities'] as List?;
      if (am != null) {
        set.addAll(
          am.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
        );
      }
    }
    return set.toList()..sort();
  }

  bool _luhnValid(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    int sum = 0;
    bool alt = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int n = int.parse(digits[i]);
      if (alt) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alt = !alt;
    }
    return sum % 10 == 0 && digits.length >= 12;
  }

  String? _validateCardName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter cardholder name';
    if (v.trim().length < 3) return 'Name too short';
    return null;
  }

  String? _validateCardNo(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'\s|-'), '');
    if (s.isEmpty) return 'Enter card number';
    if (!_luhnValid(s)) return 'Invalid card number';
    return null;
  }

  String? _validateExpiry(String? v) {
    final s = (v ?? '').trim();
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(s);
    if (m == null) return 'Use MM/YY';
    final mm = int.parse(m.group(1)!);
    final yy = int.parse(m.group(2)!);
    if (mm < 1 || mm > 12) return 'Invalid month';
    final year = 2000 + yy;
    final now = DateTime.now();
    final exp = DateTime(year, mm + 1, 0);
    if (exp.isBefore(DateTime(now.year, now.month, 1))) return 'Card expired';
    return null;
  }

  String? _validateCvv(String? v) {
    final s = (v ?? '').trim();
    if (!RegExp(r'^\d{3,4}$').hasMatch(s)) return 'Invalid CVV';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter billing email';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s)) return 'Invalid email';
    return null;
  }

  bool _dateRangeAvailable(DateTime inD, DateTime outD) {
    debugPrint("DEBUG: === AVAILABILITY CHECK DEBUG ===");
    debugPrint("DEBUG: widget.hotel structure: ${widget.hotel.keys}");
    debugPrint(
      "DEBUG: widget.hotel['properties']: ${widget.hotel['properties']}",
    );

    final props = (widget.hotel['properties'] as Map?) ?? const {};
    debugPrint("DEBUG: props keys: ${props.keys.toList()}");
    debugPrint(
      "DEBUG: props['emptyRoomsByDate']: ${props['emptyRoomsByDate']}",
    );

    final Map<String, dynamic> empty = Map<String, dynamic>.from(
      (props['emptyRoomsByDate'] as Map?) ?? const {},
    );

    if (empty.isEmpty) {
      debugPrint(
        "WARNING: No availability data found, bypassing availability check",
      );
      return true;
    }

    final rkRaw = selectedRoomKey;

    debugPrint(
      "🔍 Availability check for ${_fmtLocalYmd(inD)} to ${_fmtLocalYmd(outD)}",
    );
    debugPrint("🔍 Room type (raw): $rkRaw");
    debugPrint("🔍 Available dates: ${empty.keys.toList()}");

    if (!inD.isBefore(outD)) {
      debugPrint("❌ Invalid date range");
      return false;
    }

    for (
      var d = DateTime(inD.year, inD.month, inD.day);
      d.isBefore(DateTime(outD.year, outD.month, outD.day));
      d = d.add(const Duration(days: 1))
    ) {
      final key = _fmtLocalYmd(d);
      Map<String, dynamic>? day;
      day = (empty[key] as Map?)?.map((k, v) => MapEntry(k.toString(), v));
      if (day == null) {
        final alt = key.replaceAll('-', '/');
        day = (empty[alt] as Map?)?.map((k, v) => MapEntry(k.toString(), v));
      }

      debugPrint("🔍 Checking $key: $day");
      if (day == null) {
        debugPrint("❌ No availability data for $key");
        return false;
      }

      if (rkRaw == null) {
        final any = day.values.cast<num?>().any((v) => (v ?? 0) > 0);
        if (!any) {
          debugPrint("❌ No rooms available for $key");
          return false;
        }
        debugPrint("✅ Rooms available for $key");
      } else {
        String? _findRoomKey(Map dayInv, String? want) {
          if (want == null || want.isEmpty) return null;
          if (dayInv.containsKey(want)) return want;
          final wantLc = want.toLowerCase();
          for (final k in dayInv.keys) {
            if (k.toString().toLowerCase() == wantLc) return k.toString();
          }
          return null;
        }

        final rk = _findRoomKey(day, rkRaw);
        if (rk == null) {
          debugPrint(
            "❌ Room type '$rkRaw' not found for $key. Available: ${day.keys}",
          );
          return false;
        }
        final left = (day[rk] as num?)?.toInt() ?? 0;
        if (left <= 0) {
          debugPrint("❌ No $rk rooms available for $key (available: $left)");
          return false;
        }
        debugPrint("✅ $rk rooms available for $key: $left");
      }
    }

    debugPrint("✅ All dates available");
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final props = (widget.hotel['properties'] as Map?) ?? {};
    final name = (props['name'] ?? 'Accommodation').toString();
    final address = (props['address'] ?? '').toString();
    final rating = (props['rating'] as num?)?.toDouble();
    final reviews = props['reviews'];
    final priceLevel = props['priceLevel']?.toString();
    final primaryPhotoUrl = props['primaryPhotoUrl'];
    final checkInTime = (props['checkInTime'] ?? '—').toString();
    final checkOutTime = (props['checkOutTime'] ?? '—').toString();
    final amenities = _collectAmenities(props);
    final phone = (props['phone'] ?? '').toString();
    final website = (props['website'] ?? '').toString();
    final mapsUrl = (props['mapsUrl'] ?? '').toString();
    final List<String> photoUrls =
        ((props['photoUrls'] as List?)?.cast<String>() ?? const []);
    final Map<String, dynamic> roomTypes =
        (props['roomTypes'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v),
        ) ??
        {};

    final List<DropdownMenuItem<String>> roomItems =
        roomTypes.entries.map((e) {
          final info = (e.value as Map?) ?? {};
          final nm = (info['name'] ?? e.key).toString();
          final p = (info['price'] as num?)?.toDouble();
          final mg = (info['maxGuests'] as num?)?.toInt();
          final suffixPrice =
              (p != null) ? " (MYR ${p.toStringAsFixed(0)}/night)" : "";
          final suffixGuests = (mg != null) ? " • up to $mg pax" : "";
          return DropdownMenuItem<String>(
            value: e.key,
            child: Text(
              "$nm$suffixPrice$suffixGuests",
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          );
        }).toList();
    selectedRoomKey ??= roomItems.isNotEmpty ? roomItems.first.value : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          'Confirm Your Stay',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6D4C41),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6D4C41)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HotelCard(name: name, address: address, hotel: widget.hotel),
          const SizedBox(height: 16),
          _HotelGallery(primary: primaryPhotoUrl, photos: photoUrls),
          const SizedBox(height: 16),
          Row(
            children: [
              if (rating != null) ...[
                const Icon(
                  Icons.star_rate_rounded,
                  size: 18,
                  color: Color(0xFF6D4C41),
                ),
                const SizedBox(width: 4),
                Text(
                  "${rating.toStringAsFixed(1)} (${reviews ?? 0})",
                  style: GoogleFonts.poppins(color: Colors.black87),
                ),
                const SizedBox(width: 12),
              ],
              if (priceLevel != null) ...[
                const Icon(
                  Icons.attach_money_rounded,
                  size: 18,
                  color: Color(0xFF6D4C41),
                ),
                const SizedBox(width: 2),
                Text(
                  '•' * ((int.tryParse(priceLevel) ?? 0).clamp(0, 4)),
                  style: GoogleFonts.poppins(color: Colors.black87),
                ),
              ],
              const Spacer(),
              Text(
                'Check-in $checkInTime • Out $checkOutTime',
                style: GoogleFonts.poppins(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (amenities.isNotEmpty) ...[
            _Section(
              title: 'Amenities',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    amenities
                        .map(
                          (a) => Chip(
                            label: Text(
                              a,
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFFD7CCC8)),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _Section(
            title: 'Property Info',
            child: Column(
              children: [
                if (address.isNotEmpty)
                  _LinkTile(
                    title: address,
                    url:
                        mapsUrl.isNotEmpty
                            ? mapsUrl
                            : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}',
                    icon: Icons.pin_drop_rounded,
                  ),
                if (phone.isNotEmpty) _CallTile(phone: phone),
                if (website.isNotEmpty)
                  _LinkTile(
                    title: website,
                    url: website,
                    icon: Icons.public_rounded,
                  ),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: const Icon(
                    Icons.schedule_rounded,
                    color: Color(0xFF6D4C41),
                  ),
                  title: Text(
                    'Check-in $checkInTime • Check-out $checkOutTime',
                    style: GoogleFonts.poppins(color: Colors.black87),
                  ),
                  tileColor: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Dates',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check-in',
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                    Text(
                      _DateRow._fmt(checkIn),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Check-out',
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                    Text(
                      _DateRow._fmt(checkOut),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Guests',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Number of guests',
                  style: GoogleFonts.poppins(color: Colors.black54),
                ),
                Text(
                  '$adults',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (roomItems.isNotEmpty) ...[
            _Section(
              title: 'Room Type',
              child: Text(
                selectedRoomKey ?? 'No room selected',
                style: GoogleFonts.poppins(color: Colors.black87),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _Section(
            title: 'Price',
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Price per night (MYR)',
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                    Text(
                      pricePerNight.toStringAsFixed(2),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nights',
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                    Text(
                      '$nights',
                      style: GoogleFonts.poppins(color: Colors.black87),
                    ),
                  ],
                ),
                const Divider(height: 16, color: Color(0xFFD7CCC8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'MYR ${total.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF6D4C41),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: _Section(
              title: 'Payment Details',
              child: Column(
                children: [
                  TextFormField(
                    controller: _cardNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Cardholder Name',
                      labelStyle: GoogleFonts.poppins(color: Colors.black54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD7CCC8)),
                      ),
                    ),
                    validator: _validateCardName,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.poppins(color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cardNoCtrl,
                    decoration: InputDecoration(
                      labelText: 'Card Number',
                      hintText: '1234 5678 9012 3456',
                      labelStyle: GoogleFonts.poppins(color: Colors.black54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD7CCC8)),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(19),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        final digits = newValue.text.replaceAll(
                          RegExp(r'\D'),
                          '',
                        );
                        final buffer = StringBuffer();
                        for (int i = 0; i < digits.length; i++) {
                          buffer.write(digits[i]);
                          if ((i + 1) % 4 == 0 && i + 1 != digits.length)
                            buffer.write(' ');
                        }
                        return TextEditingValue(
                          text: buffer.toString(),
                          selection: TextSelection.collapsed(
                            offset: buffer.length,
                          ),
                        );
                      }),
                    ],
                    validator: _validateCardNo,
                    style: GoogleFonts.poppins(color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiryCtrl,
                          decoration: InputDecoration(
                            labelText: 'Expiry (MM/YY)',
                            hintText: 'MM/YY',
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.black54,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFD7CCC8),
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            TextInputFormatter.withFunction((
                              oldValue,
                              newValue,
                            ) {
                              var text = newValue.text.replaceAll(
                                RegExp(r'\D'),
                                '',
                              );
                              if (text.length >= 3) {
                                text =
                                    text.substring(0, 2) +
                                    '/' +
                                    text.substring(2);
                              }
                              return TextEditingValue(
                                text: text,
                                selection: TextSelection.collapsed(
                                  offset: text.length,
                                ),
                              );
                            }),
                          ],
                          validator: _validateExpiry,
                          style: GoogleFonts.poppins(color: Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cvvCtrl,
                          decoration: InputDecoration(
                            labelText: 'CVV',
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.black54,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFD7CCC8),
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _validateCvv,
                          obscureText: true,
                          style: GoogleFonts.poppins(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Billing Email',
                      labelStyle: GoogleFonts.poppins(color: Colors.black54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD7CCC8)),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    style: GoogleFonts.poppins(color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.lock_clock_rounded, size: 20),
            label: Text(
              'Confirm Booking',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6D4C41),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (!_dateRangeAvailable(checkIn, checkOut)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Selected dates not available for this room type.',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
                return;
              }
              if (!(_formKey.currentState?.validate() ?? false)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please complete valid payment details.',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
                return;
              }
              await _confirm();
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.skip_next_rounded, size: 20),
            label: Text(
              'Skip for Now',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6D4C41),
              side: const BorderSide(color: Color(0xFF6D4C41)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder:
                      (_) => const _ProcessingDialog(
                        text: 'Updating booking status…',
                      ),
                );
                await FirebaseFirestore.instance
                    .collection('trips')
                    .doc(widget.tripId)
                    .update({
                      'accommodation.bookingStatus': 'PENDING',
                      'accommodation.bookingId': FieldValue.delete(),
                    });
                if (!mounted) return;
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Booking skipped. Status set to PENDING.',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: const Color(0xFF6D4C41),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to set PENDING: $e',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    debugPrint("🟦 _confirm: ENTER _tripId='$_tripId'");
    if (_tripId.trim().isEmpty) {
      debugPrint(
        "🟦 _confirm: no tripId. hasCallback=${widget.saveTripCallback != null} hasPayload=${widget.tripPayload != null}",
      );
      if (widget.saveTripCallback == null || widget.tripPayload == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Missing trip. Please save the trip first.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ProcessingDialog(text: 'Saving your trip…'),
      );
      try {
        final newId = await widget.saveTripCallback!(widget.tripPayload!);
        _tripId = newId;
        debugPrint("✅ _confirm: trip saved. new _tripId='$_tripId'");
      } catch (e) {
        debugPrint("🚨 _confirm: saveTripCallback failed: $e");
        Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not save trip: $e',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
        return;
      }
      if (mounted) Navigator.of(context).pop();
    }

    if (_tripId.trim().isEmpty) {
      throw StateError("Still no tripId after save — aborting.");
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProcessingDialog(text: 'Locking your room…'),
    );
    await Future.delayed(const Duration(seconds: 2));

    final bookingId = await _createBookingWithInventory(
      tripId: _tripId,
      userId: widget.userId,
      hotel: widget.hotel,
      checkIn: checkIn,
      checkOut: checkOut,
      adults: adults,
      pricePerNight: pricePerNight,
      isSandbox: widget.isSandbox,
      roomType: selectedRoomKey,
    );

    try {
      await _upsertAccommodationExpenseFromBooking(
        tripId: _tripId,
        bookingId: bookingId,
        paidByUserId: widget.userId,
      );
    } catch (e) {
      debugPrint("⚠️ could not create expense from booking: $e");
    }

    try {
      final resolvedHotel = await ensureResolvedHotel(widget.hotel);
      final tripTitle =
          (widget.tripPayload?['title'] as String?) ?? 'Your trip';
      await _resolvePendingBookingNotification(
        receiverUid: widget.userId,
        tripId: _tripId,
        bookingId: bookingId,
        alsoEmitConfirmed: true,
        tripTitle: tripTitle,
        hotelName:
            (resolvedHotel['properties']?['name'] as String?) ??
            'Accommodation',
      );
    } catch (e) {
      debugPrint("⚠️ could not resolve pending notif: $e");
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => BookingSuccessPage(tripId: _tripId, bookingId: bookingId),
      ),
    );
  }

  Future<String> _createBookingWithInventory({
    required String tripId,
    required String userId,
    required Map<String, dynamic> hotel,
    required DateTime checkIn,
    required DateTime checkOut,
    required int adults,
    required double pricePerNight,
    required bool isSandbox,
    String? roomType,
  }) async {
    debugPrint("➡️ Starting _createBooking for trip $tripId by user $userId");
    if (tripId.trim().isEmpty) {
      debugPrint("🚨 _createBookingWithInventory: EMPTY tripId");
      throw StateError(
        'Bad state: Empty tripId passed to _createBookingWithInventory',
      );
    }

    final resolvedHotel = await ensureResolvedHotel(hotel);
    debugPrint(
      "🟦 _createBookingWithInventory: writing under /trips/$tripId/bookings",
    );
    int nights = checkOut.difference(checkIn).inDays;
    if (nights < 1) nights = 1;
    if (nights > 60) nights = 60;

    final total = (pricePerNight * nights).toDouble();
    final code = _genConfirmCode();

    String fmtLocalYmd(DateTime d) {
      final local = DateTime(d.year, d.month, d.day);
      final mm = local.month.toString().padLeft(2, '0');
      final dd = local.day.toString().padLeft(2, '0');
      return '${local.year}-$mm-$dd';
    }

    final checkInStr = fmtLocalYmd(checkIn);
    final checkOutStr = fmtLocalYmd(checkOut);

    debugPrint(
      "📅 checkIn: $checkInStr  checkOut: $checkOutStr  nights: $nights",
    );
    debugPrint("👥 guests: $adults  roomType: $roomType");
    debugPrint("💰 pricePerNight: $pricePerNight  total: $total");
    debugPrint(
      "🏨 hotel: ${resolvedHotel['properties']?['name']} (${resolvedHotel['id']})",
    );
    debugPrint("📍 coords: ${resolvedHotel['geometry']?['coordinates']}");

    final coords =
        (resolvedHotel['geometry']?['coordinates'] as List?) ??
        const [null, null];
    final hotelMap = {
      'id': resolvedHotel['id'],
      'name': resolvedHotel['properties']?['name'],
      'address': resolvedHotel['properties']?['address'],
      'lat': coords.length > 1 ? coords[1] : null,
      'lng': coords.isNotEmpty ? coords[0] : null,
      if ((resolvedHotel['properties']?['placeDocPath'] ?? '')
          .toString()
          .isNotEmpty)
        'placeDocPath': resolvedHotel['properties']['placeDocPath'],
      if ((resolvedHotel['properties']?['area'] ?? '').toString().isNotEmpty)
        'area': resolvedHotel['properties']['area'],
      if ((resolvedHotel['properties']?['primaryPhotoUrl'] ?? '')
          .toString()
          .isNotEmpty)
        'primaryPhotoUrl': resolvedHotel['properties']['primaryPhotoUrl'],
    };

    final ref =
        FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId)
            .collection('bookings')
            .doc();
    debugPrint("🆔 bookingId: ${ref.id}");

    try {
      await ref.set({
        'tripId': tripId,
        'userId': userId,
        'status': 'CONFIRMED',
        'hotel': hotelMap,
        'checkIn': checkInStr,
        'checkOut': checkOutStr,
        'guests': adults,
        'pricePerNight': pricePerNight,
        'nights': nights,
        'totalPrice': total,
        'currency': 'MYR',
        'confirmationCode': code,
        'createdAt': FieldValue.serverTimestamp(),
        'roomType': roomType,
      });
      debugPrint("✅ bookings/{id} created");

      await _decreaseHotelInventory(
        hotel: resolvedHotel,
        checkIn: checkIn,
        checkOut: checkOut,
        roomType: roomType,
      );
    } catch (e) {
      debugPrint("❌ Failed to create booking: $e");
      rethrow;
    }

    if (isSandbox) {
      try {
        await ref.collection('_meta').doc('private').set({
          'sandbox': true,
          'ts': FieldValue.serverTimestamp(),
        });
        debugPrint("✅ bookings/{id}/_meta/private written");
      } catch (e) {
        debugPrint("⚠️ Could not write sandbox meta: $e");
      }
    }

    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).update({
        'accommodation.bookingStatus': 'CONFIRMED',
        'accommodation.bookingId': ref.id,
      });
      debugPrint("✅ trips/$tripId updated with bookingId");
    } catch (e) {
      debugPrint("❌ Failed to update trip: $e");
      rethrow;
    }

    debugPrint("🎉 Booking flow finished successfully. ID=${ref.id}");
    return ref.id;
  }

  Future<void> _decreaseHotelInventory({
    required Map<String, dynamic> hotel,
    required DateTime checkIn,
    required DateTime checkOut,
    required String? roomType,
  }) async {
    debugPrint(
      "📦 Starting inventory decrease for ${hotel['properties']?['name']}",
    );
    final hotelId = hotel['id']?.toString();
    if (hotelId == null || hotelId.isEmpty) {
      debugPrint("⚠️ No hotel ID found, skipping inventory update");
      return;
    }

    String fmtLocalYmd(DateTime d) {
      final local = DateTime(d.year, d.month, d.day);
      final mm = local.month.toString().padLeft(2, '0');
      final dd = local.day.toString().padLeft(2, '0');
      return '${local.year}-$mm-$dd';
    }

    try {
      String? areaName = _extractAreaFromHotel(hotel);
      debugPrint("🗺️ Extracted area name: '$areaName'");
      debugPrint("🆔 Hotel ID: '$hotelId'");

      if (areaName == null || areaName.isEmpty) {
        debugPrint(
          "⚠️ Cannot determine area for hotel, skipping inventory update",
        );
        return;
      }

      final placeRef = FirebaseFirestore.instance
          .collection('areas')
          .doc(areaName)
          .collection('places')
          .doc(hotelId);
      debugPrint("📍 Firestore path: ${placeRef.path}");

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final placeDoc = await transaction.get(placeRef);
        debugPrint("🔍 Document exists: ${placeDoc.exists}");
        if (!placeDoc.exists) {
          debugPrint(
            "⚠️ Place document not found: $hotelId at path: ${placeRef.path}",
          );
          return;
        }

        final placeData = placeDoc.data()!;
        debugPrint("📋 Place data keys: ${placeData.keys.toList()}");

        final Map<String, dynamic> emptyRoomsByDate = Map<String, dynamic>.from(
          placeData['properties']?['emptyRoomsByDate'] ?? {},
        );

        debugPrint("🗓️ Extracted emptyRoomsByDate: $emptyRoomsByDate");

        final List<String> affectedDates = [];
        for (
          var d = DateTime(checkIn.year, checkIn.month, checkIn.day);
          d.isBefore(DateTime(checkOut.year, checkOut.month, checkOut.day));
          d = d.add(const Duration(days: 1))
        ) {
          affectedDates.add(fmtLocalYmd(d));
        }

        debugPrint("📅 Decreasing inventory for dates: $affectedDates");
        debugPrint("🏨 Room type: ${roomType ?? 'any available'}");

        bool inventoryUpdated = false;
        for (final dateKey in affectedDates) {
          debugPrint("🔍 Checking date: '$dateKey'");
          final dayInventory =
              emptyRoomsByDate[dateKey] as Map<String, dynamic>?;

          if (dayInventory == null) {
            debugPrint("❌ No inventory data for date: $dateKey");
            continue;
          }

          debugPrint("✅ Found inventory for $dateKey: $dayInventory");

          if (roomType != null && roomType.isNotEmpty) {
            final currentCount = (dayInventory[roomType] as num?)?.toInt() ?? 0;
            if (currentCount > 0) {
              emptyRoomsByDate[dateKey] = {
                ...dayInventory,
                roomType: currentCount - 1,
              };
              inventoryUpdated = true;
              debugPrint(
                "✅ $dateKey: $roomType decreased from $currentCount to ${currentCount - 1}",
              );
            } else {
              debugPrint(
                "⚠️ $dateKey: No $roomType rooms available (current: $currentCount)",
              );
            }
          } else {
            bool decreasedAny = false;
            final updatedDay = Map<String, dynamic>.from(dayInventory);

            for (final entry in dayInventory.entries) {
              final count = (entry.value as num?)?.toInt() ?? 0;
              if (count > 0) {
                updatedDay[entry.key] = count - 1;
                emptyRoomsByDate[dateKey] = updatedDay;
                inventoryUpdated = true;
                decreasedAny = true;
                debugPrint(
                  "✅ $dateKey: ${entry.key} decreased from $count to ${count - 1}",
                );
                break;
              }
            }

            if (!decreasedAny) {
              debugPrint("⚠️ $dateKey: No rooms available to decrease");
            }
          }
        }

        if (inventoryUpdated) {
          transaction.update(placeRef, {
            'properties.emptyRoomsByDate': emptyRoomsByDate,
            'lastInventoryUpdate': FieldValue.serverTimestamp(),
          });
          debugPrint("✅ Place inventory updated successfully");
        } else {
          debugPrint("⚠️ No inventory was updated");
        }
      });
    } catch (e) {
      debugPrint("❌ Failed to decrease hotel inventory: $e");
    }
  }

  String? _extractAreaFromHotel(Map<String, dynamic> hotel) {
    final props = (hotel['properties'] as Map?) ?? {};
    final areaFromProps = props['area']?.toString();
    if (areaFromProps != null && areaFromProps.isNotEmpty) {
      return areaFromProps;
    }

    final address = (props['address'] ?? '').toString();
    if (address.isNotEmpty) {
      final commonAreas = [
        'George Town',
        'Georgetown',
        'Penang Island',
        'Butterworth',
        'Kuala Lumpur',
        'Petaling Jaya',
        'Shah Alam',
        'Johor Bahru',
        'Melaka',
        'Malacca',
        'Ipoh',
        'Kota Kinabalu',
        'Kuching',
      ];
      for (final area in commonAreas) {
        if (address.toLowerCase().contains(area.toLowerCase())) {
          return area;
        }
      }
    }

    final firestorePath = props['firestorePath']?.toString();
    if (firestorePath != null && firestorePath.startsWith('/areas/')) {
      final parts = firestorePath.split('/');
      if (parts.length >= 2) {
        return parts[2];
      }
    }

    debugPrint("⚠️ Could not determine area from hotel data, using fallback");
    return 'George Town';
  }

  double _calculateDateSimilarity(String date1, String date2) {
    if (date1 == date2) return 1.0;
    final clean1 = date1.replaceAll(RegExp(r'[-/\s]'), '');
    final clean2 = date2.replaceAll(RegExp(r'[-/\s]'), '');
    if (clean1 == clean2) return 0.9;
    final nums1 =
        RegExp(r'\d+').allMatches(date1).map((m) => m.group(0)).toList();
    final nums2 =
        RegExp(r'\d+').allMatches(date2).map((m) => m.group(0)).toList();
    if (nums1.length == nums2.length && nums1.length == 3) {
      int matches = 0;
      for (int i = 0; i < 3; i++) {
        if (nums1[i] == nums2[i]) matches++;
      }
      return matches / 3.0;
    }
    return 0.0;
  }

  Future<void> _upsertAccommodationExpenseFromBooking({
    required String tripId,
    required String bookingId,
    required String paidByUserId,
  }) async {
    final bookingRef = FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId)
        .collection('bookings')
        .doc(bookingId);
    final snap = await bookingRef.get();
    if (!snap.exists) {
      debugPrint("⚠️ booking not found ($tripId/$bookingId) — skip expense");
      return;
    }

    final b = snap.data()!;
    final status = (b['status'] ?? '').toString().toUpperCase();
    if (status != 'CONFIRMED') {
      debugPrint("ℹ️ booking status is $status (not CONFIRMED) — skip expense");
      return;
    }

    final total = (b['totalPrice'] as num?)?.toDouble() ?? 0.0;
    if (total <= 0) {
      debugPrint("ℹ️ booking total is 0 — skip expense");
      return;
    }

    final hotelName = (b['hotel']?['name'] ?? 'Accommodation').toString();
    final currency = (b['currency'] ?? 'MYR').toString();
    final checkIn = (b['checkIn'] ?? '').toString();
    final checkOut = (b['checkOut'] ?? '').toString();

    final expenseRef = FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .doc('booking_$bookingId');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final existing = await tx.get(expenseRef);
      if (existing.exists) {
        debugPrint("✅ expense already exists for booking $bookingId");
        return;
      }

      tx.set(expenseRef, {
        'category': 'Accommodation',
        'amount': total,
        'currency': currency,
        'isSplit': false,
        'splitType': null,
        'customSplits': null,
        'itineraryItemId': null,
        'isOthers': false,
        'createdAt': FieldValue.serverTimestamp(),
        'paidBy': paidByUserId,
        'bookingId': bookingId,
        'note': 'Hotel: $hotelName ($checkIn → $checkOut)',
        'source': 'booking_auto',
      });
    });

    debugPrint("💾 expense posted from booking ($bookingId): $total $currency");
  }
}

class _HotelCard extends StatelessWidget {
  const _HotelCard({
    required this.name,
    required this.address,
    required this.hotel,
  });
  final String name;
  final String address;
  final Map<String, dynamic> hotel;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.apartment_rounded,
              size: 40,
              color: Color(0xFF6D4C41),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: const Color(0xFF6D4C41),
                    ),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      address,
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
      ),
    );
  }
}

class _HotelGallery extends StatefulWidget {
  const _HotelGallery({required this.primary, required this.photos});
  final String? primary;
  final List<String> photos;

  @override
  State<_HotelGallery> createState() => _HotelGalleryState();
}

class _HotelGalleryState extends State<_HotelGallery> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    final imgs = <String>[];
    if (widget.primary != null && widget.primary!.isNotEmpty)
      imgs.add(widget.primary!);
    imgs.addAll(widget.photos.where((u) => u.isNotEmpty));
    if (imgs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: PageView.builder(
            itemCount: imgs.length,
            onPageChanged: (i) => setState(() => idx = i),
            itemBuilder:
                (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imgs[i],
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                  ),
                ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(imgs.length, (i) {
            final active = i == idx;
            return Container(
              width: active ? 10 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF6D4C41) : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6D4C41),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.checkIn,
    required this.checkOut,
    required this.onPick,
  });
  final DateTime checkIn;
  final DateTime checkOut;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Check-in', style: GoogleFonts.poppins(color: Colors.black54)),
            Text(
              _fmt(checkIn),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Check-out',
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
            Text(
              _fmt(checkOut),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: onPick,
          icon: const Icon(
            Icons.edit_calendar_rounded,
            color: Color(0xFF6D4C41),
          ),
        ),
      ],
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class BookingSuccessPage extends StatelessWidget {
  const BookingSuccessPage({
    super.key,
    required this.tripId,
    required this.bookingId,
  });

  final String tripId;
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance
              .collection('trips')
              .doc(tripId)
              .collection('bookings')
              .doc(bookingId)
              .get(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final name = data?['hotel']?['name'] ?? 'Accommodation';
        final code =
            data?['confirmationCode'] ??
            bookingId.substring(0, 6).toUpperCase();
        final inD = data?['checkIn'] ?? '';
        final outD = data?['checkOut'] ?? '';
        final total = (data?['totalPrice'] ?? 0).toString();
        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F7),
          appBar: AppBar(
            title: Text(
              'Booking Confirmed',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6D4C41),
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF6D4C41)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    size: 64,
                    color: Color(0xFF6D4C41),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You’re All Set!',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: const Color(0xFF6D4C41),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$inD → $outD',
                    style: GoogleFonts.poppins(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFD7CCC8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.confirmation_number_outlined,
                          color: Color(0xFF6D4C41),
                        ),
                        const SizedBox(width: 8),
                        SelectableText(
                          code,
                          style: GoogleFonts.poppins(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total: MYR $total',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.visibility_rounded, size: 20),
                    label: Text(
                      'View My Trip',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4C41),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        () => setStatusAndOpenMyTrips(
                          context,
                          tripId: tripId,
                          status: 'CONFIRMED',
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _genConfirmCode() {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final base36 = ts.toRadixString(36).toUpperCase();
  final salt = (ts % 97).toString().padLeft(2, '0');
  return 'EE-${base36.substring(base36.length - 5)}$salt';
}
