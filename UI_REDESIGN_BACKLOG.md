# BÁO CÁO KIỂM TRA HIỆN TRẠNG GIAO DIỆN & BACKLOG THIẾT KẾ LẠI (UI REDESIGN BACKLOG)

> **Vai trò**: UI/UX Tech Lead  
> **Dự án**: Mono Expense Tracker App  
> **Thời gian quét**: Tháng 10/2026  
> **Mục tiêu**: Đánh giá toàn diện cấu hình Theme hệ thống, phát hiện các điểm nghẽn Hardcode màu sắc/Typography và thiết lập danh mục công việc chuẩn hóa giao diện đa nền tảng.

---

## 1. Kiểm tra File Cấu hình Theme Hiện tại (`lib/core/theme/`)

Hệ thống theme hiện tại của ứng dụng được xây dựng trên nền tảng Material 3 tập trung ở hai file:
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_theme.dart`

### 1.1. Màu sắc chủ đạo (Brand & System Colors)
* **Brand Primary**:
  - `primaryTeal`: `Color(0xFF438883)` (Xanh Teal ngọc trầm - Brand chính bản Light).
  - `primaryTealLight`: `Color(0xFF68AEA9)`.
  - `primaryTealDark`: `Color(0xFF0F2625)` (Xanh rêu đậm sâu).
  - `primaryTealVibrant`: `Color(0xFF2DD4BF)` (Teal Neon ngọc lục bảo - Điểm nhấn tương phản cao cho Dark Mode).
* **Nền tảng Backgrounds**:
  - Light Mode: `bgLight` = `Color(0xFFF8FAFC)` (Slate 50).
  - Dark Mode: `bgDark` = `Color(0xFF0F172A)` (Slate 900 chuẩn M3 & OLED Deep Dark).
  - Deep Dark: `bgDarkDeep` = `Color(0xFF0B1320)` (OLED pure dark).
* **Bề mặt phân lớp (Surfaces & Cards)**:
  - Surface Light: `Colors.white` | Dark: `Color(0xFF1E293B)` (Slate 800) / `Color(0xFF243248)`.
  - Card Light: `Colors.white` | Dark: `Color(0xFF182234)`.
  - Input Light: `Color(0xFFF1F5F9)` | Dark: `Color(0xFF141E2E)`.
* **Đường viền & Phân tách (Borders & Dividers)**:
  - Light: `Color(0xFFE2E8F0)` (Slate 200).
  - Dark: `Color(0xFF334155)` (Slate 700 - Đạt chuẩn tương phản cạnh).
* **Ngữ nghĩa tài chính (Financial Semantics)**:
  - Thu nhập (Income): `Color(0xFF10B981)` (Green Emerald) / `Color(0xFF34D399)`.
  - Chi tiêu (Expense): `Color(0xFFEF4444)` (Coral Red) / `Color(0xFFF87171)`.
  - Cảnh báo (Warning): `Color(0xFFF59E0B)` (Amber).
  - Thông tin (Info): `Color(0xFF0EA5E9)` (Azure).

### 1.2. Dark / Light Mode & ColorScheme
* `AppTheme.lightTheme`: Sử dụng `ColorScheme.light` chuẩn Material 3. Màu chữ chính `Color(0xFF0F172A)`, phụ `Color(0xFF475569)`.
* `AppTheme.darkTheme`: Sử dụng `ColorScheme.dark`. Màu chữ chính `Color(0xFFF8FAFC)` (Slate 50 - chuẩn WCAG AAA), phụ `Color(0xFF94A3B8)`.
* Cơ chế PageTransitions: Đồng bộ `CupertinoPageTransitionsBuilder` cho toàn bộ các nền tảng (Android, iOS, Windows, macOS, Linux).

### 1.3. Typography (Kiểu chữ)
* Hệ thống `TextTheme` được định nghĩa thủ công trong ThemeData với 11 bậc tỷ lệ:
  - `labelSmall` (12.0, w600), `labelMedium` (13.0, w600), `labelLarge` (14.5, w600)
  - `bodySmall` (13.0, w400), `bodyMedium` (15.0, w400), `bodyLarge` (16.5, w500)
  - `titleSmall` (15.5, w600), `titleMedium` (17.5, w700), `titleLarge` (20.5, bold)
  - `headlineSmall` (22.0, w800), `headlineMedium` (26.0, w800)
* **Vấn đề nhận diện**: Chưa khai báo `fontFamily` chung cấp Root (đang phụ thuộc vào font hệ điều hành mặc định thay vì Google Fonts đồng nhất như Inter/Outfit/Plus Jakarta Sans).

### 1.4. BorderRadius (Bo góc đồng bộ)
* Input Border: `16px` (`BorderRadius.circular(16)`).
* Card: `18px` (`BorderRadius.circular(18)`).
* Dialog: `24px` (`BorderRadius.circular(24)`).
* BottomSheet: `24px` bo cạnh trên (`BorderRadius.vertical(top: Radius.circular(24))`).
* Chip / Tag: `12px` (`BorderRadius.circular(12)`).

### 1.5. Shadows & Elevations
* Card: `elevation: 0` (thiết kế phẳng hiện đại dạng Flat/Outlined viền 1px).
* Dialog: `elevation: 8` (Light) / `12` (Dark) kèm border outline Slate 700.
* BottomSheet: `elevation: 10` (Light) / `12` (Dark).
* BottomNavigationBar: `elevation: 8` (Light) / `10` (Dark).

---

## 2. Đánh Giá Hiện Trạng Hardcode & Lệch Chuẩn UI

Qua quét tự động 65 tệp màn hình và thành phần giao diện, các vấn đề nổi cộm được phân loại như sau:

1. **Lạm dụng Color Hex & Material Colors trực tiếp**:
   - Rất nhiều màn hình chứa từ 50 đến hơn 400 vị trí hardcode `Color(0x...)` hoặc `Colors.white`, `Colors.black`, `Colors.grey`.
   - Các màn hình phức tạp nhất: `wallet_screen.dart` (416 hardcode), `ai_assistant_screen.dart` (377 hardcode), `mono_assistant_cards.dart` (283 hardcode), `wallet_history_screen.dart` (254 hardcode), `statistics_screen.dart` (225 hardcode).
2. **TextStyle cục bộ không liên kết TextTheme**:
   - Hầu hết các màn hình tự khai báo `TextStyle(fontSize: X, fontWeight: Y, color: Z)` trực tiếp thay vì kế thừa `Theme.of(context).textTheme.*`. Điều này gây phá vỡ tính nhất quán khi người dùng đổi cỡ chữ hoặc kích hoạt Dark Mode (màu chữ cố định có nguy cơ chìm vào nền).
3. **Màu sắc thẻ ví & biểu đồ chưa đóng gói thành Token**:
   - `wallet_screen.dart` tự định nghĩa mảng 28 mã màu palette tĩnh cho ngân hàng/ví điện tử thay vì trích xuất thành domain palette service chuyên biệt.

---

## 3. Bảng Chi Tiết UI Redesign Backlog

| ID | Tên Module | Đường dẫn File | Vấn đề UI hiện tại (Hardcode màu/Chưa đồng bộ) | Trạng thái |
|:---|:---|:---|:---|:---:|
| **UI-001** | `auth` | `lib/modules/auth/fingerprint_unlock_screen.dart` | 13 mã Color(0x...), 6 Colors.white/black, 4 TextStyle gán cứng; chỉ 1 lần dùng Theme.of(context) | Đã hoàn thành [x] |
| **UI-002** | `auth` | `lib/modules/auth/forgot_password_confirmation_screen.dart` | 27 mã Color(0x...), 11 Colors.white/black, 8 TextStyle gán cứng; ít phụ thuộc Theme | Đã hoàn thành [x] |
| **UI-003** | `auth` | `lib/modules/auth/forgot_password_screen.dart` | 26 mã Color(0x...), 9 Colors.white/black, 2 Colors.grey, 7 TextStyle thủ công | Đã hoàn thành [x] |
| **UI-004** | `auth` | `lib/modules/auth/login_screen.dart` | 51 mã Color(0x...), 8 Colors.white/black, 15 TextStyle gán cứng; tỷ lệ dùng Theme cực thấp (1 lần) | Đã hoàn thành [x] |
| **UI-005** | `auth` | `lib/modules/auth/register_screen.dart` | 51 mã Color(0x...), 10 Colors.white/black, 5 Colors.grey, 11 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-006** | `auth` | `lib/modules/auth/reset_password_screen.dart` | 36 mã Color(0x...), 8 Colors.white/black, 4 Colors.grey, 8 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-007** | `auth` | `lib/modules/auth/verify_email_screen.dart` | 20 mã Color(0x...), 12 Colors.white/black, 2 Colors.grey, 8 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-008** | `auth` | `lib/modules/auth/verify_password_screen.dart` | 9 mã Color(0x...), 10 Colors.white/black, 1 Colors.grey, 7 TextStyle thủ công | Đã hoàn thành [x] |
| **UI-009** | `home` | `lib/modules/home/category_statistics_screen.dart` | 14 mã Color(0x...), 23 Colors.white/black, 7 Colors.grey, 13 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-010** | `home` | `lib/modules/home/export_report_screen.dart` | 29 mã Color(0x...), 21 Colors.white/black, 1 Colors.grey, 14 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-011** | `home` | `lib/modules/home/home_screen.dart` | 32 mã Color(0x...), 32 Colors.white/black, 15 TextStyle gán cứng, nút Quick Action hardcode màu | Đã hoàn thành [x] |
| **UI-012** | `home` | `lib/modules/home/notification_detail_screen.dart` | 18 mã Color(0x...), 20 Colors.white/black, 9 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-013** | `home` | `lib/modules/home/notification_screen.dart` | 15 mã Color(0x...), 19 Colors.white/black, 4 Colors.grey, 8 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-014** | `home` | `lib/modules/home/statistics_screen.dart` | 114 mã Color(0x...), 85 Colors.white/black, 16 Colors.grey, 48 TextStyle gán cứng biểu đồ | Đã hoàn thành [x] |
| **UI-015** | `home` | `lib/modules/home/wallet_screen.dart` | 141 mã Color(0x...), 118 Colors.white/black, 84 TextStyle gán cứng; bảng palette 28 màu ví cứng | Cần đại tu (Cao) |
| **UI-016** | `transaction` | `lib/modules/transaction/add_transaction_screen.dart` | 110 mã Color(0x...), 49 Colors.white/black, 8 Colors.grey, 26 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-017** | `transaction` | `lib/modules/transaction/all_transactions_screen.dart` | 69 mã Color(0x...), 87 Colors.white/black, 4 Colors.grey, 30 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-018** | `transaction` | `lib/modules/transaction/category_screen.dart` | 65 mã Color(0x...), 40 Colors.white/black, 17 Colors.grey, 30 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-019** | `transaction` | `lib/modules/transaction/edit_transaction_screen.dart` | 83 mã Color(0x...), 67 Colors.white/black, 15 Colors.grey, 32 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-020** | `transaction` | `lib/modules/transaction/transaction_detail_screen.dart` | 41 mã Color(0x...), 16 Colors.white/black, 17 TextStyle gán cứng, 3 Theme.of(context) | Đã hoàn thành [x] |
| **UI-021** | `transaction` | `lib/modules/transaction/transaction_gallery_screen.dart` | 26 mã Color(0x...), 24 Colors.white/black, 3 Colors.grey, 11 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-022** | `transaction` | `lib/modules/transaction/transaction_photo_detail_screen.dart` | 11 mã Color(0x...), 29 Colors.white/black, 10 TextStyle; hoàn toàn không dùng Theme | Đã hoàn thành [x] |
| **UI-023** | `transaction` | `lib/modules/transaction/widgets/amount_suggestion_bar.dart` | 4 mã Color(0x...), 3 Colors.white/black, 2 TextStyle; không kết nối Theme | Đã hoàn thành [x] |
| **UI-024** | `transaction` | `lib/modules/transaction/widgets/category_keyword_suggestions.dart` | 7 mã Color(0x...), 1 Colors.white/black, 2 TextStyle; không kết nối Theme | Đã hoàn thành [x] |
| **UI-025** | `transaction` | `lib/modules/transaction/widgets/fintech_keypad.dart` | 7 mã Color(0x...), 2 Colors.white/black, 2 TextStyle; bàn phím số màu cố định | Đã hoàn thành [x] |
| **UI-026** | `budget` | `lib/modules/budget/add_budget_dialog.dart` | 35 mã Color(0x...), 2 Colors.white/black, 11 TextStyle gán cứng, dialog gán cứng nền | Đã hoàn thành [x] |
| **UI-027** | `budget` | `lib/modules/budget/add_goal_dialog.dart` | 47 mã Color(0x...), 3 Colors.white/black, 2 Colors.grey, 17 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-028** | `budget` | `lib/modules/budget/budget_and_goals_screen.dart` | 58 mã Color(0x...), 39 Colors.white/black, 10 Colors.grey, 28 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-029** | `calendar` | `lib/modules/calendar/calendar_tracking_screen.dart` | 36 mã Color(0x...), 30 Colors.white/black, 2 Colors.grey, 12 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-030** | `group_expense` | `lib/features/group_expense/presentation/screens/create_expense_screen.dart` | 13 mã Color(0x...), 9 Colors.white/black, 3 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-031** | `group_expense` | `lib/features/group_expense/presentation/screens/create_group_screen.dart` | 15 mã Color(0x...), 8 Colors.white/black, 17 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-032** | `group_expense` | `lib/features/group_expense/presentation/screens/group_all_transactions_screen.dart` | 32 mã Color(0x...), 21 Colors.white/black, 1 Colors.grey, 21 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-033** | `group_expense` | `lib/features/group_expense/presentation/screens/group_detail_screen.dart` | 31 mã Color(0x...), 27 Colors.white/black, 30 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-034** | `group_expense` | `lib/features/group_expense/presentation/screens/group_expense_statistics_screen.dart` | 8 mã Color(0x...), 40 Colors.white/black, 4 Colors.grey, 17 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-035** | `group_expense` | `lib/features/group_expense/presentation/screens/group_list_screen.dart` | 22 mã Color(0x...), 23 Colors.white/black, 25 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-036** | `group_expense` | `lib/features/group_expense/presentation/screens/group_members_screen.dart` | 11 mã Color(0x...), 4 Colors.white/black, 12 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-037** | `group_expense` | `lib/features/group_expense/presentation/screens/invite_member_screen.dart` | 39 mã Color(0x...), 10 Colors.white/black, 19 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-038** | `group_expense` | `lib/features/group_expense/presentation/screens/join_group_screen.dart` | 7 mã Color(0x...), 30 Colors.white/black, 19 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-039** | `group_expense` | `lib/features/group_expense/presentation/screens/settlement_confirm_screen.dart` | 4 mã Color(0x...), 15 Colors.white/black, 6 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-040** | `ai_assistant` | `lib/modules/ai_assistant/ai_assistant_screen.dart` | 169 mã Color(0x...), 134 Colors.white/black, 33 Colors.grey, 83 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-041** | `ai_assistant` | `lib/modules/ai_assistant/widgets/mono_assistant_cards.dart` | 171 mã Color(0x...), 83 Colors.white/black, 25 Colors.grey, 91 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-042** | `settings` | `lib/modules/settings/about_app_screen.dart` | 44 mã Color(0x...), 25 Colors.white/black, 8 Colors.grey, 17 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-043** | `settings` | `lib/modules/settings/account_info_screen.dart` | 43 mã Color(0x...), 37 Colors.white/black, 6 Colors.grey, 18 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-044** | `settings` | `lib/modules/settings/active_devices_screen.dart` | 14 mã Color(0x...), 12 Colors.white/black, 4 Colors.grey, 11 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-045** | `settings` | `lib/modules/settings/ai_settings_screen.dart` | 54 mã Color(0x...), 34 Colors.white/black, 8 Colors.grey, 23 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-046** | `settings` | `lib/modules/settings/appearance_screen.dart` | 33 mã Color(0x...), 31 Colors.white/black, 5 Colors.grey, 16 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-047** | `settings` | `lib/modules/settings/avatar_crop_screen.dart` | 13 mã Color(0x...), 13 Colors.white/black, 5 TextStyle; thiếu kiểm tra Dark Mode | Đã hoàn thành [x] |
| **UI-048** | `settings` | `lib/modules/settings/biometric_screen.dart` | 30 mã Color(0x...), 15 Colors.white/black, 3 Colors.grey, 8 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-049** | `settings` | `lib/modules/settings/data_usage_screen.dart` | 9 mã Color(0x...), 5 Colors.white/black, 1 Colors.grey, 4 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-050** | `settings` | `lib/modules/settings/delete_confirmation_screen.dart` | 8 mã Color(0x...), 4 Colors.white/black, 5 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-051** | `settings` | `lib/modules/settings/delete_password_screen.dart` | 8 mã Color(0x...), 5 Colors.white/black, 1 Colors.grey, 7 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-052** | `settings` | `lib/modules/settings/language_screen.dart` | 6 mã Color(0x...), 7 Colors.white/black, 1 Colors.grey, 4 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-053** | `settings` | `lib/modules/settings/message_center_screen.dart` | 16 mã Color(0x...), 17 Colors.white/black, 4 Colors.grey, 8 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-054** | `settings` | `lib/modules/settings/message_detail_screen.dart` | 12 mã Color(0x...), 9 Colors.white/black, 5 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-055** | `settings` | `lib/modules/settings/notification_settings_screen.dart` | 29 mã Color(0x...), 18 Colors.white/black, 5 Colors.grey, 18 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-056** | `settings` | `lib/modules/settings/privacy_policy_screen.dart` | 23 mã Color(0x...), 8 Colors.white/black, 10 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-057** | `settings` | `lib/modules/settings/privacy_screen.dart` | 25 mã Color(0x...), 18 Colors.white/black, 9 Colors.grey, 15 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-058** | `settings` | `lib/modules/settings/profile_screen.dart` | 33 mã Color(0x...), 41 Colors.white/black, 1 Colors.grey, 16 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-059** | `settings` | `lib/modules/settings/security_screen.dart` | 22 mã Color(0x...), 16 Colors.white/black, 2 Colors.grey, 10 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-060** | `settings` | `lib/modules/settings/success_screen.dart` | 6 mã Color(0x...), 4 Colors.white/black, 4 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-061** | `settings` | `lib/modules/settings/support_request_screen.dart` | 11 mã Color(0x...), 5 Colors.white/black, 1 Colors.grey, 8 TextStyle gán cứng | Đã hoàn thành [x] |
| **UI-062** | `settings` | `lib/modules/settings/widget_showcase_screen.dart` | 109 mã Color(0x...), 15 Colors.white/black, 44 TextStyle gán cứng; chỉ 1 Theme.of(context) | Đã hoàn thành [x] |
| **UI-063** | `wallet` | `lib/modules/wallet/wallet_history_screen.dart` | 136 mã Color(0x...), 87 Colors.white/black, 21 Colors.grey, 40 TextStyle gán cứng | Cần đại tu (Cao) |
| **UI-064** | `onboarding` | `lib/modules/onboarding/onboarding_screen.dart` | 25 mã Color(0x...), 11 Colors.white/black, 8 TextStyle gán cứng; gradient gán cứng | Đã hoàn thành [x] |
| **UI-065** | `splash` | `lib/modules/splash/splash_screen.dart` | 7 mã Color(0x...), 3 Colors.white/black, 2 TextStyle gán cứng | Đã hoàn thành [x] |

---

## 4. Danh Mục Thành Phần Dùng Chung (`lib/widgets/`) Cần Chuẩn Hóa

| Tên Widget | Đường dẫn File | Vấn đề UI Hiện tại | Đề xuất giải pháp |
|:---|:---|:---|:---|
| `VoiceInputBottomSheet` | `lib/widgets/voice_input_bottom_sheet.dart` | 110 màu hardcode, 32 TextStyle thủ công | Chuyển sang dùng `Theme.of(context).colorScheme` và `bottomSheetTheme` |
| `MonoDialog` | `lib/widgets/mono_dialog.dart` | 36 màu hardcode, 21 TextStyle | Chuẩn hóa theo `dialogTheme` và các token semantic |
| `UserAvatar` | `lib/widgets/user_avatar.dart` | 31 màu hardcode, 0 kết nối Theme | Dùng màu nền và viền từ `ColorScheme.surface` và `outline` |
| `MonoToast` | `lib/widgets/mono_toast.dart` | 20 màu hardcode, ít phụ thuộc Theme | Thống nhất với `AppColors` semantic (incomeGreen, expenseCoral, infoAzure) |
| `TransactionItem` | `lib/widgets/transaction_item.dart` | 20 màu hardcode, 28 TextStyle thủ công | Đồng bộ Typography và màu text qua `TextTheme` |
| `MonoLiquidGlassLogo` | `lib/widgets/mono_liquid_glass_logo.dart` | 17 màu gradient tĩnh | Duy trì specular reflection nhưng đưa các màu nền vào AppColors |
| `MonoBottomSheetContainer` | `lib/widgets/mono_bottom_sheet.dart` | 9 màu hardcode | Đồng bộ nền qua `Theme.of(context).bottomSheetTheme` |

---

## 5. Kế Hoạch Thực Hiện UI Redesign (Action Plan)

1. **Giai đoạn 1 - Nâng cấp Theme Core & Design Tokens**:
   - Bổ sung cấu hình `fontFamily` chuẩn (khuyến nghị Inter/Outfit) vào `AppTheme`.
   - Bổ sung các extension màu semantic: `context.colors`, `context.textTheme` để rút gọn cú pháp gọi trong màn hình.
   - Trích xuất bảng màu thẻ ví (Wallet Card Gradients) từ `wallet_screen.dart` vào `lib/core/theme/wallet_palette.dart`.

2. **Giai đoạn 2 - Chuẩn hóa các màn hình Core (Mức độ Cao)**:
   - Đại tu `wallet_screen.dart` & `wallet_history_screen.dart`.
   - Đại tu `statistics_screen.dart` & `category_statistics_screen.dart`.
   - Đại tu `ai_assistant_screen.dart` & `mono_assistant_cards.dart`.
   - Chuẩn hóa cụm màn hình giao dịch (`add_transaction_screen.dart`, `all_transactions_screen.dart`, `edit_transaction_screen.dart`).

3. **Giai đoạn 3 - Chuẩn hóa Module Phụ trợ & Group Expense**:
   - Chuẩn hóa cụm xác thực `auth` (`login_screen.dart`, `register_screen.dart`, v.v.).
   - Chuẩn hóa module `group_expense` theo đúng token theme M3.
   - Rà soát toàn bộ các màn hình `settings`.

4. **Giai đoạn 4 - Kiểm thử & Đảm bảo chuẩn Contrast WCAG AAA**:
   - Chạy test giao diện trên cả Light Mode và Dark Mode thực tế để loại trừ hoàn toàn tình trạng chữ mờ hoặc tương phản kém.
