import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';

class ExpensesBreakdownPage extends StatelessWidget {
  final Map<String, double> individualSpending;
  final Map<String, Map<String, double>> individualCategorySpending;
  final List<String> allMembers;
  final Map<String, double> categoryTotals;
  final List<String> categories;
  final List<Color> categoryColors;
  final String userId;
  final Map<String, String> userIdToUsername;
  final String tripId;

  const ExpensesBreakdownPage({
    super.key,
    required this.individualSpending,
    required this.individualCategorySpending,
    required this.allMembers,
    required this.categoryTotals,
    required this.categories,
    required this.categoryColors,
    required this.userId,
    required this.userIdToUsername,
    required this.tripId,
  });

  Future<void> _exportCSV(BuildContext context) async {
    try {
      List<List<String>> csvData = [
        ['Expense Breakdown Report'],
        ['Generated on: ${DateTime.now().toString().split('.')[0]}'],
        [],
        ['My Spending by Category'],
        ['Category', 'Amount (MYR)'],
      ];

      final mySpending = individualCategorySpending[userId] ?? {};

      mySpending.forEach((category, amount) {
        if (amount > 0) {
          csvData.add([category, amount.toStringAsFixed(2)]);
        }
      });

      csvData.add([]);
      csvData.add(['All Members Total Spending']);
      csvData.add(['Member', 'Username', 'Total Spent (MYR)']);

      double totalGroupSpending = 0;
      for (var member in allMembers) {
        double memberSpending = individualSpending[member] ?? 0.0;
        totalGroupSpending += memberSpending;
        String username = userIdToUsername[member] ?? 'Unknown User';
        csvData.add([member, username, memberSpending.toStringAsFixed(2)]);
      }

      csvData.add([
        'TOTAL GROUP SPENDING',
        '',
        totalGroupSpending.toStringAsFixed(2),
      ]);
      csvData.add([]);

      // Settlement calculations based on equal split
      csvData.add(['Settlement Analysis (Equal Split Method)']);
      csvData.add([
        'Member',
        'Username',
        'Paid',
        'Fair Share',
        'Balance',
        'Status',
      ]);

      double fairShare = totalGroupSpending / allMembers.length;
      List<Map<String, dynamic>> balances = [];

      for (var member in allMembers) {
        double paid = individualSpending[member] ?? 0.0;
        double balance = paid - fairShare;
        String username = userIdToUsername[member] ?? 'Unknown User';
        String status =
            balance > 0.01
                ? 'OVERPAID'
                : (balance < -0.01 ? 'UNDERPAID' : 'BALANCED');

        balances.add({
          'memberId': member,
          'username': username,
          'paid': paid,
          'fairShare': fairShare,
          'balance': balance,
          'status': status,
        });

        csvData.add([
          member,
          username,
          paid.toStringAsFixed(2),
          fairShare.toStringAsFixed(2),
          balance.toStringAsFixed(2),
          status,
        ]);
      }

      csvData.add([]);
      csvData.add(['Settlement Suggestions']);
      csvData.add(['From', 'To', 'Amount (MYR)', 'Description']);

      // Calculate optimal settlements
      var creditors = balances.where((b) => b['balance'] < -0.01).toList();
      var debtors = balances.where((b) => b['balance'] > 0.01).toList();

      // Sort by amount
      creditors.sort(
        (a, b) => a['balance'].compareTo(b['balance']),
      ); // Most owed first
      debtors.sort(
        (a, b) => b['balance'].compareTo(a['balance']),
      ); // Most owing first

      if (creditors.isEmpty && debtors.isEmpty) {
        csvData.add(['No settlements needed', 'All members balanced', '', '']);
      } else {
        // Create working copies for settlement calculation
        var workingCreditors =
            creditors.map((c) => Map<String, dynamic>.from(c)).toList();
        var workingDebtors =
            debtors.map((d) => Map<String, dynamic>.from(d)).toList();

        int step = 1;
        while (workingDebtors.isNotEmpty && workingCreditors.isNotEmpty) {
          var debtor = workingDebtors.first;
          var creditor = workingCreditors.first;

          double debtorOwes = debtor['balance'];
          double creditorIsOwed = -creditor['balance']; // Make positive

          double paymentAmount =
              debtorOwes < creditorIsOwed ? debtorOwes : creditorIsOwed;

          if (paymentAmount > 0.01) {
            csvData.add([
              debtor['username'],
              creditor['username'],
              paymentAmount.toStringAsFixed(2),
              'Step $step settlement',
            ]);

            step++;

            // Update balances
            debtor['balance'] -= paymentAmount;
            creditor['balance'] += paymentAmount;

            // Remove if settled
            if (debtor['balance'] < 0.01) {
              workingDebtors.removeAt(0);
            }
            if (creditor['balance'].abs() < 0.01) {
              workingCreditors.removeAt(0);
            }
          } else {
            break;
          }
        }

        csvData.add(['', '', '', 'Total steps: ${step - 1}']);
      }

      csvData.add([]);
      csvData.add(['Category Breakdown - All Members']);
      csvData.add(['Category', 'Total Amount (MYR)', 'Percentage']);

      double totalCategorySpending = categoryTotals.values.fold(
        0,
        (a, b) => a + b,
      );
      categoryTotals.forEach((category, amount) {
        if (amount > 0) {
          double percentage =
              totalCategorySpending > 0
                  ? (amount / totalCategorySpending * 100)
                  : 0;
          csvData.add([
            category,
            amount.toStringAsFixed(2),
            '${percentage.toStringAsFixed(1)}%',
          ]);
        }
      });

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/expense_breakdown.csv';
      final file = File(path);
      await file.writeAsString(const ListToCsvConverter().convert(csvData));

      await Printing.sharePdf(
        bytes: file.readAsBytesSync(),
        filename: 'expense_breakdown.csv',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'CSV exported successfully!',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6D4C41),
                fontSize: 14,
              ),
            ),
            backgroundColor: const Color(0xFFD7CCC8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print("CSV Export Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error exporting CSV: $e',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6D4C41),
                fontSize: 14,
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
  }

  Future<void> _exportPDF(BuildContext context) async {
    try {
      final pdf = pw.Document();

      // 1) Build per-member "paid" correctly from category breakdown (fallback to individualSpending)
      final Map<String, double> perMemberPaid = {
        for (final m in allMembers)
          m:
              (individualCategorySpending[m]?.values.fold<double>(
                0.0,
                (a, b) => a + b,
              )) ??
              (individualSpending[m] ?? 0.0),
      };

      // 2) Compute totals/fair share from corrected "paid"
      final totalGroupSpending = perMemberPaid.values.fold<double>(
        0.0,
        (a, b) => a + b,
      );
      final fairShare =
          allMembers.isEmpty ? 0.0 : totalGroupSpending / allMembers.length;
      const eps = 0.01;

      // 3) "My spending" from category map as before
      final mySpending = individualCategorySpending[userId] ?? {};

      pw.Widget sectionTitle(String t) => pw.Text(
        t,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      );

      pdf.addPage(
        pw.MultiPage(
          build:
              (context) => [
                pw.Text(
                  'Expense Breakdown Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Generated on: ${DateTime.now().toString().split('.')[0]}',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),

                // Summary
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Summary',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Total Group Spending: MYR ${totalGroupSpending.toStringAsFixed(2)}',
                      ),
                      pw.Text(
                        'Fair Share per Person: MYR ${fairShare.toStringAsFixed(2)}',
                      ),
                      pw.Text('Total Members: ${allMembers.length}'),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // My spending breakdown
                sectionTitle('My Spending by Category'),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: const ['Category', 'Amount (MYR)'],
                  data:
                      mySpending.entries
                          .where((e) => e.value > 0)
                          .map((e) => [e.key, e.value.toStringAsFixed(2)])
                          .toList(),
                ),

                pw.SizedBox(height: 20),

                // All members spending (PAID uses perMemberPaid)
                sectionTitle('All Members Spending'),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: const [
                    'Member ID',
                    'Username',
                    'Paid',
                    'Fair Share',
                    'Balance (Paid−Fair)',
                    'Direction',
                  ],
                  data:
                      allMembers.map((memberId) {
                        final username =
                            userIdToUsername[memberId] ?? 'Unknown User';
                        final paid = perMemberPaid[memberId] ?? 0.0;
                        final balance = paid - fairShare; // + receive, - pay
                        final direction =
                            balance > eps
                                ? 'SHOULD RECEIVE'
                                : (balance < -eps ? 'SHOULD PAY' : 'BALANCED');
                        return [
                          memberId,
                          username,
                          paid.toStringAsFixed(2),
                          fairShare.toStringAsFixed(2),
                          balance.toStringAsFixed(2),
                          direction,
                        ];
                      }).toList(),
                ),

                pw.SizedBox(height: 20),

                // Settlement Suggestions (uses perMemberPaid as source of truth)
                sectionTitle('Settlement Suggestions'),
                pw.SizedBox(height: 10),
                ...(() {
                  final rows = <pw.Widget>[];

                  // + => should receive; - => should pay
                  final balances =
                      allMembers.map((memberId) {
                        final paid = perMemberPaid[memberId] ?? 0.0;
                        final balance = paid - fairShare;
                        return {
                          'memberId': memberId,
                          'username':
                              userIdToUsername[memberId] ?? 'Unknown User',
                          'balance': balance,
                        };
                      }).toList();

                  var creditors =
                      balances
                          .where((b) => (b['balance'] as double) > eps)
                          .toList(); // should receive
                  var debtors =
                      balances
                          .where((b) => (b['balance'] as double) < -eps)
                          .toList(); // should pay

                  if (creditors.isEmpty && debtors.isEmpty) {
                    rows.add(
                      pw.Text(
                        'No settlements needed - all members are balanced!',
                      ),
                    );
                    return rows;
                  }

                  // Sort: largest receiver first; largest payer (most negative) first
                  creditors.sort(
                    (a, b) => (b['balance'] as double).compareTo(
                      a['balance'] as double,
                    ),
                  );
                  debtors.sort(
                    (a, b) => (a['balance'] as double).compareTo(
                      b['balance'] as double,
                    ),
                  );

                  final workingCreditors =
                      creditors
                          .map((c) => Map<String, dynamic>.from(c))
                          .toList();
                  final workingDebtors =
                      debtors.map((d) => Map<String, dynamic>.from(d)).toList();

                  final settlementData = <List<String>>[];
                  var step = 1;

                  while (workingDebtors.isNotEmpty &&
                      workingCreditors.isNotEmpty) {
                    final debtor = workingDebtors.first; // balance < 0
                    final creditor = workingCreditors.first; // balance > 0

                    final debtorOwes =
                        -(debtor['balance'] as double); // make positive
                    final creditorIsOwed =
                        (creditor['balance'] as double); // positive
                    final pay =
                        debtorOwes < creditorIsOwed
                            ? debtorOwes
                            : creditorIsOwed;

                    if (pay > eps) {
                      settlementData.add([
                        'Step $step',
                        debtor['username'] as String, // From (payer)
                        creditor['username'] as String, // To (receiver)
                        'MYR ${pay.toStringAsFixed(2)}',
                      ]);
                      step++;

                      // Move both toward zero
                      debtor['balance'] =
                          (debtor['balance'] as double) +
                          pay; // e.g. -66.67 + 66.67
                      creditor['balance'] =
                          (creditor['balance'] as double) -
                          pay; // e.g. 133.33 - 66.67

                      if ((debtor['balance'] as double) >= -eps) {
                        workingDebtors.removeAt(0);
                      }
                      if ((creditor['balance'] as double) <= eps) {
                        workingCreditors.removeAt(0);
                      }
                    } else {
                      break;
                    }
                  }

                  if (settlementData.isNotEmpty) {
                    rows.add(
                      pw.Table.fromTextArray(
                        headers: const [
                          'Step',
                          'From (Payer)',
                          'To (Receiver)',
                          'Amount',
                        ],
                        data: settlementData,
                      ),
                    );
                  }

                  return rows;
                })(),
              ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'expense_breakdown.pdf',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF exported successfully!',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6D4C41),
                fontSize: 14,
              ),
            ),
            backgroundColor: const Color(0xFFD7CCC8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print("PDF Export Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error exporting PDF: $e',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6D4C41),
                fontSize: 14,
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
  }

  @override
  Widget build(BuildContext context) {
    double totalSpending = categoryTotals.values.fold(0, (a, b) => a + b);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Expense Breakdown',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6D4C41),
          ),
        ),
        backgroundColor: const Color(0xFFD7CCC8),
        foregroundColor: const Color(0xFF6D4C41),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Spending by Category
              Text(
                'Overall Spending by Category',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6D4C41),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (categoryTotals.values.every(
                            (amount) => amount == 0,
                          ))
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.pie_chart_outline,
                                    size: 64,
                                    color: cs.outline,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No expenses to show yet for overall spending by category.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: cs.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: [
                                SizedBox(
                                  height: 250,
                                  child: PieChart(
                                    PieChartData(
                                      sections:
                                          categories
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                                int index = entry.key;
                                                String category = entry.value;
                                                double amount =
                                                    categoryTotals[category] ??
                                                    0.0;
                                                if (amount == 0) return null;
                                                return PieChartSectionData(
                                                  color:
                                                      categoryColors[index %
                                                          categoryColors
                                                              .length],
                                                  value: amount,
                                                  title:
                                                      '${(amount / totalSpending * 100).toStringAsFixed(1)}%',
                                                  radius: 50,
                                                  titleStyle:
                                                      GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                );
                                              })
                                              .whereType<PieChartSectionData>()
                                              .toList(),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 40,
                                      borderData: FlBorderData(show: false),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children:
                                      categories.asMap().entries.map((entry) {
                                        int index = entry.key;
                                        String category = entry.value;
                                        double amount =
                                            categoryTotals[category] ?? 0.0;
                                        if (amount == 0)
                                          return const SizedBox.shrink();
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color:
                                                    categoryColors[index %
                                                        categoryColors.length],
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              category,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 500))
                  .slideY(
                    begin: 0.2,
                    end: 0.0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 24),

              // Individual Total Spending
              Text(
                'Individual Total Spending',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6D4C41),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child:
                          individualSpending.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bar_chart_outlined,
                                      size: 64,
                                      color: cs.outline,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No expenses to show yet.',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : SizedBox(
                                height: 300,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.center,
                                    barTouchData: BarTouchData(enabled: true),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final memberList =
                                                individualSpending.keys
                                                    .toList();
                                            if (value.toInt() < 0 ||
                                                value.toInt() >=
                                                    memberList.length) {
                                              return const SizedBox.shrink();
                                            }
                                            var member =
                                                memberList[value.toInt()];
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Text(
                                                userIdToUsername[member] ??
                                                    member.substring(0, 5),
                                                style: GoogleFonts.poppins(
                                                  color: cs.onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 50,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              'MYR ${value.toInt()}',
                                              style: GoogleFonts.poppins(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 10,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    gridData: const FlGridData(show: false),
                                    barGroups:
                                        individualSpending.entries
                                            .toList()
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                              int index = entry.key;
                                              double amount = entry.value.value;
                                              return BarChartGroupData(
                                                x: index,
                                                barRods: [
                                                  BarChartRodData(
                                                    toY: amount,
                                                    color: const Color(
                                                      0xFFD7CCC8,
                                                    ),
                                                    width: 20,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                ],
                                              );
                                            })
                                            .toList(),
                                  ),
                                ),
                              ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 500))
                  .slideY(
                    begin: 0.2,
                    end: 0.0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 24),

              // My Spending by Category
              Text(
                'My Spending by Category',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6D4C41),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Builder(
                        builder: (context) {
                          final myRawSpending =
                              individualCategorySpending[userId] ?? {};
                          final nonZeroEntries =
                              myRawSpending.entries
                                  .where((e) => e.value > 0)
                                  .toList();

                          if (nonZeroEntries.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bar_chart_outlined,
                                    size: 64,
                                    color: cs.outline,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No expenses to show yet.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final filteredCategories =
                              nonZeroEntries.map((e) => e.key).toList();

                          return SizedBox(
                            height: 300,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    tooltipBgColor: Colors.grey.shade800,
                                    tooltipRoundedRadius: 8,
                                    getTooltipItem: (
                                      group,
                                      groupIndex,
                                      rod,
                                      rodIndex,
                                    ) {
                                      final category =
                                          filteredCategories[group.x.toInt()];
                                      return BarTooltipItem(
                                        '$category\nMYR ${rod.toY.toStringAsFixed(2)}',
                                        GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 60,
                                      getTitlesWidget: (value, meta) {
                                        if (value.toInt() < 0 ||
                                            value.toInt() >=
                                                filteredCategories.length) {
                                          return const SizedBox.shrink();
                                        }
                                        final category =
                                            filteredCategories[value.toInt()];
                                        return SideTitleWidget(
                                          axisSide: meta.axisSide,
                                          child: Transform.rotate(
                                            angle: -0.5,
                                            child: Text(
                                              category,
                                              style: GoogleFonts.poppins(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 9,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 50,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          'MYR ${value.toInt()}',
                                          style: GoogleFonts.poppins(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 10,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: const FlGridData(show: true),
                                barGroups:
                                    nonZeroEntries.asMap().entries.map((entry) {
                                      int index = entry.key;
                                      final spending = entry.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: spending.value,
                                            width: 20,
                                            color: const Color(0xFFD7CCC8),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                maxY:
                                    nonZeroEntries
                                        .map((e) => e.value)
                                        .reduce((a, b) => a > b ? a : b) *
                                    1.2,
                                minY: 0,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 500))
                  .slideY(
                    begin: 0.2,
                    end: 0.0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
