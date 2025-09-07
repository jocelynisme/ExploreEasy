import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'plan_trip_screen.dart';
import 'my_trips_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class MainScreen extends StatefulWidget {
  final String userId;
  final int initialIndex;

  const MainScreen({super.key, required this.userId, this.initialIndex = 0});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _screens = [
      HomeScreen(
        onNavigateToPlanTrip: () => _switchToTab(1),
        onNavigateToMyTrips: () => _switchToTab(2),
        onNavigateToNotifications: () => _switchToTab(3),
      ),
      PlanTripScreen(userId: widget.userId),
      MyTripsScreen(userId: widget.userId),
      NotificationsScreen(userId: widget.userId),
      ProfileScreen(userId: widget.userId),
    ];
  }

  void _switchToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This method is no longer needed since we're using callbacks
  }

  Widget _buildNotificationIcon() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('notifications')
              .where('receiverId', isEqualTo: widget.userId)
              .where(
                'type',
                whereIn: [
                  'collaborator_request',
                  'budget_warning',
                  'booking_pending',
                ],
              )
              .where('status', whereIn: ['new', 'pending'])
              .snapshots(),
      builder: (context, snapshot) {
        final hasActionableNotifications =
            (snapshot.data?.docs.length ?? 0) > 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications,
              color:
                  _selectedIndex == 3 ? const Color(0xFFD7CCC8) : Colors.grey,
            ),
            if (hasActionableNotifications)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFD7CCC8),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Plan Trip',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'My Trips',
          ),
          BottomNavigationBarItem(
            icon: _buildNotificationIcon(),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
