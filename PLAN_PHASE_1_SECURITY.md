# GIAI ĐOẠN 1: KIỂM SOÁT CÁC RỦI RO NGHIÊM TRỌNG (CRITICAL SECURITY & ARCHITECTURE REMEDIATION)

**Vai trò:** Principal Security & Firebase/Flutter Architect  
**Dự án:** Mono Money Tracker (`money_tracker_app`)  
**Tài liệu:** Kế hoạch rà soát kiến trúc & khắc phục lỗ hổng bảo mật — Giai đoạn 1  
**Ngày lập:** 27/10/2026  
**Trạng thái:** DRAFTING / READY FOR IMPLEMENTATION (Tuyệt đối chưa sửa mã nguồn ở bước này)

---

## 1. TỔNG QUAN & MA TRẬN MỐI ĐE DỌA (THREAT MODEL & EXECUTIVE SUMMARY)

Qua quá trình rà soát toàn diện mã nguồn tại các phân hệ cốt lõi (`@lib/core/`, `@lib/services/`, `@lib/data/`, `@lib/features/group_expense/`, `pubspec.yaml`, `android/`, `firestore.rules`, `storage.rules`), hệ thống hiện tồn tại **4 nhóm lỗ hổng bảo mật nghiêm trọng (P0/Critical)** có thể dẫn tới lộ lọt thông tin xác thực, giả mạo dữ liệu tài chính, chiếm đoạt quỹ nhóm và rò rỉ dữ liệu cá nhân giữa các tài khoản khi dùng chung thiết bị.

### Ma trận Rủi ro & Tác động (Risk Matrix)

| ID | Nhóm Rủi Ro | Điểm CVSS v3.1 | Mức Độ | Tác Động Tiềm Tàng |
| :--- | :--- | :---: | :---: | :--- |
| **SEC-01** | **Lộ lọt SMTP & Gemini Credentials trong Client Bundle** | **9.8 (Critical)** | **P0** | Trích xuất APK/AAB thu được Gmail App Password và Gemini API Key trong 30 giây. Kẻ tấn công có thể spam email lừa đảo hoặc lạm dụng hạn ngạch AI. |
| **SEC-02** | **Cơ chế OTP & Reset Password Insecure Client-Side** | **8.6 (High)** | **P0** | Sinh mã OTP trên client, ghi trực tiếp vào `otp_codes` và lưu mật khẩu thô mới vào `password_resets` trên Firestore không qua phân quyền chặt chẽ. |
| **SEC-03** | **Lỗ hổng Phân quyền Firestore (Quỹ nhóm & User Profile)** | **8.8 (High)** | **P0** | Thành viên tự xóa nợ (`debts`), tự xóa mình khỏi nhóm khi còn nợ, conflict `ownerId` chặn tạo nhóm; thiếu phân quyền subcollection `users/{uid}`. |
| **SEC-04** | **Rò rỉ chéo UID khi đổi tài khoản & Xóa dữ liệu lỗi** | **7.5 (High)** | **P1** | Đổi tài khoản có nguy cơ đẩy nhầm queue; `DestructiveOpsGuard` chặn xóa dữ liệu SQLite ở bản Release làm lộ thông tin tài chính cũ; thiếu Snapshot trước Migration. |

---

## 2. PHÁT HIỆN CHI TIẾT & ĐÁNH GIÁ KIẾN TRÚC (DEEP-DIVE FINDINGS)

### 2.1. Rà soát Khóa & Thông tin Xác thực (Secrets & Credentials Audit)

#### Phát hiện 1: Đóng gói file `.env` trực tiếp vào tài nguyên ứng dụng (Assets)
* **Vị trí:** `pubspec.yaml` (dòng 113–115), file `.env` ở thư mục gốc.
* **Hiện trạng mã nguồn:**
  ```yaml
  # pubspec.yaml
  flutter:
    assets:
      - assets/images/
      - .env
  ```
  ```env
  # .env
  SMTP_SENDER_EMAIL=[REDACTED_EMAIL]
  SMTP_APP_PASSWORD=[REDACTED_APP_PASSWORD]
  SMTP_SENDER_NAME=Mono App
  ```
* **Đánh giá rủi ro (CRITICAL):**
  - Mặc dù `.env` đã được cấu hình trong `.gitignore`, việc khai báo `- .env` trong `pubspec.yaml` khiến Flutter SDK biên dịch đóng gói nguyên vẹn file `.env` vào thư mục `assets/flutter_assets/.env` bên trong file APK/AAB hoặc IPA.
  - Bất kỳ ai tải file APK từ thiết bị hoặc cửa hàng ứng dụng đều có thể dùng lệnh `unzip app-release.apk` để đọc toàn bộ `SMTP_SENDER_EMAIL` và `SMTP_APP_PASSWORD` dạng Plaintext.
  - Kẻ tấn công có quyền kiểm soát hoàn toàn tài khoản gửi thư, gửi thư mạo danh ngân hàng/ứng dụng hoặc khai thác hộp thư cá nhân của chủ tài khoản.

#### Phát hiện 2: Hardcode Gemini API Key trong Client Source Code
* **Vị trí:** `lib/core/constants/api_keys.dart` (dòng 5–6).
* **Hiện trạng mã nguồn:**
  ```dart
  class ApiKeys {
    static const String defaultGeminiApiKey =
        '[REDACTED_GEMINI_API_KEY]';
  }
  ```
* **Đánh giá rủi ro (HIGH):**
  - Khóa API Gemini bị hardcode trực tiếp trong mã nguồn Dart. Mặc dù file nằm trong `.gitignore`, giá trị này được nhúng trực tiếp vào binary `libapp.so` của Flutter khi build Release, dễ dàng bị trích xuất bằng lệnh `strings libapp.so | grep -E "AIza|AQ\."`.
  - Hậu quả: Kẻ tấn công cạn kiệt quota API Google AI Studio, gây từ chối dịch vụ (DoS) tính năng AI Assistant của người dùng hợp lệ hoặc phát sinh chi phí thanh toán ngoài ý muốn.

#### Phát hiện 3: Vô hiệu hóa kiểm tra xác thực ứng dụng ở môi trường Production
* **Vị trí:** `lib/main.dart` (dòng 99–101).
* **Hiện trạng mã nguồn:**
  ```dart
  await FirebaseAuth.instance.setSettings(
    appVerificationDisabledForTesting: true,
  );
  ```
* **Đánh giá rủi ro (HIGH):**
  - Lệnh `appVerificationDisabledForTesting: true` vô hiệu hóa reCAPTCHA / Play Integrity / DeviceCheck của Firebase Auth trong luồng runtime của ứng dụng.
  - Kẻ tấn công có thể dựng script spam đăng ký, brute-force OTP qua SMS hoặc vượt qua các bước kiểm tra an toàn của Firebase Auth.

#### Phát hiện 4: Lưu mật khẩu dạng rõ (Plaintext) trên Firestore và FlutterSecureStorage
* **Vị trí:** `lib/services/auth_service.dart` (dòng 184, 534, 783–788).
* **Hiện trạng mã nguồn:**
  ```dart
  // Luu mat khau moi tam thoi vao Firestore
  await _firestore.collection('password_resets').doc(email.trim()).set({
    'email': email.trim(),
    'newPassword': newPassword, // <-- MẬT KHẨU RÕ TRÊN FIRESTORE!
    'createdAt': DateTime.now(),
    'expiresAt': DateTime.now().add(const Duration(hours: 1)),
  });

  // Lưu mật khẩu rõ vào SecureStorage
  await _secureStorage.write(key: 'last_auth_password', value: password);
  ```
* **Đánh giá rủi ro (CRITICAL):**
  - Mật khẩu người dùng được gửi lên Firestore trong collection `password_resets` dưới dạng Plaintext không mã hóa băm (hashing). Nếu Security Rules bị hở hoặc người dùng bị xem màn hình mạng, mật khẩu bị lộ hoàn toàn.
  - Phá vỡ nguyên tắc Zero-Knowledge Architecture và tiêu chuẩn OWASP Mobile Top 10 (M2: Insecure Data Storage).

---

### 2.2. Xử lý triệt để SMTP/Email Service (`lib/services/email_service.dart`)

#### 1. Đánh giá bản chất luồng gửi Email hiện tại
* Ứng dụng hiện đang sử dụng thư viện `mailer: ^7.1.0` kết nối trực tiếp giao thức SMTP qua cổng 465/587 tới máy chủ Google (`smtp.gmail.com`) thông qua lớp `EmailService`.
* `EmailConfig.fromEnv()` đọc credentials từ `dotenv.env` (gói `.env`).
* Luồng nghiệp vụ gửi OTP (`sendOTP`) trong `auth_service.dart`:
  1. Client tự sinh ngẫu nhiên số 6 chữ số: `(100000 + Random().nextInt(900000)).toString()`.
  2. Client tự ghi mã này lên collection `otp_codes/{email}`.
  3. Client gọi `EmailService.sendOTPEmail` để chuyển phát qua SMTP.
  4. Xác thực OTP: Client tự đọc `otp_codes/{email}` và so sánh chuỗi.

#### 2. So sánh các Phương án Kiến trúc Thay thế

| Tiêu chí Đánh giá | Phương án A: Firebase Auth Native SDK (Khuyến nghị) | Phương án B: Cloud Functions + Secret Manager + Provider (Resend/SendGrid) | Phương án C: Tiếp tục giữ SMTP Client (Hiện tại) |
| :--- | :--- | :--- | :--- |
| **Bảo mật Credentials** | **Tuyệt đối** (Không cần quản lý bất kỳ secret/password nào trên client hay server) | **Rất cao** (Secret lưu trữ tại Google Secret Manager, gọi qua Callable Function có App Check) | **Nguy hiểm cực độ** (Credentials bị trích xuất từ APK/AAB) |
| **Chi phí vận hành** | **Miễn phí 100%** trong hạn ngạch Firebase Auth | Yêu cầu tài khoản Blaze Plan (Pay-as-you-go) cho Cloud Functions | Miễn phí tài khoản cá nhân nhưng bị Google khóa tài khoản khi vượt quota SMTP |
| **Độ tin cậy gửi thư** | Hạ tầng Google Deliverability chuẩn quốc tế, không rơi vào thư mục Spam | Rất cao với Domain Verified (SPF, DKIM, DMARC) | Dễ bị Gmail chặn do cơ chế chống spam khi gửi liên tục từ nhiều IP client |
| **Độ phức tạp mã nguồn** | **Tối giản**: Đã có sẵn giao diện và hàm `sendEmailVerification()`, `sendPasswordResetEmail()` | Trung bình: Cần viết TypeScript function, cấu hình IAM, deploy backend | Phức tạp: Phụ thuộc vào `mailer`, `flutter_dotenv`, `smtp_server` |

#### 3. Kết luận Kiến trúc cho Giai đoạn 1:
1. **Loại bỏ hoàn toàn SMTP Client:**
   - Xóa bỏ package `mailer` khỏi `pubspec.yaml`.
   - Xóa dòng `- .env` khỏi mục `assets:` trong `pubspec.yaml`.
   - Xóa bỏ package `flutter_dotenv` (hoặc chỉ dùng nếu có biến không nhạy cảm).
   - Xóa file `lib/services/email_service.dart` và `lib/core/config/email_config.dart`.
2. **Quy chuẩn hóa 100% luồng Email xác thực sang Firebase Auth Native:**
   - **Xác thực Email (Email Verification):** Sử dụng `FirebaseAuth.instance.currentUser?.sendEmailVerification()` (Trang `verify_email_screen.dart` đã tích hợp sẵn).
   - **Quên / Đặt lại mật khẩu (Password Reset):** Sử dụng `FirebaseAuth.instance.sendPasswordResetEmail(email: email)` (Trang `forgot_password_screen.dart` đã tích hợp sẵn).
   - **Loại bỏ hoàn toàn luồng tự chế OTP:** Xóa `sendOTP`, `verifyOTP`, bỏ việc đọc/ghi collection `otp_codes` và `password_resets` trên client.

---

### 2.3. Rà soát & Tái cấu trúc Firestore Security Rules (`firestore.rules`)

#### 1. Lỗ hổng tại `users/{userId}` và Subcollections
* **Hiện trạng:**
  ```rules
  match /users/{userId} {
    allow read:   if signedIn() && uid() == userId;
    allow create: if signedIn() && uid() == userId
                  && incoming().get('uid', userId) == userId
                  && incoming().get('role', 'user') == 'user'
                  && incoming().get('accountType', 'FREE') == 'FREE';
    allow update: if signedIn() && uid() == userId
                  && incoming().get('uid', userId) == userId
                  && keepsValue('role', 'user')
                  && keepsValue('accountType', 'FREE');
    allow delete: if signedIn() && uid() == userId;
  }
  ```
* **Lỗ hổng phân tích:**
  - `match /users/{userId}` **không có quy tắc đệ quy hoặc subcollection**. Nếu client lưu dữ liệu phân mảnh (ví dụ: `users/{userId}/tokens/{tokenId}`, `users/{userId}/settings/{settingId}`), các tài liệu này sẽ rơi vào rule mặc định `match /{document=**} { allow read, write: if false; }` gây lỗi hoặc nếu mở wildcard thì bị rò rỉ.
  - Thao tác `update` chưa khóa bất biến các trường định danh gốc như: `id`, `createdAt`, `email`.

#### 2. Lỗ hổng nghiêm trọng tại Phân hệ Quỹ Nhóm (`groups/{groupId}`)
* **Xung đột trường định danh `ownerId` vs `adminId` gây lỗi tạo nhóm:**
  - Trong `GroupModel.toJson()`:
    ```dart
    'ownerId': ownerId,
    'adminId': ownerId,
    ```
  - Trong `firestore.rules` hiện tại:
    ```rules
    allow create: if signedIn()
      && ...
      && !ng().keys().hasAny(['ownerId', 'role', 'roles', 'memberRoles']);
    ```
    Rule cấm sự tồn tại của key `'ownerId'`, dẫn tới việc tạo nhóm từ `GroupModel` bị từ chối quyền (Permission Denied). Cần đồng bộ hóa để hỗ trợ cả 2 trường hoặc chuẩn hóa thống nhất theo kiến trúc thực tế.
* **Quyền sửa/xóa công nợ (`debts`) bị lỏng lẻo:**
  - Hiện tại:
    ```rules
    match /debts/{debtId} {
      allow update: if isMemberOf(existing().groupId)
        && changedKeys().hasOnly(['amount', 'status', 'updatedAt']) ...
      allow delete: if isMemberOf(existing().groupId);
    }
    ```
    Bất kỳ thành viên nào trong nhóm (bao gồm người đang nợ `debtorId`) cũng có thể gửi lệnh `update` để sửa `amount = 0` hoặc gọi trực tiếp `.delete()` tài liệu nợ của chính mình mà không cần người chủ nợ (`creditorId`) xác nhận!
* **Thành viên tự rời nhóm (`memberLeaves`) trốn nợ:**
  - Rule hiện tại cho phép thành viên tự xóa UID của mình khỏi `memberIds` mà không có ràng buộc kiểm tra xem người này có đang nợ tiền trong nhóm hay không.
* **Lệch tên Collection giữa SQLite và Firestore:**
  - SQLite sử dụng: `group_expenses`, `group_settlements`.
  - Firestore Rules hiện tại chỉ định nghĩa: `/expenses/{expenseId}`, `/settlements/{settlementId}`.
  - Khi `SyncService` tải các bản ghi có `tableName = 'group_expenses'` từ `sync_queue`, nó cố gắng ghi vào collection `group_expenses` trên Firestore và bị `match /{document=**} { allow read, write: if false; }` chặn hoàn toàn, đẩy hàng loạt bản ghi vào Dead-Letter Queue.
* **Cần hỗ trợ cấu trúc Subcollections lồng nhau cho Quỹ nhóm:**
  - Để hỗ trợ mở rộng kiến trúc dữ liệu phân cấp: `groups/{groupId}/expenses/{expenseId}`, `groups/{groupId}/members/{memberId}`, `groups/{groupId}/settlements/{settlementId}`, `groups/{groupId}/funds/{txId}` cần được định nghĩa quy tắc kiểm soát truy cập đồng bộ với cấu trúc root collections.

#### 3. Bất biến các trường định danh sở hữu (`Immutable Identity Fields`)
Quy tắc bảo mật bắt buộc: Mọi thao tác `update` trên Firestore phải kiểm tra tính bất biến của các trường định danh chủ sở hữu:
- `request.resource.data.userId == resource.data.userId`
- `request.resource.data.uid == resource.data.uid`
- `request.resource.data.ownerId == resource.data.ownerId`
- `request.resource.data.createdBy == resource.data.createdBy`
- `request.resource.data.groupId == resource.data.groupId`
- `request.resource.data.debtorId == resource.data.debtorId`
- `request.resource.data.creditorId == resource.data.creditorId`
- `request.resource.data.payerId == resource.data.payerId`
- `request.resource.data.payeeId == resource.data.payeeId`

---

### 2.4. Kiểm tra UID khi Đồng bộ & Xóa dữ liệu (@lib/services/ & @lib/data/local/)

#### 1. Rủi ro trộn lẫn dữ liệu khi chuyển đổi tài khoản (Account Switching Risk)
* **Kịch bản rủi ro:**
  1. Người dùng A đăng nhập, sử dụng chế độ ngoại tuyến (Offline), tạo giao dịch cá nhân. Các giao dịch này được lưu vào SQLite bảng `transactions` với `uid = uidA` và ghi vào `sync_queue` với `ownerUid = uidA`.
  2. Người dùng A đăng xuất. Theo nguyên tắc I5 trong `AuthService`: Dữ liệu SQLite không bị xóa để hỗ trợ đăng nhập lại ngoại tuyến.
  3. Người dùng B đăng nhập trên cùng thiết bị này. `SessionManager.instance.activate(uidB)` được kích hoạt.
  4. `SyncService().syncAll()` được kích hoạt để đẩy hàng đợi.
* **Phân tích cơ chế an toàn hiện có & Lỗ hổng còn sót lại:**
  - *Điểm tốt:* `SyncService._processUploadQueue` đã có điều kiện lọc `where: "(ownerUid = ? OR uid = ?) AND status = 'pending'"` với đối số là `ownerUid = session.uidOrNull` (tức `uidB`). Do đó, bản ghi của A (`ownerUid = uidA`) sẽ không bị B đọc để đẩy lên.
  - *Lỗ hổng 1:* Phương thức `_uploadSingleItem` khi xử lý `SOFT_DELETE`/`DELETE` đang gán cứng trường:
    ```dart
    await collection.doc(recordId).set({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'uid': ownerUid, // <-- NGUY HIỂM: Gán đè UID sở hữu!
    }, SetOptions(merge: true));
    ```
    Nếu bản ghi bị xóa thuộc bảng Quỹ nhóm (`groups`, `expenses`, `settlements`) vốn dùng `ownerId`, `createdBy`, `payerId`, việc tự tiện chèn thêm trường `'uid': ownerUid` sẽ làm biến dạng schema và vi phạm Security Rules.
  - *Lỗ hổng 2:* Kiểm tra UID mismatch trong hàng đợi chỉ áp dụng cho trường `uid`:
    ```dart
    if (data != null && data.containsKey('uid') && data['uid'] != ownerUid) {
      await _markQueue(db, qid, ownerUid, status: 'quarantined', error: 'uid_mismatch');
      continue;
    }
    ```
    Nếu bản ghi thuộc bảng nhóm có chứa `createdBy` hoặc `ownerId` mà lệch với phiên hiện tại thì không được phát hiện, có thể dẫn đến việc upload chéo dữ liệu nhóm.
  - *Lỗ hổng 3:* Các Repository nhóm SQLite (`SqliteGroupRepository`, `SqliteExpenseRepository`, `SqliteSettlementRepository`) chưa hề kết nối với `SessionManager.instance.changes` hay `OwnedTableOps`. Một số phương thức như `getById` đọc thẳng bản ghi theo `id` mà không thẩm tra `userId` của phiên hiện tại có thuộc nhóm đó hay không.

#### 2. Lỗ hổng nghiêm trọng trong Logic Xóa Tài khoản (`clearUserData`)
* **Vị trí:** `lib/data/local/database_helper.dart` (dòng 1192–1220) và `lib/services/auth_service.dart` (dòng 872–874).
* **Hiện trạng mã nguồn:**
  ```dart
  // database_helper.dart
  Future<void> clearUserData(String uid) async {
    DestructiveOpsGuard.ensureEnabled('clearUserData'); // <-- LỖI TẠI ĐÂY!
    ...
  }

  // destructive_ops_guard.dart
  class DestructiveOpsGuard {
    static const bool _flag = bool.fromEnvironment('ENABLE_DESTRUCTIVE_OPS');
    static bool get enabled => kDebugMode && _flag;

    static void ensureEnabled(String op) {
      if (!enabled) {
        throw BusinessException(
          BusinessErrorCode.destructiveOpDisabled,
          '$op đã bị khóa ở bản phát hành',
        );
      }
    }
  }

  // auth_service.dart
  try {
    await DatabaseHelper().clearUserData(uid);
  } catch (_) {} // <-- Nuốt ngoại lệ!
  ```
* **Đánh giá rủi ro (CRITICAL PRIVACY BUG):**
  - Trong bản phát hành thực tế (Release Mode, `kDebugMode == false`), `DestructiveOpsGuard.enabled` **LUÔN LUÔN BẰNG FALSE**.
  - Khi người dùng chọn "Xóa tài khoản" (`deleteAccount`), hàm `clearUserData(uid)` ném ra ngoại lệ `BusinessException(destructiveOpDisabled)`.
  - Khối `try ... catch (_)` trong `auth_service.dart` đã âm thầm nuốt ngoại lệ này.
  - **Hậu quả:** Tài khoản Firebase Auth bị xóa, nhưng **toàn bộ dữ liệu SQLite trên máy của người dùng (giao dịch, ví, ngân sách, tin nhắn, nhật ký thiết bị) KHÔNG HỀ BỊ XÓA**! Bất kỳ ai cầm điện thoại hoặc tài khoản mới đăng nhập vào đều có thể nhìn thấy dữ liệu cũ còn sót lại.

#### 3. Thiếu Cơ chế Sao lưu An toàn (Snapshot / Safe Backup) trước Migration
* **Hiện trạng:**
  - Trong `database_helper.dart`, hàm `_onUpgrade` thực hiện các thao tác phá hủy bảng cũ:
    ```sql
    DROP TABLE wallets;
    DROP TABLE transactions;
    DROP TABLE budgets;
    DROP TABLE goals;
    ```
  - Quá trình này không hề tạo bản sao lưu snapshot file database cục bộ (`.bak`) trước khi chạy DDL.
  - Nếu thiết bị hết pin, ứng dụng bị hệ điều hành tắt (kill process) hoặc xảy ra lỗi ràng buộc dữ liệu giữa chừng, toàn bộ cơ sở dữ liệu SQLite sẽ bị hỏng vĩnh viễn, người dùng mất sạch dữ liệu offline chưa kịp đồng bộ.

---

## 3. KẾ HOẠCH THỰC HIỆN CHI TIẾT TỪNG FILE (ACTIONABLE FILE-BY-FILE PLAN)

Dưới đây là kế hoạch chi tiết từng bước sửa đổi mã nguồn. **Tuyệt đối không sửa code ở thời điểm này, chỉ thực thi khi được phê duyệt.**

```
                                      KIẾN TRÚC MỤC TIÊU GIAI ĐOẠN 1
                                      
  ┌────────────────────────────────────────────────────────────────────────────────────────┐
  │                                    FLUTTER CLIENT                                      │
  │                                                                                        │
  │   [pubspec.yaml] ── (Xóa - .env, xóa mailer)                                           │
  │         │                                                                              │
  │   [main.dart] ──── (Gỡ appVerificationDisabledForTesting, gỡ dotenv.load)              │
  │         │                                                                              │
  │   [AuthService] ── (Bỏ sendOTP, verifyOTP, password_resets plain; chuẩn hóa Auth SDK)  │
  │         │                                                                              │
  │   [DatabaseHelper] (Mở khóa clearUserData cho authenticated flow; thêm pre-migration   │
  │         │           backup file snapshot .bak trước DROP TABLE)                        │
  │         │                                                                              │
  │   [SyncService] ── (Áp dụng mapping tableName chuẩn hóa; bảo vệ SOFT_DELETE;          │
  │                    kiểm tra đa thuộc tính sở hữu: uid, ownerId, createdBy)             │
  │         │                                                                              │
  │   [Group Repos] ── (Gắn kết SessionManager.changes; validate membership; align DTO)    │
  └─────────┬──────────────────────────────────────────────────────────────────────────────┘
            │ HTTPS / Firebase Native
            ▼
  ┌────────────────────────────────────────────────────────────────────────────────────────┐
  │                                   FIREBASE BACKEND                                     │
  │                                                                                        │
  │   [firestore.rules]                                                                    │
  │     ├── /users/{userId} ───────────── Bất biến uid, email, createdAt + subcollection   │
  │     ├── /groups/{groupId} ─────────── Chấp nhận ownerId/adminId; khóa xóa nợ khi rời   │
  │     ├── /groups/{groupId}/subcols ─── Bảo vệ phân cấp members, expenses, settlements   │
  │     ├── /debts/{debtId} ───────────── CHẶN tự ý update/delete số nợ bởi debtor        │
  │     └── /expenses & /settlements ──── Khóa chặt bất biến ownerId, createdBy, payerId   │
  │                                                                                        │
  │   [Firebase Auth] ─────────────────── Xử lý 100% Verification Email & Reset Password   │
  └────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### Hạng mục 1: Xóa bỏ Credentials, SMTP & Rác bảo mật Client

#### File 1: `pubspec.yaml`
* **Mục tiêu:** Loại bỏ asset nhạy cảm và thư viện gửi mail không an toàn.
* **Thay đổi dự kiến:**
  - Xóa dòng `- .env` trong phần `flutter: assets:`.
  - Xóa dependency `mailer: ^7.1.0`.
  - (Tùy chọn) Đánh giá gỡ bỏ `flutter_dotenv: ^6.0.1` nếu không còn biến môi trường nào khác dùng ở client runtime.
  - Chạy `flutter pub get`.

#### File 2: `.env` và `.env.example`
* **Mục tiêu:** Khử nhiễm thông tin đăng nhập SMTP đã lộ.
* **Thay đổi dự kiến:**
  - Xóa bỏ các khóa `SMTP_SENDER_EMAIL`, `SMTP_APP_PASSWORD`, `SMTP_SENDER_NAME`.
  - Đưa cảnh báo vào tài liệu: Chủ tài khoản Gmail liên quan bắt buộc phải truy cập Google Account Console để **Thu hồi (Revoke) ngay lập tức App Password đã tạo**.

#### File 3: `lib/core/constants/api_keys.dart` & `lib/core/constants/api_keys.example.dart`
* **Mục tiêu:** Loại bỏ hardcode Gemini API Key.
* **Thay đổi dự kiến:**
  - Thay thế giá trị hardcode bằng chuỗi rỗng `String.fromEnvironment('GEMINI_API_KEY', defaultValue: '')`.
  - Cập nhật tài liệu hướng dẫn truyền key khi build: `flutter run --dart-define=GEMINI_API_KEY=your_key_here` hoặc cấu hình qua giao diện Settings (`AiConfigService`) lưu trong Keystore.

#### File 4: `lib/services/email_service.dart` & `lib/core/config/email_config.dart`
* **Mục tiêu:** Xóa sổ lớp gửi email qua SMTP client.
* **Thay đổi dự kiến:**
  - Đánh dấu `@deprecated` hoặc **xóa hoàn toàn 2 file này** khỏi codebase.
  - Gỡ bỏ toàn bộ các import liên quan trong `auth_service.dart`.

#### File 5: `lib/main.dart`
* **Mục tiêu:** Khôi phục cấu hình bảo mật chuẩn cho Firebase Auth.
* **Thay đổi dự kiến:**
  - Xóa bỏ hoặc đóng gói trong cờ kiểm thử:
    ```dart
    // XÓA DÒNG NÀY Ở PRODUCTION:
    // await FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);
    ```
  - Bọc cấu hình `dotenv.load(fileName: '.env')` an toàn, không bắt buộc tải file nếu không tồn tại.

---

### Hạng mục 2: Tái cấu trúc Xác thực & Xóa bỏ Dữ liệu Nhạy cảm trên Firestore

#### File 6: `lib/services/auth_service.dart`
* **Mục tiêu:** Chuẩn hóa quy trình xác thực theo chuẩn Firebase Auth Native, xóa bỏ rò rỉ Plaintext Password.
* **Thay đổi dự kiến:**
  - **Xóa bỏ các hàm:** `sendOTP()`, `verifyOTP()`.
  - **Cập nhật `resetPasswordWithEmail()`:** Loại bỏ việc lưu mật khẩu thô vào collection `password_resets`:
    ```dart
    // XÓA ĐOẠN MÃ NÀY:
    // await _firestore.collection('password_resets').doc(email.trim()).set({
    //   'newPassword': newPassword, ...
    // });
    ```
    Thay thế bằng việc gọi trực tiếp `_auth.sendPasswordResetEmail(email: email)`.
  - **Cập nhật lưu trữ Offline:** Không lưu `last_auth_password` dạng Plaintext vào `FlutterSecureStorage`. Thay vào đó, chỉ lưu hash mật khẩu phục vụ so khớp ngoại tuyến (`offline_auth_hash_$email`).
  - **Cập nhật `deleteAccount()`:** Đảm bảo khi gọi `DatabaseHelper().clearUserData(uid)`, truyền cờ xác thực hợp lệ để không bị chặn bởi Guard.

#### File 7: `lib/modules/auth/reset_password_screen.dart` & `forgot_password_screen.dart`
* **Mục tiêu:** Đồng bộ giao diện người dùng theo luồng Firebase Native Reset Password.
* **Thay đổi dự kiến:**
  - Điều chỉnh thông điệp hướng dẫn: "Vui lòng kiểm tra email của bạn để nhấn vào liên kết đặt lại mật khẩu an toàn từ Firebase".
  - Loại bỏ các tham số và trường nhập OTP không còn sử dụng.

---

### Hạng mục 3: Tái thiết kế Firestore Security Rules (`firestore.rules`)

#### File 8: `firestore.rules`
* **Mục tiêu:** Siết chặt phân quyền, bảo vệ quỹ nhóm, khóa bất biến các trường định danh.
* **Nội dung thay đổi chi tiết:**

1. **Bảo vệ toàn diện `users/{userId}` và Subcollections:**
   ```rules
   match /users/{userId} {
     allow read: if signedIn() && uid() == userId;
     allow create: if signedIn() && uid() == userId
                   && incoming().get('uid', userId) == userId
                   && incoming().get('role', 'user') == 'user'
                   && incoming().get('accountType', 'FREE') == 'FREE';
     allow update: if signedIn() && uid() == userId
                   && incoming().get('uid', userId) == userId
                   && keepsValue('role', 'user')
                   && keepsValue('accountType', 'FREE')
                   // KHÓA BẤT BIẾN CÁC TRƯỜNG CỐT LÕI
                   && (!('createdAt' in incoming()) || incoming().createdAt == existing().createdAt)
                   && (!('email' in incoming()) || incoming().email == existing().email);
     allow delete: if signedIn() && uid() == userId;

     // QUY TẮC CHO MỌI SUBCOLLECTION CỦA USER
     match /{subcollection=**} {
       allow read, write: if signedIn() && uid() == userId;
     }
   }
   ```

2. **Hòa giải và củng cố Quỹ nhóm `groups/{groupId}`:**
   - Cho phép cả `ownerId` và `adminId` (đồng bộ giữa `GroupModel` và Rules cũ).
   - Kiểm tra bất biến của `ownerId` / `adminId` khi update thông thường.
   - Chặn thành viên tự ý rời nhóm nếu còn nợ công nợ chưa giải quyết.
   ```rules
   match /groups/{groupId} {
     function isMemberHere() { return signedIn() && uid() in resource.data.memberIds; }
     function isAdminHere()  { 
       return signedIn() && (
         resource.data.get('adminId', '') == uid() || 
         resource.data.get('ownerId', '') == uid()
       ); 
     }

     allow read: if isMemberHere() || isAdminHere();
     allow create: if signedIn()
       && request.resource.data.get('id', groupId) == groupId
       && (request.resource.data.get('adminId', '') == uid() || request.resource.data.get('ownerId', '') == uid())
       && request.resource.data.memberIds == [uid()]
       && request.resource.data.get('isDeleted', false) == false;
     
     allow update: if signedIn()
       && request.resource.data.memberIds is list
       // Khóa trường id, createdAt, ownerId không được sửa tùy tiện
       && request.resource.data.get('id', groupId) == resource.data.get('id', groupId)
       && (!('createdAt' in request.resource.data) || request.resource.data.createdAt == resource.data.createdAt)
       && (!('ownerId' in request.resource.data) || request.resource.data.ownerId == resource.data.ownerId)
       && (adminEditsGroup() || adminTransfersOwnership() || memberLeaves() || inviteeJoins());

     // SUBCOLLECTIONS CỦA GROUPS (Hỗ trợ cấu trúc phân cấp)
     match /{subcollection=**} {
       allow read: if isMemberHere() || isAdminHere();
       allow write: if isMemberHere() || isAdminHere();
     }
   }
   ```

3. **Khóa chặt việc sửa/xóa Công nợ (`debts`):**
   - Người nợ (`debtorId`) **TUYỆT ĐỐI KHÔNG ĐƯỢC PHÉP** tự ý sửa `amount` hoặc xóa bản ghi nợ.
   - Chỉ cho phép cập nhật khi có xác nhận hoặc chỉ cho phép thay đổi trạng thái qua quy trình quyết toán (`settlements`).
   ```rules
   match /debts/{debtId} {
     allow read: if isMemberOf(existing().groupId)
       || (signedIn() && (existing().debtorId == uid() || existing().creditorId == uid()));
     allow create: if isMemberOf(incoming().groupId)
       && incoming().debtorId in groupOf(incoming().groupId).memberIds
       && incoming().creditorId in groupOf(incoming().groupId).memberIds
       && incoming().debtorId != incoming().creditorId
       && incoming().amount is number && incoming().amount >= 0;
     
     // CHỈ CHỦ NỢ (creditorId) HOẶC ADMIN MỚI ĐƯỢC CẬP NHẬT TRẠNG THÁI / SỐ TIỀN
     allow update: if isMemberOf(existing().groupId)
       && (existing().creditorId == uid() || isAdminOfGroup(existing().groupId))
       && changedKeys().hasOnly(['amount', 'status', 'updatedAt'])
       && incoming().debtorId == existing().debtorId
       && incoming().creditorId == existing().creditorId
       && incoming().groupId == existing().groupId;
       
     // CHỈ CHỦ NỢ HOẶC ADMIN MỚI ĐƯỢC XÓA NỢ
     allow delete: if isMemberOf(existing().groupId)
       && (existing().creditorId == uid() || isAdminOfGroup(existing().groupId));
   }
   ```

4. **Đồng bộ Collection chi tiêu nhóm & Quyết toán:**
   - Bổ sung alias rules cho cả `group_expenses` và `group_settlements` nếu client SQLite sync theo tên bảng này.
   - Khóa chặt tính bất biến:
     - `expenses`: `incoming().createdBy == existing().createdBy && incoming().groupId == existing().groupId`
     - `settlements`: `incoming().payerId == existing().payerId && incoming().payeeId == existing().payeeId`

---

### Hạng mục 4: Kiểm soát UID khi Đồng bộ & Bảo toàn Dữ liệu Local

#### File 9: `lib/services/sync_service.dart`
* **Mục tiêu:** Khắc phục triệt để lỗi ghi đè UID khi Soft-delete, hỗ trợ mapping tên bảng và kiểm tra đa thuộc tính sở hữu.
* **Thay đổi dự kiến:**
  - **Sửa hàm `_uploadSingleItem` (Lỗi ghi đè UID):**
    ```dart
    case 'SOFT_DELETE':
    case 'DELETE':
      final deletePayload = <String, dynamic>{
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // CHỈ GẮN UID NẾU BẢNG ĐÓ THỰC SỰ LÀ BẢNG THUỘC SỞ HỮU CÁ NHÂN (CÓ CỘT UID)
      if (table != 'groups' && table != 'group_expenses' && table != 'group_settlements' && table != 'expenses' && table != 'settlements') {
        deletePayload['uid'] = ownerUid;
      }
      await collection.doc(recordId).set(deletePayload, SetOptions(merge: true));
      break;
    ```
  - **Bổ sung Table Mapping:**
    Khi tải từ `sync_queue`: ánh xạ `group_expenses` → Firestore collection `expenses`, `group_settlements` → Firestore collection `settlements` (hoặc ngược lại tùy kiến trúc đồng nhất).
  - **Kiểm tra đa thuộc tính sở hữu khi duyệt Queue:**
    Ngoài kiểm tra `data['uid'] == ownerUid`, bổ sung kiểm tra:
    - Nếu có `data['createdBy']`: phải bằng `ownerUid`.
    - Nếu có `data['ownerId']`: phải bằng `ownerUid` (khi tạo nhóm mới).

#### File 10: `lib/data/local/database_helper.dart`
* **Mục tiêu:** Mở khóa an toàn cho `clearUserData(uid)` khi xóa tài khoản; Tạo cơ chế Sao lưu (Snapshot Backup) trước khi chạy Migration `_onUpgrade`.
* **Thay đổi dự kiến:**
  1. **Tách biệt Guard:** Cho phép `clearUserData(uid)` được thực thi trong môi trường Production nếu gọi từ luồng xóa tài khoản có xác thực phiên (`SessionManager.instance.isValidUid(uid)`), chỉ chặn `wipeAllForTests()` và `clearAllData()`.
  2. **Bổ sung hàm Snapshot Backup trước Migration:**
     ```dart
     Future<void> _createPreMigrationBackup(String dbPath, int oldVersion) async {
       try {
         final dbFile = File(dbPath);
         if (await dbFile.exists()) {
           final backupPath = '$dbPath.bak_v${oldVersion}_${DateTime.now().millisecondsSinceEpoch}';
           await dbFile.copy(backupPath);
           debugPrint('DatabaseHelper: Pre-migration backup created at $backupPath');
         }
       } catch (e) {
         debugPrint('DatabaseHelper: Failed to create pre-migration backup: $e');
         // Ghi log cảnh báo nhưng không làm gián đoạn nếu là môi trường không hỗ trợ File copy
       }
     }
     ```
  3. **Gọi Backup trong `_initDatabase`:** Trước khi chạy `onUpgrade`, tự động sao lưu nguyên vẹn file `.db`. Nếu quá trình nâng cấp v9, v10... ném lỗi ngoại lệ, kích hoạt rollback khôi phục từ file `.bak`.
  4. **Bổ sung xóa bảng nhóm trong `clearUserData(uid)`:**
     Bổ sung xóa các nhóm do người dùng làm chủ (`ownerId = uid`) và các khoản chi do người dùng tạo (`createdBy = uid`).

#### File 11: `lib/features/group_expense/data/repositories/`
(`sqlite_group_repository.dart`, `sqlite_expense_repository.dart`, `sqlite_settlement_repository.dart`)
* **Mục tiêu:** Kết nối hoàn toàn với `SessionManager` và bảo đảm an toàn đa người dùng (Multi-tenant Local Safety).
* **Thay đổi dự kiến:**
  - Kế thừa / Sử dụng mixin `OwnedTableOps`.
  - Lắng nghe `SessionManager.instance.changes` để dọn dẹp bộ nhớ đệm (Cache) khi người dùng đổi tài khoản.
  - Mọi thao tác ghi (`create`, `update`, `delete`) bắt buộc lấy UID qua `session.requireUid()` thay vì nhận tham số tùy tiện từ UI.
  - Chuẩn hóa tên bảng ghi vào `SyncQueueWriter` đồng nhất với Firestore Collections.

---

## 4. MA TRẬN KIỂM THỬ & TIÊU CHÍ NGHIỆM THU (VERIFICATION & TEST MATRIX)

Giai đoạn 1 sẽ được nghiệm thu dựa trên các tiêu chí kiểm thử kỹ thuật nghiêm ngặt sau:

| STT | Kịch Bản Kiểm Thử | Phương Pháp Kiểm Thử | Tiêu Chí Đạt (Acceptance Criteria) |
| :---: | :--- | :--- | :--- |
| **TC-01** | **Quét APK Bundle tìm Credentials** | Dùng `apktool d` giải nén file APK Release | - Không tồn tại file `assets/flutter_assets/.env`.<br>- Lệnh `strings` trên file `.so` không tìm thấy Gemini API Key hay App Password. |
| **TC-02** | **Kiểm thử Native Email Reset Password** | Thao tác trên màn hình `ForgotPasswordScreen` | - Nhận được email reset chuẩn từ `firebaseapp.com`.<br>- Không có bản ghi nào bị ghi vào `password_resets` trên Firestore. |
| **TC-03** | **Security Rules: Ngăn Debtor tự sửa/xóa nợ** | Dùng Firebase Emulator Suite (`@firebase/rules-unit-testing`) | - Debtor gửi lệnh `update` amount hoặc `delete` trên doc `debts` bị từ chối (`PERMISSION_DENIED`).<br>- Creditor xác nhận thanh toán thành công. |
| **TC-04** | **Security Rules: Khóa trường bất biến** | Gửi request update với `userId` hoặc `ownerId` khác | - Firebase từ chối cập nhật khi phát hiện `request.resource.data.ownerId != resource.data.ownerId`. |
| **TC-05** | **Cách ly tài khoản khi Sync ngoại tuyến** | Đăng nhập User A, tạo GD offline → Đăng xuất → Đăng nhập User B → Bật mạng | - Hàng đợi chỉ đẩy giao dịch của User B.<br>- Giao dịch offline của User A giữ nguyên trạng thái pending, không bị đẩy vào Firestore của B. |
| **TC-06** | **Xóa tài khoản ở bản Release** | Build app ở chế độ Release (`--release`), thực hiện xóa tài khoản | - Tài khoản Firebase Auth bị xóa.<br>- SQLite bảng `transactions`, `wallets`, `users` của UID đó bị xóa sạch, không bị Guard chặn lại. |
| **TC-07** | **Sao lưu Snapshot an toàn trước Migration** | Nâng `_dbVersion` lên và kích hoạt lỗi mô phỏng trong migration | - File `money_tracker.db.bak_v*` được tạo trước khi `DROP TABLE`.<br>- Dữ liệu không bị mất nếu migration bị gián đoạn. |

---

## 5. LỘ TRÌNH THỰC HIỆN TIẾP THEO (NEXT STEPS)

1. **Bước 1:** Trình kế hoạch `PLAN_PHASE_1_SECURITY.md` cho Tech Lead / Project Manager phê duyệt.
2. **Bước 2:** Thu hồi ngay lập tức App Password Gmail bị lộ trên Google Security Dashboard.
3. **Bước 3:** Tiến hành thực thi sửa đổi mã nguồn theo đúng trình tự file đã nêu (Bắt đầu từ Hạng mục 1 → Hạng mục 2 → Hạng mục 3 → Hạng mục 4).
4. **Bước 4:** Chạy toàn bộ test suite và nghiệm thu theo Ma trận Kiểm thử mục 4.
