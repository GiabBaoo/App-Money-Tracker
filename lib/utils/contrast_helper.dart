import 'dart:math';
import 'package:flutter/material.dart';

/// Helper function để tính toán contrast ratio theo WCAG
/// 
/// Tính toán tỷ lệ tương phản giữa màu foreground và background
/// theo công thức WCAG 2.0:
/// (L1 + 0.05) / (L2 + 0.05)
/// trong đó L1 là luminance của màu sáng hơn và L2 là luminance của màu tối hơn
/// 
/// Returns: Giá trị contrast ratio từ 1:1 (không có tương phản) đến 21:1 (tương phản tối đa)
double calculateContrastRatio(Color foreground, Color background) {
  final fgLuminance = foreground.computeLuminance();
  final bgLuminance = background.computeLuminance();
  
  final lighter = max(fgLuminance, bgLuminance);
  final darker = min(fgLuminance, bgLuminance);
  
  return (lighter + 0.05) / (darker + 0.05);
}

/// Kiểm tra xem cặp màu có đạt chuẩn WCAG AA không
/// 
/// WCAG AA yêu cầu:
/// - Text thường: contrast ratio tối thiểu 4.5:1
/// - Text lớn (>= 18pt hoặc >= 14pt bold): contrast ratio tối thiểu 3:1
/// - UI components và graphics: contrast ratio tối thiểu 3:1
/// 
/// [foreground] Màu chữ hoặc icon
/// [background] Màu nền
/// [isLargeText] True nếu text có kích thước lớn (>= 18pt hoặc >= 14pt bold)
/// 
/// Returns: true nếu đạt chuẩn WCAG AA, false nếu không đạt
bool meetsWCAGAA(Color foreground, Color background, {bool isLargeText = false}) {
  final ratio = calculateContrastRatio(foreground, background);
  return isLargeText ? ratio >= 3.0 : ratio >= 4.5;
}
