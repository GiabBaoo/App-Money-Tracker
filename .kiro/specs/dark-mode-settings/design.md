# Tài liệu Thiết kế - Giao diện Cài đặt và Chế độ Tối

## Overview

Tính năng này bổ sung màn hình cài đặt mới với khả năng chuyển đổi chế độ tối (dark mode) cho toàn bộ ứng dụng quản lý thu chi. Thiết kế tận dụng ThemeService hiện có và mở rộng nó để hỗ trợ chuyển đổi theme động với hiệu ứng mượt mà. Ngoài ra, thiết kế cũng chuẩn hóa việc hiển thị biểu tượng giao dịch giữa các màn hình để đảm bảo tính nhất quán trong trải nghiệm người dùng.

Các thành phần chính:
- SettingsScreen: Màn hình cài đặt mới với dark mode toggle
- ThemeService: Dịch vụ quản lý theme đã được mở rộng (đã tồn tại)
- ProfileScreen: Cập nhật để thêm menu item "Cài đặt"
- HomeBody: Cập nhật để chuẩn hóa màu sắc icon giao dịch

## Architecture

### State Management

Ứng dụng sử dụng Provider pattern với ChangeNotifier để quản lý trạng thái theme:

```
MaterialApp (Consumer)
    ↓
ThemeService (ChangeNotifier)
    ↓
SettingsScreen (UI Controls)
```

ThemeService đã tồn tại và cung cấp:
- `isDarkMode`: Boolean state cho chế độ hiện tại
- `themeMode`: ThemeMode enum (light/dark)
- `toggleDarkMode()`: Method để chuyển đổi theme
- `lightTheme` và `darkTheme`: ThemeData configurations
- Persistence qua FlutterSecureStorage

### Navigation Flow

```
ProfileScreen
    ↓ (tap "Cài đặt" menu item)
SettingsScreen
    ↓ (toggle dark mode switch)
ThemeService.toggleDarkMode()
    ↓ (notifyListeners)
MaterialApp rebuilds with new theme
```

### Theme Application

MaterialApp đã được cấu hình với:
- `theme`: lightTheme từ ThemeService
- `darkTheme`: darkTheme từ ThemeService  
- `themeMode`: Động dựa trên ThemeService.themeMode

Khi `toggleDarkMode()` được gọi:
1. ThemeService cập nhật `_isDarkMode` state
2. Lưu preference vào FlutterSecureStorage
3. Gọi `notifyListeners()`
4. MaterialApp tự động rebuild với theme mới
5. Tất cả widgets con kế thừa theme mới qua Theme.of(context)

## Components and Interfaces

### 1. SettingsScreen (New)

**Location:** `lib/modules/settings/settings_screen.dart`

**Purpose:** Màn hình cài đặt chính hiển thị các tùy chọn cấu hình ứng dụng

**UI Structure:**
```
Scaffold
├── AppBar (title: "Cài đặt", back button)
└── ListView
    └── Dark Mode Toggle Item
        ├── Icon (moon/sun based on mode)
        ├── Text ("Chế độ tối")
        ├── Subtitle ("Tiết kiệm pin và dịu mắt hơn")
        └── Switch (bound to ThemeService.isDarkMode)
```

**Key Properties:**
- Responsive to theme changes via Theme.of(context)
- Switch state synced with ThemeService.isDarkMode
- Icon changes dynamically: Icons.dark_mode (moon) when dark, Icons.light_mode (sun) when light

**Implementation Notes:**
- Use Consumer<ThemeService> hoặc context.watch<ThemeService>() để lắng nghe thay đổi
- Switch.onChanged gọi ThemeService.toggleDarkMode()
- Transition animation được xử lý tự động bởi Flutter framework (AnimatedTheme)

### 2. ThemeService (Existing - No Changes Needed)

**Location:** `lib/services/theme_service.dart`

**Current Implementation:** Đã hoàn chỉnh với tất cả chức năng cần thiết:
- Dark mode state management
- Theme persistence với FlutterSecureStorage
- Light và dark ThemeData configurations
- Màu sắc đã được định nghĩa đúng theo requirements:
  - Primary color: #438883 (giữ nguyên cả 2 modes)
  - Dark background: #121212
  - Dark containers: #1E1E1E
  - Light background: white

**No modifications required** - Service đã đáp ứng đầy đủ requirements.

### 3. ProfileScreen (Update)

**Location:** `lib/modules/settings/profile_screen.dart`

**Changes Required:**
- Thêm menu item "Cài đặt" vào ListView
- Position: Trước menu item "Đăng nhập và bảo mật" (index 0)
- Icon: Icons.settings_outlined
- OnTap: Navigate to SettingsScreen

**Updated Menu Order:**
1. Cài đặt (NEW)
2. Thông tin tài khoản
3. Trung tâm tin nhắn
4. Đăng nhập và bảo mật
5. Dữ liệu và riêng tư

### 4. HomeBody Transaction Icons (Update)

**Location:** `lib/modules/home/home_screen.dart` (HomeBody class)

**Current Issue:** Transaction icons trong HomeBody sử dụng màu cố định (Color(0xFF438883)) thay vì màu động dựa trên loại giao dịch.

**Changes Required:**
Trong `_transactionItem` method, cập nhật icon container:

```dart
// Current (incorrect):
Container(
  decoration: BoxDecoration(color: const Color(0xFFF0F6F5), ...),
  child: Icon(icon, color: const Color(0xFF438883), size: 24),
)

// Updated (correct):
Container(
  decoration: BoxDecoration(color: const Color(0xFFF0F6F5), ...),
  child: Icon(icon, color: isIncome ? const Color(0xFF24A869) : const Color(0xFFF95B51), size: 24),
)
```

**Icon Specifications:**
- Income transactions: Color(0xFF24A869) - green
- Expense transactions: Color(0xFFF95B51) - red
- Background: Color(0xFFF0F6F5) - light teal (same for both)
- Size: 24 (HomeBody) matches 28 (WalletScreen) - acceptable variance

**Note:** WalletScreen đã implement đúng với `iconColor` parameter.

## Data Models

### Theme Preference Storage

**Storage Key:** `'isDarkMode'`
**Storage Type:** FlutterSecureStorage
**Value Format:** String boolean ('true' or 'false')

**Persistence Flow:**
```
User toggles switch
    ↓
ThemeService.toggleDarkMode()
    ↓
_storage.write(key: 'isDarkMode', value: _isDarkMode.toString())
    ↓
notifyListeners()
```

**Initialization Flow:**
```
App startup
    ↓
ThemeService.init()
    ↓
_storage.read(key: 'isDarkMode')
    ↓
_isDarkMode = value == 'true'
    ↓
notifyListeners()
```

### Theme Configuration

**Light Theme:**
- scaffoldBackgroundColor: Colors.white
- primaryColor: Color(0xFF438883)
- bottomAppBarTheme.color: Colors.white
- colorScheme.brightness: Brightness.light

**Dark Theme:**
- scaffoldBackgroundColor: Color(0xFF121212)
- primaryColor: Color(0xFF438883)
- bottomAppBarTheme.color: Color(0xFF1E1E1E)
- colorScheme.brightness: Brightness.dark

**Shared Properties:**
- useMaterial3: true
- colorScheme seeded from Color(0xFF438883)

## Correctness Properties


*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Theme Persistence Round-Trip

*For any* dark mode state (true or false), after toggling dark mode and reinitializing the ThemeService, the restored state should match the saved state.

**Validates: Requirements 2.4, 2.5**

### Property 2: Dark Theme Colors Applied Correctly

*For any* screen in the app, when dark mode is enabled, the scaffold background color should be #121212, text colors should use light variants from the theme, and container backgrounds should use #1E1E1E.

**Validates: Requirements 3.1, 3.2, 3.3**

### Property 3: Light Theme Colors Applied Correctly

*For any* screen in the app, when light mode is enabled, the scaffold background color should be white (0xFFFFFFFF) and text colors should use dark variants from the theme.

**Validates: Requirements 3.4, 3.5**

### Property 4: Primary Color Consistency Across Modes

*For any* theme mode (light or dark), the primary color should always be #438883.

**Validates: Requirements 3.6**

### Property 5: Widget-Specific Theme Updates

*For any* theme mode, the BottomAppBar color should be white in light mode and #1E1E1E in dark mode, and AppBar colors should match the theme's surface colors.

**Validates: Requirements 3.7, 3.8**

### Property 6: Transaction Icon Colors Match Transaction Type

*For any* transaction displayed on either Profile_Screen or Wallet_Screen, income transactions should use icon color #24A869 (green) and expense transactions should use icon color #F95B51 (red), and the colors should be consistent between both screens for the same transaction type.

**Validates: Requirements 4.1, 4.2, 4.5**

### Property 7: Settings Screen State Persistence Across Navigation

*For any* dark mode state, after navigating to Settings_Screen, navigating away, and returning to Settings_Screen, the switch should reflect the current dark mode state accurately.

**Validates: Requirements 6.5**

## Error Handling

### Theme Service Initialization

**Scenario:** Storage read fails during ThemeService.init()

**Handling:**
- Catch exception from FlutterSecureStorage.read()
- Default to light mode (_isDarkMode = false)
- Log error for debugging
- Continue app initialization normally

```dart
Future<void> init() async {
  try {
    final value = await _storage.read(key: 'isDarkMode');
    _isDarkMode = value == 'true';
  } catch (e) {
    _isDarkMode = false; // Default to light mode
    debugPrint('Error loading theme preference: $e');
  }
  notifyListeners();
}
```

### Theme Toggle Persistence

**Scenario:** Storage write fails during toggleDarkMode()

**Handling:**
- UI state still updates immediately (optimistic update)
- Catch exception from FlutterSecureStorage.write()
- Log error but don't block UI
- On next app restart, will revert to last successfully saved state

```dart
Future<void> toggleDarkMode() async {
  _isDarkMode = !_isDarkMode;
  notifyListeners(); // Update UI immediately
  
  try {
    await _storage.write(key: 'isDarkMode', value: _isDarkMode.toString());
  } catch (e) {
    debugPrint('Error saving theme preference: $e');
    // Don't revert UI state - user sees immediate feedback
  }
}
```

### Navigation Errors

**Scenario:** Navigation to SettingsScreen fails

**Handling:**
- Flutter's Navigator handles route errors automatically
- If route not found, Navigator.push returns null
- No additional error handling needed - framework handles gracefully

### Theme Data Access

**Scenario:** Theme.of(context) called before MaterialApp builds

**Handling:**
- This is a developer error, not runtime error
- Flutter throws clear error message during development
- Prevented by proper widget tree structure with MaterialApp at root

## Testing Strategy

### Dual Testing Approach

This feature requires both unit tests and property-based tests for comprehensive coverage:

**Unit Tests** focus on:
- Specific UI examples (e.g., "Cài đặt" title appears, settings icon is correct)
- Edge cases (e.g., storage read returns null, empty string)
- Integration points (e.g., navigation between screens)
- Widget structure validation

**Property-Based Tests** focus on:
- Universal properties across all theme states
- Round-trip persistence behavior
- Color consistency across all screens
- Icon color rules for all transaction types

### Property-Based Testing Configuration

**Library:** Use `flutter_test` with custom property test helpers or `test` package with manual randomization

**Configuration:**
- Minimum 100 iterations per property test
- Each test tagged with: **Feature: dark-mode-settings, Property {number}: {property_text}**

**Property Test Implementation:**

Each correctness property must be implemented as a single property-based test:

1. **Property 1 Test:** Generate random boolean states, toggle and reinitialize, verify round-trip
   - Tag: **Feature: dark-mode-settings, Property 1: Theme Persistence Round-Trip**

2. **Property 2 Test:** Generate random dark theme contexts, verify all color values
   - Tag: **Feature: dark-mode-settings, Property 2: Dark Theme Colors Applied Correctly**

3. **Property 3 Test:** Generate random light theme contexts, verify all color values
   - Tag: **Feature: dark-mode-settings, Property 3: Light Theme Colors Applied Correctly**

4. **Property 4 Test:** Generate random theme modes, verify primary color is always #438883
   - Tag: **Feature: dark-mode-settings, Property 4: Primary Color Consistency Across Modes**

5. **Property 5 Test:** Generate random theme modes, verify BottomAppBar and AppBar colors
   - Tag: **Feature: dark-mode-settings, Property 5: Widget-Specific Theme Updates**

6. **Property 6 Test:** Generate random transactions (income/expense), verify icon colors on both screens
   - Tag: **Feature: dark-mode-settings, Property 6: Transaction Icon Colors Match Transaction Type**

7. **Property 7 Test:** Generate random dark mode states, simulate navigation, verify switch state
   - Tag: **Feature: dark-mode-settings, Property 7: Settings Screen State Persistence Across Navigation**

### Unit Test Coverage

**SettingsScreen Tests:**
- Verify "Cài đặt" title appears in AppBar
- Verify back button exists
- Verify ListView with dark mode toggle exists
- Verify moon icon when dark mode enabled
- Verify sun icon when light mode enabled
- Verify subtitle text "Tiết kiệm pin và dịu mắt hơn"
- Verify switch tap triggers ThemeService.toggleDarkMode()

**ProfileScreen Tests:**
- Verify "Cài đặt" menu item exists
- Verify settings icon (Icons.settings_outlined) is used
- Verify menu item positioned before "Đăng nhập và bảo mật"
- Verify tap navigates to SettingsScreen
- Verify menu item uses same styling as other items

**HomeBody Tests:**
- Verify income transaction icons use color #24A869
- Verify expense transaction icons use color #F95B51
- Verify icon background color is #F0F6F5
- Verify icon size consistency

**ThemeService Tests:**
- Verify init() loads saved preference
- Verify init() defaults to false when no saved value
- Verify toggleDarkMode() updates state
- Verify toggleDarkMode() saves to storage
- Verify lightTheme has correct colors
- Verify darkTheme has correct colors

### Integration Tests

**Theme Switching Flow:**
1. Launch app
2. Navigate to Profile → Settings
3. Toggle dark mode switch
4. Verify all screens update to dark theme
5. Restart app
6. Verify dark mode persists

**Icon Consistency Flow:**
1. Create test transactions (income and expense)
2. View on HomeBody
3. Navigate to WalletScreen
4. Verify icon colors match between screens

### Test Data

**Mock Transactions:**
```dart
final incomeTransaction = TransactionModel(
  isIncome: true,
  category: 'Lương',
  amount: 10000000,
  icon: Icons.attach_money,
  date: DateTime.now(),
  time: '14:30',
);

final expenseTransaction = TransactionModel(
  isIncome: false,
  category: 'Ăn uống',
  amount: 50000,
  icon: Icons.restaurant,
  date: DateTime.now(),
  time: '12:00',
);
```

**Mock Storage:**
```dart
class MockSecureStorage extends Mock implements FlutterSecureStorage {}

// Test setup
final mockStorage = MockSecureStorage();
when(mockStorage.read(key: 'isDarkMode')).thenAnswer((_) async => 'true');
```

### Performance Validation

While timing requirements (300ms transitions) are not unit-testable, they should be validated through:
- Manual testing on target devices
- Flutter DevTools performance profiling
- Frame rendering metrics (should maintain 60fps during transitions)

### Accessibility Testing

Verify theme changes maintain accessibility:
- Contrast ratios meet WCAG AA standards
- Text remains readable in both modes
- Icons remain distinguishable
- Focus indicators visible in both themes

Note: Automated tests cannot fully validate WCAG compliance - manual testing with assistive technologies is required.
