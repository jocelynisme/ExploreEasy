import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  // Show the PDF in viewer/share dialog
  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}
