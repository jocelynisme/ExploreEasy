import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'main_screen.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart'
    as dp;

import 'dart:async'; // 👈 for StreamSubscription
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  print("✅ main.dart started!");
  await FirebaseAuth.instance.signOut();
  runApp(const ExploreEasyApp());
}

class ExploreEasyApp extends StatelessWidget {
  const ExploreEasyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Explore Easy',
      theme: ThemeData(
        primaryColor: Color(0xFFD7CCC8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFFD7CCC8),
          secondary: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFD7CCC8),
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFD7CCC8),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _lastUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        // Start/stop booking status checker based on auth state
        if (user != null && user.uid != _lastUid) {
          _lastUid = user.uid;
          // Use the enhanced BookingStatusChecker instead
          BookingStatusChecker.instance.start(user.uid);
        } else if (user == null && _lastUid != null) {
          BookingStatusChecker.instance.stop();
          _lastUid = null;
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (user != null) {
          return MainScreen(userId: user.uid);
        }
        return const LoginScreen();
      },
    );
  }

  @override
  void dispose() {
    BookingStatusChecker.instance.stop();
    super.dispose();
  }
}

class BookingStatusChecker {
  BookingStatusChecker._();
  static final BookingStatusChecker instance = BookingStatusChecker._();

  Timer? _timer;
  String? _uid;
  bool _isChecking = false; // prevent overlapping runs

  /// Start periodic booking status checks
  void start(String uid) {
    if (_uid == uid && _timer != null) {
      debugPrint('🔁 BookingStatusChecker already running for $uid');
      return;
    }
    stop();
    _uid = uid;

    // Run initial check immediately
    _performBookingCheck();

    // Set up periodic timer to check every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _performBookingCheck();
    });

    debugPrint('▶️ BookingStatusChecker started for $uid (every 30s)');
  }

  /// Stop periodic checking
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_uid != null) {
      debugPrint('⏹ BookingStatusChecker stopped for $_uid');
    }
    _uid = null;
  }

  /// Manual trigger for checking booking status (useful for pull-to-refresh)
  Future<void> manualCheck() async {
    debugPrint('🔄 Manual booking status check requested');
    await _performBookingCheck();
  }

  /// Perform booking status check
  Future<void> _performBookingCheck() async {
    // snapshot the uid for the WHOLE run
    final uid = _uid;
    if (uid == null) return;
    if (_isChecking) {
      debugPrint('⏳ Previous booking check still running, skipping this tick');
      return;
    }

    _isChecking = true;
    debugPrint('🔍 Checking booking status as $uid ...');

    try {
      // Query trips owned by this user
      final userTrips =
          await FirebaseFirestore.instance
              .collection('trips')
              .where('ownerId', isEqualTo: uid)
              .get();

      debugPrint('📊 Found ${userTrips.docs.length} trips owned by user');

      int totalBookings = 0;
      int processedTrips = 0;
      int errorTrips = 0;

      for (final tripDoc in userTrips.docs) {
        try {
          final bookings =
              await FirebaseFirestore.instance
                  .collection('trips')
                  .doc(tripDoc.id)
                  .collection('bookings')
                  .where('userId', isEqualTo: uid)
                  .get();

          totalBookings += bookings.docs.length;
          processedTrips++;

          for (final bookingDoc in bookings.docs) {
            await _processBookingDoc(bookingDoc, receiverUid: uid);
          }

          debugPrint(
            '✅ Trip ${tripDoc.id}: ${bookings.docs.length} bookings processed',
          );
        } catch (e) {
          errorTrips++;
          debugPrint(
            '⚠️ Skipping trip ${tripDoc.id} due to permission error: $e',
          );
          continue;
        }
      }

      debugPrint(
        '✅ Booking check completed: $processedTrips trips processed, $errorTrips trips skipped, $totalBookings total bookings',
      );
    } catch (e) {
      debugPrint('❌ Booking check failed: $e');
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _cleanupPendingNotification({
    required String receiverUid,
    required String tripId,
    required String bookingId,
  }) async {
    final pendingId = 'booking_pending_${tripId}_$bookingId';
    final ref = FirebaseFirestore.instance
        .collection('notifications')
        .doc(pendingId);
    try {
      // Delete even if it might not exist; if rules fail because doc missing, just ignore.
      await ref.delete();
      debugPrint('🧹 Removed stale pending notification $pendingId');
    } catch (e) {
      // Not found or permission edge (doc missing → rules evaluate with null resource). Ignore.
      debugPrint('ℹ️ No pending notification to remove ($pendingId): $e');
    }
  }

  Future<void> _processBookingDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String receiverUid,
  }) async {
    final data = doc.data();
    final status = (data['status']?.toString() ?? '').toUpperCase();

    final tripId = (data['tripId']?.toString() ?? '');
    if (tripId.isEmpty) return;

    final bookingId = doc.id;

    // Try to extract richer hotel/trip context for the notification
    final hotel =
        (data['hotel'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
        <String, dynamic>{};
    final hotelName =
        (hotel['name'] ?? data['hotelName'] ?? 'Accommodation').toString();

    // Dates (store as ISO for navigation payload)
    final checkInStr = (data['checkIn'] ?? '').toString();
    final checkOutStr = (data['checkOut'] ?? '').toString();

    // Trip title if you saved it on booking; fallback safe
    final tripTitle = (data['tripTitle'] ?? 'Your trip').toString();

    // Adults / price hint if available (safe fallbacks)
    final adults = (data['adults'] as num?)?.toInt() ?? 2;
    final priceHint = (data['pricePerNight'] as num?)?.toDouble() ?? 0.0;
    final isSandbox = (data['isSandbox'] as bool?) ?? true;

    debugPrint(
      '🏨 Processing booking $bookingId: status=$status, hotel=$hotelName',
    );

    if (status == 'PENDING') {
      // CREATE / UPSERT a pending notification
      await _createNotification(
        receiverUid: receiverUid,
        notifId: 'booking_pending_${tripId}_$bookingId',
        type: 'booking_pending',
        tripId: tripId,
        tripTitle: tripTitle,
        bookingId: bookingId,
        hotelName: hotelName,
        checkIn: checkInStr,
        checkOut: checkOutStr,
        message: 'Trip • $tripTitle\nYour booking at $hotelName is pending.',
        action: 'open_booking',
        actionPayload: {
          'tripId': tripId,
          'bookingId': bookingId, // 👈 ADD THIS
          'hotel': hotel, // may be partial; we’ll re-fetch on page
          'checkIn': checkInStr,
          'checkOut': checkOutStr,
          'adults': adults,
          'isSandbox': isSandbox,
          'pricePerNight': priceHint,
        },
      );

      return;
    }

    // Any non-pending status → remove stale pending notification (best-effort)
    await _cleanupPendingNotification(
      receiverUid: receiverUid,
      tripId: tripId,
      bookingId: bookingId,
    );

    // As per your request: do NOT create notifications for confirmed/cancelled/rejected
  }

  Future<void> _createNotification({
    required String receiverUid,
    required String notifId,
    required String type,
    required String tripId,
    required String tripTitle,
    required String bookingId,
    required String hotelName,
    required String checkIn,
    required String checkOut,
    required String message,
    String? action, // NEW
    Map<String, dynamic>? actionPayload, // NEW
  }) async {
    final notifRef = FirebaseFirestore.instance
        .collection('notifications')
        .doc(notifId);

    try {
      await notifRef.set({
        'type': type,
        'status': 'new',
        'senderId': receiverUid, // or 'system'
        'receiverId': receiverUid, // must match auth.uid per your rules
        'tripId': tripId,
        'tripTitle': tripTitle,
        'bookingId': bookingId,
        'hotelName': hotelName,
        'checkIn': checkIn,
        'checkOut': checkOut,
        'message': message, // ← includes Trip title
        'action': action, // ← NEW (e.g., "open_booking")
        'actionPayload': actionPayload, // ← NEW (navigation args)
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));

      debugPrint('📬 $type notification created: $notifId');
    } catch (e) {
      debugPrint('❌ Failed to create notification $notifId: $e');
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  String? _errorMessage;
  bool _isLoading = false;

  String _getCustomErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return "No user found, please register first.";
      case 'wrong-password':
        return "Incorrect password. Please try again.";
      case 'invalid-email':
        return "The email address is invalid.";
      case 'too-many-requests':
        return "Too many login attempts. Try again later.";
      default:
        return "Login failed: ${e.message}";
    }
  }

  Future<void> _signIn(String email, String password) async {
    final stopwatch = Stopwatch()..start();
    setState(() {
      _isLoading = true;
    });

    try {
      print("⏱ Signing in...");
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("✅ FirebaseAuth done in ${stopwatch.elapsedMilliseconds}ms");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(userId: userCredential.user!.uid),
        ),
      );
    } on FirebaseAuthException catch (e) {
      print("❌ Sign-in failed in ${stopwatch.elapsedMilliseconds}ms");

      if (e.code == 'user-not-found') {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Login Failed"),
                content: const Text("No user found, please register first."),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: const Text("Register"),
                  ),
                ],
              ),
        );
      } else {
        String errorMsg = _getCustomErrorMessage(e);
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Login Failed"),
                content: Text(errorMsg),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("OK"),
                  ),
                ],
              ),
        );
      }

      setState(() {
        _errorMessage = _getCustomErrorMessage(e);
      });
    } catch (e) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("Login Failed"),
              content: const Text(
                "An unexpected error occurred. Please try again.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ExploreEasy - Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed:
                      () => _signIn(
                        _emailController.text.trim(),
                        _passwordController.text.trim(),
                      ),
                  child: const Text('Sign In'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpScreen(),
                      ),
                    );
                  },
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String? _gender;
  File? _profilePic;
  String? _errorMessage;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,}$');
  final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.(com|net|org|edu|gov|my|co\.uk|io)$",
  );

  final RegExp _passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{6,}$',
  );
  final RegExp _dobRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  final RegExp _phoneRegex = RegExp(r'^\d{9,11}$');
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _dobError;
  String? _phoneError;
  String? _genderError;

  bool _validateInputs() {
    bool isValid = true;

    setState(() {
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _dobError = null;
      _phoneError = null;
      _genderError = null;

      final username = _usernameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;
      final dob = _dobController.text.trim();
      final phone = _phoneNumberController.text.replaceAll(RegExp(r'\D'), '');

      if (username.isEmpty || !_usernameRegex.hasMatch(username)) {
        _usernameError = 'At least 3 characters, alphanumeric only.';
        isValid = false;
      }

      if (!_emailRegex.hasMatch(email)) {
        _emailError = 'Invalid email format.';
        isValid = false;
      }

      if (!_passwordRegex.hasMatch(password)) {
        _passwordError = 'Include upper, lower case & number.';
        isValid = false;
      }

      if (!_dobRegex.hasMatch(dob)) {
        _dobError = 'Use YYYY-MM-DD format.';
        isValid = false;
      } else {
        try {
          DateTime parsedDate = DateTime.parse(dob);
          int age = DateTime.now().year - parsedDate.year;
          if (parsedDate.month > DateTime.now().month ||
              (parsedDate.month == DateTime.now().month &&
                  parsedDate.day > DateTime.now().day)) {
            age--;
          }
          if (age < 13) {
            _dobError = 'You must be at least 13 years old.';
            isValid = false;
          }
        } catch (_) {
          _dobError = 'Invalid date.';
          isValid = false;
        }
      }

      if (!_phoneRegex.hasMatch(phone)) {
        _phoneError = 'Must be 9–11 digits.';
        isValid = false;
      }

      if (_gender == null) {
        _genderError = 'Select gender';
        isValid = false;
      }
    });

    return isValid;
  }

  Future<bool> _checkUsernameAvailability(String username) async {
    var result =
        await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .get();
    return result.docs.isEmpty;
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profilePic = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadProfilePic(String userId) async {
    if (_profilePic == null) return null;
    try {
      var ref = _storage.ref().child('profile_pics/$userId.jpg');

      await ref.putFile(_profilePic!);
      return await ref.getDownloadURL();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to upload profile picture: \$e';
      });
      return null;
    }
  }

  Future<void> _signUp() async {
    final stopwatch = Stopwatch()..start();
    if (!_validateInputs()) return;

    try {
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;
      final dob = _dobController.text.trim();
      final phone = _phoneNumberController.text.replaceAll(RegExp(r'\D'), '');

      // Continue as before:
      print("⏱ Creating user...");
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("✅ FirebaseAuth done in \${stopwatch.elapsedMilliseconds}ms");

      bool isUsernameAvailable = await _checkUsernameAvailability(
        _usernameController.text.trim(),
      );
      if (!isUsernameAvailable) {
        await userCredential.user?.delete();
        setState(() {
          _errorMessage = 'Username is already taken';
        });
        return;
      }

      String? profilePicUrl = await _uploadProfilePic(userCredential.user!.uid);

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'userId': userCredential.user!.uid,
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'dob': _dobController.text.trim(),
        'gender': _gender,
        'phoneNumber': _phoneNumberController.text.trim(),
        'profilePicUrl': profilePicUrl,
      });

      print("✅ Firestore write done in \${stopwatch.elapsedMilliseconds}ms");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(userId: userCredential.user!.uid),
        ),
      );
    } catch (e) {
      print("❌ Sign-up failed in \${stopwatch.elapsedMilliseconds}ms");
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sign-up failed: \${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ExploreEasy - Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                errorText: _usernameError,
              ),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'e.g. example@gmail.com',
                border: OutlineInputBorder(),
                errorText: _emailError,
              ),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Min 6 chars with A-Z, a-z, 0-9',
                border: OutlineInputBorder(),
                errorText: _passwordError,
              ),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _dobController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Date of Birth (YYYY-MM-DD)',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
                errorText: _dobError,
              ),
              // Inside your onTap:
              onTap: () {
                dp.DatePicker.showDatePicker(
                  context,
                  showTitleActions: true,
                  minTime: DateTime(1900),
                  maxTime: DateTime.now(),
                  currentTime: DateTime(2005, 1, 1),
                  locale: dp.LocaleType.en,
                  theme: dp.DatePickerTheme(
                    headerColor: Color(0xFFD7CCC8),
                    backgroundColor: Colors.white,
                    itemStyle: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    doneStyle: TextStyle(color: Colors.blue),
                  ),
                  onConfirm: (date) {
                    _dobController.text = date.toIso8601String().substring(
                      0,
                      10,
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
                errorText: _genderError,
              ),
              items:
                  ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
              onChanged: (value) => setState(() => _gender = value),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _phoneNumberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. 0123456789',
                border: OutlineInputBorder(),
                errorText: _phoneError,
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Pick Profile Picture'),
                  ),
                ),
                const SizedBox(width: 16),
                if (_profilePic != null)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: FileImage(_profilePic!),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            Center(
              child: ElevatedButton(
                onPressed: _signUp,
                child: const Text('Sign Up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
