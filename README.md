# Money Tracker App (Quản Lý Thu Chi Cá Nhân & Nhóm)

Ứng dụng di động theo dõi và quản lý tài chính thông minh trên nền tảng **Flutter**, tích hợp trợ lý AI, quản lý ngân sách, phân bổ chi tiêu nhóm và đồng bộ hóa đám mây đa thiết bị.

---

## Tính Năng Nổi Bật

### 1. Quản lý Thu/Chi & Đa Ví
- Quản lý nhiều nguồn tiền: Tiền mặt, Tài khoản ngân hàng, Ví điện tử (Momo, ZaloPay,...).
- Ghi chép giao dịch nhanh chóng với đầy đủ thông tin: số tiền, danh mục, thời gian, hình ảnh hóa đơn, địa điểm và ghi chú.
- Chuyển tiền qua lại giữa các ví (Transfer) với kiểm tra biến động số dư chặt chẽ.
- Tự động theo dõi giao dịch định kỳ (lương hàng tháng, tiền trọ, hóa đơn tiện ích,...).

### 2. Ngân Sách (Budget) & Mục Tiêu Tiết Kiệm (Savings Goals)
- Thiết lập ngân sách chi tiêu theo danh mục (Ăn uống, Mua sắm, Di chuyển,...) theo tháng hoặc tùy chọn kỳ hạn.
- Hệ thống theo dõi trực quan và cảnh báo mức chi tiêu vượt ngưỡng (80%, 100%).
- Tạo mục tiêu tiết kiệm, theo dõi tiến độ nạp tiền và ngày hoàn thành dự kiến.

### 3. Chia Sẻ Chi Tiêu Nhóm (Group Expenses)
- Tạo nhóm chi tiêu cho gia đình, chuyến du lịch hoặc bạn cùng phòng.
- Tự động tính toán chia đều (split bill) hoặc theo phần trăm/số tiền thực tế.
- Báo cáo số dư nợ và đề xuất chuyển khoản quyết toán tối ưu số lượt giao dịch.

### 4. Báo Cáo & Phân Tích Thống Kê
- Biểu đồ trực quan: hình tròn (Pie chart), cột (Bar chart), đường xu hướng (Trend line) hỗ trợ bởi `fl_chart`.
- Xem phân tích theo tuần, tháng, quý, năm hoặc khoảng thời gian tùy chỉnh.
- Xuất báo cáo tài chính chuyên nghiệp định dạng **PDF**, **Excel (.xlsx)** hoặc **CSV**.

### 5. Tiện Ích Thông Minh & AI
- **Trợ lý tài chính AI (Google Gemini & Local Qwen)**: Phân tích thói quen tiêu dùng, gợi ý tối ưu ngân sách và giải đáp thắc mắc tài chính.
- **Nhập liệu bằng giọng nói (Voice Input)**: Nói câu lệnh tự nhiên để tạo giao dịch (ví dụ: *"Ăn trưa 45 nghìn ví tiền mặt"*).
- **Quét hóa đơn (Receipt OCR)**: Tự động trích xuất số tiền, ngày tháng và nội dung từ ảnh chụp hóa đơn.
- **Đọc SMS biến động số dư ngân hàng (Bank SMS Parser)**: Hỗ trợ cú pháp SMS của các ngân hàng phổ biến tại Việt Nam (Vietcombank, Techcombank, MB, BIDV, VPBank, ACB,...).

### 6. Bảo Mật & Dữ Liệu
- Khóa bảo mật bằng sinh trắc học: Vân tay / Face ID qua `local_auth`.
- Lưu trữ an toàn thông tin đăng nhập với `flutter_secure_storage`.
- Hoạt động mượt mà cả khi offline qua SQLite / Hive, tự động đồng bộ lên Firebase Cloud Firestore khi có mạng.

---

## Công Nghệ Sử Dụng

- **Framework**: Flutter (Dart SDK ^3.10.7)
- **State Management**: Flutter Riverpod & Provider
- **Backend & Cloud**: Firebase Core, Firebase Auth, Cloud Firestore, Firebase Storage, Firebase Messaging (FCM)
- **Cơ sở dữ liệu cục bộ**: SQLite (`sqflite`), Hive
- **Biểu đồ & Giao diện**: `fl_chart`, Custom Micro-animations, Dark/Light Theme
- **Bảo mật**: `local_auth`, `flutter_secure_storage`, `crypto`
- **Xử lý tập tin & Báo cáo**: `excel`, `pdf`, `csv`, `printing`, `share_plus`
- **Trí tuệ nhân tạo**: Google Gemini AI API, Local LLM integration

---

## Cấu Trúc Dự Án

```text
lib/
├── core/                  # Cấu hình cốt lõi, constants, theme, api keys template
├── data/
│   ├── local/             # Cơ sở dữ liệu SQLite & bảng cục bộ
│   ├── models/            # Model dữ liệu chuyển đổi
│   └── repositories/      # Các Repository xử lý logic nghiệp vụ & truy xuất dữ liệu
├── features/
│   └── group_expense/     # Tính năng quản lý chi tiêu nhóm
├── models/                # Thực thể dữ liệu (Wallet, Transaction, Budget, Goal,...)
├── modules/               # Màn hình theo phân hệ chức năng
│   ├── ai_assistant/      # Trợ lý AI và hội thoại tài chính
│   ├── auth/              # Đăng ký, đăng nhập, quên mật khẩu
│   ├── budget/            # Quản lý ngân sách & mục tiêu
│   ├── calendar/          # Theo dõi giao dịch theo lịch
│   ├── home/              # Màn hình chính, ví, báo cáo thống kê
│   ├── settings/          # Cài đặt cá nhân, bảo mật, thiết bị, giao diện
│   └── transaction/       # Thêm, sửa, xoá, chi tiết giao dịch
├── services/              # Dịch vụ nền tảng (AI, SMS, Sync, Notification, Voice,...)
├── utils/                 # Tiện ích định dạng tiền tệ, ngày tháng, danh mục
└── widgets/               # Thành phần UI tái sử dụng
```

---

## Hướng Dẫn Cài Đặt & Chạy Ứng Dụng

### Yêu Cầu Môi Trường
- Flutter SDK 3.10 trở lên.
- Android Studio / VS Code với Dart & Flutter extensions.
- Máy ảo Android / iOS hoặc thiết bị thật kết nối qua USB Debugging.

### Các Bước Thực Hiện

1. **Clone repository về máy**:
   ```bash
   git clone <URL_REPOSITORY>
   cd money_tracker_app
   ```

2. **Cài đặt các thư viện phụ thuộc**:
   ```bash
   flutter pub get
   ```

3. **Cấu hình API Key (Google Gemini AI)**:
   - Tạo file `lib/core/constants/api_keys.dart` bằng cách sao chép từ file mẫu `lib/core/constants/api_keys.example.dart`:
     ```bash
     cp lib/core/constants/api_keys.example.dart lib/core/constants/api_keys.dart
     ```
   - Lấy API Key miễn phí tại [Google AI Studio](https://aistudio.google.com/).
   - Điền key vào biến `defaultGeminiApiKey` trong file `lib/core/constants/api_keys.dart`.

4. **Chạy kiểm tra dự án (Analyze & Tests)**:
   ```bash
   flutter analyze
   flutter test
   ```

5. **Chạy ứng dụng**:
   ```bash
   flutter run
   ```

---

## Chính Sách Bảo Mật & Đóng Góp
- Tuyệt đối không commit các file chứa secret: `.env`, `api_keys.dart`, `google-services.json` cá nhân lên Git.
- Mọi đóng góp xin vui lòng tạo branch riêng và gửi Pull Request để được review.
