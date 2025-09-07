import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter_animate/flutter_animate.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onNavigateToPlanTrip;
  final VoidCallback? onNavigateToMyTrips;
  final VoidCallback? onNavigateToNotifications;

  const HomeScreen({
    super.key,
    this.onNavigateToPlanTrip,
    this.onNavigateToMyTrips,
    this.onNavigateToNotifications,
  });

  static const _brand = Color(0xFFD7CCC8);
  static const _brandDark = Color(0xFF6D4C41);

  void _hint(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _navigateToPlanTrip(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid == null) {
      _hint(context, 'Please sign in first.');
      return;
    }
    onNavigateToPlanTrip?.call();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('ExploreEasy'),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),

      body: Stack(
        children: [
          // Full-screen Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_brand, Colors.white],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 20.0,
              ),
              children: [
                // Greeting
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    'Hi, ${user?.displayName ?? 'Traveler'}!',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),

                // Hero Carousel (animated)
                _HeroCarousel(
                  onCta: (destination) => _navigateToPlanTrip(context),
                ),

                const SizedBox(height: 16),
                const SizedBox(height: 24),

                // Your Upcoming Trips
                _NextTripSection(
                  userId: user?.uid,
                  onNavigateToMyTrips: onNavigateToMyTrips,
                ),
                const SizedBox(height: 24),

                // Quick Access
                Text(
                  'Quick Access',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Access Buttons - Clean Row Layout
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.add_circle_outline,
                        label: 'Create Trip',
                        onPressed: () => _navigateToPlanTrip(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.map_outlined,
                        label: 'My Trips',
                        onPressed: () => onNavigateToMyTrips?.call(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Discover Features
                Text(
                  'Discover Features',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Feature grid with "animate when visible"
                _buildFeatureGrid(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    final cards = <Widget>[
      _buildFeatureCard(
        context,
        icon: Icons.auto_awesome_rounded,
        title: 'AI Trip Planner',
        subtitle: 'Smart routes & picks',
        onTap: () => _hint(context, 'AI-powered trip planning coming soon!'),
      ),
      _buildFeatureCard(
        context,
        icon: Icons.savings_rounded,
        title: 'Budget Guard',
        subtitle: 'Stay on track',
        onTap: () => _hint(context, 'Track budgets with real-time alerts.'),
      ),
      _buildFeatureCard(
        context,
        icon: Icons.cloud_rounded,
        title: 'Weather-Aware',
        subtitle: 'Plans that adapt',
        onTap: () => _hint(context, 'Weather-aware planning coming soon!'),
      ),
      _buildFeatureCard(
        context,
        icon: Icons.group_rounded,
        title: 'Collaborate',
        subtitle: 'Plan with friends',
        onTap: () => _hint(context, 'Invite friends to plan together.'),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: List.generate(cards.length, (i) {
        // Simple per-item entrance animation (no AnimateIfVisible needed)
        return cards[i]
            .animate(
              key: ValueKey('feature-$i'),
            ) // stable key so hot-restart replays
            .fade(duration: 400.ms)
            .slide(
              begin: const Offset(0, .1),
              end: Offset.zero,
              duration: 400.ms,
            );
      }),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isFullWidth = false,
    double height = 56, // Consistent height for all buttons
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22, color: Colors.white),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
          shadowColor: _brandDark.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: _brandDark),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== HERO CAROUSEL ===================

class _HeroCarousel extends StatefulWidget {
  final ValueChanged<String> onCta;
  const _HeroCarousel({required this.onCta});
  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  int _index = 0;

  final List<Map<String, String>> _items = const [
    {
      'title': 'Georgetown',
      'subtitle': 'Street art & heritage eats',
      'image': 'assets/georgetown.jpg',
    },
    {
      'title': 'Bayan Lepas',
      'subtitle': 'Temples & seafood delights',
      'image': 'assets/bayanlepas.jpg',
    },
    {
      'title': 'Batu Ferringhi',
      'subtitle': 'Beaches & night market vibes',
      'image': 'assets/batuferringhi.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];

    return Animate(
      key: ValueKey('hero-$_index'),
      effects: [
        FadeEffect(duration: 600.ms, curve: Curves.easeInOut),
        SlideEffect(
          begin: const Offset(0, .2),
          end: Offset.zero,
          duration: 600.ms,
          curve: Curves.easeInOut,
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              HomeScreen._brand.withOpacity(.35),
              HomeScreen._brand.withOpacity(.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Image and Text
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    item['image']!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image,
                            color: HomeScreen._brandDark,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DestinationTile(
                    title: item['title']!,
                    subtitle: item['subtitle']!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Pager Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_items.length, (i) {
                final active = i == _index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 10 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.black87 : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            // CTA
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeScreen._brandDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => widget.onCta(item['title']!),
                icon: const Icon(Icons.map_rounded),
                label: Text(
                  'Plan a Trip',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed:
                      () => setState(
                        () =>
                            _index =
                                (_index - 1 + _items.length) % _items.length,
                      ),
                ),
                IconButton(
                  tooltip: 'Next',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed:
                      () =>
                          setState(() => _index = (_index + 1) % _items.length),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  const _DestinationTile({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black.withOpacity(.7),
          ),
        ),
      ],
    );
  }
}

// =================== YOUR UPCOMING TRIPS ===================

class _NextTripSection extends StatelessWidget {
  final String? userId;
  final VoidCallback? onNavigateToMyTrips;

  const _NextTripSection({required this.userId, this.onNavigateToMyTrips});

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('trips')
              .where('ownerId', isEqualTo: userId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final upcomingTrips =
            snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final startTs = data['startDate'];
              DateTime? start;

              if (startTs is Timestamp) {
                start = startTs.toDate();
              } else if (startTs is String) {
                start = DateTime.tryParse(startTs);
              }
              return start != null && !start.isBefore(today);
            }).toList();

        if (upcomingTrips.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Upcoming Trips',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 130, // Reduced height to prevent overflow
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: upcomingTrips.length,
                itemBuilder: (context, index) {
                  final trip =
                      upcomingTrips[index].data() as Map<String, dynamic>;
                  final city =
                      (trip['city'] ?? trip['title'] ?? 'Your Trip').toString();
                  final budgetUsed = (trip['spent'] ?? 0).toInt();
                  final budgetTotal = (trip['budget'] ?? 0).toInt();
                  final startTs = trip['startDate'];
                  final endTs = trip['endDate'];
                  DateTime? start =
                      startTs is Timestamp
                          ? startTs.toDate()
                          : (startTs is String
                              ? DateTime.tryParse(startTs)
                              : null);
                  DateTime? end =
                      endTs is Timestamp
                          ? endTs.toDate()
                          : (endTs is String ? DateTime.tryParse(endTs) : null);

                  final dateRange =
                      (start != null && end != null)
                          ? _fmtRange(start, end)
                          : (start != null ? _fmtSingle(start) : 'Dates TBC');

                  return Container(
                    width: 280, // Slightly increased width
                    margin: const EdgeInsets.only(right: 12),
                    child: _NextTripCardCompact(
                      city: city,
                      dateRange: dateRange,
                      budgetUsed: budgetUsed,
                      budgetTotal: budgetTotal <= 0 ? 1 : budgetTotal,
                      onView: () => onNavigateToMyTrips?.call(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _fmtRange(DateTime s, DateTime e) {
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
    final sd = '${s.day} ${months[s.month - 1]} ${s.year}';
    final ed = '${e.day} ${months[e.month - 1]} ${e.year}';
    return '$sd – $ed';
  }

  String _fmtSingle(DateTime d) {
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
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _NextTripCardCompact extends StatelessWidget {
  final String city;
  final String dateRange;
  final int budgetUsed;
  final int budgetTotal;
  final VoidCallback onView;

  const _NextTripCardCompact({
    required this.city,
    required this.dateRange,
    required this.budgetUsed,
    required this.budgetTotal,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final double pct = (budgetUsed / budgetTotal).clamp(0, 1.0).toDouble();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12), // Reduced padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, // Smaller icon container
                height: 40,
                decoration: BoxDecoration(
                  color: HomeScreen._brand.withOpacity(.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateRange,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black.withOpacity(.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: onView,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.black.withOpacity(.15)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(50, 32), // Smaller button
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text('View', style: GoogleFonts.poppins(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "RM $budgetUsed / RM $budgetTotal",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.black.withOpacity(.7),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4, // Thinner progress bar
              backgroundColor: Colors.black.withOpacity(.08),
              color: pct >= .8 ? Colors.red : HomeScreen._brand,
            ),
          ),
        ],
      ),
    );
  }
}
