import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Danh sách các Preset Avatar minh họa có sẵn để người dùng lựa chọn nhanh
class PresetAvatar {
  final String id;
  final String label;
  final IconData icon;
  final List<Color> gradient;

  const PresetAvatar({
    required this.id,
    required this.label,
    required this.icon,
    required this.gradient,
  });
}

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? avatarLocalPath;
  final String? name;
  final double radius;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final double? fontSize;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.avatarLocalPath,
    this.name,
    this.radius = 24,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2.0,
    this.fontSize,
  });

  /// Danh sách 8 mẫu Preset Avatar theo phong cách gradient hiện đại
  static const List<PresetAvatar> presetAvatars = [
    PresetAvatar(
      id: 'preset_emerald',
      label: 'Ngọc lục bảo',
      icon: Icons.eco_rounded,
      gradient: [Color(0xFF438883), Color(0xFF1E524E)],
    ),
    PresetAvatar(
      id: 'preset_ocean',
      label: 'Đại dương',
      icon: Icons.waves_rounded,
      gradient: [Color(0xFF00B4D8), Color(0xFF0077B6)],
    ),
    PresetAvatar(
      id: 'preset_sunset',
      label: 'Hoàng hôn',
      icon: Icons.wb_twilight_rounded,
      gradient: [Color(0xFFFF7E5F), Color(0xFFFEB47B)],
    ),
    PresetAvatar(
      id: 'preset_purple',
      label: 'Tím huyền bí',
      icon: Icons.auto_awesome_rounded,
      gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    ),
    PresetAvatar(
      id: 'preset_crown',
      label: 'Vương miện',
      icon: Icons.workspace_premium_rounded,
      gradient: [Color(0xFFFFB703), Color(0xFFFB8500)],
    ),
    PresetAvatar(
      id: 'preset_rocket',
      label: 'Phi thuyền',
      icon: Icons.rocket_launch_rounded,
      gradient: [Color(0xFFEA004B), Color(0xFF790938)],
    ),
    PresetAvatar(
      id: 'preset_diamond',
      label: 'Kim cương',
      icon: Icons.diamond_rounded,
      gradient: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
    ),
    PresetAvatar(
      id: 'preset_cat',
      label: 'Mèo cưng',
      icon: Icons.pets_rounded,
      gradient: [Color(0xFFFA709A), Color(0xFFFEE140)],
    ),
  ];

  /// Lấy 1-2 chữ cái viết tắt từ tên người dùng
  static String getInitials(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return 'U';
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    // Lấy chữ cái đầu của từ đầu và từ cuối: ví dụ "Nguyễn Gia Bảo" -> "NB" hoặc từ cuối "B"
    final firstChar = parts.first.substring(0, 1).toUpperCase();
    final lastChar = parts.last.substring(0, 1).toUpperCase();
    return '$firstChar$lastChar';
  }

  /// Lấy màu gradient đồng điệu dựa trên mã hash của tên
  static List<Color> getGradientForName(String? name) {
    final palettes = [
      [const Color(0xFF438883), const Color(0xFF225B57)],
      [const Color(0xFF2A9D8F), const Color(0xFF264653)],
      [const Color(0xFF3A86FF), const Color(0xFF00509D)],
      [const Color(0xFF8338EC), const Color(0xFF5B21B6)],
      [const Color(0xFFFB5607), const Color(0xFFD90429)],
      [const Color(0xFF00B4D8), const Color(0xFF0077B6)],
    ];
    if (name == null || name.isEmpty) return palettes[0];
    final hash = name.codeUnits.fold(0, (sum, c) => sum + c);
    return palettes[hash % palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final double size = radius * 2;
    final List<Color> gradient = getGradientForName(name);

    // Kiểm tra xem avatarUrl có phải là một preset ID hay không
    final cleanPresetId = avatarUrl?.startsWith('preset:') == true
        ? avatarUrl!.substring(7)
        : avatarUrl;
    final preset = presetAvatars.cast<PresetAvatar?>().firstWhere(
      (p) => p?.id == avatarUrl || p?.id == cleanPresetId,
      orElse: () => null,
    );

    Widget innerContent;

    if (preset != null) {
      // Hiển thị Preset Avatar
      innerContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: preset.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            preset.icon,
            size: radius * 1.05,
            color: Colors.white,
          ),
        ),
      );
    } else if (avatarLocalPath != null &&
        avatarLocalPath!.isNotEmpty &&
        File(avatarLocalPath!).existsSync()) {
      // Ảnh từ file cục bộ
      innerContent = ClipOval(
        child: Image.file(
          File(avatarLocalPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsFallback(size, gradient),
        ),
      );
    } else if (avatarUrl != null && avatarUrl!.trim().isNotEmpty && avatarUrl!.startsWith('data:image')) {
      // Ảnh mã hóa Base64 dự phòng khi Firebase Storage bị gián đoạn/khóa billing
      try {
        final commaIndex = avatarUrl!.indexOf(',');
        final base64Data = commaIndex != -1 ? avatarUrl!.substring(commaIndex + 1) : avatarUrl!;
        final bytes = base64Decode(base64Data);
        innerContent = ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildInitialsFallback(size, gradient),
          ),
        );
      } catch (e) {
        innerContent = _buildInitialsFallback(size, gradient);
      }
    } else if (avatarUrl != null && avatarUrl!.trim().isNotEmpty && avatarUrl!.startsWith('http')) {
      // Ảnh từ URL mạng qua CachedNetworkImage với disk cache và fallback tức thì (0ms)
      innerContent = ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: (size * 2).toInt(),
          memCacheHeight: (size * 2).toInt(),
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, url) => _buildInitialsFallback(size, gradient),
          errorWidget: (context, url, error) => _buildInitialsFallback(size, gradient),
        ),
      );
    } else {
      // Mặc định: Initials Avatar thời thượng trên nền Gradient
      innerContent = _buildInitialsFallback(size, gradient);
    }

    Widget avatarWidget = innerContent;

    if (showBorder) {
      avatarWidget = Container(
        padding: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: borderColor ?? Colors.white.withValues(alpha: 0.3),
        ),
        child: avatarWidget,
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  Widget _buildInitialsFallback(double size, List<Color> gradient) {
    final initials = getInitials(name);
    final calculatedFontSize = fontSize ?? (radius * 0.85);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: calculatedFontSize,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
