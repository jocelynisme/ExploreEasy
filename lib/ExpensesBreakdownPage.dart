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
  });

  Future<void> _exportCSV(BuildContext context) async {
    try {
      List<List<String>> csvData = [
        ['Category', 'Amount (MYR)'],
      ];

      final mySpending = individualCategorySpending[userId] ?? {};

      mySpending.forEach((category, amount) {
        if (amount > 0) {
          csvData.add([category, amount.toStringAsFixed(2)]);
        }
      });

      csvData.add([]);
      csvData.add(['Who Owes Who']);
      csvData.add([]);

      for (var member in allMembers) {
        if (member != userId) {
          double userSpend = individualSpending[userId] ?? 0;
          double memberSpend = individualSpending[member] ?? 0;
          double difference = (userSpend - memberSpend) / allMembers.length;

          csvData.add([
            '$member owes $userId MYR ${difference.toStringAsFixed(2)}',
          ]);
        }
      }

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
            content: Builder(
              builder:
                  (context) => Text(
                    'CSV exported successfully!',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6D4C41),
                      fontSize: 14,
                    ),
                  ).animate().fadeIn(
                    duration: const Duration(milliseconds: 500),
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
            content: Builder(
              builder:
                  (context) => Text(
                    'Error exporting CSV: $e',
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
    }
  }

  Future<void> _exportPDF(BuildContext context) async {
    try {
      final pdf = pw.Document();

      final mySpending = individualCategorySpending[userId] ?? {};

      pdf.addPage(
        pw.MultiPage(
          build:
              (context) => [
                pw.Text(
                  'Expense Breakdown Report',
                  style: pw.TextStyle(fontSize: 24),
                ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: ['Category', 'Amount (MYR)'],
                  data:
                      mySpending.entries
                          .where((e) => e.value > 0)
                          .map((e) => [e.key, e.value.toStringAsFixed(2)])
                          .toList(),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Who Owes Who', style: pw.TextStyle(fontSize: 18)),
                pw.SizedBox(height: 10),
                ...allMembers.where((member) => member != userId).map((member) {
                  double userSpend = individualSpending[userId] ?? 0;
                  double memberSpend = individualSpending[member] ?? 0;
                  double difference =
                      (userSpend - memberSpend) / allMembers.length;

                  return pw.Text(
                    '$member owes $userId MYR ${difference.toStringAsFixed(2)}',
                  );
                }).toList(),
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
            content: Builder(
              builder:
                  (context) => Text(
                    'PDF exported successfully!',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6D4C41),
                      fontSize: 14,
                    ),
                  ).animate().fadeIn(
                    duration: const Duration(milliseconds: 500),
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
            content: Builder(
              builder:
                  (context) => Text(
                    'Error exporting PDF: $e',
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

              // Export Report
              Text(
                'Export Report',
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _exportCSV(context),
                            icon: const Icon(Icons.file_download, size: 18),
                            label: Text(
                              'Export CSV',
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFD7CCC8),
                              foregroundColor: const Color(0xFF6D4C41),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => _exportPDF(context),
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: Text(
                              'Export PDF',
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFD7CCC8),
                              foregroundColor: const Color(0xFF6D4C41),
                            ),
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
            ],
          ),
        ),
      ),
    );
  }
}
