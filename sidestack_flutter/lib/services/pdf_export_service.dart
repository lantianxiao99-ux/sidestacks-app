import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Neutral palette — no app-brand colours
// ─────────────────────────────────────────────────────────────────────────────
const _kBlack     = PdfColor.fromInt(0xFF0D0D0D);
const _kGrey100   = PdfColor.fromInt(0xFFF3F4F6);
const _kGrey300   = PdfColor.fromInt(0xFFD1D5DB);
const _kGrey500   = PdfColor.fromInt(0xFF6B7280);
const _kGrey700   = PdfColor.fromInt(0xFF374151);
const _kGreen     = PdfColor.fromInt(0xFF166534); // dark, ink-like green
const _kRed       = PdfColor.fromInt(0xFF991B1B); // dark, ink-like red

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

Future<void> exportStackPdf({
  required BuildContext context,
  required SideStack stack,
  required String currencySymbol,
}) async {
  final bytes = await _buildPdf(stack: stack, symbol: currencySymbol);
  final safeName = stack.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
  final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  await Printing.sharePdf(bytes: bytes, filename: '${safeName}_$date.pdf');
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF construction
// ─────────────────────────────────────────────────────────────────────────────

Future<Uint8List> _buildPdf({
  required SideStack stack,
  required String symbol,
}) async {
  final doc  = pw.Document();
  final font     = await PdfGoogleFonts.interRegular();
  final fontBold = await PdfGoogleFonts.interBold();
  final fontSemi = await PdfGoogleFonts.interSemiBold();

  final txs = List<Transaction>.from(stack.transactions)
    ..sort((a, b) => b.date.compareTo(a.date));

  final fmt = (double v) =>
      '$symbol${v.abs().toStringAsFixed(2).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      header: (ctx) => _buildHeader(stack, fontBold, fontSemi, font),
      footer: (ctx) => _buildFooter(ctx, font),
      build: (ctx) => [
        pw.SizedBox(height: 24),
        _buildSummaryGrid(stack, symbol, fmt, fontBold, fontSemi, font),
        pw.SizedBox(height: 28),
        _buildTransactionTable(txs, symbol, fmt, fontBold, fontSemi, font),
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

// ── Header ────────────────────────────────────────────────────────────────────

pw.Widget _buildHeader(
    SideStack stack, pw.Font fontBold, pw.Font fontSemi, pw.Font font) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 14),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _kBlack, width: 1.5)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                stack.name,
                style: pw.TextStyle(
                    font: fontBold, fontSize: 20, color: _kBlack),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${stack.hustleType.label}  ·  Financial Summary',
                style: pw.TextStyle(
                    font: font, fontSize: 10, color: _kGrey500),
              ),
            ],
          ),
        ),
        pw.Text(
          DateFormat('d MMMM yyyy').format(DateTime.now()),
          style: pw.TextStyle(font: font, fontSize: 9, color: _kGrey500),
        ),
      ],
    ),
  );
}

// ── Footer ────────────────────────────────────────────────────────────────────

pw.Widget _buildFooter(pw.Context ctx, pw.Font font) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _kGrey300, width: 0.5)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Confidential',
          style: pw.TextStyle(font: font, fontSize: 8, color: _kGrey500),
        ),
        pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: pw.TextStyle(font: font, fontSize: 8, color: _kGrey500),
        ),
      ],
    ),
  );
}

// ── Summary grid ──────────────────────────────────────────────────────────────

pw.Widget _buildSummaryGrid(
  SideStack stack,
  String symbol,
  String Function(double) fmt,
  pw.Font fontBold,
  pw.Font fontSemi,
  pw.Font font,
) {
  final profit = stack.netProfit;
  final margin = stack.totalIncome > 0
      ? (profit / stack.totalIncome * 100)
      : 0.0;

  final tiles = [
    ('Total Revenue',  fmt(stack.totalIncome),  _kGreen),
    ('Total Expenses', fmt(stack.totalExpenses), _kRed),
    ('Net Profit',     fmt(profit),              profit >= 0 ? _kGreen : _kRed),
    ('Profit Margin',  '${margin.toStringAsFixed(1)}%',
        profit >= 0 ? _kGreen : _kRed),
  ];

  return pw.Row(
    children: tiles
        .map(
          (t) => pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.only(right: 8),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _kGrey100,
                border: pw.Border.all(color: _kGrey300, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    t.$1,
                    style: pw.TextStyle(
                        font: font, fontSize: 8, color: _kGrey500),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    t.$2,
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 13, color: t.$3),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList(),
  );
}

// ── Transaction table ─────────────────────────────────────────────────────────

pw.Widget _buildTransactionTable(
  List<Transaction> txs,
  String symbol,
  String Function(double) fmt,
  pw.Font fontBold,
  pw.Font fontSemi,
  pw.Font font,
) {
  if (txs.isEmpty) {
    return pw.Text('No transactions recorded.',
        style: pw.TextStyle(font: font, fontSize: 10, color: _kGrey500));
  }

  const headers = ['Date', 'Category', 'Notes', 'Type', 'Amount'];

  final rows = txs
      .map((tx) => [
            DateFormat('dd MMM yyyy').format(tx.date),
            tx.category,
            tx.notes ?? '—',
            tx.type == TransactionType.income ? 'Income' : 'Expense',
            '${tx.type == TransactionType.income ? '+' : '−'}${fmt(tx.amount)}',
          ])
      .toList();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Transactions  (${txs.length})',
        style: pw.TextStyle(font: fontSemi, fontSize: 11, color: _kGrey700),
      ),
      pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle:
            pw.TextStyle(font: fontSemi, fontSize: 8, color: _kGrey700),
        cellStyle: pw.TextStyle(font: font, fontSize: 8, color: _kBlack),
        headerDecoration: const pw.BoxDecoration(color: _kGrey100),
        rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        oddRowDecoration: const pw.BoxDecoration(color: _kGrey100),
        border: const pw.TableBorder(
          top:              pw.BorderSide(color: _kGrey300, width: 0.5),
          bottom:           pw.BorderSide(color: _kGrey300, width: 0.5),
          horizontalInside: pw.BorderSide(color: _kGrey300, width: 0.3),
          left:             pw.BorderSide.none,
          right:            pw.BorderSide.none,
          verticalInside:   pw.BorderSide.none,
        ),
        cellPadding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        columnWidths: {
          0: const pw.FixedColumnWidth(60),
          1: const pw.FixedColumnWidth(72),
          2: const pw.FlexColumnWidth(),
          3: const pw.FixedColumnWidth(48),
          4: const pw.FixedColumnWidth(66),
        },
        cellAlignments: {
          4: pw.Alignment.centerRight,
        },
      ),
    ],
  );
}
