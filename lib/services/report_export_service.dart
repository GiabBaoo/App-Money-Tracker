import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

import '../models/transaction_model.dart';
import 'firestore_service.dart';

class ReportExportService {
  final FirestoreService _firestoreService;

  ReportExportService({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  /// 1) Xử lý khoảng thời gian từ lựa chọn UI
  DateTimeRange resolveDateRange({
    required String selectedOption,
    DateTimeRange? customDateRange,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);

    switch (selectedOption) {
      case 'Tháng này':
        return DateTimeRange(
          start: DateTime(current.year, current.month, 1),
          end: current,
        );
      case 'Tháng trước':
        final firstDayThisMonth = DateTime(current.year, current.month, 1);
        final lastDayPrevMonth = firstDayThisMonth.subtract(const Duration(days: 1));
        final firstDayPrevMonth = DateTime(lastDayPrevMonth.year, lastDayPrevMonth.month, 1);
        return DateTimeRange(start: firstDayPrevMonth, end: lastDayPrevMonth);
      case '3 tháng qua':
        return DateTimeRange(
          start: DateTime(current.year, current.month - 3, current.day),
          end: current,
        );
      case 'Năm nay':
        return DateTimeRange(
          start: DateTime(current.year, 1, 1),
          end: current,
        );
      case 'Tùy chỉnh':
        if (customDateRange == null) {
          throw Exception('Vui lòng chọn khoảng thời gian tùy chỉnh.');
        }
        return DateTimeRange(start: customDateRange.start, end: customDateRange.end);
      default:
        // fallback an toàn
        return DateTimeRange(start: today, end: current);
    }
  }

  /// 2) Query Firestore theo khoảng thời gian
  Future<List<TransactionModel>> fetchTransactions({
    required DateTimeRange range,
  }) {
    return _firestoreService.getTransactionsByDateRange(
      startDate: range.start,
      endDate: range.end,
    );
  }

  /// 3) Tạo bytes PDF
  Future<Uint8List> buildPdfBytes({
    required List<TransactionModel> transactions,
    required DateTimeRange range,
  }) async {
    final pdf = pw.Document();
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final total = transactions.fold<double>(0.0, (sum, tx) => sum + tx.amount);
    final dateFmt = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(
            base: regularFont,
            bold: boldFont,
          ),
        ),
        build: (context) => [
          pw.Text(
            'Báo cáo chi tiêu',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Khoảng thời gian: ${dateFmt.format(range.start)} - ${dateFmt.format(range.end)}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FixedColumnWidth(70),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FixedColumnWidth(90),
              3: const pw.FlexColumnWidth(3),
            },
            headers: const ['Ngày', 'Danh mục', 'Số tiền', 'Ghi chú'],
            data: transactions
                .map(
                  (tx) => [
                    dateFmt.format(tx.date),
                    tx.category,
                    NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(tx.amount),
                    tx.description.isEmpty ? '-' : tx.description,
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Tổng chi tiêu: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(total)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// 4) Tạo bytes Excel (.xlsx)
  Future<Uint8List> buildExcelBytes({
    required List<TransactionModel> transactions,
    required DateTimeRange range,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = 'BaoCao';
    final Sheet sheet = excel[sheetName];

    // Header
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Báo cáo chi tiêu');
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
      'Khoảng thời gian: ${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}',
    );
    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('D2'));

    sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('Ngày');
    sheet.cell(CellIndex.indexByString('B4')).value = TextCellValue('Danh mục');
    sheet.cell(CellIndex.indexByString('C4')).value = TextCellValue('Số tiền');
    sheet.cell(CellIndex.indexByString('D4')).value = TextCellValue('Ghi chú');

    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    for (final col in ['A4', 'B4', 'C4', 'D4']) {
      sheet.cell(CellIndex.indexByString(col)).cellStyle = headerStyle;
    }

    var row = 5;
    double total = 0;
    for (final tx in transactions) {
      total += tx.amount;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(DateFormat('dd/MM/yyyy').format(tx.date));
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(tx.category);
      sheet.cell(CellIndex.indexByString('C$row')).value =
          TextCellValue(NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(tx.amount));
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(tx.description.isEmpty ? '-' : tx.description);
      row++;
    }

    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Tổng');
    sheet.merge(CellIndex.indexByString('A$row'), CellIndex.indexByString('B$row'));
    sheet.cell(CellIndex.indexByString('C$row')).value =
        TextCellValue(NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(total));
    sheet.cell(CellIndex.indexByString('A$row')).cellStyle = CellStyle(bold: true);
    sheet.cell(CellIndex.indexByString('C$row')).cellStyle = CellStyle(bold: true);

    sheet.setColumnWidth(0, 16);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 35);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Không thể tạo file Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<File> saveToTempFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<String> saveToDeviceDownloads({
    required Uint8List bytes,
    required String fileName,
    required String format,
  }) async {
    if (Platform.isAndroid) {
      final hasPermission = await _ensureAndroidDownloadPermission();
      if (!hasPermission) {
        throw Exception(
          'Chưa có quyền lưu vào bộ nhớ máy. '
          'Hãy cấp quyền "Quản lý tất cả tệp" cho ứng dụng rồi thử lại.',
        );
      }

      const downloadPath = '/storage/emulated/0/Download';
      final dir = Directory(downloadPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final outFile = File('$downloadPath/$fileName');
      await outFile.writeAsBytes(bytes, flush: true);
      return outFile.path;
    }

    final ext = format.toLowerCase() == 'pdf' ? 'pdf' : 'xlsx';
    final mimeType = format.toLowerCase() == 'pdf' ? MimeType.pdf : MimeType.microsoftExcel;

    final result = await FileSaver.instance.saveFile(
      name: fileName.replaceAll('.$ext', ''),
      bytes: bytes,
      fileExtension: ext,
      mimeType: mimeType,
    );

    if (result.isEmpty) {
      throw Exception('Bạn đã hủy chọn thư mục lưu file.');
    }
    return result;
  }

  Future<bool> _ensureAndroidDownloadPermission() async {
    // Android 11+ thường cần MANAGE_EXTERNAL_STORAGE để ghi trực tiếp
    // vào /storage/emulated/0/Download.
    if (await Permission.manageExternalStorage.isGranted) return true;

    final manageStatus = await Permission.manageExternalStorage.request();
    if (manageStatus.isGranted) return true;

    // Fallback cho một số thiết bị Android cũ hơn
    if (await Permission.storage.isGranted) return true;
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  String buildFileName({
    required String format,
    required DateTimeRange range,
  }) {
    final start = DateFormat('dd_MM_yyyy').format(range.start);
    final end = DateFormat('dd_MM_yyyy').format(range.end);
    final ext = format.toLowerCase() == 'pdf' ? 'pdf' : 'xlsx';
    return 'report_${start}_to_$end.$ext';
  }
}

