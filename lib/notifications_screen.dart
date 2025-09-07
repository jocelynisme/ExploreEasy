import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_budget_dialog.dart';
import 'main.dart';
import 'booking_flow.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'my_trips_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

// NOTIFICATION CONFIGURATION
class NotificationConfig {
  final bool requiresAction;
  final bool showRedDot;
  final bool autoDismiss;
  final int? autoDismissHours;
  final Color sectionColor;
  final String sectionTitle;

  const NotificationConfig({
    required this.requiresAction,
    required this.showRedDot,
    required this.autoDismiss,
    this.autoDismissHours,
    required this.sectionColor,
    required this.sectionTitle,
  });
}

class NotificationLogic {
  static const Map<String, NotificationConfig> configs = {
    'collaborator_request': NotificationConfig(
      requiresAction: true,
      showRedDot: true,
      autoDismiss: false,
      sectionColor: Color(0xFFD7CCC8),
      sectionTitle: 'Action Required',
    ),
    'budget_warning': NotificationConfig(
      requiresAction: true,
      showRedDot: true,
      autoDismiss: false,
      sectionColor: Color(0xFFD7CCC8),
      sectionTitle: 'Action Required',
    ),
    'booking_pending': NotificationConfig(
      requiresAction: true,
      showRedDot: true,
      autoDismiss: false,
      sectionColor: Color(0xFFD7CCC8),
      sectionTitle: 'Action Required',
    ),
    'collaborator_accepted': NotificationConfig(
      requiresAction: false,
      showRedDot: false,
      autoDismiss: true,
      autoDismissHours: 24,
      sectionColor: Colors.grey,
      sectionTitle: 'Recent Updates',
    ),
    'collaborator_declined': NotificationConfig(
      requiresAction: false,
      showRedDot: false,
      autoDismiss: true,
      autoDismissHours: 24,
      sectionColor: Colors.grey,
      sectionTitle: 'Recent Updates',
    ),
    // Add this to the NotificationLogic.configs map
    'payment_receipt': NotificationConfig(
      requiresAction: true,
      showRedDot: true,
      autoDismiss: false,
      sectionColor: Color(0xFFD7CCC8),
      sectionTitle: 'Action Required',
    ),
    'settlement_confirmed': NotificationConfig(
      requiresAction: false,
      showRedDot: false,
      autoDismiss: true,
      autoDismissHours: 24,
      sectionColor: Colors.grey,
      sectionTitle: 'Recent Updates',
    ),
    'split_expense': NotificationConfig(
      requiresAction: true,
      showRedDot: true,
      autoDismiss: false,
      sectionColor: Color(0xFFD7CCC8),
      sectionTitle: 'Action Required',
    ),
  };

  static NotificationConfig getConfig(String type) {
    return configs[type] ??
        const NotificationConfig(
          requiresAction: false,
          showRedDot: false,
          autoDismiss: true,
          autoDismissHours: 24,
          sectionColor: Colors.grey,
          sectionTitle: 'Recent Updates',
        );
  }
}

class NotificationsScreen extends StatefulWidget {
  final String userId;

  const NotificationsScreen({super.key, required this.userId});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  static const _brand = Color(0xFFD7CCC8);
  static const _brandDark = Color(0xFF6D4C41);
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context); // Save reference
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationViewing();
      _autoDismissOldInformational();
    });
  }

  Future<void> _handleNotificationViewing() async {
    try {
      final informationalTypes = [
        'collaborator_accepted',
        'collaborator_declined',
      ];

      final batch = FirebaseFirestore.instance.batch();
      final informationalNotifications =
          await FirebaseFirestore.instance
              .collection('notifications')
              .where('receiverId', isEqualTo: widget.userId)
              .where('type', whereIn: informationalTypes)
              .where('status', isEqualTo: 'new')
              .get();

      for (var doc in informationalNotifications.docs) {
        batch.update(doc.reference, {
          'status': 'read',
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      if (informationalNotifications.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      print('Error updating notification status: $e');
    }
  }

  Future<void> _autoDismissOldInformational() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));

      await FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: widget.userId)
          .where(
            'type',
            whereIn: ['collaborator_accepted', 'collaborator_declined'],
          )
          .where('status', isEqualTo: 'read')
          .where('readAt', isLessThan: Timestamp.fromDate(yesterday))
          .get()
          .then((snapshot) {
            final batch = FirebaseFirestore.instance.batch();
            for (var doc in snapshot.docs) {
              batch.update(doc.reference, {'status': 'dismissed'});
            }
            return batch.commit();
          });
    } catch (e) {
      print('Error dismissing old notifications: $e');
    }
  }

  Future<void> _markActionComplete(String notificationId, String action) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('Error: No authenticated user found.');
        return;
      }
      print('Current user UID: ${user.uid}');

      DocumentSnapshot notificationDoc =
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(notificationId)
              .get();

      if (!notificationDoc.exists) {
        print('Error: Notification $notificationId does not exist.');
        return;
      }

      final data = notificationDoc.data() as Map<String, dynamic>?;
      print('Notification data: $data');
      print('SenderId: ${data?['senderId']}');
      print('ReceiverId: ${data?['receiverId']}');

      if (data?['senderId'] != user.uid && data?['receiverId'] != user.uid) {
        print(
          'Error: User ${user.uid} is not authorized to update this notification.',
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({
            'status': 'completed',
            'completedAction': action,
            'completedAt': FieldValue.serverTimestamp(),
          });
      print('Notification $notificationId updated successfully.');
    } catch (e) {
      print('Error updating notification: $e');
    }
  }

  Future<void> _acceptRequest(
    String notificationId,
    String tripId,
    String receiverId,
    String senderId,
    String tripTitle,
    BuildContext hostContext,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final tripRef = FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId);

        tx.update(
          FirebaseFirestore.instance
              .collection('notifications')
              .doc(notificationId),
          {'status': 'accepted', 'resolvedAt': FieldValue.serverTimestamp()},
        );

        tx.update(tripRef, {
          'pendingCollaboratorIds': FieldValue.arrayRemove([receiverId]),
          'collaboratorIds': FieldValue.arrayUnion([receiverId]),
        });

        tx.set(
          tripRef.collection('collaborators').doc(receiverId),
          {
            'userId': receiverId,
            'role': 'editor',
            'status': 'accepted',
            'status': 'accepted',
            'addedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'collaborator_accepted',
        'tripId': tripId,
        'tripTitle': tripTitle,
        'senderId': receiverId,
        'receiverId': senderId,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request accepted!', style: GoogleFonts.poppins()),
          backgroundColor: _brandDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _declineRequest(
    String notificationId,
    String tripId,
    String receiverId,
    String senderId,
    String tripTitle,
    BuildContext hostContext,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final tripRef = FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId);

        tx.update(
          FirebaseFirestore.instance
              .collection('notifications')
              .doc(notificationId),
          {'status': 'declined', 'resolvedAt': FieldValue.serverTimestamp()},
        );

        tx.update(tripRef, {
          'pendingCollaboratorIds': FieldValue.arrayRemove([receiverId]),
        });
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'collaborator_declined',
        'tripId': tripId,
        'tripTitle': tripTitle,
        'senderId': receiverId,
        'receiverId': senderId,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!hostContext.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request declined', style: GoogleFonts.poppins()),
          backgroundColor: _brandDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      if (!hostContext.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _refreshBookingStatus() async {
    await BookingStatusChecker.instance.manualCheck();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Booking status refreshed!',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: _brandDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          'Notifications',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshBookingStatus,
            tooltip: 'Refresh booking status',
            color: _brandDark,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('notifications')
                .where('receiverId', isEqualTo: widget.userId)
                .where(
                  'type',
                  whereIn: [
                    'collaborator_request',
                    'collaborator_accepted',
                    'collaborator_declined',
                    'budget_warning',
                    'booking_pending',
                    'payment_receipt',
                    'settlement_confirmed',
                    'split_expense',
                  ],
                )
                .where('status', whereIn: ['new', 'pending', 'read'])
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _brandDark));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading notifications',
                style: GoogleFonts.poppins(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          final notifications = snapshot.data?.docs ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: _brand),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final actionableNotifications = <QueryDocumentSnapshot>[];
          final informationalNotifications = <QueryDocumentSnapshot>[];

          for (var notification in notifications) {
            final data = notification.data() as Map<String, dynamic>;
            final type = data['type'] ?? '';
            final config = NotificationLogic.getConfig(type);

            if (config.requiresAction) {
              actionableNotifications.add(notification);
            } else {
              informationalNotifications.add(notification);
            }
          }

          return RefreshIndicator(
            onRefresh: _refreshBookingStatus,
            color: _brandDark,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (actionableNotifications.isNotEmpty) ...[
                  _buildSectionHeader('Action Required', _brand),
                  ...actionableNotifications.asMap().entries.map(
                    (entry) => _buildNotificationCard(
                      entry.value,
                      isActionable: true,
                      animationController: AnimationController(
                        duration: const Duration(milliseconds: 500),
                        vsync: this,
                      )..forward(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (informationalNotifications.isNotEmpty) ...[
                  _buildSectionHeader('Recent Updates', Colors.grey),
                  ...informationalNotifications.asMap().entries.map(
                    (entry) => _buildNotificationCard(
                      entry.value,
                      isActionable: false,
                      animationController: AnimationController(
                        duration: const Duration(milliseconds: 500),
                        vsync: this,
                      )..forward(),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettlementConfirmedCard(
    QueryDocumentSnapshot notification,
    Map<String, dynamic> data,
    bool isNew,
    DateTime? createdAt,
  ) {
    final nestedData =
        data['data'] is Map ? data['data'] as Map<String, dynamic> : {};
    final amount = nestedData['amount']?.toDouble() ?? 0.0;
    final settledBy = nestedData['settledBy']?.toString() ?? 'Someone';

    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(Icons.check_circle, color: Colors.green.shade600),
      title: Text(
        data['message'] ??
            '$settledBy confirmed your payment of MYR ${amount.toStringAsFixed(2)}',
        style: GoogleFonts.poppins(
          fontWeight: isNew ? FontWeight.bold : FontWeight.w500,
          color: isNew ? Colors.black : Colors.black54,
        ),
      ),
      subtitle:
          createdAt != null
              ? Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Confirmed: ${DateFormat('MMM d, yyyy HH:mm').format(createdAt)}',
                  style: GoogleFonts.poppins(
                    color: isNew ? Colors.black54 : Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              )
              : null,
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    QueryDocumentSnapshot notification, {
    required bool isActionable,
    required AnimationController animationController,
  }) {
    final data = notification.data() as Map<String, dynamic>;
    final type = data['type'] ?? '';
    final status = data['status'] ?? 'new';
    final isNew = status == 'new' || status == 'pending';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return FadeTransition(
      opacity: animationController,
      child: Card(
        elevation: isActionable && isNew ? 2 : 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: _buildNotificationContent(
          notification,
          isActionable,
          isNew,
          createdAt,
        ),
      ),
    );
  }

  Widget _buildSplitExpenseCard(
    QueryDocumentSnapshot notification,
    Map<String, dynamic> data,
    bool isNew,
    DateTime? createdAt,
  ) {
    final nestedData =
        data['data'] is Map ? data['data'] as Map<String, dynamic> : {};
    final amount = nestedData['amount']?.toDouble() ?? 0.0;
    final category = nestedData['category']?.toString() ?? 'Unknown';
    final splitAmount = nestedData['splitAmount']?.toDouble() ?? 0.0;
    final fromUsername = nestedData['fromUsername']?.toString() ?? 'Someone';

    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(Icons.receipt_long, color: _brandDark),
      title: Text(
        data['message'] ??
            '$fromUsername added a split expense: $category (MYR ${amount.toStringAsFixed(2)})',
        style: GoogleFonts.poppins(
          fontWeight: isNew ? FontWeight.bold : FontWeight.w500,
          color: isNew ? Colors.black : Colors.black54,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Added: ${DateFormat('MMM d, yyyy HH:mm').format(createdAt)}',
              style: GoogleFonts.poppins(
                color: isNew ? Colors.black54 : Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              'Your share: MYR ${splitAmount.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.visibility, size: 18),
                  label: Text('View Details', style: GoogleFonts.poppins()),
                  onPressed: () async {
                    await _markActionComplete(notification.id, 'viewed');

                    // pull tripId from the notification payload
                    final tripIdStr = (data['tripId'] ?? '').toString();
                    if (tripIdStr.isEmpty) {
                      _scaffoldMessenger?.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Missing trip ID for this expense.',
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

                    // use the current screen’s userId
                    final currentUserId = widget.userId;

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => TripExpensesTabPage(
                              tripId: tripIdStr,
                              userId: currentUserId,
                            ),
                      ),
                    );
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showPayFromNotification(
    BuildContext context,
    String notificationId,
    String toUserId,
    String fromUserId,
    double amount,
    String tripId,
  ) async {
    // Fetch usernames
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(toUserId)
            .get();
    final toUsername = userDoc.data()?['username'] ?? 'Someone';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Pay Split Expense',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6D4C41),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
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
                              TextSpan(text: 'Pay '),
                              TextSpan(
                                text: 'MYR ${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              TextSpan(text: ' to '),
                              TextSpan(
                                text: toUsername,
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
                  'Upload a receipt or proof of payment.',
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
                onPressed: () {
                  Navigator.pop(context);
                  // Call the receipt upload method (you'll need to adapt this)
                  // _showReceiptUploadDialog(context, fromUserId, toUserId, amount, {toUserId: toUsername});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Upload Receipt', style: GoogleFonts.poppins()),
              ),
            ],
          ),
    );
  }

  Widget _buildNotificationContent(
    QueryDocumentSnapshot notification,
    bool isActionable,
    bool isNew,
    DateTime? createdAt,
  ) {
    final data = notification.data() as Map<String, dynamic>;
    final type = data['type'] ?? '';

    switch (type) {
      case 'payment_receipt':
        return _buildPaymentReceiptCard(notification, data, isNew, createdAt);
      case 'settlement_confirmed':
        return _buildSettlementConfirmedCard(
          notification,
          data,
          isNew,
          createdAt,
        );
      case 'collaborator_request':
        return _buildCollaboratorRequestCard(
          notification,
          data,
          isNew,
          createdAt,
        );
      case 'budget_warning':
        return _buildBudgetWarningCard(notification, data, isNew, createdAt);
      case 'booking_pending':
        return _buildBookingStatusCard(notification, data, isNew, createdAt);
      case 'collaborator_accepted':
      case 'collaborator_declined':
        return _buildInfoCard(notification, data, isNew, createdAt);
      case 'split_expense':
        return _buildSplitExpenseCard(notification, data, isNew, createdAt);
      default:
        return ListTile(
          title: Text(
            'Unknown notification type: $type',
            style: GoogleFonts.poppins(),
          ),
        );
    }
  }

  // Enhanced Payment Receipt Notification Card with Settle Up functionality
  Widget _buildPaymentReceiptCard(
    QueryDocumentSnapshot notification,
    Map<String, dynamic> data,
    bool isNew,
    DateTime? createdAt,
  ) {
    print('Notification ID: ${notification.id}');
    print('Notification data: $data');

    // Safely access nested data field
    final nestedData =
        data['data'] is Map ? data['data'] as Map<String, dynamic> : {};
    final receiptUrl = nestedData['receiptUrl']?.toString() ?? '';
    final note = nestedData['note']?.toString() ?? '';
    final amount = nestedData['amount']?.toDouble() ?? 0.0;
    final fromUserId = data['senderId']?.toString() ?? '';
    final toUserId = data['receiverId']?.toString() ?? '';

    print('Extracted receiptUrl: $receiptUrl');
    print('Extracted note: $note');
    print('Amount: $amount, From: $fromUserId, To: $toUserId');

    return FutureBuilder<Map<String, String>>(
      future: _fetchUserIdToUsername([fromUserId, toUserId]),
      builder: (context, usernameSnapshot) {
        if (usernameSnapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: CircularProgressIndicator(color: _brandDark),
          );
        }

        final userIdToUsername = usernameSnapshot.data ?? {};
        final fromUsername = userIdToUsername[fromUserId] ?? 'Someone';
        final toUsername = userIdToUsername[toUserId] ?? 'You';

        return StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('trips')
                  .doc(data['tripId'])
                  .collection('settlements')
                  .where('fromUserId', isEqualTo: fromUserId)
                  .where('toUserId', isEqualTo: toUserId)
                  .snapshots(),
          builder: (context, settlementSnapshot) {
            final settlements = settlementSnapshot.data?.docs ?? [];
            final isAlreadySettled = settlements.any((settlement) {
              final settlementData = settlement.data() as Map<String, dynamic>;
              final settlementAmount =
                  settlementData['amount']?.toDouble() ?? 0.0;
              return (settlementAmount - amount).abs() <
                  0.01; // Same amount settlement exists
            });

            return ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                isAlreadySettled ? Icons.check_circle : Icons.receipt,
                color: isAlreadySettled ? Colors.green.shade600 : _brandDark,
              ),
              title: Text(
                data['message'] ??
                    '$fromUsername uploaded a payment receipt for MYR ${amount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontWeight: isNew ? FontWeight.bold : FontWeight.w500,
                  color: isNew ? Colors.black : Colors.black54,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (createdAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Received: ${DateFormat('MMM d, yyyy HH:mm').format(createdAt)}',
                      style: GoogleFonts.poppins(
                        color: isNew ? Colors.black54 : Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (isAlreadySettled) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'Already settled',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // View Receipt Button
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.visibility, size: 18),
                            label: Text(
                              'View Receipt',
                              style: GoogleFonts.poppins(),
                            ),
                            onPressed:
                                receiptUrl.isNotEmpty
                                    ? () {
                                      print(
                                        'Opening receipt viewer with URL: $receiptUrl',
                                      );
                                      _showReceiptViewer(
                                        context,
                                        receiptUrl,
                                        note,
                                      );
                                    }
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  receiptUrl.isNotEmpty
                                      ? _brandDark
                                      : Colors.grey,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Settle Up Button
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.handshake, size: 18),
                            label: Text(
                              'Settle Up',
                              style: GoogleFonts.poppins(),
                            ),
                            onPressed:
                                () => _settleUpFromNotification(
                                  context,
                                  notification.id,
                                  fromUserId,
                                  toUserId,
                                  amount,
                                  userIdToUsername,
                                  data['tripId'],
                                ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // New method to handle settlement from notification
  Future<void> _settleUpFromNotification(
    BuildContext context,
    String notificationId,
    String fromUserId,
    String toUserId,
    double amount,
    Map<String, String> userIdToUsername,
    String tripId,
  ) async {
    // Store current user ID to avoid widget access after dispose
    final currentUserId = widget.userId;

    try {
      // Create settlement record
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .collection('settlements')
          .add({
            'fromUserId': fromUserId,
            'toUserId': toUserId,
            'amount': amount,
            'settledAt': FieldValue.serverTimestamp(),
            'settledBy': currentUserId,
            'status': 'settled',
            'settledFromNotification': true,
          });

      // Update any pending payment receipts as confirmed
      final receipts =
          await FirebaseFirestore.instance
              .collection('trips')
              .doc(tripId)
              .collection('payment_receipts')
              .where('fromUserId', isEqualTo: fromUserId)
              .where('toUserId', isEqualTo: toUserId)
              .where('status', isEqualTo: 'pending_confirmation')
              .get();

      for (var receipt in receipts.docs) {
        await receipt.reference.update({'status': 'confirmed'});
      }

      // Mark notification as completed
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({
            'status': 'completed',
            'completedAction': 'settled',
            'completedAt': FieldValue.serverTimestamp(),
          });

      // Send confirmation notification to the debtor
      final fromUsername = userIdToUsername[fromUserId] ?? 'Someone';
      final toUsername = userIdToUsername[toUserId] ?? 'Someone';

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'settlement_confirmed',
        'tripId': tripId,
        'senderId': toUserId,
        'receiverId': fromUserId,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
        'message':
            '$toUsername confirmed your payment of MYR ${amount.toStringAsFixed(2)}',
        'data': {'amount': amount, 'settledBy': toUsername},
      });

      // Show success SnackBar
      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(
            content: Text(
              'Payment settled! Confirmation sent to $fromUsername.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      // Show error SnackBar
      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(
            content: Text(
              'Error settling payment: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        print(
          'Cannot show SnackBar: Widget not mounted or ScaffoldMessenger not available',
        );
      }
    }
  }

  // Helper method to fetch usernames
  Future<Map<String, String>> _fetchUserIdToUsername(
    List<String> userIds,
  ) async {
    Map<String, String> userIdToUsername = {};

    for (String userId in userIds) {
      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          userIdToUsername[userId] = userData?['username'] ?? userId;
        }
      } catch (e) {
        print('Error fetching username for $userId: $e');
        userIdToUsername[userId] = userId;
      }
    }

    return userIdToUsername;
  }

  void _showReceiptViewer(
    BuildContext context,
    String receiptUrl,
    String note,
  ) {
    print('Showing receipt viewer with URL: $receiptUrl');
    if (receiptUrl.isEmpty) {
      print('Error: receiptUrl is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid receipt URL', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        print('Dialog built for receipt viewer');
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF6D4C41),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
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
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InteractiveViewer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: receiptUrl,
                              width: double.infinity,
                              height: 300,
                              fit: BoxFit.contain,
                              placeholder:
                                  (context, url) => const SizedBox(
                                    height: 300,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF6D4C41),
                                      ),
                                    ),
                                  ),
                              errorWidget: (context, url, error) {
                                print(
                                  'Image loading error: $error for URL: $url',
                                );
                                return const SizedBox(
                                  height: 300,
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
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                        Text(
                                          'Check your internet connection',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Note:',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6D4C41),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
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
        );
      },
    );
  }

  Widget _buildCollaboratorRequestCard(
    QueryDocumentSnapshot notification,
    Map<String, dynamic> data,
    bool isNew,
    DateTime? createdAt,
  ) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('users')
              .doc(data['senderId'])
              .get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox.shrink();

        final senderData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final senderUsername = senderData?['username'] ?? 'Unknown';
        final tripTitle = data['tripTitle'] ?? 'Unknown Trip';

        return ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Icon(Icons.person_add, color: _brandDark),
          title: Text(
            '$senderUsername invited you to "$tripTitle"',
            style: GoogleFonts.poppins(
              fontWeight: isNew ? FontWeight.bold : FontWeight.w500,
              color: isNew ? Colors.black : Colors.black54,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (createdAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Received: ${DateFormat('MMM d, yyyy HH:mm').format(createdAt)}',
                  style: GoogleFonts.poppins(
                    color: isNew ? Colors.black54 : Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(
                    onPressed:
                        () => _acceptRequest(
                          notification.id,
                          data['tripId'],
                          widget.userId,
                          data['senderId'],
                          tripTitle,
                          context,
                        ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Accept', style: GoogleFonts.poppins()),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed:
                        () => _declineRequest(
                          notification.id,
                          data['tripId'],
                          widget.userId,
                          data['senderId'],
                          tripTitle,
                          context,
                        ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Decline', style: GoogleFonts.poppins()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetWarningCard(
    QueryDocumentSnapshot notification,
    Map<String, dynamic> data,
    bool isNew,
    DateTime? createdAt,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(Icons.warning_amber, color: _brandDark),
      title: Text(
        data['message'] ?? 'Budget alert!',
        style: GoogleFonts.poppins(
          fontWeight: isNew ? FontWeight.bold : FontWeight.w500,
          color: isNew ? Colors.black : Colors.black54,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Received: ${DateFormat('MMM d, yyyy HH:mm').format(createdAt)}',
              style: GoogleFonts.poppins(
                color: isNew ? Colors.black54 : Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit, size: 18),
            label: Text('Adjust Budget', style: GoogleFonts.poppins()),
            onPressed: () async {
              final tripDoc =
                  await FirebaseFirestore.instance
                      .collection('trips')
                      .doc(data['tripId'])
                      .get();
              final currentBudget =
                  (tripDoc.data()?['budget'] as num?)?.toDouble() ?? 0.0;

              final saved = await showEditBudgetDialog(
                context: context,
                tripId: data['tripId'],
                currentBudget: currentBudget,
              );

              if (saved == true) {
                await _markActionComplete(notification.id, 'budget_adjusted');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingStatusCard(
    QueryDocumentSnapshot notification,
    Map<String, dynamic> data,
    bool isNew,
    DateTime? createdAt,
  ) {
    final action = (data['action'] ?? '').toString();
    final payload =
        (data['actionPayload'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v),
        ) ??
        <String, dynamic>{};

    final tripTitle = (data['tripTitle'] ?? 'Your trip').toString();
    final hotelName = (data['hotelName'] ?? 'Accommodation').toString();
    final message =
        data['message'] ??
        'Trip • $tripTitle\nYour booking at $hotelName is pending.';

    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(Icons.hourglass_empty, color: _brandDark),
      title: Text(
        message,
        style: GoogleFonts.poppins(
          fontWeight: isNew ? FontWeight.bold : FontWeight.w500,
          color: isNew ? Colors.black : Colors.black54,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data['hotelName'] != null)
            Text(
              'Hotel: ${data['hotelName']}',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          if (data['checkIn'] != null && data['checkOut'] != null)
            Text(
              '${data['checkIn']} to ${data['checkOut']}',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Received: ${DateFormat('MMM d, yyyy HH:mm').format(createdAt)}',
              style: GoogleFonts.poppins(
                color: isNew ? Colors.black54 : Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
          if (action == 'open_booking') ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.hotel_rounded, size: 18),
              label: Text('Review booking', style: GoogleFonts.poppins()),
              onPressed: () async {
                await _markActionComplete(notification.id, 'booking_reviewed');

                final tripId = (payload['tripId'] ?? '').toString();
                if (tripId.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TripBookingTabPage(tripId: tripId),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    QueryDocumentSnapshot notification,
    Map<String, dynamic> data,
    bool isNew,
    DateTime? createdAt,
  ) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('users')
              .doc(data['senderId'])
              .get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox.shrink();

        final senderData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final senderUsername = senderData?['username'] ?? 'Unknown';
        final tripTitle = data['tripTitle'] ?? 'Unknown Trip';
        final type = data['type'] ?? '';

        final title =
            type == 'collaborator_accepted'
                ? '$senderUsername accepted your invitation to "$tripTitle"'
                : '$senderUsername declined your invitation to "$tripTitle"';

        final icon =
            type == 'collaborator_accepted' ? Icons.check_circle : Icons.cancel;

        final iconColor =
            type == 'collaborator_accepted' ? _brandDark : Colors.redAccent;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Icon(icon, color: iconColor),
            title: Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: isNew ? FontWeight.bold : FontWeight.w500,
                color: isNew ? Colors.black : Colors.black54,
              ),
            ),
            subtitle:
                createdAt != null
                    ? Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Received: ${DateFormat('MMM d, yyyy HH:mm').format(createdAt)}',
                        style: GoogleFonts.poppins(
                          color: isNew ? Colors.black54 : Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    )
                    : null,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class TripBookingTabPage extends StatelessWidget {
  const TripBookingTabPage({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Accommodation',
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
        foregroundColor: _NotificationsScreenState._brandDark,
        elevation: 0,
        centerTitle: true,
      ),
      body: BookingTab(tripId: tripId),
    );
  }
}

class TripExpensesTabPage extends StatelessWidget {
  const TripExpensesTabPage({
    super.key,
    required this.tripId,
    required this.userId,
  });

  final String tripId;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trip Expenses',
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
        foregroundColor: _NotificationsScreenState._brandDark,
        elevation: 0,
        centerTitle: true,
      ),
      body: ExpensesTab(tripId: tripId, userId: userId),
    );
  }
}
