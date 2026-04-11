import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Neutral palette — no app-brand colours
// ─────────────────────────────────────────────────────────────────────────────
const _kBlack   = PdfColor.fromInt(0xFF0D0D0D);
const _kGrey100 = PdfColor.fromInt(0xFFF3F4F6);
const _kGrey300 = PdfColor.fromInt(0xFFD1D5DB);
const _kGrey500 = PdfColor.fromInt(0xFF6B7280);
const _kGrey700 = PdfColor.fromInt(0xFF374151);

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class InvoiceLineItem {
  final String description;
  final double quantity;
  final double unitPrice;

  InvoiceLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;
}

class InvoiceData {
  final String businessName;
  final String? businessEmail;
  /// Australian Business Number — shown on PDF as required by ATO for invoices > $82.50.
  final String? abn;
  final String clientName;
  final String? clientEmail;
  final String invoiceNumber;
  final DateTime issueDate;
  final DateTime dueDate;
  final List<InvoiceLineItem> items;
  final String currencySymbol;
  final String? notes;
  /// Optional payment link (PayPal, Stripe, bank details URL, etc.)
  /// — rendered on the PDF so the client can pay directly.
  final String? paymentLink;
  /// When true, 10% GST is added to the subtotal and itemised on the PDF.
  final bool includesGst;

  InvoiceData({
    required this.businessName,
    this.businessEmail,
    this.abn,
    required this.clientName,
    this.clientEmail,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.items,
    required this.currencySymbol,
    this.notes,
    this.paymentLink,
    this.includesGst = false,
  });

  double get subtotal => items.fold(0, (s, i) => s + i.total);
  double get gstAmount => includesGst ? subtotal * 0.10 : 0;
  double get totalPayable => subtotal + gstAmount;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

Future<void> shareInvoicePdf(InvoiceData data) async {
  final bytes = await _buildInvoice(data);
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'Invoice_${data.invoiceNumber}.pdf',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF construction
// ─────────────────────────────────────────────────────────────────────────────

Future<Uint8List> _buildInvoice(InvoiceData data) async {
  final doc      = pw.Document();
  final font     = await PdfGoogleFonts.interRegular();
  final fontBold = await PdfGoogleFonts.interBold();
  final fontSemi = await PdfGoogleFonts.interSemiBold();

  final fmt     = (double v) =>
      '${data.currencySymbol}${v.toStringAsFixed(2).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  final fmtDate = (DateTime d) => DateFormat('d MMMM yyyy').format(d);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 52, vertical: 48),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header: business name left, invoice meta right ───────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // From block
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      data.businessName,
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 16, color: _kBlack),
                    ),
                    if (data.businessEmail != null) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        data.businessEmail!,
                        style: pw.TextStyle(
                            font: font, fontSize: 9, color: _kGrey500),
                      ),
                    ],
                    if (data.abn != null && data.abn!.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'ABN: ${data.abn}',
                        style: pw.TextStyle(
                            font: font, fontSize: 9, color: _kGrey500),
                      ),
                    ],
                  ],
                ),
              ),
              // Invoice meta
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 22,
                        color: _kBlack,
                        letterSpacing: 1.5),
                  ),
                  pw.SizedBox(height: 8),
                  _metaRow(font, fontSemi, 'Invoice No.',
                      data.invoiceNumber),
                  pw.SizedBox(height: 3),
                  _metaRow(font, fontSemi, 'Date Issued',
                      fmtDate(data.issueDate)),
                  pw.SizedBox(height: 3),
                  _metaRow(font, fontSemi, 'Due Date',
                      fmtDate(data.dueDate)),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 28),
          // Full-width thin rule
          pw.Container(height: 0.75, color: _kGrey300),
          pw.SizedBox(height: 24),

          // ── Bill to ──────────────────────────────────────────────────────
          pw.Text(
            'BILL TO',
            style: pw.TextStyle(
                font: fontSemi,
                fontSize: 8,
                color: _kGrey500,
                letterSpacing: 1.0),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            data.clientName,
            style: pw.TextStyle(
                font: fontSemi, fontSize: 12, color: _kBlack),
          ),
          if (data.clientEmail != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              data.clientEmail!,
              style: pw.TextStyle(
                  font: font, fontSize: 9, color: _kGrey500),
            ),
          ],

          pw.SizedBox(height: 28),

          // ── Line items table ─────────────────────────────────────────────
          pw.TableHelper.fromTextArray(
            headers: ['Description', 'Qty', 'Unit Price', 'Amount'],
            data: data.items
                .map((item) => [
                      item.description,
                      item.quantity % 1 == 0
                          ? item.quantity.toInt().toString()
                          : item.quantity.toStringAsFixed(2),
                      fmt(item.unitPrice),
                      fmt(item.total),
                    ])
                .toList(),
            headerStyle:
                pw.TextStyle(font: fontSemi, fontSize: 9, color: _kGrey700),
            cellStyle:
                pw.TextStyle(font: font, fontSize: 9, color: _kBlack),
            headerDecoration:
                const pw.BoxDecoration(color: _kGrey100),
            rowDecoration:
                const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration:
                const pw.BoxDecoration(color: _kGrey100),
            border: const pw.TableBorder(
              top:              pw.BorderSide(color: _kGrey300, width: 0.5),
              bottom:           pw.BorderSide(color: _kGrey300, width: 0.5),
              horizontalInside: pw.BorderSide(color: _kGrey300, width: 0.3),
              left:             pw.BorderSide.none,
              right:            pw.BorderSide.none,
              verticalInside:   pw.BorderSide.none,
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6, vertical: 7),
            columnWidths: {
              0: const pw.FlexColumnWidth(),
              1: const pw.FixedColumnWidth(30),
              2: const pw.FixedColumnWidth(72),
              3: const pw.FixedColumnWidth(72),
            },
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),

          pw.SizedBox(height: 12),

          // ── Totals block (right-aligned, no coloured background) ─────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 200,
              child: pw.Column(
                children: [
                  _totalRow(font, fontSemi, 'Subtotal',
                      fmt(data.subtotal), false),
                  if (data.includesGst) ...[
                    pw.Container(height: 0.5, color: _kGrey300),
                    _totalRow(font, fontSemi, 'GST (10%)',
                        fmt(data.gstAmount), false),
                  ],
                  pw.Container(height: 0.5, color: _kGrey300),
                  _totalRow(fontBold, fontBold, 'TOTAL DUE',
                      fmt(data.totalPayable), true),
                ],
              ),
            ),
          ),

          // ── Payment link ─────────────────────────────────────────────────
          if (data.paymentLink != null && data.paymentLink!.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _kGrey100,
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PAY VIA: ',
                    style: pw.TextStyle(
                        font: fontSemi,
                        fontSize: 8,
                        color: _kGrey700,
                        letterSpacing: 0.5),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      data.paymentLink!,
                      style: pw.TextStyle(
                          font: font, fontSize: 8, color: _kBlack),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Notes ────────────────────────────────────────────────────────
          if (data.notes != null && data.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'NOTES',
              style: pw.TextStyle(
                  font: fontSemi,
                  fontSize: 8,
                  color: _kGrey500,
                  letterSpacing: 1.0),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              data.notes!,
              style:
                  pw.TextStyle(font: font, fontSize: 9, color: _kGrey700),
            ),
          ],

          pw.Spacer(),

          // ── Footer ───────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  top: pw.BorderSide(color: _kGrey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Thank you for your business.',
                  style: pw.TextStyle(
                      font: font, fontSize: 8, color: _kGrey500),
                ),
                pw.Text(
                  'Invoice ${data.invoiceNumber}',
                  style: pw.TextStyle(
                      font: font, fontSize: 8, color: _kGrey500),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  return Uint8List.fromList(await doc.save());
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Right-aligned key / value pair used in the invoice meta block.
pw.Widget _metaRow(
    pw.Font font, pw.Font fontSemi, String label, String value) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text('$label  ',
          style: pw.TextStyle(font: font, fontSize: 9, color: _kGrey500)),
      pw.Text(value,
          style:
              pw.TextStyle(font: fontSemi, fontSize: 9, color: _kBlack)),
    ],
  );
}

/// A single row in the totals block.
pw.Widget _totalRow(pw.Font font, pw.Font fontLabel, String label,
    String value, bool isTotal) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 0, vertical: 6),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
              font: fontLabel,
              fontSize: isTotal ? 10 : 9,
              color: isTotal ? _kBlack : _kGrey700),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
              font: font,
              fontSize: isTotal ? 12 : 9,
              color: isTotal ? _kBlack : _kGrey700),
        ),
      ],
    ),
  );
}
