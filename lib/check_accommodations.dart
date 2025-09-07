// lib/scripts/check_accommodations.dart
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    print("✅ Firebase initialized");

    var places =
        await FirebaseFirestore.instance
            .collection('states')
            .doc('Penang')
            .collection('areas')
            .doc('George Town')
            .collection('places')
            .where('category', isEqualTo: 'accommodation')
            .where('price_level', isLessThanOrEqualTo: 2)
            .get();
    print("Level 1–2 accommodations: ${places.docs.length}");

    // Optional: List hotel details
    for (var doc in places.docs) {
      var data = doc.data();
      print(
        "Hotel: ${data['name']}, Level: ${data['price_level']}, Cost: ${data['estimated_cost']}",
      );
    }
  } catch (e) {
    print("🚨 Error: $e");
  }
}
