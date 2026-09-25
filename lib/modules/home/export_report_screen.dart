import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/report_export_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/top_toast.dart';

class ExportReportScreen extends StatefulWidget {
  const ExportReportScreen({super.key});

  @override
  State<ExportReportScreen> createState() => _ExportReportScreenState();
}

class _ExportReportScreenState extends State<ExportReportScreen> {
  final ReportExportService _reportExportService = ReportExportService();

  String _selectedDateRange = 'Tháng này';
  final List<String> _dateRanges = [
    'Tháng này',
    'Tháng trước',
    '3 tháng qua',
    'Năm nay',
    'Tùy chỉnh',
  ];

  String _selectedFormat = 'PDF';
  DateTimeRange? _customDateRange;
  bool _isLoading = false;

  Future<void> _pickDateRange() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Chọn khoảng thời gian',
      cancelText: 'HỦY',
      confirmText: 'CHỌN',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF438883),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E2827),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF438883),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1E293B),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
      });
    }
  }

  Future<void> _handleDownload() async {
    if (_isLoading) return;

    if (_selectedDateRange == 'Tùy chỉnh' && _customDateRange == null) {
      _showSnackBar('Vui lòng chọn khoảng thời gian!', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final range = _reportExportService.resolveDateRange(
        selectedOption: _selectedDateRange,
        customDateRange: _customDateRange,
      );

      final transactions = await _reportExportService.fetchTransactions(range: range);
      if (transactions.isEmpty) {
        _showSnackBar('Không có dữ liệu chi tiêu trong khoảng thời gian này.');
        return;
      }

      final isPdf = _selectedFormat == 'PDF';
      final bytes = isPdf
          ? await _reportExportService.buildPdfBytes(transactions: transactions, range: range)
          : await _reportExportService.buildExcelBytes(transactions: transactions, range: range);

      final fileName = _reportExportService.buildFileName(format: _selectedFormat, range: range);
      final savedPath = await _reportExportService.saveToDeviceDownloads(
        bytes: bytes,
        fileName: fileName,
        format: _selectedFormat,
      );
      final file = await _reportExportService.saveToTempFile(bytes: bytes, fileName: fileName);

      if (!mounted) return;
      _showSnackBar('Đã lưu file: $savedPath');
      await _showExportDoneSheet(file: file, bytes: bytes, isPdf: isPdf, savedPath: savedPath);
    } catch (e) {
      _showSnackBar('Tạo báo cáo thất bại: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showExportDoneSheet({
    required File file,
    required Uint8List bytes,
    required bool isPdf,
    required String savedPath,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Đã tải file về máy thành công',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                savedPath,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(file.path)],
                      text: 'Báo cáo chi tiêu',
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF438883),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.share),
                label: const Text('Chia sẻ file', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (isPdf) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Printing.layoutPdf(onLayout: (_) async => bytes);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Color(0xFF438883)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF438883)),
                  label: const Text('Mở/Xem trước PDF', style: TextStyle(color: Color(0xFF438883), fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    TopToast.show(context, message, isError: isError);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final cardBg = AppThemeColors.cardBackground(context);
    final textPrimary = AppThemeColors.textPrimary(context);
    final textSecondary = AppThemeColors.textSecondary(context);
    final inputBg = AppThemeColors.inputBackground(context);

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. CUSTOM APP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Tải báo cáo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG NỘI DUNG BO GÓC
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề
                      Text(
                        'Tùy chọn tải xuống',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chọn thời gian và định dạng file bạn muốn xuất để lưu trữ dữ liệu thống kê.',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // CHỌN THỜI GIAN (Dropdown)
                      _buildLabel('Thời gian xuất báo cáo', isDark),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDateRange,
                        dropdownColor: cardBg,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF438883),
                        ),
                        decoration: _buildInputDecoration(isDark),
                        items: _dateRanges.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(fontSize: 16, color: textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedDateRange = newValue!;
                          });
                          if (newValue == 'Tùy chỉnh') {
                            _pickDateRange();
                          }
                        },
                      ),

                      // Hiện ô chọn ngày nếu người dùng đang ở chế độ "Tùy chỉnh"
                      if (_selectedDateRange == 'Tùy chỉnh') ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _pickDateRange,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: inputBg,
                              border: Border.all(
                                color: const Color(0xFF438883),
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _customDateRange == null
                                      ? 'Bấm để chọn ngày...'
                                      : '${_customDateRange!.start.day.toString().padLeft(2, '0')}/${_customDateRange!.start.month.toString().padLeft(2, '0')}/${_customDateRange!.start.year}  -  ${_customDateRange!.end.day.toString().padLeft(2, '0')}/${_customDateRange!.end.month.toString().padLeft(2, '0')}/${_customDateRange!.end.year}',
                                  style: TextStyle(
                                    color: _customDateRange == null
                                        ? (isDark ? Colors.white38 : const Color(0xFFAAAAAA))
                                        : textPrimary,
                                    fontSize: 15,
                                    fontWeight: _customDateRange == null
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_month,
                                  color: Color(0xFF438883),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),

                      // CHỌN ĐỊNH DẠNG FILE
                      _buildLabel('Định dạng tệp', isDark),
                      Row(
                        children: [
                          _buildFormatCard(
                            title: 'PDF',
                            icon: Icons.picture_as_pdf,
                            color: const Color(0xFFE63946),
                            isSelected: _selectedFormat == 'PDF',
                            isDark: isDark,
                            onTap: () => setState(() => _selectedFormat = 'PDF'),
                          ),
                          const SizedBox(width: 16),
                          _buildFormatCard(
                            title: 'Excel',
                            icon: Icons.table_chart,
                            color: const Color(0xFF2EAF7D),
                            isSelected: _selectedFormat == 'Excel',
                            isDark: isDark,
                            onTap: () => setState(() => _selectedFormat = 'Excel'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),

                      // NÚT TẢI XUỐNG
                      AnimatedScaleButton(
                        onTap: _isLoading ? () {} : _handleDownload,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _isLoading ? Colors.grey : const Color(0xFF438883),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF438883).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _isLoading
                                ? const [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.4,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Đang tạo báo cáo...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ]
                                : const [
                                    Icon(
                                      Icons.download,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Tải xuống ngay',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: AnimatedScaleButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.2 : 0.1)
                : (isDark ? const Color(0xFF282828) : const Color(0xFFF8FAFC)),
            border: Border.all(
              color: isSelected ? color : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? color : (isDark ? Colors.white38 : const Color(0xFFAAAAAA)),
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? color : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(bool isDark) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: isDark ? const Color(0xFF282828) : const Color(0xFFF8FAFC),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5),
      ),
    );
  }
}
