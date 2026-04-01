import 'package:flutter/material.dart';

/// App Colors - Centralized color management
class AppColors {
  // Primary teal color for light mode
  static const Color primaryTeal = Color(0xFF438883);
  
  // Dark teal color for dark mode (much darker, closer to black)
  static const Color primaryTealDark = Color(0xFF0F2625);
  
  // Helper method to get the appropriate teal color based on theme
  static Color getTealColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
      ? primaryTealDark 
      : primaryTeal;
  }
  
  // Card teal color for dark mode (slightly lighter than primary for cards)
  static const Color cardTealDark = Color(0xFF1A3635);
  
  // Helper method to get the appropriate card teal color based on theme
  static Color getCardTealColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
      ? cardTealDark 
      : const Color(0xFF2E7E78);
  }
}
