import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<bool?> showEditBudgetDialog({
  required BuildContext context,
  required String tripId,
  required double currentBudget,
}) {
  final TextEditingController _budgetController = TextEditingController(
    text: currentBudget.toStringAsFixed(2),
  );

  // simple 2-decimal number filter (allows "" while typing)
  final budgetInputFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(\.\d{0,2})?$')),
  ];

  Future<double> _getTotalSpent() async {
    final expenses =
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId)
            .collection('expenses')
            .get();
    double total = 0.0;
    for (final d in expenses.docs) {
      total += (d.data()['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  Future<bool> _hasPermission() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final trip =
        await FirebaseFirestore.instance.collection('trips').doc(tripId).get();
    if (!trip.exists) return false;
    final data = trip.data()!;
    final ownerId = data['ownerId'] as String? ?? '';
    final collaborators = List<String>.from(data['collaboratorIds'] ?? []);
    return uid == ownerId || collaborators.contains(uid);
  }

  return showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Adjust Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _budgetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: budgetInputFormatters,
                decoration: const InputDecoration(
                  labelText: 'New Budget Amount (MYR)',
                  helperText: 'Up to 2 decimals. Minimum = current spent.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // basic parse
                final raw = _budgetController.text.trim();
                final newBudget = double.tryParse(raw);

                if (newBudget == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a number')),
                    );
                  }
                  return;
                }
                if (newBudget <= 0) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Budget must be > 0')),
                    );
                  }
                  return;
                }
                if (newBudget > 1_000_000) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Budget seems too large')),
                    );
                  }
                  return;
                }

                // auth/permission
                if (!await _hasPermission()) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'You do not have permission to edit this budget',
                        ),
                      ),
                    );
                  }
                  return;
                }

                // cannot set below total spent
                final totalSpent = await _getTotalSpent();
                if (newBudget < totalSpent) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Budget cannot be lower than current spending (RM ${totalSpent.toStringAsFixed(2)}).',
                        ),
                      ),
                    );
                  }
                  return;
                }

                // soft warning if shrinking by >30%
                final shrinkRatio =
                    currentBudget == 0
                        ? 0
                        : (currentBudget - newBudget) / currentBudget;
                if (shrinkRatio > 0.30) {
                  final proceed = await showDialog<bool>(
                    context: context,
                    builder:
                        (_) => AlertDialog(
                          title: const Text('Large Reduction'),
                          content: Text(
                            'You are reducing budget by ${(shrinkRatio * 100).toStringAsFixed(0)}%. Continue?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Yes'),
                            ),
                          ],
                        ),
                  );
                  if (proceed != true) return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('trips')
                      .doc(tripId)
                      .update({
                        'budget': double.parse(newBudget.toStringAsFixed(2)),
                      });

                  if (context.mounted) {
                    Navigator.pop(context, true); // success
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Budget updated successfully!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating budget: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
  );
}
