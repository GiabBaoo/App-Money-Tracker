import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          Consumer<ThemeService>(
            builder: (context, themeService, child) {
              return ListTile(
                leading: Icon(
                  themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                ),
                title: const Text('Chế độ tối'),
                subtitle: const Text('Tiết kiệm pin và dịu mắt hơn'),
                trailing: Switch(
                  value: themeService.isDarkMode,
                  onChanged: (value) {
                    themeService.toggleDarkMode();
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
