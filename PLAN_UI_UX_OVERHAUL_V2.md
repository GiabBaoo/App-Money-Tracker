# Kế Hoạch Đại Tu Giao Diện Toàn Diện (UI/UX Overhaul v2.0.0)
**Dự án:** Mono Money Tracker  
**Phiên bản mục tiêu:** `2.0.0+1` (Major Release)  
**Kiến trúc:** Flutter 3.x, Material 3, Riverpod, Offline-First SQLite & Firebase  
**Tác giả:** Senior UI/UX Designer & Flutter Architect  

---

## 1. TỔNG QUAN CHIẾN LƯỢC & MỤC TIÊU 2.0.0

Phiên bản 2.0.0 là cột mốc đại tu toàn diện trải nghiệm thị giác và tương tác của ứng dụng **Mono Money Tracker**:
1. **Dark Mode Chuẩn Mực (Deep Contrast & Semantic Theming):** Loại bỏ triệt để hardcoded colors, giải quyết các lỗi tương phản chữ tối trên nền tối, hoàn thiện hệ thống token màu thích ứng tại `lib/core/theme/`.
2. **Hệ Thống Popup & Thông Báo Hiện Đại (Frosted Glass & Micro-Interactions):** Chuẩn hóa toàn bộ Dialogs, BottomSheets, SnackBars/Toasts về ngôn ngữ thiết kế kính mờ (Frosted Glassmorphism), bo góc 20-24px, hiệu ứng mở mượt mà kết hợp haptic feedback.
3. **Thương Hiệu & Logo "MONO" Liquid Glass:** Thiết kế widget `MonoLiquidGlassLogo` hiệu ứng khối thủy tinh 3D lỏng, dải khúc xạ ánh sáng đa lớp, specular highlights viền phát sáng, đồng bộ trên toàn bộ màn hình và tạo bộ App Launcher Icons (Android / iOS).
4. **Hiệu Ứng Khởi Động Ứng Dụng Đỉnh Cao (60fps Liquid Splash Entrance):** Xóa bỏ màn hình splash tĩnh màu phẳng giật lag; thay bằng chuỗi hoạt họa đàn hồi 60fps (`Curves.easeOutBack`), ánh sáng quét bề mặt kính và chuyển cảnh liền mạch vào trang đích.
5. **Nâng Cấp Phiên Bản 2.0.0 (Major Version Bump):** Đồng bộ cấu hình `pubspec.yaml`, `PackageInfo`, và các hằng số phiên bản tập trung.

---

## 2. CHI TIẾT 5 HẠNG MỤC KỸ THUẬT

### 2.1. Hạng Mục 1: Kiểm Toán & Hoàn Thiện Giao Diện Tối (Dark Mode Audit)

#### A. Tình trạng hiện tại & Rủi ro phát hiện
- **Cấu hình theme chưa tập trung:** Thư mục `lib/core/theme/` đang trống. Theme nằm rải rác ở `lib/services/theme_service.dart` và `lib/utils/app_colors.dart`.
- **Lỗi Hardcoded Colors:** Có hơn 30 màn hình/widget sử dụng trực tiếp `Colors.white`, `Colors.black`, `Colors.grey`, `Color(0xFF...)` cho card backgrounds, icons và text labels.
- **Lỗi tương phản thấp (Low Contrast):**
  - Màn hình `budget_and_goals_screen.dart`: Tab bar active pill sử dụng `Colors.white` nổi trên nền header xanh rêu đậm `0xFF0F2625`, gây chói lóa và lệch chuẩn Dark Mode. Một số tiêu đề thiếu thuộc tính `color`, dẫn đến nguy cơ chữ xám chìm vào nền đen.
  - Màn hình `wallet_screen.dart`: Có tới 84 vị trí hardcoded màu trắng/đen, một số card chi tiết và nút thao tác có viền và màu nền không đồng nhất giữa các tab.
  - Màn hình `add_budget_dialog.dart`, `add_goal_dialog.dart`: Input background dùng `Color(0xFF242424)` và label xám mờ `Colors.grey` không tương thích linh hoạt với độ tương phản hệ thống.
  - Nhóm màn hình Onboarding & Auth (`login_screen.dart`, `register_screen.dart`...): Nền aura radial gradient cố định sắc độ, chưa tối ưu cho màn hình OLED deep black.

#### B. Giải pháp kiến trúc
1. **Thiết lập Bộ Token Theme Chuẩn tại `lib/core/theme/`:**
   - Tạo file `lib/core/theme/app_colors.dart`: Mở rộng bảng màu semantic hỗ trợ OLED Dark Mode (`surface: Color(0xFF161D1C)`, `surfaceElevated: Color(0xFF1E2827)`, `cardDark: Color(0xFF182221)`, `textPrimaryDark: Color(0xFFF1F5F9)`, `textSecondaryDark: Color(0xFF94A3B8)`, `borderDark: Colors.white.withValues(alpha: 0.08)`).
   - Tạo file `lib/core/theme/app_theme.dart`: Định nghĩa Material 3 `ThemeData` hoàn chỉnh cho cả Light và Dark Mode với đầy đủ `colorScheme`, `cardTheme`, `dialogTheme`, `bottomSheetTheme`, `snackBarTheme`, `dividerTheme`, `inputDecorationTheme`.
   - Kết nối `lib/services/theme_service.dart` sử dụng cấu hình tập trung từ `lib/core/theme/app_theme.dart`.
2. **Quy tắc chuyển đổi toàn diện cho các màn hình:**
   - Thay thế mọi `Colors.white` nền card bằng `Theme.of(context).colorScheme.surface` hoặc `AppThemeColors.cardBackground(context)`.
   - Thay thế mọi `Colors.black` / `Colors.white` text bằng `Theme.of(context).colorScheme.onSurface` hoặc `AppThemeColors.textPrimary(context)`.
   - Thay thế mọi viền cứng bằng `Theme.of(context).colorScheme.outline.withValues(alpha: ...)` hoặc `AppThemeColors.border(context)`.

---

### 2.2. Hạng Mục 2: Hiện Đại Hóa Hệ Thống Popup / Thông Báo (Dialogs, BottomSheets, Toasts)

#### A. Tình trạng hiện tại & Bất cập
- **Phân mảnh mã nguồn:**
  - Hơn 52 nơi gọi trực tiếp `ScaffoldMessenger.of(context).showSnackBar()`. Nhiều màn hình copy-paste hàm cục bộ `_showSnackBar()` tạo ra thanh thông báo chữ nhật thô cứng, che mất Floating Action Button và Bottom Navigation Bar.
  - Hơn 27 nơi gọi `showModalBottomSheet()` tự định nghĩa lại `shape`, `backgroundColor`, và tự vẽ thanh kéo `Container(width: 40, height: 4...)` bằng tay không đồng nhất (bo góc dao động 20px, 24px, 28px).
  - Hơn 19 nơi gọi `showDialog()` dùng `AlertDialog` nguyên bản vuông vức, thiếu hiệu ứng đổ bóng mờ và thiếu micro-animation.

#### B. Giải pháp thiết kế & Kiến trúc UI v2.0
1. **Chuẩn hóa BottomSheet `MonoModalBottomSheet`:**
   - Bo góc trên tiêu chuẩn `24px` với viền `specular highlight` (`Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12)))`).
   - Tích hợp sẵn `Drag Handle Pill` (chiều rộng 36px, cao 4px, bo góc 2px) có độ mờ thích ứng theme.
   - Nền kính mờ tinh tế kết hợp `BackdropFilter` (blur 12px) hoặc surface tone cao cấp (`Color(0xFF1A2625)` trong Dark Mode, `Colors.white` trong Light Mode).
   - Hiệu ứng trượt vào với gia tốc `Curves.easeOutCubic`.
2. **Chuẩn hóa Hộp thoại `MonoDialog`:**
   - Tạo tiện ích `MonoDialog.confirm()`, `MonoDialog.alert()`, `MonoDialog.showCustom()`.
   - Thiết kế dạng nổi (floating card), bo góc `22px`, đổ bóng sâu mềm mại (`BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: Offset(0, 8))`).
   - Animation xuất hiện phối hợp: `Transform.scale(0.92 -> 1.0)` + `FadeTransition(0 -> 1.0)` thời lượng `220ms`.
3. **Nâng cấp Toàn diện Toasts / SnackBars (`MonoToast`):**
   - Mở rộng từ `TopToast` thành bộ công cụ thông báo nổi đỉnh màn hình dạng viên nang kính lỏng (Liquid Capsule Toast).
   - 4 trạng thái ngữ nghĩa rõ ràng: `success` (Emerald Green), `error` (Rose Red), `warning` (Amber Orange), `info` (Teal Azure).
   - Thiết kế có icon động, chữ tương phản chuẩn WCAG 2.1 AAA, tự kích hoạt nhẹ nhàng `HapticFeedback.lightImpact()` hoặc `HapticFeedback.mediumImpact()` khi có lỗi.
   - Thay thế toàn bộ 52+ lệnh gọi `ScaffoldMessenger` và các hàm `_showSnackBar()` trùng lặp.

---

### 2.3. Hạng Mục 3: Thiết Kế Lại Logo "MONO" Liquid Glass & Đồng Bộ Toàn App

#### A. Thiết kế Widget `MonoLiquidGlassLogo` (`lib/widgets/mono_liquid_glass_logo.dart`)
1. **Cấu trúc thị giác hiệu ứng Thủy Tinh Lỏng 3D (Liquid Glass Spec):**
   - **Lớp khúc xạ nền (Refraction Layer):** Sử dụng `BackdropFilter` với Gaussian blur `sigmaX: 10`, `sigmaY: 10` làm mờ nhẹ hậu cảnh phía sau logo.
   - **Khối gradient lỏng (Fluid Prism Gradient):** Dải chuyển sắc từ Teal ngọc lục bảo tươi (`#2DD4BF`) đến Teal thẫm (`#0F2625` / `#134E4A`) tạo chiều sâu lập thể.
   - **Viền phản quang sáng (Specular Edge Bevel):** Viền sáng `1.2px` với `LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: 0.6), Colors.white.withValues(alpha: 0.05)])` mô phỏng ánh sáng chiếu lên góc cạnh thủy tinh.
   - **Tia sáng quét động (Active Light Sheen Sweep):** Dải highlight ánh sáng góc 45 độ quét nhẹ qua bề mặt logo theo chu kỳ hoặc khi kích hoạt mở app.
   - **Lớp chữ hoặc biểu tượng Mono:** Phối hợp biểu tượng vô cực/đồng xu lỏng tinh gọn cùng chữ "mono" typography phong cách Neomorphic Glass.
2. **Các biến thể hiển thị (Variants):**
   - `MonoLiquidGlassLogo.badge({double size = 72, bool isInteractive = true})`: Huy hiệu app icon dùng cho Splash, Onboarding, Login, About App.
   - `MonoLiquidGlassLogo.wordmark({double height = 32, Color? tintColor})`: Dạng chữ tối giản kèm viền sáng dùng cho Header và App Bars.
   - `MonoLiquidGlassLogo.compact({double size = 40})`: Biểu tượng nhỏ dùng cho Drawer, thẻ tóm tắt.
3. **Kế thừa & Tương thích ngược:**
   - Cập nhật file hiện hữu `lib/widgets/app_logo.dart` làm facade bao gói `MonoLiquidGlassLogo`, đảm bảo mọi nơi đang import `AppLogo` đều tự động nhận diện mạo Liquid Glass mới mà không vỡ code.

#### B. Toàn bộ vị trí sử dụng Logo trong App cần đồng bộ
1. `lib/modules/splash/splash_screen.dart` (Hiện là `Image.asset` thô sơ -> nâng cấp lên `MonoLiquidGlassLogo.badge` kích thước 120px kèm animation).
2. `lib/modules/onboarding/onboarding_screen.dart` (Dòng 144, 150: Badge & Wordmark).
3. `lib/modules/auth/login_screen.dart` (Dòng 252, 257: Badge & Wordmark).
4. `lib/modules/auth/register_screen.dart` (Dòng 310: Wordmark).
5. `lib/modules/auth/forgot_password_screen.dart` (Dòng 114: Wordmark).
6. `lib/modules/auth/forgot_password_confirmation_screen.dart` (Dòng 31: Wordmark).
7. `lib/modules/auth/reset_password_screen.dart` (Dòng 211: Wordmark).
8. `lib/modules/auth/verify_email_screen.dart` (Dòng 133: Wordmark).
9. `lib/modules/settings/about_app_screen.dart` (Dòng 295: Badge 88px trung tâm thông tin app).
10. `lib/modules/home/home_screen.dart` (Thêm icon thương hiệu Mono Liquid Glass thu nhỏ tại khu vực Header).

#### C. Phương án cập nhật Native App Launcher Icon (Android / iOS)
1. **Thiết kế Master Icon 1024x1024px:**
   - Xuất file hình ảnh chất lượng cao `assets/images/app_icon_liquid_glass.png` (1024x1024 px, 32-bit RGBA) thể hiện trọn vẹn khối thủy tinh lỏng Mono trên nền gradient tối sang trọng.
2. **Cấu hình `flutter_launcher_icons` trong `pubspec.yaml`:**
   ```yaml
   flutter_launcher_icons:
     android: "launcher_icon"
     ios: true
     image_path: "assets/images/app_icon_liquid_glass.png"
     min_sdk_android: 21
     adaptive_icon_background: "#0F2625"
     adaptive_icon_foreground: "assets/images/app_icon_liquid_glass_foreground.png"
   ```
3. **Triển khai sinh tài nguyên native tự động:**
   - Chạy lệnh `flutter pub run flutter_launcher_icons` để tự động ghi đè bộ icons tại:
     - `android/app/src/main/res/mipmap-*/` (ic_launcher.png, ic_launcher_foreground.png)
     - `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (Icon-App-*.png)

---

### 2.4. Hạng Mục 4: Làm Mới Hiệu Ứng Mở Ứng Dụng (Splash / App Launch Animation 60fps)

#### A. Phân tích điểm nghẽn của Splash Screen cũ
- `lib/modules/splash/splash_screen.dart`:
  - Màu nền cứng `backgroundColor: Color(0xFF5E9387)` chói mắt khi thiết bị ở Dark Mode.
  - Khởi tạo và điều hướng ngay lập tức tại `addPostFrameCallback` làm màn hình giật nháy, không cho người dùng cảm nhận nhận diện thương hiệu.
  - Sử dụng ảnh bitmap tĩnh phẳng, không có chiều sâu tương tác.

#### B. Thiết kế kịch bản hoạt họa 60fps chuẩn điện ảnh (Cinematic Launch Flow)
1. **Giai đoạn 1: Nền Aura Thích Ứng (0 - 200ms)**
   - Nền tự động nhận diện `Theme.of(context).brightness`.
   - Vầng sáng Radial Gradient thở nhẹ (breathing aura) phía sau trung tâm logo, tạo chiều sâu thị giác ngay từ millisecond đầu tiên.
2. **Giai đoạn 2: Khối Liquid Glass Xuất Hiện Đàn Hồi (100 - 650ms)**
   - `AnimationController` điều khiển `ScaleTransition` từ `0.65` lên `1.05` rồi hãm nhẹ về `1.0` với đường cong `Curves.easeOutBack`.
   - Đồng thời `FadeTransition` độ mờ tăng mượt từ `0.0` lên `1.0` (`Curves.easeOutCubic`).
3. **Giai đoạn 3: Luồng Sáng Quét Kính (Specular Sheen Sweep) (550 - 1050ms)**
   - Tia sáng chéo lướt qua mặt kính logo từ góc trên bên trái xuống dưới bên phải với gia tốc `Curves.easeInOutCubic`.
   - Mang lại cảm giác thủy tinh khúc xạ chân thực và sống động.
4. **Giai đoạn 4: Tải Dữ Liệu Song Song & Chuyển Cảnh Liền Mạch (Concurrent Gate & Transition)**
   - Quá trình kiểm tra phiên đăng nhập (`AuthService`), phiên sinh trắc học vân tay (`BiometricService`), và pending invites được thực thi song song trong thời gian hoạt họa (tối thiểu 850ms, tối đa 1200ms).
   - Chuyển màn hình đích (`HomeScreen` / `OnboardingScreen` / `FingerprintUnlockScreen`) bằng bộ chuyển cảnh `PageRouteBuilder` tùy biến kết hợp `FadeTransition` (300ms) và `ScaleTransition` (0.98 -> 1.0), triệt tiêu hoàn toàn cảm giác giật khựng.

---

### 2.5. Hạng Mục 5: Nâng Cấp Phiên Bản Ứng Dụng Lên 2.0.0 (Major Release Bump)

#### A. Cập nhật tập tin cấu hình
1. **`pubspec.yaml`:**
   - Thay đổi: `version: 1.0.0+1` ➔ `version: 2.0.0+1`.
   - Khai báo chính thức `package_info_plus: ^9.0.1` vào nhóm `dependencies` (loại bỏ cờ ignore lint).
   - Bổ sung `flutter_launcher_icons: ^0.14.3` vào nhóm `dev_dependencies`.
2. **Tập trung hóa hằng số phiên bản tại `lib/core/constants/app_constants.dart`:**
   - Tạo file `app_constants.dart` chứa:
     ```dart
     class AppConstants {
       static const String appName = 'Mono';
       static const String appVersion = '2.0.0';
       static const int appBuildNumber = 1;
       static const String appVersionFull = '2.0.0.1';
       static const String appReleaseName = 'Mono 2.0 - Liquid Glass Edition';
     }
     ```
3. **Đồng bộ các màn hình hiển thị phiên bản:**
   - `lib/modules/settings/about_app_screen.dart`:
     - Cập nhật chuỗi fallback tại `_getAppVersion()` từ `'1.0.0.1'` ➔ `AppConstants.appVersionFull` (`'2.0.0.1'`).
     - Tối ưu hóa logic phân tách chuỗi version/build để luôn hiển thị định dạng chuẩn `2.0.0 (Build 1)` hoặc `2.0.0.1`.
   - `lib/modules/settings/profile_screen.dart`:
     - Dòng 819: Cập nhật badge menu "Về ứng dụng Mono" từ `badgeText: 'v1.0.0'` ➔ `badgeText: 'v2.0.0'`.

---

## 3. DANH SÁCH FILE THỰC THI & PHÂN BỔ 3 BATCH

### BATCH 1: Nền Tảng Core, Chuẩn Hóa Dark Mode & Major Version Bump
> **Trọng tâm:** Kiến tạo hệ thống tokens giao diện tại `lib/core/`, loại bỏ các lỗi hardcoded colors, fix tương phản Dark Mode và kích hoạt phiên bản 2.0.0.

#### Danh sách File chỉnh sửa & tạo mới:
1. `pubspec.yaml` *(Sửa: Bump version lên 2.0.0+1, thêm package_info_plus, flutter_launcher_icons)*
2. `lib/core/constants/app_constants.dart` *(Tạo mới: Hằng số phiên bản 2.0.0, tên ứng dụng, metadata thương hiệu)*
3. `lib/core/theme/app_colors.dart` *(Tạo mới: Bảng màu semantic, gradient tokens, OLED dark mode surfaces)*
4. `lib/core/theme/app_theme.dart` *(Tạo mới: Bộ cấu hình ThemeData Light/Dark chuẩn Material 3)*
5. `lib/services/theme_service.dart` *(Sửa: Tích hợp với `app_theme.dart` và `app_colors.dart`)*
6. `lib/utils/app_colors.dart` *(Sửa: Xuất alias hoặc đồng bộ về `core/theme/app_colors.dart` để giữ tương thích)*
7. `lib/modules/settings/about_app_screen.dart` *(Sửa: Cập nhật hiển thị phiên bản 2.0.0.1 từ AppConstants)*
8. `lib/modules/settings/profile_screen.dart` *(Sửa: Cập nhật badge version 'v2.0.0', rà soát màu nền dark mode)*
9. `lib/modules/budget/budget_and_goals_screen.dart` *(Sửa: Khắc phục lỗi active tab trắng toát trên nền tối, fix màu chữ tiêu đề)*
10. `lib/modules/budget/add_budget_dialog.dart` *(Sửa: Thay thế màu nền hardcode, fix tương phản label xám)*
11. `lib/modules/budget/add_goal_dialog.dart` *(Sửa: Khắc phục hardcoded colors, chuẩn hóa input dark mode)*
12. `lib/modules/home/home_screen.dart` *(Sửa: Rà soát header và card số dư ở Dark Mode)*
13. `lib/modules/home/statistics_screen.dart` *(Sửa: Chuẩn hóa màu sắc biểu đồ và thẻ phân tích theo theme)*
14. `lib/modules/calendar/calendar_tracking_screen.dart` *(Sửa: Rà soát tương phản lịch chi tiêu Dark Mode)*
15. `lib/modules/ai_assistant/ai_assistant_screen.dart` *(Sửa: Rà soát khung chat AI và bong bóng tin nhắn dark mode)*
16. `lib/modules/ai_assistant/widgets/mono_assistant_cards.dart` *(Sửa: Khắc phục các thẻ thông tin AI hardcoded màu)*

---

### BATCH 2: Khung Popups, Dialogs, BottomSheets & Modern Toast Framework
> **Trọng tâm:** Hiện đại hóa toàn diện hệ thống tương tác nổi, triệt tiêu `showSnackBar` phân mảnh, áp dụng Frosted Glass và chuẩn hóa bo góc 20-24px.

#### Danh sách File chỉnh sửa & tạo mới:
1. `lib/core/utils/mono_dialogs.dart` *(Tạo mới: Bộ khung tiện ích hiển thị Dialog xác nhận, cảnh báo chuẩn Liquid Glass 22px)*
2. `lib/core/utils/mono_bottom_sheet.dart` *(Tạo mới: Bộ khung BottomSheet chuẩn bo góc 24px kèm Drag Handle và BackdropFilter)*
3. `lib/widgets/top_toast.dart` *(Sửa & Nâng cấp: Nâng cấp thành Liquid Capsule Toast 4 trạng thái, bo góc 24px, haptic feedback)*
4. `lib/modules/home/wallet_screen.dart` *(Sửa: Thay thế toàn bộ showModalBottomSheet và showDialog xóa ví thô sơ bằng chuẩn mới)*
5. `lib/modules/transaction/category_screen.dart` *(Sửa: Chuẩn hóa hộp thoại xóa danh mục và BottomSheet tùy chỉnh icon/màu)*
6. `lib/modules/transaction/add_transaction_screen.dart` *(Sửa: Thay thế sheet chọn ảnh hóa đơn và dialog xác nhận hủy)*
7. `lib/modules/transaction/edit_transaction_screen.dart` *(Sửa: Đồng bộ dialogs và sheets tương ứng)*
8. `lib/modules/transaction/transaction_detail_screen.dart` *(Sửa: Hộp thoại xác nhận xóa giao dịch)*
9. `lib/modules/auth/login_screen.dart` *(Sửa: Thay thế _showSnackBar nội bộ bằng TopToast mới)*
10. `lib/modules/auth/register_screen.dart` *(Sửa: Thay thế SnackBar nội bộ)*
11. `lib/modules/auth/forgot_password_screen.dart` *(Sửa: Thay thế SnackBar nội bộ)*
12. `lib/modules/auth/forgot_password_confirmation_screen.dart` *(Sửa: Thay thế SnackBar nội bộ)*
13. `lib/modules/auth/reset_password_screen.dart` *(Sửa: Thay thế SnackBar nội bộ)*
14. `lib/modules/auth/verify_email_screen.dart` *(Sửa: Thay thế SnackBar nội bộ)*
15. `lib/modules/settings/active_devices_screen.dart` *(Sửa: Chuẩn hóa dialog đăng xuất thiết bị)*
16. `lib/modules/settings/account_info_screen.dart` *(Sửa: Chuẩn hóa sheet đổi tên, đổi mật khẩu)*
17. `lib/features/group_expense/presentation/screens/group_detail_screen.dart` *(Sửa: Chuẩn hóa dialog rời nhóm/xóa nhóm)*
18. `lib/features/group_expense/presentation/screens/group_list_screen.dart` *(Sửa: Thay thế các thông báo SnackBar)*
19. `lib/features/group_expense/presentation/screens/create_expense_screen.dart` *(Sửa: Chuyển đổi SnackBar sang Toast)*

---

### BATCH 3: Logo "MONO" Liquid Glass, 60fps Splash Launch Animation & App Launcher Icon
> **Trọng tâm:** Chế tác widget `MonoLiquidGlassLogo`, lập trình hoạt họa mở app 60fps đỉnh cao, đồng bộ logo toàn app và thiết lập launcher icons native.

#### Danh sách File chỉnh sửa & tạo mới:
1. `lib/widgets/mono_liquid_glass_logo.dart` *(Tạo mới: Custom Widget hiệu ứng thủy tinh lỏng 3D, specular highlights và shimmer sweep)*
2. `lib/widgets/app_logo.dart` *(Sửa: Tích hợp và trỏ về `MonoLiquidGlassLogo` để đảm bảo tương thích ngược 100%)*
3. `lib/modules/splash/splash_screen.dart` *(Sửa: Tái cấu trúc toàn diện 60fps entrance animation, Curves.easeOutBack, ánh sáng quét kính và PageRouteBuilder mượt mà)*
4. `lib/modules/onboarding/onboarding_screen.dart` *(Sửa: Tích hợp Liquid Glass Logo)*
5. `lib/modules/auth/login_screen.dart` *(Sửa: Cập nhật Liquid Glass Logo badge và wordmark)*
6. `lib/modules/auth/register_screen.dart` *(Sửa: Cập nhật Liquid Glass Logo)*
7. `lib/modules/auth/forgot_password_screen.dart` *(Sửa: Cập nhật Liquid Glass Logo)*
8. `lib/modules/auth/reset_password_screen.dart` *(Sửa: Cập nhật Liquid Glass Logo)*
9. `lib/modules/settings/about_app_screen.dart` *(Sửa: Cập nhật Liquid Glass Logo badge 88px)*
10. `assets/images/app_icon_liquid_glass.png` *(Tạo mới/Tích hợp: Master App Icon 1024x1024 phong cách Liquid Glass)*
11. `assets/images/app_icon_liquid_glass_foreground.png` *(Tạo mới: Adaptive icon foreground cho Android)*
12. Các tài nguyên native phát sinh sau khi chạy `flutter_launcher_icons`:
    - `android/app/src/main/res/mipmap-*/ic_launcher*.png`
    - `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png`

---

## 4. TIÊU CHUẨN KIỂM THỬ & NGHIỆM THU (VERIFICATION CRITERIA)

| Hạng mục | Tiêu chuẩn nghiệm thu v2.0.0 |
| :--- | :--- |
| **Dark Mode** | Không có chữ tối trên nền tối; tab và card chuyển đổi mượt mà khi đổi chế độ sáng/tối; không phát hiện chói sáng bất thường trên màn hình OLED. |
| **Popup / Dialogs** | 100% dialogs và bottom sheets có bo góc chuẩn (20-24px); không che khuất FAB; Toast xuất hiện đỉnh màn hình dạng viên nang lỏng kèm haptic feedback; không còn gọi `ScaffoldMessenger.showSnackBar()` thô sơ. |
| **Liquid Glass Logo** | Khối thủy tinh hiển thị sắc nét ở mọi kích cỡ (28px đến 150px); hiệu ứng vệt sáng lướt qua mượt mà không gây rớt frame. |
| **Splash Launch** | Đạt ổn định 60fps trên thiết bị thật; không giật nháy màu nền; thời gian chờ khởi động tối ưu từ 800ms đến 1100ms; chuyển trang đích bằng fade/scale êm ái. |
| **Version 2.0.0** | `pubspec.yaml` hiển thị `2.0.0+1`; trang Cài đặt / Giới thiệu hiển thị đúng `2.0.0.1` hoặc `2.0.0`; menu hồ sơ hiển thị huy hiệu `v2.0.0`; App icon trên màn hình điện thoại hiển thị đúng biểu tượng Liquid Glass mới. |
| **Chất lượng mã** | `flutter analyze` không có lỗi nghiêm trọng (0 errors); không có dependency conflict. |
