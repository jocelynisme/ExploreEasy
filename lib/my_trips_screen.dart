import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:rxdart/rxdart.dart';
import 'ExpensesBreakdownPage.dart';
import 'place_details_sheet.dart';
import 'booking_flow.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import 'edit_budget_dialog.dart';

class MyTripsScreen extends StatefulWidget {
  final String userId;

  const MyTripsScreen({super.key, required this.userId});

  @override
  _MyTripsScreenState createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with TickerProviderStateMixin {
  static const _brand = Color(0xFFD7CCC8);
  static const _brandDark = Color(0xFF6D4C41);

  Future<void> _deleteTrip(
    BuildContext context,
    String tripId,
    String title,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              'Delete $title',
              style: GoogleFonts.poppins(
                color: _brandDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Are you sure you want to delete this trip? This action cannot be undone.',
              style: GoogleFonts.poppins(),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: _brandDark),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: Text('Delete', style: GoogleFonts.poppins()),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        final tripRef = FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId);

        // ✅ Delete subcollections first
        final subcollections = [
          'itinerary',
          'expenses',
          'bookings',
          'collaborators',
        ];
        for (var sub in subcollections) {
          final docs = await tripRef.collection(sub).get();
          for (var doc in docs.docs) {
            await doc.reference.delete();
          }
        }

        // ✅ Then delete parent trip document
        await tripRef.delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$title deleted successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: _brandDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );

          // Optional: navigate back to trip list if inside detail
          Navigator.of(context).maybePop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error deleting trip: $e',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          'My Trips',
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
      ),
      body: StreamBuilder<List<QuerySnapshot>>(
        stream: CombineLatestStream.combine2(
          FirebaseFirestore.instance
              .collection('trips')
              .where('ownerId', isEqualTo: widget.userId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          FirebaseFirestore.instance
              .collection('trips')
              .where('collaboratorIds', arrayContains: widget.userId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          (QuerySnapshot ownedTrips, QuerySnapshot collaboratedTrips) => [
            ownedTrips,
            collaboratedTrips,
          ],
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: _brandDark));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading trips',
                style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
              ),
            );
          }
          if (!snapshot.hasData ||
              snapshot.data == null ||
              snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.explore, size: 64, color: _brand),
                  const SizedBox(height: 16),
                  Text(
                    'No trips yet. Start planning your adventure!',
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          List<QueryDocumentSnapshot<Object?>> ownedTrips = [];
          List<QueryDocumentSnapshot<Object?>> collaboratedTrips = [];
          try {
            if (snapshot.data!.length > 0 && snapshot.data![0] != null) {
              ownedTrips = snapshot.data![0].docs;
            }
            if (snapshot.data!.length > 1 && snapshot.data![1] != null) {
              collaboratedTrips = snapshot.data![1].docs;
            }
          } catch (e) {
            return Center(
              child: Text(
                'Error processing trip data',
                style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          List<QueryDocumentSnapshot<Object?>> allTrips = [];
          Set<String> tripIds = <String>{};
          for (var trip in ownedTrips) {
            if (trip.id.isNotEmpty && !tripIds.contains(trip.id)) {
              allTrips.add(trip);
              tripIds.add(trip.id);
            }
          }
          for (var trip in collaboratedTrips) {
            if (trip.id.isNotEmpty && !tripIds.contains(trip.id)) {
              allTrips.add(trip);
              tripIds.add(trip.id);
            }
          }
          allTrips.sort((a, b) {
            try {
              var aData = a.data() as Map<String, dynamic>?;
              var bData = b.data() as Map<String, dynamic>?;
              var aCreatedAt =
                  (aData?['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
              var bCreatedAt =
                  (bData?['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
              return bCreatedAt.compareTo(aCreatedAt);
            } catch (e) {
              return 0;
            }
          });

          if (allTrips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.explore, size: 64, color: _brand),
                  const SizedBox(height: 16),
                  Text(
                    'No trips found. Let’s create one!',
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allTrips.length,
            itemBuilder: (context, index) {
              var trip = allTrips[index];
              Map<String, dynamic>? tripData;
              try {
                tripData = trip.data() as Map<String, dynamic>?;
              } catch (e) {
                return _TripCard(
                  title: 'Error loading trip',
                  startDate: null,
                  endDate: null,
                  budget: 0.0,
                  tripId: '',
                  isOwner: false,
                  userId: widget.userId,
                  onDelete: _deleteTrip,
                  animationController: AnimationController(
                    duration: const Duration(milliseconds: 500),
                    vsync: this,
                  )..forward(),
                );
              }
              if (tripData == null) {
                return _TripCard(
                  title: 'Invalid trip data',
                  startDate: null,
                  endDate: null,
                  budget: 0.0,
                  tripId: '',
                  isOwner: false,
                  userId: widget.userId,
                  onDelete: _deleteTrip,
                  animationController: AnimationController(
                    duration: const Duration(milliseconds: 500),
                    vsync: this,
                  )..forward(),
                );
              }

              var title = tripData['title'] ?? 'Untitled Trip';
              var startDate = (tripData['startDate'] as Timestamp?)?.toDate();
              var endDate = (tripData['endDate'] as Timestamp?)?.toDate();
              var budget = (tripData['budget'] as num?)?.toDouble() ?? 0.0;
              var tripId = trip.id;
              var ownerId = tripData['ownerId'] as String? ?? '';
              var isOwner = ownerId == widget.userId;

              return _TripCard(
                title: title,
                startDate: startDate,
                endDate: endDate,
                budget: budget,
                tripId: tripId,
                isOwner: isOwner,
                userId: widget.userId,
                onDelete: _deleteTrip,
                animationController: AnimationController(
                  duration: const Duration(milliseconds: 500),
                  vsync: this,
                )..forward(),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _TripCard extends StatefulWidget {
  final String title;
  final DateTime? startDate;
  final DateTime? endDate;
  final double budget;
  final String tripId;
  final bool isOwner;
  final String userId;
  final Function(BuildContext, String, String) onDelete;
  final AnimationController animationController;

  const _TripCard({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.tripId,
    required this.isOwner,
    required this.userId,
    required this.onDelete,
    required this.animationController,
  });

  @override
  __TripCardState createState() => __TripCardState();
}

class __TripCardState extends State<_TripCard> {
  static const _brand = Color(0xFFD7CCC8);
  static const _brandDark = Color(0xFF6D4C41);
  bool _isTapped = false;

  @override
  void dispose() {
    widget.animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isTapped ? 0.98 : (1.0 * animation.value),
          child: Opacity(
            opacity: animation.value,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isTapped = true),
              onTapUp: (_) => setState(() => _isTapped = false),
              onTapCancel: () => setState(() => _isTapped = false),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => TripDetailScreen(
                          tripId: widget.tripId,
                          userId: widget.userId,
                        ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, _brand.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _brand.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: _brandDark,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _brandDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.startDate != null && widget.endDate != null
                                  ? '${DateFormat('MMM d, yyyy').format(widget.startDate!)} - ${DateFormat('MMM d, yyyy').format(widget.endDate!)}'
                                  : 'No dates set',
                              style: GoogleFonts.poppins(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Budget: MYR ${widget.budget.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isOwner)
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed:
                              () => widget.onDelete(
                                context,
                                widget.tripId,
                                widget.title,
                              ),
                          tooltip: 'Delete Trip',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  final String userId;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    required this.userId,
  });

  @override
  _TripDetailScreenState createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with TickerProviderStateMixin {
  static const _brand = Color(0xFFD7CCC8);
  static const _brandDark = Color(0xFF6D4C41);
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      animationDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('trips')
                  .doc(widget.tripId)
                  .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.hasError) {
              return Text(
                'Trip Details',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              );
            }
            final tripData = snapshot.data!.data() as Map<String, dynamic>?;
            final title = tripData?['title'] ?? 'Trip Details';
            return Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            );
          },
        ),
        backgroundColor: Colors.white,
        foregroundColor: _brandDark,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_brand.withOpacity(0.35), _brand.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: _brandDark,
              unselectedLabelColor: _brandDark.withOpacity(0.6),
              indicatorColor: _brandDark,
              indicatorWeight: 3.0,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              labelStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
              isScrollable: false,
              physics: const BouncingScrollPhysics(),
              tabs: const [
                Tab(text: 'Itinerary', icon: Icon(Icons.schedule, size: 18)),
                Tab(
                  text: 'Expenses',
                  icon: Icon(Icons.account_balance_wallet, size: 18),
                ),
                Tab(text: 'Booking', icon: Icon(Icons.book_online, size: 18)),
                Tab(text: 'Collaborators', icon: Icon(Icons.people, size: 18)),
              ],
            ).animate().fadeIn(duration: const Duration(milliseconds: 600)),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [
                ItineraryTab(
                  tripId: widget.tripId,
                ).animate().fadeIn(duration: const Duration(milliseconds: 600)),
                ExpensesTab(
                  tripId: widget.tripId,
                  userId: widget.userId,
                ).animate().fadeIn(duration: const Duration(milliseconds: 600)),
                BookingTab(
                  tripId: widget.tripId,
                ).animate().fadeIn(duration: const Duration(milliseconds: 600)),
                CollaboratorsTab(
                  tripId: widget.tripId,
                  userId: widget.userId,
                ).animate().fadeIn(duration: const Duration(milliseconds: 600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CollaboratorsTab extends StatefulWidget {
  final String tripId;
  final String userId;

  const CollaboratorsTab({
    super.key,
    required this.tripId,
    required this.userId,
  });

  // Public method to trigger adding a collaborator
  void addCollaborator(BuildContext context) {
    final state = context.findAncestorStateOfType<_CollaboratorsTabState>();
    state?._addCollaborator(context);
  }

  @override
  _CollaboratorsTabState createState() => _CollaboratorsTabState();
}

class _CollaboratorsTabState extends State<CollaboratorsTab> {
  static const _brand = Color(0xFFD7CCC8);
  static const _brandDark = Color(0xFF6D4C41);

  Future<void> _addCollaborator(BuildContext context) async {
    final TextEditingController searchController = TextEditingController();
    final List<Map<String, dynamic>> searchResults = [];
    final List<Map<String, dynamic>> allUsers = [];
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setState) => AlertDialog(
                  title: Text(
                    'Add Collaborator',
                    style: GoogleFonts.poppins(
                      color: _brandDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: Colors.white,
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: searchController,
                            decoration: InputDecoration(
                              labelText: 'Search Username',
                              hintText: 'Enter username to search',
                              labelStyle: GoogleFonts.poppins(
                                color: _brandDark,
                              ),
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: _brandDark),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator:
                                (value) =>
                                    value == null || value.isEmpty
                                        ? 'Enter a username'
                                        : null,
                            onChanged: (value) async {
                              if (value.isEmpty) {
                                setState(() => searchResults.clear());
                                return;
                              }
                              try {
                                if (allUsers.isEmpty) {
                                  var usersSnapshot = await FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .get()
                                      .timeout(
                                        const Duration(seconds: 5),
                                        onTimeout:
                                            () =>
                                                throw Exception(
                                                  'Timeout fetching users',
                                                ),
                                      );
                                  allUsers.addAll(
                                    usersSnapshot.docs
                                        .map((doc) {
                                          var data = doc.data();
                                          if (!data.containsKey('username') ||
                                              !data.containsKey('email'))
                                            return null;
                                          return {
                                            'userId': doc.id,
                                            'username': data['username'],
                                            'email': data['email'],
                                          };
                                        })
                                        .where((user) => user != null)
                                        .cast<Map<String, dynamic>>(),
                                  );
                                }
                                setState(() {
                                  searchResults.clear();
                                  searchResults.addAll(
                                    allUsers
                                        .where(
                                          (user) =>
                                              user['username']
                                                  .toLowerCase()
                                                  .contains(
                                                    value.toLowerCase(),
                                                  ) &&
                                              user['userId'] != widget.userId,
                                        )
                                        .toList(),
                                  );
                                });
                              } catch (e) {
                                setState(() => searchResults.clear());
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error searching users: $e',
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
                          const SizedBox(height: 16),
                          Expanded(
                            child:
                                searchResults.isEmpty
                                    ? Text(
                                      'No users found',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black54,
                                      ),
                                    )
                                    : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: searchResults.length,
                                      itemBuilder: (context, index) {
                                        var user = searchResults[index];
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white,
                                                _brand.withOpacity(0.1),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.05,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: ListTile(
                                            contentPadding:
                                                const EdgeInsets.all(12),
                                            leading: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: _brand.withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: _brandDark,
                                                size: 24,
                                              ),
                                            ),
                                            title: Text(
                                              user['username'],
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                color: _brandDark,
                                              ),
                                            ),
                                            subtitle: Text(
                                              user['email'],
                                              style: GoogleFonts.poppins(
                                                color: Colors.black54,
                                              ),
                                            ),
                                            trailing: IconButton(
                                              icon: Icon(
                                                Icons.send,
                                                color: _brandDark,
                                              ),
                                              onPressed: () async {
                                                try {
                                                  final tripDoc =
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('trips')
                                                          .doc(widget.tripId)
                                                          .get()
                                                          .timeout(
                                                            const Duration(
                                                              seconds: 5,
                                                            ),
                                                            onTimeout:
                                                                () =>
                                                                    throw Exception(
                                                                      'Timeout fetching trip data',
                                                                    ),
                                                          );
                                                  final tripTitle =
                                                      tripDoc
                                                          .data()?['title'] ??
                                                      'Unknown Trip';
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection(
                                                        'notifications',
                                                      )
                                                      .add({
                                                        'type':
                                                            'collaborator_request',
                                                        'tripId': widget.tripId,
                                                        'tripTitle': tripTitle,
                                                        'senderId':
                                                            widget.userId,
                                                        'receiverId':
                                                            user['userId'],
                                                        'status': 'pending',
                                                        'createdAt':
                                                            FieldValue.serverTimestamp(),
                                                      });
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('trips')
                                                      .doc(widget.tripId)
                                                      .update({
                                                        'pendingCollaboratorIds':
                                                            FieldValue.arrayUnion(
                                                              [user['userId']],
                                                            ),
                                                      });
                                                  if (dialogContext.mounted) {
                                                    ScaffoldMessenger.of(
                                                      dialogContext,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Request sent to ${user['username']}',
                                                          style:
                                                              GoogleFonts.poppins(),
                                                        ),
                                                        backgroundColor:
                                                            _brandDark,
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                    );
                                                    Navigator.pop(
                                                      dialogContext,
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (dialogContext.mounted) {
                                                    ScaffoldMessenger.of(
                                                      dialogContext,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Error sending request: $e',
                                                          style:
                                                              GoogleFonts.poppins(),
                                                        ),
                                                        backgroundColor:
                                                            Colors.redAccent,
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          ),
                                        ).animate().fadeIn(
                                          duration: const Duration(
                                            milliseconds: 500,
                                          ),
                                          delay: Duration(
                                            milliseconds: index * 100,
                                          ),
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(color: _brandDark),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _removeCollaborator(
    BuildContext context,
    String collaboratorId,
    String username,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              'Remove $username',
              style: GoogleFonts.poppins(
                color: _brandDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Are you sure you want to remove $username from this trip?',
              style: GoogleFonts.poppins(),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: _brandDark),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: Text('Remove', style: GoogleFonts.poppins()),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .update({
              'collaboratorIds': FieldValue.arrayRemove([collaboratorId]),
            });
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .collection('collaborators')
            .doc(collaboratorId)
            .delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$username removed from the trip',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: _brandDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error removing collaborator: $e',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F7),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collaborators',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _brandDark,
                ),
              ),
              // Add Collaborator button -> only for owner
              StreamBuilder<DocumentSnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('trips')
                        .doc(widget.tripId)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.data() == null) {
                    return const SizedBox.shrink();
                  }
                  final tripData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  final ownerId = tripData['ownerId'] as String? ?? '';

                  final isOwner = widget.userId == ownerId;

                  return IconButton(
                    icon: Icon(
                      Icons.person_add,
                      color:
                          isOwner
                              ? _brandDark
                              : Colors.grey, // greyed out if not owner
                    ),
                    onPressed:
                        isOwner
                            ? () => _addCollaborator(context)
                            : null, // disable if not owner
                    tooltip:
                        isOwner
                            ? 'Add Collaborator'
                            : 'Only owner can add collaborators',
                  );
                },
              ),
            ],
          ),

          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('trips')
                      .doc(widget.tripId)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: _brandDark),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading collaborators',
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.data() == null) {
                  return Center(
                    child: Text(
                      'No collaborators added yet',
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                  );
                }

                final tripData = snapshot.data!.data() as Map<String, dynamic>;
                final collaboratorIds = List<String>.from(
                  tripData['collaboratorIds'] ?? [],
                );
                final ownerId = tripData['ownerId'] as String? ?? '';

                return StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('users')
                          .where(
                            FieldPath.documentId,
                            whereIn:
                                collaboratorIds.isNotEmpty
                                    ? collaboratorIds
                                    : ['dummy'],
                          )
                          .snapshots(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: _brandDark),
                      );
                    }
                    if (userSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading user data',
                          style: GoogleFonts.poppins(color: Colors.black54),
                        ),
                      );
                    }

                    final users =
                        userSnapshot.hasData ? userSnapshot.data!.docs : [];

                    return ListView.builder(
                      itemCount: users.length + (ownerId.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == 0 && ownerId.isNotEmpty) {
                          return StreamBuilder<DocumentSnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(ownerId)
                                    .snapshots(),
                            builder: (context, ownerSnapshot) {
                              if (!ownerSnapshot.hasData) {
                                return const SizedBox.shrink();
                              }
                              final ownerData =
                                  ownerSnapshot.data!.data()
                                      as Map<String, dynamic>?;
                              final name =
                                  ownerData?['username'] ??
                                  ownerData?['displayName'] ??
                                  'Owner';
                              final email = ownerData?['email'] ?? 'No email';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white,
                                      _brand.withOpacity(0.1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _brand.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: _brandDark,
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    '$name (Owner)',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: _brandDark,
                                    ),
                                  ),
                                  subtitle: Text(
                                    email,
                                    style: GoogleFonts.poppins(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn(
                                duration: const Duration(milliseconds: 500),
                                delay: Duration(milliseconds: index * 100),
                              );
                            },
                          );
                        }

                        final user =
                            users[index - (ownerId.isNotEmpty ? 1 : 0)].data()
                                as Map<String, dynamic>;
                        final name =
                            user['username'] ??
                            user['displayName'] ??
                            'Collaborator';
                        final email = user['email'] ?? 'No email';
                        final userId =
                            users[index - (ownerId.isNotEmpty ? 1 : 0)].id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white, _brand.withOpacity(0.1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _brand.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                color: _brandDark,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: _brandDark,
                              ),
                            ),
                            subtitle: Text(
                              email,
                              style: GoogleFonts.poppins(color: Colors.black54),
                            ),
                            trailing:
                                widget.userId == ownerId
                                    ? IconButton(
                                      icon: Icon(
                                        Icons.remove_circle,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed:
                                          () => _removeCollaborator(
                                            context,
                                            userId,
                                            name,
                                          ),
                                      tooltip: 'Remove Collaborator',
                                    )
                                    : null,
                          ),
                        ).animate().fadeIn(
                          duration: const Duration(milliseconds: 500),
                          delay: Duration(milliseconds: index * 100),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ItineraryTab extends StatefulWidget {
  final String tripId;

  const ItineraryTab({super.key, required this.tripId});

  @override
  _ItineraryTabState createState() => _ItineraryTabState();
}

class _ItineraryTabState extends State<ItineraryTab> {
  static const _brand = Color(0xFFD7CCC8);
  static const _brandDark = Color(0xFF6D4C41);
  late Future<Map<String, dynamic>> _dataFuture;
  bool _isMapView = false;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchItineraryAndWeather();
  }

  Future<Map<String, dynamic>> _fetchItineraryAndWeather() async {
    try {
      var tripDoc = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .get()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Timeout fetching trip data'),
          );

      var itinerarySnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .collection('itinerary')
          .orderBy('date')
          .get()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Timeout fetching itinerary'),
          );

      var weatherSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .collection('weather')
          .get()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Timeout fetching weather'),
          );

      Map<String, List<Map<String, dynamic>>> groupedItinerary = {};
      for (var doc in itinerarySnapshot.docs) {
        var data = doc.data();
        if (!data.containsKey('date') || !data.containsKey('placeId')) continue;
        var item = {
          'placeId': data['placeId'],
          'area': data['area'] ?? 'Unknown',
          'isOutdoor': data['isOutdoor'] ?? false,
          'date': data['date'],
          'sequence': data['sequence'] ?? 0,
          'docId': doc.id,
        };
        var date = (data['date'] as Timestamp).toDate();
        var dateKey = DateFormat('yyyy-MM-dd').format(date);
        groupedItinerary.putIfAbsent(dateKey, () => []);
        groupedItinerary[dateKey]!.add(item);
      }
      groupedItinerary.forEach((dateKey, items) {
        items.sort(
          (a, b) => (a['sequence'] ?? 0).compareTo(b['sequence'] ?? 0),
        );
      });

      return {
        'tripData': tripDoc.data() ?? {},
        'groupedItinerary': groupedItinerary,
        'weatherItems': weatherSnapshot.docs,
      };
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error fetching itinerary: $e',
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
      return {'groupedItinerary': {}, 'weatherItems': [], 'tripData': {}};
    }
  }

  Widget _buildDaySelector(List<String> sortedDates) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final dateKey = sortedDates[index];
          final displayDate = DateFormat(
            'MMM d',
          ).format(DateTime.parse(dateKey));
          final isSelected = index == _selectedDayIndex;

          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: Container(
              margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      isSelected
                          ? [_brand, _brandDark.withOpacity(0.8)]
                          : [Colors.white, _brand.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 72, maxWidth: 96),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Day ${index + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : _brandDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayDate,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isSelected ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(
            duration: const Duration(milliseconds: 500),
            delay: Duration(milliseconds: index * 100),
          );
        },
      ),
    );
  }

  Widget _buildPlaceCard(
    Map<String, dynamic> item,
    String weather,
    int index,
    int totalItems,
  ) {
    final placeId = item['placeId'];
    final isOutdoor = item['isOutdoor'] ?? false;
    final area = item['area'];

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('areas')
              .doc(area)
              .collection('places')
              .doc(placeId)
              .get(),
      builder: (context, placeSnapshot) {
        if (placeSnapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const ListTile(
                contentPadding: EdgeInsets.all(12),
                leading: CircularProgressIndicator(color: _brandDark),
                title: Text(
                  'Loading...',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          );
        }
        if (!placeSnapshot.hasData || !placeSnapshot.data!.exists) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Icon(Icons.error, color: Colors.redAccent),
                title: Text(
                  'Place Not Found',
                  style: GoogleFonts.poppins(color: Colors.black54),
                ),
              ),
            ),
          );
        }

        final placeData = placeSnapshot.data!.data() as Map<String, dynamic>?;
        final placeName = placeData?['name'] ?? 'Unknown';
        final category = placeData?['category'] ?? 'Unknown';
        final description =
            placeData?['description'] ?? 'No description available';
        final rating =
            (placeData?['rating'] is num)
                ? (placeData!['rating'] as num).toDouble()
                : 0.0;

        String? imageUrl;
        if (placeData?['primaryPhotoUrl'] != null) {
          imageUrl = placeData!['primaryPhotoUrl'] as String?;
        } else if (placeData?['photoUrls'] != null) {
          final photoUrls = placeData!['photoUrls'] as List?;
          if (photoUrls != null && photoUrls.isNotEmpty)
            imageUrl = photoUrls.first.toString();
        } else if (placeData?['imageUrl'] != null) {
          imageUrl = placeData!['imageUrl'] as String?;
        } else if (placeData?['image'] != null) {
          imageUrl = placeData!['image'] as String?;
        }

        final IconData categoryIcon = _getCategoryIcon(category);
        final Color categoryColor = _getCategoryColor(category);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Stack(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap:
                      () => _showPlaceDetails(
                        placeData,
                        placeName,
                        weather,
                        isOutdoor,
                      ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              (imageUrl != null && imageUrl.isNotEmpty)
                                  ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: _brandDark,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _buildPlaceholderImage(
                                              categoryIcon,
                                              categoryColor,
                                            ),
                                  )
                                  : _buildPlaceholderImage(
                                    categoryIcon,
                                    categoryColor,
                                  ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.1),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    placeName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: _brandDark,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (rating > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _CategoryChip(
                                  categoryIcon: categoryIcon,
                                  categoryColor: categoryColor,
                                  category: category,
                                ),
                                _IndoorOutdoorChip(isOutdoor: isOutdoor),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: GoogleFonts.poppins(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.cloud, color: _brandDark, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Weather: $weather',
                                    style: GoogleFonts.poppins(
                                      color: _brandDark,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _brandDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(
          duration: const Duration(milliseconds: 500),
          delay: Duration(milliseconds: index * 100),
        );
      },
    );
  }

  Widget _buildPlaceholderImage(IconData icon, Color color) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(icon, size: 48, color: Colors.white)),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'restaurant':
      case 'food':
        return Icons.restaurant;
      case 'attraction':
      case 'tourist_attraction':
        return Icons.place;
      case 'hotel':
      case 'accommodation':
        return Icons.hotel;
      case 'shopping':
        return Icons.shopping_bag;
      case 'transport':
        return Icons.directions_bus;
      case 'entertainment':
        return Icons.movie;
      case 'park':
        return Icons.park;
      case 'museum':
        return Icons.museum;
      default:
        return Icons.location_on;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'restaurant':
      case 'food':
        return Colors.orange;
      case 'attraction':
      case 'tourist_attraction':
        return Colors.red;
      case 'hotel':
      case 'accommodation':
        return Colors.blue;
      case 'shopping':
        return Colors.purple;
      case 'transport':
        return Colors.green;
      case 'entertainment':
        return Colors.pink;
      case 'park':
        return Colors.lightGreen;
      case 'museum':
        return Colors.brown;
      default:
        return _brand;
    }
  }

  void _showPlaceDetails(
    Map<String, dynamic>? placeData,
    String placeName,
    String weather,
    bool isOutdoor,
  ) {
    // Extract the area from the place data or use a default
    final area = placeData?['area'] as String? ?? 'George Town';
    final placeId = placeData?['placeId'] as String? ?? '';

    if (placeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Place ID not found',
            style: GoogleFonts.poppins(color: Color(0xFF6D4C41), fontSize: 14),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // Use your existing PlaceDetailsSheet
    PlaceDetailsSheet.show(
      context,
      areaId: area,
      placeId: placeId,
      radiusKm: 2.0,
    );
  }

  Widget _buildListView(
    List<String> sortedDates,
    Map<String, List<Map<String, dynamic>>> groupedItinerary,
    Map<String, String> weatherMap,
  ) {
    if (_selectedDayIndex >= sortedDates.length) {
      return Center(
        child: Text(
          'No itinerary for selected day',
          style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
        ),
      );
    }

    var selectedDateKey = sortedDates[_selectedDayIndex];
    var dayItems = groupedItinerary[selectedDateKey] ?? [];
    var displayDate = DateFormat(
      'MMMM d, yyyy',
    ).format(DateTime.parse(selectedDateKey));
    var weather = weatherMap[selectedDateKey] ?? 'Unknown';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day ${_selectedDayIndex + 1}',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                displayDate,
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.cloud, color: Colors.white70, size: 16),
                  Text(
                    'Weather: $weather',
                    style: GoogleFonts.poppins(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${dayItems.length} places',
                    style: GoogleFonts.poppins(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (dayItems.isEmpty)
          Center(
            child: Text(
              'No places planned for this day',
              style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
            ),
          )
        else
          ...dayItems.asMap().entries.map(
            (entry) => _buildPlaceCard(
              entry.value,
              weather,
              entry.key,
              dayItems.length,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F7),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading itinerary',
                style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _brandDark));
          }

          var groupedItinerary =
              snapshot.data!['groupedItinerary']
                  as Map<String, List<Map<String, dynamic>>>;
          var weatherItems =
              snapshot.data!['weatherItems'] as List<QueryDocumentSnapshot>;
          Map<String, String> weatherMap = {
            for (var doc in weatherItems) doc['date']: doc['condition'],
          };
          var sortedDates = groupedItinerary.keys.toList()..sort();

          if (sortedDates.isEmpty) {
            return Center(
              child: Text(
                'No itinerary items found',
                style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: SegmentedButton<bool>(
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(
                                  'List View',
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                                icon: Icon(
                                  Icons.list,
                                  size: 16,
                                  color: _brandDark,
                                ),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(
                                  'Map View',
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                                icon: Icon(
                                  Icons.map,
                                  size: 16,
                                  color: _brandDark,
                                ),
                              ),
                            ],
                            selected: {_isMapView},
                            onSelectionChanged:
                                (Set<bool> selection) => setState(
                                  () => _isMapView = selection.first,
                                ),
                            style: SegmentedButton.styleFrom(
                              backgroundColor: Colors.grey[100],
                              foregroundColor: _brandDark,
                              selectedBackgroundColor: _brand,
                              selectedForegroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDaySelector(sortedDates),
                  ],
                ),
              ),
              Expanded(
                child:
                    _isMapView
                        ? Container(
                          color: const Color(0xFFF7F7F7),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map, size: 64, color: _brandDark),
                              const SizedBox(height: 16),
                              Text(
                                'Map View Coming Soon!',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: _brandDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Integrate Google Maps or similar service here',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        )
                        : _buildListView(
                          sortedDates,
                          groupedItinerary,
                          weatherMap,
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData categoryIcon;
  final Color categoryColor;
  final String category;

  const _CategoryChip({
    required this.categoryIcon,
    required this.categoryColor,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(categoryIcon, size: 16, color: categoryColor),
          const SizedBox(width: 4),
          Text(
            category,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: categoryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _IndoorOutdoorChip extends StatelessWidget {
  final bool isOutdoor;

  const _IndoorOutdoorChip({required this.isOutdoor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            isOutdoor
                ? Colors.green.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isOutdoor
                  ? Colors.green.withOpacity(0.5)
                  : Colors.blue.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOutdoor ? Icons.wb_sunny : Icons.meeting_room,
            size: 16,
            color: isOutdoor ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 4),
          Text(
            isOutdoor ? 'Outdoor' : 'Indoor',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isOutdoor ? Colors.green : Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ExpensesTab extends StatefulWidget {
  final String tripId;
  final String userId; // ✅ Add this

  const ExpensesTab({super.key, required this.tripId, required this.userId});

  @override
  _ExpensesTabState createState() => _ExpensesTabState();
}

enum IndividualSpendingView { total, byCategory }

class _ExpensesTabState extends State<ExpensesTab> {
  final _amountController = TextEditingController();
  String _selectedCurrency = 'MYR';
  String _selectedCategory = 'Accommodation';
  bool _isSplit = false;
  String? _selectedItineraryItemId;
  bool _isOthers = false;
  String _splitType = 'equal'; // New: 'equal' or 'custom'
  Map<String, double> _customSplits = {}; // New: Store custom split amounts
  Map<String, TextEditingController> _customSplitControllers = {};

  final List<String> categories = [
    'Accommodation',
    'Food',
    'Transport',
    'Flight',
    'Car Rental',
    'Gas',
    'Shopping',
    'Activities',
    'Others',
  ];

  // Define colors for each category in the pie chart
  final List<Color> categoryColors = [
    const Color(0xFFD7CCC8), // Light brown
    Colors.blue.shade300,
    Colors.green.shade300,
    Colors.orange.shade300,
    Colors.purple.shade300,
    Colors.red.shade300,
    Colors.yellow.shade300,
    Colors.teal.shade300,
    Colors.grey.shade300,
  ];

  @override
  void dispose() {
    _amountController.dispose();
    // Dispose custom split controllers
    for (var controller in _customSplitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showAddExpenseDialog({Map<String, dynamic>? existingExpense}) {
    if (existingExpense != null) {
      _amountController.text = existingExpense['amount'].toString();
      _selectedCurrency = existingExpense['currency'];
      _selectedCategory = existingExpense['category'];
      _isSplit = existingExpense['isSplit'];
      _selectedItineraryItemId = existingExpense['itineraryItemId'];
      _isOthers = existingExpense['isOthers'] ?? false;
      _splitType = existingExpense['splitType'] ?? 'equal';
      _customSplits = Map<String, double>.from(
        existingExpense['customSplits'] ?? {},
      );
    } else {
      _amountController.clear();
      _selectedCurrency = 'MYR';
      _selectedCategory = 'Accommodation';
      _isSplit = false;
      _selectedItineraryItemId = null;
      _isOthers = false;
      _splitType = 'equal';
      _customSplits = {};
      _customSplitControllers.clear();
    }

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setState) => FutureBuilder<List<String>>(
                  future: _fetchCollaborators(),
                  builder: (context, collaboratorsSnapshot) {
                    if (collaboratorsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6D4C41),
                        ),
                      );
                    }
                    final collaborators = collaboratorsSnapshot.data ?? [];
                    final allMembers = [widget.userId, ...collaborators];
                    final isSoloTrip =
                        collaborators.isEmpty; // Check if no collaborators

                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.white,
                      title: Text(
                        existingExpense == null
                            ? 'Add Expense'
                            : 'Edit Expense',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6D4C41),
                        ),
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                labelStyle: GoogleFonts.poppins(
                                  color: Color(0xFF6D4C41),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Color(0xFFD7CCC8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (!isSoloTrip) ...[
                              // Only show split option for group trips
                              SwitchListTile(
                                title: Text(
                                  'Split Expense?',
                                  style: GoogleFonts.poppins(
                                    color: Color(0xFF6D4C41),
                                  ),
                                ),
                                activeColor: Color(0xFFD7CCC8),
                                value: _isSplit,
                                onChanged: (value) {
                                  setState(() {
                                    _isSplit = value;
                                    if (!value) {
                                      _splitType = 'equal';
                                      _customSplits.clear();
                                    }
                                  });
                                },
                              ),
                            ],
                            if (_isSplit && !isSoloTrip) ...[
                              const SizedBox(height: 8),
                              DropdownButton<String>(
                                value: _splitType,
                                isExpanded: true,
                                items: [
                                  DropdownMenuItem(
                                    value: 'equal',
                                    child: Text(
                                      'Equal Split',
                                      style: GoogleFonts.poppins(
                                        color: Color(0xFF6D4C41),
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'custom',
                                    child: Text(
                                      'Custom Split',
                                      style: GoogleFonts.poppins(
                                        color: Color(0xFF6D4C41),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _splitType = value!;
                                    if (_splitType == 'equal') {
                                      _customSplitControllers.clear();
                                      _customSplits.clear();
                                    } else {
                                      _customSplits = {
                                        for (var member in allMembers)
                                          member: 0.0,
                                      };
                                    }
                                  });
                                },
                                style: GoogleFonts.poppins(
                                  color: Color(0xFF6D4C41),
                                ),
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),

                              // Replace the custom split TextField section
                              if (_splitType == 'custom') ...[
                                const SizedBox(height: 8),
                                FutureBuilder<Map<String, String>>(
                                  future: _fetchUserIdToUsername(allMembers),
                                  builder: (context, usernameSnapshot) {
                                    if (usernameSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const SizedBox.shrink();
                                    }
                                    final userIdToUsername =
                                        usernameSnapshot.data ?? {};

                                    // Create controllers map outside of the build to persist them
                                    if (_customSplitControllers.isEmpty) {
                                      _customSplitControllers = {
                                        for (var member in allMembers)
                                          member: TextEditingController(
                                            text: (_customSplits[member] ?? 0.0)
                                                .toStringAsFixed(2),
                                          ),
                                      };
                                    }

                                    return Column(
                                      children:
                                          allMembers.map((member) {
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4.0,
                                                  ),
                                              child: TextField(
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  labelText:
                                                      'Amount for ${userIdToUsername[member] ?? member}',
                                                  labelStyle:
                                                      GoogleFonts.poppins(
                                                        color: Color(
                                                          0xFF6D4C41,
                                                        ),
                                                      ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: Color(
                                                            0xFFD7CCC8,
                                                          ),
                                                        ),
                                                      ),
                                                ),
                                                controller:
                                                    _customSplitControllers[member],
                                                onChanged: (value) {
                                                  final amount =
                                                      double.tryParse(value) ??
                                                      0.0;
                                                  _customSplits[member] =
                                                      amount;
                                                },
                                              ),
                                            );
                                          }).toList(),
                                    );
                                  },
                                ),
                              ],
                            ],

                            const SizedBox(height: 8),
                            DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              items:
                                  categories.map((category) {
                                    return DropdownMenuItem<String>(
                                      value: category,
                                      child: Text(
                                        category,
                                        style: GoogleFonts.poppins(
                                          color: Color(0xFF6D4C41),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value!;
                                });
                              },
                              style: GoogleFonts.poppins(
                                color: Color(0xFF6D4C41),
                              ),
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(
                        duration: const Duration(milliseconds: 500),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              color: Color(0xFF6D4C41),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            var amount = double.tryParse(
                              _amountController.text,
                            );
                            if (amount == null || amount <= 0) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                          'Please enter a valid amount',
                                          style: GoogleFonts.poppins(
                                            color: Color(0xFF6D4C41),
                                            fontSize: 14,
                                          ),
                                        )
                                        .animate() // ✅ animate the content, not the SnackBar
                                        .fadeIn(
                                          duration: const Duration(
                                            milliseconds: 500,
                                          ),
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

                            if (_isSplit &&
                                _splitType == 'custom' &&
                                !isSoloTrip) {
                              double totalCustomSplit = _customSplits.values
                                  .reduce((a, b) => a + b);
                              if ((totalCustomSplit - amount).abs() > 0.01) {
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                            'Custom split amounts must equal total amount',
                                            style: GoogleFonts.poppins(
                                              color: Color(0xFF6D4C41),
                                              fontSize: 14,
                                            ),
                                          )
                                          .animate() // ✅ animate the content, not the SnackBar
                                          .fadeIn(
                                            duration: const Duration(
                                              milliseconds: 500,
                                            ),
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
                            }

                            var expenseData = {
                              'category': _selectedCategory,
                              'amount': amount,
                              'currency': _selectedCurrency,
                              'isSplit': _isSplit && !isSoloTrip,
                              'itineraryItemId': _selectedItineraryItemId,
                              'isOthers': _isOthers,
                              'splitType':
                                  (_isSplit && !isSoloTrip) ? _splitType : null,
                              'customSplits':
                                  (_isSplit &&
                                          _splitType == 'custom' &&
                                          !isSoloTrip)
                                      ? _customSplits
                                      : null,
                              'createdAt': Timestamp.now(),
                              'addedBy':
                                  widget
                                      .userId, // ✅ This tracks who added/paid for the expense
                              // Remove the old paidBy logic since we're using addedBy now
                            };

                            final expenseRef = FirebaseFirestore.instance
                                .collection('trips')
                                .doc(widget.tripId)
                                .collection('expenses');

                            if (existingExpense == null) {
                              await expenseRef.add(expenseData);

                              // Send notifications for split expenses
                              if (_isSplit && !isSoloTrip) {
                                final collaborators =
                                    await _fetchCollaborators();
                                final allMembers = [
                                  widget.userId,
                                  ...collaborators,
                                ];

                                // Get current user's username
                                final currentUserDoc =
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(widget.userId)
                                        .get();
                                final currentUsername =
                                    currentUserDoc.data()?['username'] ??
                                    'Someone';

                                // Calculate split amount per person
                                double splitAmountPerPerson;
                                if (_splitType == 'custom') {
                                  // For custom splits, send individual notifications with specific amounts
                                  for (var member in allMembers) {
                                    if (member != widget.userId) {
                                      // Don't notify the person who added the expense
                                      final memberSplitAmount =
                                          _customSplits[member] ?? 0.0;
                                      if (memberSplitAmount > 0) {
                                        await FirebaseFirestore.instance
                                            .collection('notifications')
                                            .add({
                                              'type': 'split_expense',
                                              'tripId': widget.tripId,
                                              'senderId': widget.userId,
                                              'receiverId': member,
                                              'status': 'new',
                                              'createdAt':
                                                  FieldValue.serverTimestamp(),
                                              'message':
                                                  '$currentUsername added a split expense: $_selectedCategory (MYR ${amount.toStringAsFixed(2)})',
                                              'data': {
                                                'amount': amount,
                                                'category': _selectedCategory,
                                                'splitAmount':
                                                    memberSplitAmount,
                                                'fromUsername': currentUsername,
                                                'expenseId':
                                                    expenseRef
                                                        .id, // Store reference to expense
                                              },
                                            });
                                      }
                                    }
                                  }
                                } else {
                                  // Equal split
                                  splitAmountPerPerson =
                                      amount / allMembers.length;
                                  for (var member in allMembers) {
                                    if (member != widget.userId) {
                                      // Don't notify the person who added the expense
                                      await FirebaseFirestore.instance
                                          .collection('notifications')
                                          .add({
                                            'type': 'split_expense',
                                            'tripId': widget.tripId,
                                            'senderId': widget.userId,
                                            'receiverId': member,
                                            'status': 'new',
                                            'createdAt':
                                                FieldValue.serverTimestamp(),
                                            'message':
                                                '$currentUsername added a split expense: $_selectedCategory (MYR ${amount.toStringAsFixed(2)})',
                                            'data': {
                                              'amount': amount,
                                              'category': _selectedCategory,
                                              'splitAmount':
                                                  splitAmountPerPerson,
                                              'fromUsername': currentUsername,
                                              'expenseId':
                                                  expenseRef
                                                      .id, // Store reference to expense
                                            },
                                          });
                                    }
                                  }
                                }
                              }
                            }

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            Future.delayed(Duration(milliseconds: 300), () {
                              checkAndSendBudgetWarning(
                                widget.tripId,
                                widget.userId,
                                context,
                              );
                            });
                          },
                          child: Text(
                            'Save',
                            style: GoogleFonts.poppins(
                              color: Color(0xFF6D4C41),
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(
                      duration: const Duration(milliseconds: 500),
                    );
                  },
                ),
          ),
    );
  }

  Future<List<String>> _fetchCollaborators() async {
    var tripDoc =
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .get();
    return List<String>.from(tripDoc.data()?['collaboratorIds'] ?? []);
  }

  Future<void> checkAndSendBudgetWarning(
    String tripId,
    String userId,
    BuildContext context, // 🔸 Add context for UI alert
  ) async {
    print("🔥 UNIQUE_DEBUG_12345 - Budget check started for trip: $tripId");
    print("🚀 Starting budget check for tripId: $tripId, userId: $userId");

    final tripDoc =
        await FirebaseFirestore.instance.collection('trips').doc(tripId).get();

    print("📄 Trip document fetch result: exists=${tripDoc.exists}");
    if (!tripDoc.exists) {
      print("❌ Trip document not found, returning early");
      return;
    }

    final trip = tripDoc.data()!;
    final budget = trip['budget']?.toDouble() ?? 0.0;
    final tripTitle = trip['title'] ?? 'Unnamed Trip';

    print(
      "💼 Trip details: title='$tripTitle', budget=\$${budget.toStringAsFixed(2)}",
    );

    if (budget == 0) {
      print("⚠️ Budget is 0, skipping check");
      return;
    }

    print("📊 Fetching expenses for trip: $tripId");
    final expensesSnapshot =
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId)
            .collection('expenses')
            .get();

    print("📋 Found ${expensesSnapshot.docs.length} expense documents");

    double totalSpent = 0.0;
    for (var doc in expensesSnapshot.docs) {
      final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
      totalSpent += amount;
      print(
        "💸 Expense ${doc.id}: \$${amount.toStringAsFixed(2)} (running total: \$${totalSpent.toStringAsFixed(2)})",
      );
    }

    final percentUsed = (totalSpent / budget) * 100;
    print(
      "💰 Final calculation: \$${totalSpent.toStringAsFixed(2)} / \$${budget.toStringAsFixed(2)} = ${percentUsed.toStringAsFixed(1)}%",
    );

    if (percentUsed >= 80) {
      print(
        "🚨 Budget warning threshold reached (${percentUsed.toStringAsFixed(1)}% >= 80%)",
      );

      try {
        // 🔔 Save to Firestore
        final notificationRef = await FirebaseFirestore.instance
            .collection('notifications')
            .add({
              'type': 'budget_warning',
              'tripId': tripId,
              'tripTitle': tripTitle,
              'senderId': userId,
              'receiverId': userId,
              'status': 'new',
              'createdAt': Timestamp.now(),
              "message":
                  "⚠️ You've used ${percentUsed.toStringAsFixed(1)}% of your budget for \"$tripTitle\". Do you want to adjust it?",
            });
        print("✅ Budget warning notification created: ${notificationRef.id}");
      } catch (e) {
        print("❌ Error creating notification: $e");
      }

      print("🔔 Budget warning sent to $userId for trip: $tripTitle");

      // 🧾 Show popup immediately
      if (context.mounted) {
        print("🎯 Context is mounted, showing popup budget alert...");
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.white,
                title: Text(
                  '⚠️ Budget Alert - $tripTitle',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6D4C41),
                  ),
                ),
                content: Text(
                  'You\'ve used ${percentUsed.toStringAsFixed(1)}% of your budget for "$tripTitle".\n\nCurrent budget: \$${budget.toStringAsFixed(2)}\nAmount spent: \$${totalSpent.toStringAsFixed(2)}\n\nDo you want to adjust the budget?',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
                actions: [
                  TextButton(
                    child: Text(
                      "Not Now",
                      style: GoogleFonts.poppins(color: Color(0xFF6D4C41)),
                    ),
                    onPressed: () {
                      print("🚫 User selected 'Not Now' for budget adjustment");
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text(
                      "Adjust Budget",
                      style: GoogleFonts.poppins(color: Color(0xFF6D4C41)),
                    ),
                    onPressed: () async {
                      print("✏️ User selected 'Adjust Budget'");
                      Navigator.of(context).pop();
                      print(
                        "🎯 Triggering budget adjustment for tripId: $tripId",
                      );

                      try {
                        print("📤 Re-fetching trip data for budget dialog...");
                        final tripDoc =
                            await FirebaseFirestore.instance
                                .collection('trips')
                                .doc(tripId)
                                .get();
                        print("📥 Trip fetch result: exists=${tripDoc.exists}");

                        if (!tripDoc.exists) {
                          print(
                            "❌ Trip not found when trying to show budget dialog",
                          );
                          return;
                        }

                        final currentBudget =
                            tripDoc.data()?['budget']?.toDouble() ?? 0.0;
                        print(
                          "💼 Current budget for dialog: \$${currentBudget.toStringAsFixed(2)}",
                        );

                        print("🎨 Calling _showEditBudgetDialog...");
                        _showEditBudgetDialog(context, tripId, currentBudget);
                        print("✅ _showEditBudgetDialog called successfully");
                      } catch (e) {
                        print("❌ Error in budget adjustment flow: $e");
                        print("🔍 Error details: ${e.toString()}");
                      }
                    },
                  ),
                ],
              ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
        );
        print("✅ Budget alert dialog shown successfully");
      } else {
        print("⚠️ Context not mounted, skipping dialog");
      }
    } else {
      print(
        "✅ Budget under control for $tripTitle (${percentUsed.toStringAsFixed(1)}% < 80%)",
      );
    }

    print("🏁 Budget check completed for trip: $tripTitle");
  }

  void _showEditBudgetDialog(
    BuildContext context,
    String tripId,
    double currentBudget,
  ) {
    final _budgetController = TextEditingController(
      text: currentBudget.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.white,
            title: Text(
              'Adjust Budget',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6D4C41),
              ),
            ),
            content: TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'New Budget Amount (MYR)',
                labelStyle: GoogleFonts.poppins(color: Color(0xFF6D4C41)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFFD7CCC8)),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Color(0xFF6D4C41)),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newBudget = double.tryParse(_budgetController.text);
                  if (newBudget == null || newBudget <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                              'Please enter a valid budget',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF6D4C41),
                                fontSize: 14,
                              ),
                            )
                            .animate() // ✅ animate the Text widget instead
                            .fadeIn(
                              duration: const Duration(milliseconds: 500),
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

                  final userId =
                      FirebaseFirestore.instance.app.options.projectId;

                  try {
                    // 🔍 DEBUG: Fetch trip doc
                    final tripDoc =
                        await FirebaseFirestore.instance
                            .collection('trips')
                            .doc(tripId)
                            .get();

                    if (!tripDoc.exists) {
                      print("❌ Trip document not found.");
                      return;
                    }

                    final tripData = tripDoc.data()!;
                    // after reading tripData:
                    final ownerId = tripData['ownerId'] as String? ?? userId;
                    final collaboratorIds = List<String>.from(
                      tripData['collaboratorIds'] ?? [],
                    );
                    final allMembers = [ownerId, ...collaboratorIds];

                    final currentUserId =
                        FirebaseAuth.instance.currentUser?.uid ?? '';

                    print("👤 Current user ID: $currentUserId");
                    print("👑 Owner ID: $ownerId");
                    print("🧑‍🤝‍🧑 Collaborators: $collaboratorIds");

                    final isOwner = ownerId == currentUserId;
                    final isCollaborator = collaboratorIds.contains(
                      currentUserId,
                    );
                    print("✅ Is owner? $isOwner");
                    print("✅ Is collaborator? $isCollaborator");

                    // 🚀 Attempt update
                    await FirebaseFirestore.instance
                        .collection('trips')
                        .doc(tripId)
                        .update({'budget': newBudget});
                    print("✅ Budget updated to $newBudget");

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                              'Budget updated successfully!',
                              style: GoogleFonts.poppins(
                                color: Color(0xFF6D4C41),
                                fontSize: 14,
                              ),
                            )
                            .animate() // <-- animate the Text widget
                            .fadeIn(
                              duration: const Duration(milliseconds: 500),
                            ),
                        backgroundColor: const Color(0xFFD7CCC8),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  } catch (e) {
                    print("❌ Failed to update budget: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                              'Error updating budget: $e',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF6D4C41),
                                fontSize: 14,
                              ),
                            )
                            .animate() // animate the content, not the SnackBar
                            .fadeIn(
                              duration: const Duration(milliseconds: 500),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFD7CCC8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Save',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
    );
  }

  // Receipt Viewer Dialog
  void _showReceiptViewer(
    BuildContext context,
    String receiptUrl,
    String note,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF6D4C41),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment Receipt',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              receiptUrl,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF6D4C41),
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder:
                                  (context, error, stackTrace) => Container(
                                    height: 200,
                                    color: Colors.grey.shade200,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.error,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                          Text(
                                            'Failed to load image',
                                            style: GoogleFonts.poppins(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                          if (note.isNotEmpty) ...[
                            SizedBox(height: 16),
                            Text(
                              'Note:',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6D4C41),
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                note,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Helper function to format date time
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  // Complete Settlement Dashboard Widget - Add this to your _ExpensesTabState class
  // Enhanced Settlement Dashboard with Pending Status Logic
  Widget _buildSettlementDashboard(
    List<QueryDocumentSnapshot> expenses,
    Map<String, dynamic> tripData,
    List<String> collaborators,
  ) {
    if (collaborators.isEmpty) {
      return SizedBox.shrink(); // Don't show for solo trips
    }

    final allMembers = [tripData['ownerId'] as String, ...collaborators];

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('trips')
              .doc(widget.tripId)
              .collection('settlements')
              .snapshots(),
      builder: (context, settlementsSnapshot) {
        final settlements = settlementsSnapshot.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('trips')
                  .doc(widget.tripId)
                  .collection('payment_receipts')
                  .snapshots(),
          builder: (context, receiptsSnapshot) {
            final paymentReceipts = receiptsSnapshot.data?.docs ?? [];

            // Calculate what each person paid and what they owe
            Map<String, double> totalPaid = {};
            Map<String, double> totalOwed = {};

            // Initialize maps
            for (var member in allMembers) {
              totalPaid[member] = 0.0;
              totalOwed[member] = 0.0;
            }

            // Calculate actual payments and debts from expenses
            for (var expense in expenses) {
              var data = expense.data() as Map<String, dynamic>;
              var amount = data['amount']?.toDouble() ?? 0.0;
              var isSplit = data['isSplit'] ?? false;
              var splitType = data['splitType'] ?? 'equal';
              var customSplits = data['customSplits'] as Map<String, dynamic>?;
              var paidBy =
                  data['addedBy'] as String? ??
                  data['paidBy'] as String? ??
                  tripData['ownerId'] as String;

              // Add to what this person paid
              totalPaid[paidBy] = (totalPaid[paidBy] ?? 0.0) + amount;

              if (isSplit) {
                if (splitType == 'custom' && customSplits != null) {
                  // Custom split - use specified amounts
                  for (var member in allMembers) {
                    var owedAmount =
                        (customSplits[member] as num?)?.toDouble() ?? 0.0;
                    totalOwed[member] = (totalOwed[member] ?? 0.0) + owedAmount;
                  }
                } else {
                  // Equal split
                  var splitAmount = amount / allMembers.length;
                  for (var member in allMembers) {
                    totalOwed[member] =
                        (totalOwed[member] ?? 0.0) + splitAmount;
                  }
                }
              } else {
                // Not split - only the payer owes this amount
                totalOwed[paidBy] = (totalOwed[paidBy] ?? 0.0) + amount;
              }
            }

            // Apply existing settlements to adjust balances
            for (var settlement in settlements) {
              var settlementData = settlement.data() as Map<String, dynamic>;
              var fromUserId = settlementData['fromUserId'] as String;
              var toUserId = settlementData['toUserId'] as String;
              var amount = settlementData['amount']?.toDouble() ?? 0.0;

              // Adjust the paid amounts based on settlements
              totalPaid[fromUserId] = (totalPaid[fromUserId] ?? 0.0) + amount;
              totalPaid[toUserId] = (totalPaid[toUserId] ?? 0.0) - amount;
            }

            // Calculate net balances (positive = owes money, negative = is owed money)
            Map<String, double> netBalances = {};
            for (var member in allMembers) {
              netBalances[member] =
                  (totalOwed[member] ?? 0.0) - (totalPaid[member] ?? 0.0);
            }

            // Calculate settlements using a simple greedy algorithm
            List<Map<String, dynamic>> suggestedSettlements =
                _calculateSettlements(netBalances);

            // Check for pending receipts for each settlement
            Map<String, bool> settlementHasPendingReceipt = {};
            for (var settlement in suggestedSettlements) {
              final key = '${settlement['from']}_${settlement['to']}';
              settlementHasPendingReceipt[key] = paymentReceipts.any((receipt) {
                final receiptData = receipt.data() as Map<String, dynamic>;
                return receiptData['fromUserId'] == settlement['from'] &&
                    receiptData['toUserId'] == settlement['to'] &&
                    receiptData['status'] == 'pending_confirmation';
              });
            }

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Color(0xFF6D4C41),
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Settlement Dashboard',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6D4C41),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Individual balances section
                    FutureBuilder<Map<String, String>>(
                      future: _fetchUserIdToUsername(allMembers),
                      builder: (context, usernameSnapshot) {
                        if (usernameSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator(
                            color: Color(0xFF6D4C41),
                          );
                        }

                        final userIdToUsername = usernameSnapshot.data ?? {};

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Individual Balances:',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6D4C41),
                              ),
                            ),
                            SizedBox(height: 8),
                            ...allMembers.map((member) {
                              final balance = netBalances[member] ?? 0.0;
                              final username =
                                  userIdToUsername[member] ?? member;
                              final isCurrentUser = member == widget.userId;

                              return Container(
                                margin: EdgeInsets.symmetric(vertical: 2),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isCurrentUser
                                          ? Color(0xFFF5F5F5)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      isCurrentUser
                                          ? Border.all(
                                            color: Color(0xFFD7CCC8),
                                            width: 2,
                                          )
                                          : null,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        if (isCurrentUser)
                                          Icon(
                                            Icons.person,
                                            size: 16,
                                            color: Color(0xFF6D4C41),
                                          ),
                                        if (isCurrentUser) SizedBox(width: 4),
                                        Text(
                                          isCurrentUser
                                              ? '$username (You)'
                                              : username,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight:
                                                isCurrentUser
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                            color: Color(0xFF6D4C41),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      balance > 0.01
                                          ? 'Owes MYR ${balance.toStringAsFixed(2)}'
                                          : balance < -0.01
                                          ? 'Is owed MYR ${(-balance).toStringAsFixed(2)}'
                                          : 'Settled up',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            balance > 0.01
                                                ? Colors.red.shade600
                                                : balance < -0.01
                                                ? Colors.green.shade600
                                                : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),

                            if (suggestedSettlements.isNotEmpty) ...[
                              SizedBox(height: 16),
                              Divider(color: Color(0xFFE0E0E0)),
                              SizedBox(height: 8),
                              Text(
                                'Suggested Settlements:',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6D4C41),
                                ),
                              ),
                              SizedBox(height: 8),
                              ...suggestedSettlements.map((settlement) {
                                final fromUser =
                                    userIdToUsername[settlement['from']] ??
                                    settlement['from'];
                                final toUser =
                                    userIdToUsername[settlement['to']] ??
                                    settlement['to'];
                                final amount = settlement['amount'] as double;
                                final isCurrentUserInvolved =
                                    settlement['from'] == widget.userId ||
                                    settlement['to'] == widget.userId;
                                final settlementKey =
                                    '${settlement['from']}_${settlement['to']}';
                                final hasPendingReceipt =
                                    settlementHasPendingReceipt[settlementKey] ??
                                    false;

                                return Container(
                                  margin: EdgeInsets.symmetric(vertical: 2),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        isCurrentUserInvolved
                                            ? Color(0xFFFFF3E0)
                                            : Color(0xFFF8F8F8),
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        isCurrentUserInvolved
                                            ? Border.all(
                                              color: Color(0xFFFFB74D),
                                              width: 1,
                                            )
                                            : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_forward,
                                        color: Color(0xFF6D4C41),
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Color(0xFF6D4C41),
                                            ),
                                            children: [
                                              TextSpan(
                                                text:
                                                    settlement['from'] ==
                                                            widget.userId
                                                        ? 'You'
                                                        : fromUser,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              TextSpan(text: ' pays '),
                                              TextSpan(
                                                text:
                                                    'MYR ${amount.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.red.shade600,
                                                ),
                                              ),
                                              TextSpan(text: ' to '),
                                              TextSpan(
                                                text:
                                                    settlement['to'] ==
                                                            widget.userId
                                                        ? 'You'
                                                        : toUser,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Enhanced button logic with Pending status
                                      if (settlement['to'] ==
                                          widget.userId) ...[
                                        // Current user is receiving money - show "Settle" button
                                        SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed:
                                              () => _showSettleUpDialog(
                                                context,
                                                settlement['from'],
                                                settlement['to'],
                                                amount,
                                                userIdToUsername,
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.green.shade600,
                                            foregroundColor: Colors.white,
                                            minimumSize: Size(70, 30),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: Text(
                                            'Settle',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ] else if (settlement['from'] ==
                                          widget.userId) ...[
                                        // Current user owes money
                                        SizedBox(width: 8),
                                        if (hasPendingReceipt) ...[
                                          // Show "Pending" status if receipt uploaded but not settled
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.orange.shade300,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.hourglass_empty,
                                                  size: 14,
                                                  color: Colors.orange.shade700,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Pending',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        Colors.orange.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ] else ...[
                                          // Show "Pay" button if no pending receipt
                                          ElevatedButton(
                                            onPressed:
                                                () => _showPayDialog(
                                                  context,
                                                  settlement['from'],
                                                  settlement['to'],
                                                  amount,
                                                  userIdToUsername,
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.orange.shade600,
                                              foregroundColor: Colors.white,
                                              minimumSize: Size(70, 30),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            child: Text(
                                              'Pay',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ] else
                                        // User not involved - show view icon
                                        Icon(
                                          Icons.visibility,
                                          color: Colors.grey.shade600,
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ] else ...[
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade600,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'All expenses are settled up!',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: const Duration(milliseconds: 500));
          },
        );
      },
    );
  }

  // Helper method to calculate optimal settlements
  List<Map<String, dynamic>> _calculateSettlements(
    Map<String, double> netBalances,
  ) {
    List<Map<String, dynamic>> settlements = [];

    // Create lists of debtors and creditors
    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    for (var entry in netBalances.entries) {
      if (entry.value > 0.01) {
        debtors.add(entry);
      } else if (entry.value < -0.01) {
        creditors.add(MapEntry(entry.key, -entry.value));
      }
    }

    // Sort by amount (largest first)
    debtors.sort((a, b) => b.value.compareTo(a.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    // Greedy settlement algorithm
    int debtorIndex = 0;
    int creditorIndex = 0;

    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      var debtor = debtors[debtorIndex];
      var creditor = creditors[creditorIndex];

      double settlementAmount = math.min(debtor.value, creditor.value);

      if (settlementAmount > 0.01) {
        settlements.add({
          'from': debtor.key,
          'to': creditor.key,
          'amount': settlementAmount,
        });

        // Update remaining amounts
        debtors[debtorIndex] = MapEntry(
          debtor.key,
          debtor.value - settlementAmount,
        );
        creditors[creditorIndex] = MapEntry(
          creditor.key,
          creditor.value - settlementAmount,
        );
      }

      // Move to next debtor/creditor if current one is settled
      if (debtors[debtorIndex].value <= 0.01) debtorIndex++;
      if (creditors[creditorIndex].value <= 0.01) creditorIndex++;
    }

    return settlements;
  }

  // Pay Dialog Method (for people who owe money)
  void _showPayDialog(
    BuildContext context,
    String fromUserId,
    String toUserId,
    double amount,
    Map<String, String> userIdToUsername,
  ) {
    final toDisplayName =
        toUserId == widget.userId
            ? 'You'
            : (userIdToUsername[toUserId] ?? toUserId);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Icon(Icons.payment, color: Colors.orange.shade600, size: 24),
                SizedBox(width: 8),
                Text(
                  'Upload Payment Receipt',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6D4C41),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: Colors.orange.shade600,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Color(0xFF6D4C41),
                            ),
                            children: [
                              TextSpan(text: 'Payment: '),
                              TextSpan(
                                text: 'MYR ${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              TextSpan(text: ' to '),
                              TextSpan(
                                text: toDisplayName,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Please upload a receipt or proof of payment to notify the recipient.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Color(0xFF6D4C41)),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _showReceiptUploadDialog(
                    context,
                    fromUserId,
                    toUserId,
                    amount,
                    userIdToUsername,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Upload Receipt',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
    );
  }

  // Receipt Upload Dialog - Cloudinary Integration
  void _showReceiptUploadDialog(
    BuildContext context,
    String fromUserId,
    String toUserId,
    double amount,
    Map<String, String> userIdToUsername,
  ) async {
    final ImagePicker picker = ImagePicker();
    XFile? selectedImage;
    final noteController = TextEditingController();
    bool isUploading = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.white,
                  title: Text(
                    'Upload Payment Receipt',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6D4C41),
                    ),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Image preview or upload button
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child:
                              selectedImage != null
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(selectedImage!.path),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.image,
                                                    size: 50,
                                                    color: Colors.grey,
                                                  ),
                                                  Text(
                                                    'Image selected',
                                                    style:
                                                        GoogleFonts.poppins(),
                                                  ),
                                                ],
                                              ),
                                    ),
                                  )
                                  : InkWell(
                                    onTap:
                                        isUploading
                                            ? null
                                            : () async {
                                              final XFile? image = await picker
                                                  .pickImage(
                                                    source: ImageSource.gallery,
                                                    maxWidth: 1024,
                                                    maxHeight: 1024,
                                                    imageQuality: 80,
                                                  );
                                              if (image != null) {
                                                setState(() {
                                                  selectedImage = image;
                                                });
                                              }
                                            },
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.cloud_upload,
                                          size: 50,
                                          color:
                                              isUploading
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          isUploading
                                              ? 'Uploading...'
                                              : 'Tap to upload receipt',
                                          style: GoogleFonts.poppins(
                                            color:
                                                isUploading
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (isUploading)
                                          Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF6D4C41),
                                              strokeWidth: 2,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: noteController,
                          maxLines: 3,
                          enabled: !isUploading,
                          decoration: InputDecoration(
                            labelText: 'Payment note (optional)',
                            labelStyle: GoogleFonts.poppins(
                              color: Color(0xFF6D4C41),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Color(0xFFD7CCC8)),
                            ),
                            hintText: 'Add any notes about the payment...',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isUploading ? null : () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          color:
                              isUploading
                                  ? Colors.grey.shade400
                                  : Color(0xFF6D4C41),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          (selectedImage != null && !isUploading)
                              ? () async {
                                setState(() {
                                  isUploading = true;
                                });

                                try {
                                  // Upload to Cloudinary
                                  final cloudinary = CloudinaryPublic(
                                    'dkcqc2zpd',
                                    'travel_app_preset',
                                    cache: false,
                                  );

                                  CloudinaryResponse response = await cloudinary
                                      .uploadFile(
                                        CloudinaryFile.fromFile(
                                          selectedImage!.path,
                                          resourceType:
                                              CloudinaryResourceType.Image,
                                          folder: 'payment_receipts',
                                        ),
                                      );

                                  final receiptUrl = response.secureUrl;

                                  // Create payment record with receipt
                                  await FirebaseFirestore.instance
                                      .collection('trips')
                                      .doc(widget.tripId)
                                      .collection('payment_receipts')
                                      .add({
                                        'fromUserId': fromUserId,
                                        'toUserId': toUserId,
                                        'amount': amount,
                                        'receiptUrl': receiptUrl,
                                        'cloudinaryPublicId': response.publicId,
                                        'note': noteController.text.trim(),
                                        'status': 'pending_confirmation',
                                        'uploadedAt': Timestamp.now(),
                                        'tripId': widget.tripId,
                                      });

                                  // Send notification to recipient
                                  final fromUsername =
                                      userIdToUsername[fromUserId] ?? 'Someone';
                                  await FirebaseFirestore.instance
                                      .collection('notifications')
                                      .add({
                                        'type': 'payment_receipt',
                                        'tripId': widget.tripId,
                                        'senderId': fromUserId,
                                        'receiverId': toUserId,
                                        'status': 'new',
                                        'createdAt': Timestamp.now(),
                                        'message':
                                            '$fromUsername has uploaded a payment receipt for MYR ${amount.toStringAsFixed(2)}',
                                        'data': {
                                          'amount': amount,
                                          'receiptUrl': receiptUrl,
                                          'note': noteController.text.trim(),
                                        },
                                      });

                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Receipt uploaded! Recipient will be notified.',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ).animate().fadeIn(
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
                                      ),
                                      backgroundColor: Colors.green.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  setState(() {
                                    isUploading = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error uploading receipt: $e',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ).animate().fadeIn(
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
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
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (selectedImage != null && !isUploading)
                                ? Colors.green.shade600
                                : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          isUploading
                              ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                'Submit Receipt',
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                    ),
                  ],
                ),
          ),
    );
  }

  // Enhanced Settle Up Dialog that checks for payment receipts
  void _showSettleUpDialog(
    BuildContext context,
    String fromUserId,
    String toUserId,
    double amount,
    Map<String, String> userIdToUsername,
  ) {
    final fromUser = userIdToUsername[fromUserId] ?? fromUserId;
    final toUser = userIdToUsername[toUserId] ?? toUserId;
    final fromDisplayName = fromUserId == widget.userId ? 'You' : fromUser;
    final toDisplayName = toUserId == widget.userId ? 'You' : toUser;

    // Check for pending payment receipts
    showDialog(
      context: context,
      builder:
          (context) => StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('trips')
                    .doc(widget.tripId)
                    .collection('payment_receipts')
                    .where('fromUserId', isEqualTo: fromUserId)
                    .where('toUserId', isEqualTo: toUserId)
                    .where('status', isEqualTo: 'pending_confirmation')
                    .snapshots(),
            builder: (context, receiptSnapshot) {
              final receipts = receiptSnapshot.data?.docs ?? [];
              final hasReceipts = receipts.isNotEmpty;

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.white,
                title: Row(
                  children: [
                    Icon(
                      Icons.handshake,
                      color: Colors.green.shade600,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Confirm Settlement',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6D4C41),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.payment,
                              color: Colors.green.shade600,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Color(0xFF6D4C41),
                                  ),
                                  children: [
                                    TextSpan(
                                      text: fromDisplayName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: ' → '),
                                    TextSpan(
                                      text: toDisplayName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: ': '),
                                    TextSpan(
                                      text: 'MYR ${amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (hasReceipts) ...[
                        SizedBox(height: 16),
                        Text(
                          'Payment Receipts:',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6D4C41),
                          ),
                        ),
                        SizedBox(height: 8),
                        ...receipts.map((receipt) {
                          final receiptData =
                              receipt.data() as Map<String, dynamic>;
                          final receiptUrl =
                              receiptData['receiptUrl'] as String;
                          final note = receiptData['note'] as String? ?? '';
                          final uploadedAt =
                              receiptData['uploadedAt'] as Timestamp;

                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.receipt,
                                      color: Colors.blue.shade600,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Uploaded ${_formatDateTime(uploadedAt.toDate())}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => _showReceiptViewer(
                                            context,
                                            receiptUrl,
                                            note,
                                          ),
                                      style: TextButton.styleFrom(
                                        minimumSize: Size(60, 30),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      child: Text(
                                        'View',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.blue.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (note.isNotEmpty) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    'Note: $note',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ] else ...[
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info,
                                color: Colors.orange.shade600,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No payment receipt uploaded yet. You can still mark as settled if payment was received.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 12),
                      Text(
                        'Mark this debt as settled? This will create a settlement record.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(color: Color(0xFF6D4C41)),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        // Create a settlement record
                        await FirebaseFirestore.instance
                            .collection('trips')
                            .doc(widget.tripId)
                            .collection('settlements')
                            .add({
                              'fromUserId': fromUserId,
                              'toUserId': toUserId,
                              'amount': amount,
                              'settledAt': Timestamp.now(),
                              'settledBy': widget.userId,
                              'status': 'settled',
                              'hasReceipts': hasReceipts,
                            });

                        // Mark payment receipts as confirmed
                        if (hasReceipts) {
                          for (var receipt in receipts) {
                            await receipt.reference.update({
                              'status': 'confirmed',
                            });
                          }
                        }

                        Navigator.pop(context);

                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Payment marked as settled!',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ).animate().fadeIn(
                              duration: const Duration(milliseconds: 500),
                            ),
                            backgroundColor: Colors.green.shade600,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      } catch (e) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error settling payment: $e',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ).animate().fadeIn(
                              duration: const Duration(milliseconds: 500),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Mark as Settled',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
    );
  }

  Future<String> _fetchPlaceName(String? itineraryItemId) async {
    if (itineraryItemId == null) {
      return 'Others';
    }
    var itineraryDoc =
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .collection('itinerary')
            .doc(itineraryItemId)
            .get();
    var placeId = itineraryDoc.data()?['placeId'] as String?;
    if (placeId == null) {
      return 'Unknown';
    }
    var placeDoc =
        await FirebaseFirestore.instance
            .collection('areas')
            .doc('George Town')
            .collection('places')
            .doc(placeId)
            .get();
    return placeDoc.data()?['name'] ?? 'Unknown';
  }

  Future<Map<String, String>> _fetchUserIdToUsername(
    List<String> userIds,
  ) async {
    Map<String, String> userIdToUsername = {};
    for (String uid in userIds) {
      var userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        userIdToUsername[uid] = userDoc.data()?['username'] ?? uid;
      } else {
        userIdToUsername[uid] = uid; // fallback if username not found
      }
    }
    return userIdToUsername;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: const Color(0xFFF7F7F7),
          child: StreamBuilder<DocumentSnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('trips')
                    .doc(widget.tripId)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading expenses',
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: Color(0xFF6D4C41)),
                );
              }

              var tripData = snapshot.data?.data() as Map<String, dynamic>?;
              var budget = tripData?['budget']?.toDouble() ?? 0.0;
              var hotelPercent = tripData?['hotelPercent']?.toDouble() ?? 40.0;
              var hotelBudget = budget * hotelPercent / 100;
              var collaborators =
                  tripData?['collaboratorIds'] as List<dynamic>? ?? [];
              var isGroupTrip = collaborators.isNotEmpty;

              return StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('trips')
                        .doc(widget.tripId)
                        .collection('expenses')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                builder: (context, expensesSnapshot) {
                  if (expensesSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading expenses',
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }
                  if (expensesSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6D4C41),
                      ),
                    );
                  }

                  var expenses = expensesSnapshot.data?.docs ?? [];
                  Map<String, double> categoryTotals = {};
                  for (var category in categories) {
                    categoryTotals[category] = 0.0;
                  }

                  // Calculate overall spending per category
                  for (var expense in expenses) {
                    var data = expense.data() as Map<String, dynamic>;
                    var category = data['category'] as String;
                    var amount = data['amount']?.toDouble() ?? 0.0;
                    if (categoryTotals.containsKey(category)) {
                      categoryTotals[category] =
                          categoryTotals[category]! + amount;
                    }
                  }
                  List<String> allMembers = [];
                  // Calculate individual spending for group trips
                  Map<String, double> individualSpending = {};
                  if (isGroupTrip) {
                    var allMembers = [
                      tripData!['ownerId'] as String,
                      ...collaborators.cast<String>(),
                    ];
                    for (var member in allMembers) {
                      individualSpending[member] = 0.0;
                    }

                    for (var expense in expenses) {
                      var data = expense.data() as Map<String, dynamic>;
                      var amount = data['amount']?.toDouble() ?? 0.0;
                      var isSplit = data['isSplit'] ?? false;

                      if (isSplit) {
                        var splitAmount = amount / allMembers.length;
                        for (var member in allMembers) {
                          individualSpending[member] =
                              individualSpending[member]! + splitAmount;
                        }
                      } else {
                        // Assume owner incurs non-split expenses
                        var ownerId = tripData['ownerId'] as String;
                        individualSpending[ownerId] =
                            individualSpending[ownerId]! + amount;
                      }
                    }
                  }

                  Map<String, Map<String, double>> individualCategorySpending =
                      {};
                  for (var member in allMembers) {
                    individualCategorySpending[member] = {
                      for (var category in categories) category: 0.0,
                    };
                  }

                  // Loop through expenses again to split into categories
                  for (var expense in expenses) {
                    var data = expense.data() as Map<String, dynamic>;
                    var category = data['category'] as String;
                    var amount = data['amount']?.toDouble() ?? 0.0;
                    var isSplit = data['isSplit'] ?? false;

                    if (isSplit) {
                      var splitAmount = amount / allMembers.length;
                      for (var member in allMembers) {
                        individualCategorySpending[member]![category] =
                            (individualCategorySpending[member]![category] ??
                                0.0) +
                            splitAmount;
                      }
                    } else {
                      var ownerId = tripData!['ownerId'] as String;

                      // Ensure the ownerId exists in the individualCategorySpending map
                      if (!individualCategorySpending.containsKey(ownerId)) {
                        individualCategorySpending[ownerId] = {
                          for (var cat in categories) cat: 0.0,
                        };
                      }

                      individualCategorySpending[ownerId]![category] =
                          (individualCategorySpending[ownerId]![category] ??
                              0.0) +
                          amount;
                    }
                  }

                  double totalAccomCost =
                      categoryTotals['Accommodation'] ?? 0.0;
                  double totalFoodCost = categoryTotals['Food'] ?? 0.0;
                  double totalTransportCost =
                      categoryTotals['Transport'] ?? 0.0;
                  double totalFlightCost = categoryTotals['Flight'] ?? 0.0;
                  double totalCarRentalCost =
                      categoryTotals['Car Rental'] ?? 0.0;
                  double totalGasCost = categoryTotals['Gas'] ?? 0.0;
                  double totalShoppingCost = categoryTotals['Shopping'] ?? 0.0;
                  double totalActivitiesCost =
                      categoryTotals['Activities'] ?? 0.0;
                  double totalOtherCost = categoryTotals['Others'] ?? 0.0;

                  // Calculate total spending for percentage calculation
                  double totalSpending = categoryTotals.values.reduce(
                    (a, b) => a + b,
                  );
                  if (totalSpending == 0)
                    totalSpending = 1; // Avoid division by zero

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          // 🚀 Recalculate fresh individualCategorySpending
                          Map<String, Map<String, double>>
                          freshIndividualCategorySpending = {};
                          for (var member in [
                            tripData!['ownerId'] as String,
                            ...collaborators.cast<String>(),
                          ]) {
                            freshIndividualCategorySpending[member] = {
                              for (var category in categories) category: 0.0,
                            };
                          }

                          for (var expense in expenses) {
                            var data = expense.data() as Map<String, dynamic>;
                            var category = data['category'] as String;
                            var amount = data['amount']?.toDouble() ?? 0.0;
                            var isSplit = data['isSplit'] ?? false;

                            if (isSplit) {
                              var splitAmount =
                                  amount /
                                  (freshIndividualCategorySpending.length);
                              for (var member
                                  in freshIndividualCategorySpending.keys) {
                                freshIndividualCategorySpending[member]![category] =
                                    (freshIndividualCategorySpending[member]![category] ??
                                        0.0) +
                                    splitAmount;
                              }
                            } else {
                              var ownerId = tripData['ownerId'] as String;
                              freshIndividualCategorySpending[ownerId]![category] =
                                  (freshIndividualCategorySpending[ownerId]![category] ??
                                      0.0) +
                                  amount;
                            }
                          }
                          final userIdToUsername =
                              await _fetchUserIdToUsername([
                                tripData['ownerId'] as String,
                                ...collaborators.cast<String>(),
                              ]);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ExpensesBreakdownPage(
                                    individualSpending: individualSpending,
                                    individualCategorySpending:
                                        freshIndividualCategorySpending,
                                    allMembers: [
                                      tripData['ownerId'] as String,
                                      ...collaborators.cast<String>(),
                                    ],
                                    categories: categories,
                                    categoryColors: categoryColors,
                                    categoryTotals: categoryTotals,
                                    userId: widget.userId,
                                    userIdToUsername: userIdToUsername,
                                  ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFD7CCC8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'View Expenses Breakdown Chart',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ).animate().fadeIn(
                        duration: const Duration(milliseconds: 500),
                      ),

                      const SizedBox(height: 16),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Budget',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6D4C41),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color: Color(0xFF6D4C41),
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      final result = await showEditBudgetDialog(
                                        context: context,
                                        tripId: widget.tripId,
                                        currentBudget: budget,
                                      );
                                      if (result == true) {
                                        // Budget was updated successfully
                                        // The StreamBuilder will automatically refresh the UI
                                      }
                                    },
                                    tooltip: 'Edit Budget',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "RM ${budget.toStringAsFixed(2)}",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(
                          duration: const Duration(milliseconds: 500),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 🎯 ADD SETTLEMENT DASHBOARD HERE (only for group trips)
                      if (isGroupTrip) ...[
                        _buildSettlementDashboard(
                          expenses,
                          tripData!,
                          collaborators.cast<String>(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text(
                        'Expenses',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6D4C41),
                        ),
                      ).animate().fadeIn(
                        duration: const Duration(milliseconds: 500),
                      ),

                      // Rest of your existing expense cards...
                      ...expenses.map((expense) {
                        var data = expense.data() as Map<String, dynamic>;
                        var category = data['category'] ?? 'unknown';
                        var amount = data['amount']?.toDouble() ?? 0.0;
                        var currency = data['currency'] ?? 'MYR';
                        var isSplit = data['isSplit'] ?? false;
                        var itineraryItemId = data['itineraryItemId'];
                        var isOthers = data['isOthers'] ?? false;

                        return FutureBuilder<String>(
                          future: _fetchPlaceName(itineraryItemId),
                          builder: (context, nameSnapshot) {
                            if (nameSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }
                            if (nameSnapshot.hasError) {
                              return ListTile(
                                title: Text(
                                  'Error loading place name',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black54,
                                  ),
                                ),
                              );
                            }

                            var displayName =
                                isOthers
                                    ? 'Other Expense'
                                    : nameSnapshot.data?.isNotEmpty == true
                                    ? nameSnapshot.data!
                                    : _selectedCategory;

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              color: Colors.white,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  displayName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF6D4C41),
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Category: $category',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Amount: $amount $currency',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Split: ${isSplit ? "Yes" : "No"}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color: Color(0xFFD7CCC8),
                                      ),
                                      onPressed:
                                          () => _showAddExpenseDialog(
                                            existingExpense: {
                                              'id': expense.id,
                                              ...data,
                                            },
                                          ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () async {
                                        bool confirmDelete = await showDialog(
                                          context: context,
                                          builder:
                                              (context) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                backgroundColor: Colors.white,
                                                title: Text(
                                                  'Delete Expense',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF6D4C41),
                                                  ),
                                                ),
                                                content: Text(
                                                  'Are you sure you want to delete this expense?',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.black54,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: Text(
                                                      'Cancel',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            color: Color(
                                                              0xFF6D4C41,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: Text(
                                                      'Delete',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            color:
                                                                Colors
                                                                    .redAccent,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ).animate().fadeIn(
                                                duration: const Duration(
                                                  milliseconds: 500,
                                                ),
                                              ),
                                        );

                                        if (confirmDelete == true) {
                                          await FirebaseFirestore.instance
                                              .collection('trips')
                                              .doc(widget.tripId)
                                              .collection('expenses')
                                              .doc(expense.id)
                                              .delete();
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Builder(
                                                builder:
                                                    (context) => Text(
                                                      'Expense deleted',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            color: const Color(
                                                              0xFF6D4C41,
                                                            ),
                                                            fontSize: 14,
                                                          ),
                                                    ).animate().fadeIn(
                                                      duration: const Duration(
                                                        milliseconds: 500,
                                                      ),
                                                    ),
                                              ),
                                              backgroundColor: const Color(
                                                0xFFD7CCC8,
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(
                              duration: const Duration(milliseconds: 500),
                            );
                          },
                        );
                      }).toList(),

                      const SizedBox(height: 16),
                      const SizedBox(height: 16),

                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Expenses',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6D4C41),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Accommodation: MYR ${totalAccomCost.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Food: MYR ${totalFoodCost.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Transport: MYR ${totalTransportCost.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Flight: MYR ${totalFlightCost.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Car Rental: MYR ${totalCarRentalCost.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Gas: MYR ${totalGasCost.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Shopping: MYR ${totalShoppingCost.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Activities: MYR ${totalActivitiesCost.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Others: MYR ${totalOtherCost.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(
                          duration: const Duration(milliseconds: 500),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFFD7CCC8),
            foregroundColor: Colors.white,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddExpenseDialog(),
          ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
        ),
      ],
    );
  }
}

class BookingTab extends StatelessWidget {
  const BookingTab({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    final bookingsQ = FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId)
        .collection('bookings')
        .orderBy('createdAt', descending: true);

    final tripDoc =
        FirebaseFirestore.instance.collection('trips').doc(tripId).snapshots();

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: bookingsQ.snapshots(),
        builder: (context, bSnap) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: tripDoc,
            builder: (context, tSnap) {
              if (bSnap.connectionState == ConnectionState.waiting ||
                  tSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (bSnap.hasError || tSnap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading booking(s): ${(bSnap.error ?? tSnap.error)}',
                    style: GoogleFonts.poppins(),
                  ),
                );
              }

              // Build list from this trip's bookings only
              final items = <_Item>[];
              final bookingDocs = bSnap.data?.docs ?? [];

              // Group bookings by trip and keep only the latest one
              Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
              latestBookings = {};

              for (final d in bookingDocs) {
                final m = d.data();
                final createdAt = m['createdAt'] as Timestamp?;

                final key = tripId;

                if (!latestBookings.containsKey(key) ||
                    (createdAt != null &&
                        (latestBookings[key]!.data()['createdAt'] as Timestamp?)
                                ?.compareTo(createdAt) ==
                            -1)) {
                  latestBookings[key] = d;
                }
              }

              // Convert to items list using only the latest booking
              for (final d in latestBookings.values) {
                final m = d.data();
                final hotel = (m['hotel'] as Map?) ?? {};
                items.add(
                  _Item(
                    source: _Src.booking,
                    id: d.id,
                    tripId: tripId,
                    status: _parseStatus(
                      (m['status'] ?? 'CONFIRMED').toString(),
                    ),
                    name: (hotel['name'] ?? 'Accommodation').toString(),
                    address: (hotel['address'] ?? '').toString(),
                    checkIn: _tryParseYmd(m['checkIn']?.toString()),
                    checkOut: _tryParseYmd(m['checkOut']?.toString()),
                    price: (m['totalPrice'] as num?)?.toDouble(),
                    confirmationCode: (m['confirmationCode'] ?? '').toString(),
                  ),
                );
              }

              // Add trip-level fallback if no booking docs exist
              final trip = tSnap.data?.data() ?? {};
              final acc = (trip['accommodation'] as Map?) ?? {};
              final hasAnyBooking = latestBookings.isNotEmpty;

              if (acc.isNotEmpty && !hasAnyBooking) {
                final status = _parseStatus(
                  (acc['bookingStatus'] ?? 'PENDING').toString(),
                );
                items.add(
                  _Item(
                    source: _Src.trip,
                    id: tripId,
                    tripId: tripId,
                    status: status,
                    name:
                        (acc['name'] ??
                                acc['properties']?['name'] ??
                                'Accommodation')
                            .toString(),
                    address:
                        (acc['address'] ?? acc['properties']?['address'] ?? '')
                            .toString(),
                    checkIn: _tryParseYmd(
                      (trip['checkIn'] ?? acc['checkIn'])?.toString(),
                    ),
                    checkOut: _tryParseYmd(
                      (trip['checkOut'] ?? acc['checkOut'])?.toString(),
                    ),
                    price:
                        (trip['totals']?['accommodation'] as num?)?.toDouble(),
                    photoUrl:
                        (acc['primaryPhotoUrl'] ??
                                acc['properties']?['primaryPhotoUrl'])
                            ?.toString(),
                    bookingId:
                        (acc['bookingId'] ?? '').toString().isEmpty
                            ? null
                            : (acc['bookingId'] as String),
                  ),
                );
              }

              if (items.isEmpty) {
                return _EmptyState(
                  title: 'No accommodation yet',
                  message:
                      'Select or confirm a stay for this trip to see it here.',
                  cta: 'Choose accommodation',
                  onTap: () async {
                    final tripSnap =
                        await FirebaseFirestore.instance
                            .collection('trips')
                            .doc(tripId)
                            .get();

                    final accMap =
                        (tripSnap.data()?['accommodation'] as Map?) ?? {};
                    if (accMap.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Builder(
                              builder:
                                  (context) => Text(
                                    'No accommodation selected for this trip yet.',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF6D4C41),
                                      fontSize: 14,
                                    ),
                                  ).animate().fadeIn(
                                    duration: const Duration(milliseconds: 500),
                                  ),
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

                    final normalizedHotel = _hotelFromAccommodationMap(accMap);
                    await showBookingPromptBottomSheet(
                      context: context,
                      trip: {'id': tripId, ...?tripSnap.data()},
                      hotel: normalizedHotel,
                      isSandbox: (tripSnap.data()?['sandbox'] == true),
                    );
                  },
                );
              }

              // Since only one item is expected, display it prominently
              final it = items.first;
              final nights =
                  (it.checkIn != null && it.checkOut != null)
                      ? it.checkOut!.difference(it.checkIn!).inDays.clamp(1, 60)
                      : null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: _BookingCard(
                          tripTitle: 'Trip ${it.tripId.substring(0, 6)}',
                          hotelName: it.name,
                          address: it.address,
                          status: it.status,
                          checkIn: it.checkIn,
                          checkOut: it.checkOut,
                          nights: nights,
                          thumbnailUrl: it.photoUrl,
                          price: it.price,
                          confirmationCode: it.confirmationCode,
                          bookingId: it.bookingId,
                          onPrimary: () async {
                            final tripRef = FirebaseFirestore.instance
                                .collection('trips')
                                .doc(tripId);
                            final tripSnap = await tripRef.get();
                            final tripMap = {'id': tripId, ...?tripSnap.data()};
                            final isSandbox =
                                (tripSnap.data()?['sandbox'] == true);

                            final userId =
                                (tripSnap.data()?['userId'] ??
                                        FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid ??
                                        '')
                                    .toString();

                            DateTime inDate =
                                it.checkIn ??
                                DateTime.tryParse(tripMap['checkIn'] ?? '') ??
                                DateTime.now().add(const Duration(days: 7));
                            DateTime outDate =
                                it.checkOut ??
                                DateTime.tryParse(tripMap['checkOut'] ?? '') ??
                                inDate.add(const Duration(days: 2));
                            final adults = (tripMap['adults'] as int?) ?? 1;

                            Map<String, dynamic> hotelForPage;

                            if (it.source == _Src.booking) {
                              final bSnap =
                                  await tripRef
                                      .collection('bookings')
                                      .doc(it.id)
                                      .get();
                              final b = bSnap.data() ?? {};
                              final h =
                                  (b['hotel'] as Map?)?.map(
                                    (k, v) => MapEntry(k.toString(), v),
                                  ) ??
                                  {};

                              final bIn = _tryParseYmd(
                                b['checkIn']?.toString(),
                              );
                              final bOut = _tryParseYmd(
                                b['checkOut']?.toString(),
                              );
                              if (bIn != null) inDate = bIn;
                              if (bOut != null) outDate = bOut;

                              hotelForPage = _hotelFromAccommodationMap({
                                'name': h['name'],
                                'address': h['address'],
                                'lat': h['lat'],
                                'lng': h['lng'],
                                'placeId': h['id'] ?? h['placeId'],
                                'properties': {
                                  'name': h['name'],
                                  'address': h['address'],
                                  'primaryPhotoUrl': h['primaryPhotoUrl'],
                                },
                              });
                            } else {
                              final accMap =
                                  (tripSnap.data()?['accommodation'] as Map?) ??
                                  {};
                              hotelForPage = _hotelFromAccommodationMap(accMap);
                            }

                            switch (it.status) {
                              case BookingStatus.pending:
                                Map<String, dynamic> completeHotelData =
                                    hotelForPage;

                                if (it.source == _Src.booking) {
                                  final bSnap =
                                      await tripRef
                                          .collection('bookings')
                                          .doc(it.id)
                                          .get();
                                  final b = bSnap.data() ?? {};
                                  final h =
                                      (b['hotel'] as Map?)?.map(
                                        (k, v) => MapEntry(k.toString(), v),
                                      ) ??
                                      {};
                                  final hotelId = h['id']?.toString();

                                  if (hotelId != null && hotelId.isNotEmpty) {
                                    print(
                                      "DEBUG: Fetching complete hotel data for ID: $hotelId",
                                    );

                                    const areas = [
                                      'George Town',
                                      'Tanjung Bungah',
                                      'Batu Ferringhi',
                                      'Bayan Lepas',
                                      'Butterworth',
                                      'Ayer Itam',
                                    ];
                                    DocumentSnapshot<Map<String, dynamic>>?
                                    hotelDoc;
                                    String foundArea = '';

                                    for (final area in areas) {
                                      try {
                                        hotelDoc =
                                            await FirebaseFirestore.instance
                                                .collection('areas')
                                                .doc(area)
                                                .collection('places')
                                                .doc(hotelId)
                                                .get();

                                        if (hotelDoc.exists) {
                                          foundArea = area;
                                          print(
                                            "DEBUG: Found hotel in area: $area",
                                          );
                                          break;
                                        }
                                      } catch (e) {
                                        print(
                                          "DEBUG: Error checking area $area: $e",
                                        );
                                        continue;
                                      }
                                    }

                                    if (hotelDoc != null && hotelDoc.exists) {
                                      final hotelData = hotelDoc.data()!;

                                      completeHotelData = {
                                        'id': hotelId,
                                        'properties': {
                                          'name':
                                              hotelData['name'] ??
                                              h['name'] ??
                                              'Accommodation',
                                          'address':
                                              hotelData['address'] ??
                                              h['address'] ??
                                              '',
                                          'emptyRoomsByDate':
                                              hotelData['emptyRoomsByDate'] ??
                                              {},
                                          'roomTypes':
                                              hotelData['roomTypes'] ?? {},
                                          'primaryPhotoUrl':
                                              hotelData['primaryPhotoUrl'] ??
                                              h['primaryPhotoUrl'],
                                          'phone': hotelData['phone'],
                                          'website': hotelData['website'],
                                          'checkInTime':
                                              hotelData['checkInTime'],
                                          'checkOutTime':
                                              hotelData['checkOutTime'],
                                          'amenities':
                                              hotelData['amenities'] ?? [],
                                          'photoUrls':
                                              hotelData['photoUrls'] ?? [],
                                          'rating': hotelData['rating'],
                                          'reviews': hotelData['reviews'],
                                          'priceLevel': hotelData['priceLevel'],
                                        },
                                        'geometry': {
                                          'coordinates': [
                                            (hotelData['lng'] ??
                                                    h['lng'] ??
                                                    0.0)
                                                .toDouble(),
                                            (hotelData['lat'] ??
                                                    h['lat'] ??
                                                    0.0)
                                                .toDouble(),
                                          ],
                                        },
                                      };

                                      print(
                                        "DEBUG: Hotel availability data keys: ${(hotelData['emptyRoomsByDate'] as Map?)?.keys.toList() ?? 'No availability data'}",
                                      );
                                      print(
                                        "DEBUG: Hotel room types: ${(hotelData['roomTypes'] as Map?)?.keys.toList() ?? 'No room types'}",
                                      );
                                    } else {
                                      print(
                                        "WARNING: Could not find complete hotel data for ID: $hotelId in any area",
                                      );
                                      print(
                                        "DEBUG: Falling back to basic hotel data: ${hotelForPage['properties']}",
                                      );
                                    }
                                  } else {
                                    print(
                                      "WARNING: No hotel ID found in booking data",
                                    );
                                  }
                                }

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => AccommodationBookingPage(
                                          tripId: tripId,
                                          userId:
                                              userId.isEmpty
                                                  ? 'user-demo'
                                                  : userId,
                                          hotel: completeHotelData,
                                          initialAdults: adults,
                                          initialCheckIn: inDate,
                                          initialCheckOut: outDate,
                                          isSandbox: isSandbox,
                                          pricePerNightHint: () {
                                            // Try item price divided by nights first
                                            if (it.price != null &&
                                                nights != null &&
                                                nights > 0) {
                                              return it.price! / nights;
                                            }

                                            // Try trip totals
                                            final accTotal =
                                                (tripMap['totals']?['accommodation']
                                                        as num?)
                                                    ?.toDouble();
                                            if (accTotal != null &&
                                                nights != null &&
                                                nights > 0) {
                                              return accTotal / nights;
                                            }

                                            // Fallback
                                            return 160.0;
                                          }(),
                                        ),
                                  ),
                                );
                                break;

                              case BookingStatus.hold:
                              case BookingStatus.failed:
                              case BookingStatus.cancelled:
                                await showBookingPromptBottomSheet(
                                  context: context,
                                  trip: tripMap,
                                  hotel: hotelForPage,
                                  isSandbox: isSandbox,
                                );
                                break;

                              case BookingStatus.confirmed:
                                try {
                                  final bookingSnap =
                                      await FirebaseFirestore.instance
                                          .collection('trips')
                                          .doc(it.tripId)
                                          .collection('bookings')
                                          .doc(it.id)
                                          .get();

                                  final booking = bookingSnap.data();

                                  if (booking == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Builder(
                                          builder:
                                              (context) => Text(
                                                'Booking details not found.',
                                                style: GoogleFonts.poppins(
                                                  color: const Color(
                                                    0xFF6D4C41,
                                                  ),
                                                  fontSize: 14,
                                                ),
                                              ).animate().fadeIn(
                                                duration: const Duration(
                                                  milliseconds: 500,
                                                ),
                                              ),
                                        ),
                                        backgroundColor: Colors.redAccent,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    );
                                    break;
                                  }

                                  await generateBookingPdf(booking);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Builder(
                                        builder:
                                            (context) => Text(
                                              'PDF generated successfully!',
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF6D4C41),
                                                fontSize: 14,
                                              ),
                                            ).animate().fadeIn(
                                              duration: const Duration(
                                                milliseconds: 500,
                                              ),
                                            ),
                                      ),
                                      backgroundColor: const Color(0xFFD7CCC8),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Builder(
                                        builder:
                                            (context) => Text(
                                              'Failed to generate PDF: $e',
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF6D4C41),
                                                fontSize: 14,
                                              ),
                                            ).animate().fadeIn(
                                              duration: const Duration(
                                                milliseconds: 500,
                                              ),
                                            ),
                                      ),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                }
                                break;

                              case BookingStatus.completed:
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Builder(
                                      builder:
                                          (context) => Text(
                                            'Rating flow coming soon…',
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF6D4C41),
                                              fontSize: 14,
                                            ),
                                          ).animate().fadeIn(
                                            duration: const Duration(
                                              milliseconds: 500,
                                            ),
                                          ),
                                    ),
                                    backgroundColor: const Color(0xFFD7CCC8),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                                break;
                            }
                          },

                          onDetails: () {
                            print('Details button pressed');

                            // Extract area and placeId from the hotel data
                            String? areaId;
                            String? placeId;

                            if (it.source == _Src.booking) {
                              // For bookings, we need to get the hotel data
                              FirebaseFirestore.instance
                                  .collection('trips')
                                  .doc(tripId)
                                  .collection('bookings')
                                  .doc(it.id)
                                  .get()
                                  .then((bSnap) {
                                    final b = bSnap.data() ?? {};
                                    final h = (b['hotel'] as Map?) ?? {};

                                    placeId =
                                        h['id']?.toString() ??
                                        h['placeId']?.toString();

                                    // Try to determine area from address or use default
                                    final address =
                                        h['address']?.toString() ?? '';
                                    areaId = _extractAreaFromAddress(address);

                                    print('Area: $areaId');
                                    print('PlaceId: $placeId');

                                    if (areaId != null && placeId != null) {
                                      PlaceDetailsSheet.show(
                                        context,
                                        areaId: areaId!,
                                        placeId: placeId!,
                                        radiusKm: 2.0,
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Hotel details not available',
                                          ),
                                        ),
                                      );
                                    }
                                  });
                            } else {
                              // For trip-level accommodation
                              final tripRef = FirebaseFirestore.instance
                                  .collection('trips')
                                  .doc(tripId);

                              tripRef.get().then((tripSnap) {
                                final tripData = tripSnap.data() ?? {};
                                final acc =
                                    (tripData['accommodation'] as Map?) ?? {};

                                placeId =
                                    acc['placeId']?.toString() ??
                                    acc['id']?.toString();

                                // Extract area from address
                                final address =
                                    acc['address']?.toString() ??
                                    acc['properties']?['address']?.toString() ??
                                    '';
                                areaId = _extractAreaFromAddress(address);

                                print('Area: $areaId');
                                print('PlaceId: $placeId');

                                if (areaId != null && placeId != null) {
                                  PlaceDetailsSheet.show(
                                    context,
                                    areaId: areaId!,
                                    placeId: placeId!,
                                    radiusKm: 2.0,
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Hotel details not available',
                                      ),
                                    ),
                                  );
                                }
                              });
                            }
                          },
                        )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 500))
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1.0, 1.0),
                          duration: const Duration(milliseconds: 500),
                        ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String? _extractAreaFromAddress(String address) {
  if (address.isEmpty) return null;

  // List of known areas in Penang
  const areas = [
    'George Town',
    'Tanjung Bungah',

    'Tanjung Tokong',
    'Batu Ferringhi',
    'Bayan Lepas',
    'Butterworth',
    'Balik Pulau',
  ];

  // Check if any area is mentioned in the address
  for (final area in areas) {
    if (address.toLowerCase().contains(area.toLowerCase())) {
      return area;
    }
  }

  // Default fallback
  return 'George Town';
}

// Unchanged: _Src, _Item, _parseStatus, _fmt, _statusLabel, generateBookingPdf, _tryParseYmd, _statusIcon, _statusColor, _hotelFromAccommodationMap

enum _Src { booking, trip }

class _Item {
  _Item({
    required this.source,
    required this.id,
    required this.tripId,
    required this.status,
    required this.name,
    required this.address,
    this.checkIn,
    this.checkOut,
    this.price,
    this.confirmationCode,
    this.photoUrl,
    this.bookingId,
  });
  final _Src source;
  final String id;
  final String tripId;
  final BookingStatus status;
  final String name;
  final String address;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double? price;
  final String? confirmationCode;
  final String? photoUrl;
  final String? bookingId;
}

enum BookingStatus { pending, hold, confirmed, completed, cancelled, failed }

BookingStatus _parseStatus(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'PENDING':
      return BookingStatus.pending;
    case 'HOLD':
      return BookingStatus.hold;
    case 'CONFIRMED':
      return BookingStatus.confirmed;
    case 'COMPLETED':
      return BookingStatus.completed;
    case 'CANCELLED':
      return BookingStatus.cancelled;
    case 'FAILED':
      return BookingStatus.failed;
    default:
      return BookingStatus.pending;
  }
}

String _fmt(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

String _statusLabel(BookingStatus s) => switch (s) {
  BookingStatus.pending => 'Pending',
  BookingStatus.hold => 'On Hold',
  BookingStatus.confirmed => 'Confirmed',
  BookingStatus.completed => 'Completed',
  BookingStatus.cancelled => 'Cancelled',
  BookingStatus.failed => 'Failed',
};

Future<void> generateBookingPdf(Map<String, dynamic> booking) async {
  final pdf = pw.Document();

  final hotel = booking['hotel'] as Map? ?? {};
  final name = hotel['name'] ?? 'Accommodation';
  final address = hotel['address'] ?? '';
  final checkIn = booking['checkIn'] ?? '';
  final checkOut = booking['checkOut'] ?? '';
  final nights = booking['nights']?.toString() ?? '1';
  final guests = booking['guests']?.toString() ?? '1';
  final totalPrice = booking['totalPrice']?.toString() ?? '—';
  final confirmationCode = booking['confirmationCode'] ?? '—';

  pdf.addPage(
    pw.Page(
      build:
          (context) => pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Booking Confirmation',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Hotel: $name',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Address: $address'),
                pw.SizedBox(height: 12),
                pw.Text('Check-in: $checkIn'),
                pw.Text('Check-out: $checkOut'),
                pw.Text('Nights: $nights'),
                pw.Text('Guests: $guests'),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Total Price: MYR $totalPrice',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Confirmation Code: $confirmationCode',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue,
                  ),
                ),
                pw.Spacer(),
                pw.Text(
                  'Thank you for booking with ExploreEasy!',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

DateTime? _tryParseYmd(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
      final p = s.split('-');
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
    return DateTime.tryParse(s);
  } catch (_) {
    return null;
  }
}

IconData _statusIcon(BookingStatus s) => switch (s) {
  BookingStatus.pending => Icons.hourglass_top_rounded,
  BookingStatus.hold => Icons.pause_circle_filled_rounded,
  BookingStatus.confirmed => Icons.verified_rounded,
  BookingStatus.completed => Icons.check_circle_rounded,
  BookingStatus.cancelled => Icons.cancel_rounded,
  BookingStatus.failed => Icons.error_rounded,
};

Color _statusColor(BookingStatus s, BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return switch (s) {
    BookingStatus.pending => cs.tertiary,
    BookingStatus.hold => cs.secondary,
    BookingStatus.confirmed => cs.primary,
    BookingStatus.completed => cs.primary,
    BookingStatus.cancelled => cs.error,
    BookingStatus.failed => cs.error,
  };
}

Map<String, dynamic> _hotelFromAccommodationMap(Map acc) {
  final props = (acc['properties'] as Map?) ?? {};
  final name = (acc['name'] ?? props['name'] ?? 'Accommodation').toString();
  final address = (acc['address'] ?? props['address'] ?? '').toString();
  final primaryPhotoUrl =
      (acc['primaryPhotoUrl'] ?? props['primaryPhotoUrl'])?.toString();
  final phone = (acc['phone'] ?? props['phone'])?.toString();
  final website = (acc['website'] ?? props['website'])?.toString();
  final mapsUrl = (acc['mapsUrl'] ?? props['mapsUrl'])?.toString();
  final checkInTime = (acc['checkInTime'] ?? props['checkInTime'])?.toString();
  final checkOutTime =
      (acc['checkOutTime'] ?? props['checkOutTime'])?.toString();
  final amenitiesList =
      ((acc['amenities'] ?? props['amenities']) as List?)
          ?.map((e) => e.toString())
          .toList() ??
      const <String>[];
  final photoUrls =
      ((acc['photoUrls'] ?? props['photoUrls']) as List?)
          ?.map((e) => e.toString())
          .toList() ??
      const <String>[];
  final lat = (acc['lat'] ?? acc['geometry']?['location']?['lat']) as num?;
  final lng = (acc['lng'] ?? acc['geometry']?['location']?['lng']) as num?;
  final placeId =
      (acc['placeId'] ?? props['placeId'] ?? acc['id'] ?? acc['docId'])
          ?.toString();

  return {
    'id': placeId,
    'properties': {
      'name': name,
      'address': address,
      'primaryPhotoUrl': primaryPhotoUrl,
      'phone': phone,
      'website': website,
      'mapsUrl': mapsUrl,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'amenities': amenitiesList,
      'photoUrls': photoUrls,
      'placeId': placeId,
      'roomTypes':
          (acc['roomTypes'] as Map?) ?? (props['roomTypes'] as Map?) ?? {},
      'emptyRoomsByDate':
          (acc['emptyRoomsByDate'] as Map?) ??
          (props['emptyRoomsByDate'] as Map?) ??
          {},
    },
    'geometry': {
      'coordinates': [(lng ?? 0).toDouble(), (lat ?? 0).toDouble()],
    },
  };
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.tripTitle,
    required this.hotelName,
    required this.address,
    required this.status,
    required this.onPrimary,
    required this.onDetails,
    this.checkIn,
    this.checkOut,
    this.nights,
    this.thumbnailUrl,
    this.price,
    this.confirmationCode,
    this.bookingId,
  });

  final String tripTitle;
  final String hotelName;
  final String address;
  final BookingStatus status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? nights;
  final String? thumbnailUrl;
  final double? price;
  final String? confirmationCode;
  final String? bookingId;
  final VoidCallback onPrimary;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full-width image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              width: double.infinity,
              height: 200,
              color: cs.surfaceContainerHighest,
              child:
                  (thumbnailUrl == null || thumbnailUrl!.isEmpty)
                      ? const Icon(
                        Icons.hotel_class_rounded,
                        size: 48,
                        color: Colors.grey,
                      )
                      : Image.network(
                        thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.hotel,
                              size: 48,
                              color: Colors.grey,
                            ),
                      ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trip title and status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tripTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(status: status),
                  ],
                ),
                const SizedBox(height: 8),
                // Hotel name
                Text(
                  hotelName,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6D4C41),
                  ),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                // Dates and nights
                if (checkIn != null && checkOut != null)
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${_fmt(checkIn!)} → ${_fmt(checkOut!)}'
                        '${nights != null ? ' • $nights night${nights == 1 ? '' : 's'}' : ''}',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ],
                  ),
                // Confirmation code
                if ((confirmationCode?.isNotEmpty ?? false) ||
                    (bookingId?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        size: 18,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Code: ${confirmationCode?.isNotEmpty == true ? confirmationCode : bookingId}',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // Progress strip
                _ProgressStrip(status: status),
                const SizedBox(height: 16),
                // Price and actions
                // Price and actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price on top
                    if (price != null) ...[
                      Text(
                        'RM ${price!.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6D4C41),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Buttons in a row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _primaryActionFor(status, onPrimary),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: onDetails,
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: Text(
                            'Details',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _primaryActionFor(BookingStatus s, VoidCallback onPressed) {
    switch (s) {
      case BookingStatus.pending:
        return FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.payment, size: 18),
          label: Text(
            'Complete booking',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        );
      case BookingStatus.hold:
        return FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.upload_file, size: 18),
          label: Text(
            'Upload receipt',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        );
      case BookingStatus.failed:
        return FilledButton.tonalIcon(
          onPressed: onPressed,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text('Retry', style: GoogleFonts.poppins(fontSize: 14)),
        );
      case BookingStatus.confirmed:
        return FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.picture_as_pdf, size: 18),
          label: Text(
            'Download Confirmation',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        );
      case BookingStatus.completed:
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.star_rate_rounded, size: 18),
          label: Text('Rate stay', style: GoogleFonts.poppins(fontSize: 14)),
        );
      case BookingStatus.cancelled:
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text('Rebook', style: GoogleFonts.poppins(fontSize: 14)),
        );
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            _statusLabel(status),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.status});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final active = switch (status) {
      BookingStatus.pending || BookingStatus.hold || BookingStatus.failed => 0,
      BookingStatus.confirmed => 1,
      BookingStatus.cancelled => 1,
      BookingStatus.completed => 3,
    };
    return Row(
      children: List.generate(4, (i) {
        final on = i <= active;
        return Expanded(
          child: Container(
            height: 8,
            margin: EdgeInsets.only(right: i == 3 ? 0 : 8),
            decoration: BoxDecoration(
              color:
                  on
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    required this.cta,
    required this.onTap,
  });
  final String title, message, cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6D4C41),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(cta, style: GoogleFonts.poppins(fontSize: 14)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD7CCC8),
                foregroundColor: const Color(0xFF6D4C41),
              ),
            ),
          ],
        ).animate().slideY(
          begin: 0.2,
          end: 0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        ),
      ),
    );
  }
}
