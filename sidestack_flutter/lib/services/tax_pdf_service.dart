import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TaxPdfService — generates a self-assessment-ready tax summary PDF
// ─────────────────────────────────────────────────────────────────────────────

const _kBlack   = PdfColor.fromInt(0xFF0D0D0D);
const _kGrey100 = PdfColor.fromInt(0xFFF3F4F6);
const _kGrey300 = PdfColor.fromInt(0xFFD1D5DB);
const _kGrey500 = PdfColor.fromInt(0xFF6B7280);
const _kGrey700 = PdfColor.fromInt(0xFF374151);
const _kGreen   = PdfColor.fromInt(0xFF166534);
const _kRed     = PdfColor.fromInt(0xFF991B1B);
const _kTeal    = PdfColor.fromInt(0xFF0F766E);

const _kDeductibleCategories = {
  'Software', 'Tools & Equipment', 'Marketing', 'Professional Services',
  'Travel', 'Home Office', 'Training', 'Subscriptions',
  'Phone & Internet', 'Office Supplies',
};

// Public entry point ──────────────────────────────────────────────────────────

Future<void> shareTaxReportPdf({
  required BuildContext context,
  required List<Transaction> allTransactions,
  required int year,
  required double taxRate,
  required String currencySymbol,
}) async {
  final bytes = await _buildPdf(
    transactions: allTransactions,
    year: year,
    taxRate: taxRate,
    symbol: currencySymbol,
  );
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'SideStacks_Tax_Report_$year.pdf',
  );
}

// PDF construction ────────────────────────────────────────────────────────────

Future<Uint8List> _buildPdf({
  required List<Transaction> transactions,
  required int year,
  required double taxRate,
  required String symbol,
}) async {
  final doc      = pw.Document();
  final font     = await PdfGoogleFonts.interRegular();
  final fontBold = await PdfGoogleFonts.interBold();
  final fontSemi = await PdfGoogleFonts.interSemiBold();

  // Filter to selected year
  final yearTx = transactions.where((t) => t.date.year == year).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  final income   = yearTx.where((t) => t.type == TransactionType.income)
      .fold(0.0, (s, t) => s + t.amount);
  final expenses = yearTx.where((t) => t.type == TransactionType.expense)
      .fold(0.0, (s, t) => s + t.amount);
  final profit   = income - expenses;

  // Deductible breakdown
  final deductibles = <String, double>{};
  for (final tx in yearTx) {
    if (tx.type == TransactionType.expense &&
        _kDeductibleCategories.contains(tx.category)) {
      deductibles[tx.category] =
          (deductibles[tx.category] ?? 0) + tx.amount;
    }
  }
  final deductibles_ = deductibles.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final totalDeductions = deductibles.values.fold(0.0, (s, v) => s + v);
  final taxableProfit   = (profit - totalDeductions).clamp(0, double.infinity);
  final estimatedTax    = taxableProfit * taxRate;
  final takeHome        = profit - estimatedTax;

  String fmt(double v) =>
      '$symbol${v.abs().toStringAsFixed(2).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      header: (ctx) =>
          _header(year, taxRate, font, fontBold),
      footer: (ctx) => _footer(ctx, font),
      build: (ctx) => [
        pw.SizedBox(height: 20),
        _summaryGrid(income, expenses, profit, estimatedTax, takeHome,
            taxRate, fmt, font, fontBold, fontSemi),
        pw.SizedBox(height: 24),
        if (deductibles_.isNotEmpty) ...[
          _deductionsTable(deductibles_, totalDeductions, fmt,
              font, fontBold, fontSemi),
          pw.SizedBox(height: 24),
        ],
        _incomeTable(yearTx, fmt, font, fontBold, fontSemi),
        pw.SizedBox(height: 24),
        _expenseTable(yearTx, fmt, font, fontBold, fontSemi),
        pw.SizedBox(height: 20),
        _disclaimer(font),
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

// ── Header ────────────────────────────────────────────────────────────────────

pw.Widget _header(
    int year, double rate, pw.Font font, pw.Font fontBold) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 12),
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
              pw.Text('Self-Assessment Tax Summary',
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 18, color: _kBlack)),
              pw.SizedBox(height: 3),
              pw.Text(
                'Tax year $year  ·  ${(rate * 100).toStringAsFixed(0)}% estimated rate  ·  For reference only',
                style: pw.TextStyle(font: font, fontSize: 9, color: _kGrey500),
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

pw.Widget _footer(pw.Context ctx, pw.Font font) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border:
          pw.Border(top: pw.BorderSide(color: _kGrey300, width: 0.5)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Generated by SideStacks · Estimates only — consult a tax professional',
            style: pw.TextStyle(font: font, fontSize: 7, color: _kGrey500)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 7, color: _kGrey500)),
      ],
    ),
  );
}

// ── Summary grid ──────────────────────────────────────────────────────────────

pw.Widget _summaryGrid(
  double income, double expenses, double profit,
  double estimatedTax, double takeHome, double taxRate,
  String Function(double) fmt,
  pw.Font font, pw.Font fontBold, pw.Font fontSemi,
) {
  final tiles = [
    ('Total Income',    fmt(income),       _kGreen),
    ('Total Expenses',  fmt(expenses),     _kRed),
    ('Net Profit',      fmt(profit),       profit >= 0 ? _kGreen : _kRed),
    ('Estimated Tax\n(${(taxRate * 100).toStringAsFixed(0)}%)',
        fmt(estimatedTax), _kRed),
    ('Take-Home',       fmt(takeHome),     takeHome >= 0 ? _kTeal : _kRed),
  ];

  return pw.Wrap(
    spacing: 8,
    runSpacing: 8,
    children: tiles.map((t) {
      return pw.Container(
        width: 90,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _kGrey100,
          border: pw.Border.all(color: _kGrey300, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(t.$1,
                style: pw.TextStyle(
                    font: font, fontSize: 7.5, color: _kGrey500)),
            pw.SizedBox(height: 5),
            pw.Text(t.$2,
                style: pw.TextStyle(
                    font: fontBold, fontSize: 12, color: t.$3)),
          ],
        ),
      );
    }).toList(),
  );
}

// ── Deductions table ──────────────────────────────────────────────────────────

pw.Widget _deductionsTable(
  List<MapEntry<String, double>> deductibles,
  double total,
  String Function(double) fmt,
  pw.Font font, pw.Font fontBold, pw.Font fontSemi,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Deductible Expenses',
          style: pw.TextStyle(
              font: fontSemi, fontSize: 11, color: _kGrey700)),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: ['Category', 'Amount'],
        data: [
          ...deductibles
              .map((e) => [e.key, fmt(e.value)])
              .toList(),
          ['TOTAL DEDUCTIONS', fmt(total)],
        ],
        headerStyle:
            pw.TextStyle(font: fontSemi, fontSize: 8, color: _kGrey700),
        cellStyle: pw.TextStyle(font: font, fontSize: 8, color: _kBlack),
        headerDecoration: const pw.BoxDecoration(color: _kGrey100),
        oddRowDecoration: const pw.BoxDecoration(color: _kGrey100),
        border: const pw.TableBorder(
          top:              pw.BorderSide(color: _kGrey300, width: 0.5),
          bottom:           pw.BorderSide(color: _kGrey300, width: 0.5),
          horizontalInside: pw.BorderSide(color: _kGrey300, width: 0.3),
          left:             pw.BorderSide.none,
          right:            pw.BorderSide.none,
          verticalInside:   pw.BorderSide.none,
        ),
        cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 6, vertical: 5),
        columnWidths: {
          0: const pw.FlexColumnWidth(),
          1: const pw.FixedColumnWidth(80),
        },
        cellAlignments: {1: pw.Alignment.centerRight},
      ),
    ],
  );
}

// ── Income table ──────────────────────────────────────────────────────────────

pw.Widget _incomeTable(
  List<Transaction> txs,
  String Function(double) fmt,
  pw.Font font, pw.Font fontBold, pw.Font fontSemi,
) {
  final income = txs
      .where((t) => t.type == TransactionType.income)
      .toList();
  if (income.isEmpty) return pw.SizedBox();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Income  (${income.length})',
          style: pw.TextStyle(
              font: fontSemi, fontSize: 11, color: _kGrey700)),
      pw.SizedBox(height: 8),
      _txTable(income, fmt, font, fontSemi),
    ],
  );
}

// ── Expense table ─────────────────────────────────────────────────────────────

pw.Widget _expenseTable(
  List<Transaction> txs,
  String Function(double) fmt,
  pw.Font font, pw.Font fontBold, pw.Font fontSemi,
) {
  final expenses = txs
      .where((t) => t.type == TransactionType.expense)
      .toList();
  if (expenses.isEmpty) return pw.SizedBox();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Expenses  (${expenses.length})',
          style: pw.TextStyle(
              font: fontSemi, fontSize: 11, color: _kGrey700)),
      pw.SizedBox(height: 8),
      _txTable(expenses, fmt, font, fontSemi),
    ],
  );
}

pw.Widget _txTable(
  List<Transaction> txs,
  String Function(double) fmt,
  pw.Font font, pw.Font fontSemi,
) {
  return pw.TableHelper.fromTextArray(
    headers: ['Date', 'Category', 'Notes', 'Amount'],
    data: txs
        .map((t) => [
              DateFormat('dd MMM yyyy').format(t.date),
              t.category,
              t.notes ?? '—',
              fmt(t.amount),
            ])
        .toList(),
    headerStyle:
        pw.TextStyle(font: fontSemi, fontSize: 8, color: _kGrey700),
    cellStyle: pw.TextStyle(font: font, fontSize: 8, color: _kBlack),
    headerDecoration: const pw.BoxDecoration(color: _kGrey100),
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
      1: const pw.FixedColumnWidth(80),
      2: const pw.FlexColumnWidth(),
      3: const pw.FixedColumnWidth(66),
    },
    cellAlignments: {3: pw.Alignment.centerRight},
  );
}

// ── Disclaimer ────────────────────────────────────────────────────────────────

pw.Widget _disclaimer(pw.Font font) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _kGrey100,
      border: pw.Border.all(color: _kGrey300, width: 0.5),
    ),
    child: pw.Text(
      '⚠  This report is for reference purposes only and does not constitute '
      'tax advice. Figures are based on transactions recorded in SideStacks. '
      'Always consult a qualified accountant or tax professional before '
      'submitting your self-assessment tax return.',
      style: pw.TextStyle(font: font, fontSize: 7.5, color: _kGrey500),
    ),
  );
}
