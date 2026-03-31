# Implementation Plan: Giao diện Cài đặt và Chế độ Tối

## Overview

Triển khai màn hình cài đặt mới với khả năng chuyển đổi chế độ tối, cập nhật ProfileScreen để thêm menu item "Cài đặt", và chuẩn hóa màu sắc icon giao dịch trong HomeBody để khớp với WalletScreen. ThemeService đã tồn tại và hoàn chỉnh, không cần thay đổi.

## Tasks

- [x] 1. Tạo SettingsScreen với dark mode toggle
  - [x] 1.1 Tạo file settings_screen.dart với cấu trúc cơ bản
    - Tạo StatelessWidget với Scaffold
    - Thêm AppBar với title "Cài đặt" và back button
    - Thêm ListView làm body
    - _Requirements: 1.1, 1.2, 1.3_
  
  - [x] 1.2 Implement dark mode toggle UI
    - Tạo ListTile với icon động (moon/sun), title "Chế độ tối", subtitle "Tiết kiệm pin và dịu mắt hơn"
    - Thêm Switch widget bound với ThemeService.isDarkMode
    - Sử dụng Consumer<ThemeService> để lắng nghe thay đổi
    - Icon: Icons.dark_mode khi dark, Icons.light_mode khi light
    - _Requirements: 2.1, 2.6, 2.7, 2.8_
  
  - [x] 1.3 Wire switch onChanged với ThemeService.toggleDarkMode()
    - Gọi ThemeService.toggleDarkMode() khi switch thay đổi
    - Đảm bảo UI cập nhật tự động qua notifyListeners
    - _Requirements: 2.2, 2.3_
  
  - [ ]* 1.4 Write property test for SettingsScreen
    - **Property 7: Settings Screen State Persistence Across Navigation**
    - **Validates: Requirements 6.5**
  
  - [ ]* 1.5 Write unit tests for SettingsScreen
    - Test title "Cài đặt" hiển thị
    - Test back button tồn tại
    - Test moon icon khi dark mode enabled
    - Test sun icon khi light mode enabled
    - Test subtitle text
    - Test switch tap triggers toggleDarkMode()
    - _Requirements: 1.1, 1.2, 2.6, 2.7, 2.8_

- [x] 2. Cập nhật ProfileScreen để thêm menu item "Cài đặt"
  - [x] 2.1 Thêm menu item "Cài đặt" vào ProfileScreen
    - Thêm ListTile với icon Icons.settings_outlined
    - Title: "Cài đặt"
    - Position: Index 0 (trước "Đăng nhập và bảo mật")
    - OnTap: Navigate to SettingsScreen
    - Áp dụng cùng styling với các menu items khác
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  
  - [ ]* 2.2 Write unit tests for ProfileScreen updates
    - Test "Cài đặt" menu item tồn tại
    - Test settings icon đúng
    - Test position trước "Đăng nhập và bảo mật"
    - Test tap navigates to SettingsScreen
    - Test styling khớp với các menu items khác
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 3. Checkpoint - Verify navigation and basic UI
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Chuẩn hóa màu sắc icon giao dịch trong HomeBody
  - [x] 4.1 Cập nhật _transactionItem method trong HomeBody
    - Thay đổi icon color từ Color(0xFF438883) sang màu động
    - Income transactions: Color(0xFF24A869) - green
    - Expense transactions: Color(0xFFF95B51) - red
    - Giữ nguyên background color Color(0xFFF0F6F5)
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_
  
  - [ ]* 4.2 Write property test for transaction icon colors
    - **Property 6: Transaction Icon Colors Match Transaction Type**
    - **Validates: Requirements 4.1, 4.2, 4.5**
  
  - [ ]* 4.3 Write unit tests for HomeBody icon colors
    - Test income transaction icons use #24A869
    - Test expense transaction icons use #F95B51
    - Test icon background color is #F0F6F5
    - _Requirements: 4.1, 4.2, 4.4_

- [ ] 5. Implement property-based tests for theme system
  - [ ]* 5.1 Write property test for theme persistence
    - **Property 1: Theme Persistence Round-Trip**
    - **Validates: Requirements 2.4, 2.5**
  
  - [ ]* 5.2 Write property test for dark theme colors
    - **Property 2: Dark Theme Colors Applied Correctly**
    - **Validates: Requirements 3.1, 3.2, 3.3**
  
  - [ ]* 5.3 Write property test for light theme colors
    - **Property 3: Light Theme Colors Applied Correctly**
    - **Validates: Requirements 3.4, 3.5**
  
  - [ ]* 5.4 Write property test for primary color consistency
    - **Property 4: Primary Color Consistency Across Modes**
    - **Validates: Requirements 3.6**
  
  - [ ]* 5.5 Write property test for widget-specific theme updates
    - **Property 5: Widget-Specific Theme Updates**
    - **Validates: Requirements 3.7, 3.8**

- [ ] 6. Write unit tests for ThemeService
  - [ ]* 6.1 Write unit tests for ThemeService
    - Test init() loads saved preference
    - Test init() defaults to false when no saved value
    - Test toggleDarkMode() updates state
    - Test toggleDarkMode() saves to storage
    - Test lightTheme has correct colors
    - Test darkTheme has correct colors
    - _Requirements: 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 7. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- ThemeService đã tồn tại và hoàn chỉnh, không cần thay đổi
- Mỗi property test phải chạy tối thiểu 100 iterations
- Theme transitions được xử lý tự động bởi Flutter framework (AnimatedTheme)
- Manual testing cần thiết để verify 300ms transition requirement
- Accessibility testing cần manual validation với assistive technologies
