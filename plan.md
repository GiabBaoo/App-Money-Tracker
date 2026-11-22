# Kế hoạch fix lỗi & cập nhật tính năng — Money Tracker

> Nguồn: `error.md` (6 nhóm lỗi) + 2 yêu cầu mới.
> Thứ tự thực hiện: **Giai đoạn 0 (câu hỏi) → 1 → 2 → … → 8**. Mỗi giai đoạn kết thúc bằng `flutter analyze` + `flutter test` (quiet).

---

## ❓ GIAI ĐOẠN 0 — CÂU HỎI CẦN BẠN TRẢ LỜI (ghi câu trả lời ngay dưới mỗi câu)

**Q1. Firestore Rules vs Code nhóm (mục 5.2)** — chọn hướng sửa:
- (A) **Sửa code cho đúng rules hiện tại** (dùng `group_invites` pending → accepted, tạo nhóm chỉ với `[uid]` rồi mời) — an toàn bảo mật hơn, sửa nhiều code hơn.
- (B) **Nới rules** cho khớp code hiện tại (admin được `arrayUnion` thành viên trực tiếp) — nhanh hơn, kém chặt hơn.
- Đề xuất: **(A) cho mời/tham gia**, nhưng **sửa rules** cho các chỗ rules bị sai logic (chuyển quyền owner dòng 180, xóa `/debts` khi tính lại công nợ, soft-delete settlement).
> Trả lời:A

**Q2. Bạn có quyền deploy `firestore.rules` lên Firebase Console không?** (Nếu không, tôi chỉ sửa file local và bạn tự deploy bằng `firebase deploy --only firestore:rules`.)
> Trả lời:tôi có

**Q3. Xóa tài khoản (mục 3.1)** — có xóa luôn file trên Firebase Storage (`avatars/`, `transaction_images/`) không? Việc này **không thể khôi phục**.
> Trả lời:có

**Q4. Ảnh hóa đơn offline (mục 4.3)** — khi offline/mạng yếu:
- (A) Lưu ảnh local trước, giao dịch lưu ngay, upload ảnh nền khi có mạng (**đề xuất**).
- (B) Bỏ hẳn fallback Base64, chỉ lưu đường dẫn local.
> Trả lời:A

**Q5. Thumbnail ảnh hóa đơn** — "khi chụp hóa đơn" là:
- (A) Chụp/chọn ảnh từ nút **"Ảnh hóa đơn"** trong màn hình Ghi thu/chi thủ công.
- (B) Luồng **quét hóa đơn (OCR/AI)** rồi chuyển sang màn hình Ghi thu/chi.
- (C) Cả hai (**đề xuất** — cùng dùng biến `_pickedPhoto` nên làm 1 lần áp dụng cho cả hai).
> Trả lời:C

**Q6. Thumbnail đặt ở đâu?**
- (A) Thay icon trong pill "Ảnh hóa đơn" bằng ảnh tròn nhỏ 24px.
- (B) Thêm 1 khung ảnh nhỏ (~64×64, bo góc) ngay dưới hàng pill, có nút ✕ để xóa, chạm vào để xem toàn màn hình (**đề xuất**).
> Trả lời:B

**Q7. Trang "Lịch sử giao dịch"** — tôi xác định là `AllTransactionsScreen` (mở từ Home). Các thẻ **Tổng thu / Tổng chi** đang hiện chữ thô `total_income` / `total_expense` vì thiếu key dịch. Đúng màn hình bạn nói chưa? Có chỗ nào khác còn tiếng Anh bạn thấy không (chụp màn hình nếu được)?
> Trả lời:Đúng rồi là trang đó

**Q8. Dữ liệu Firestore cũ có bị hỏng (ví 0đ) cần khôi phục không?** Nếu có, tôi sẽ viết thêm script/nút "Tính lại số dư từ sổ cái" chạy 1 lần.
> Trả lời:không cần, chỉ cần sửa lại logic cho nó đồng bộ không còn bị mất là được

---

## GIAI ĐOẠN 1 — Lỗi nghiêm trọng: mất ví / sai số dư trên máy mới (mục 1)

### 1.1 Realtime listeners bị hủy ngay sau khi bật
- **File:** `lib/services/auth_service.dart` (`setOnlineUid`), `lib/core/session/session_manager.dart` (`activate`), `lib/services/sync_service.dart` (`_internal`).
- **Fix:**
  - `SessionManager.changes` phát kèm `uid` mới (`Stream<String?>`).
  - Trong `SyncService._internal`: chỉ `stopRealtimeListeners()` khi `uid` phát ra **khác** `_listenersUid` hiện tại (hoặc `null`).
  - `setOnlineUid`: `await` cho session phát xong (`await Future.microtask((){})`) **rồi** mới `startRealtimeListeners()`; trong `startRealtimeListeners` lưu `_listenersUid = uid`.
- **Kiểm tra:** unit test giả lập `activate(uid)` → listeners vẫn còn 7 subscription.

### 1.2 Đăng nhập mới không tải dữ liệu
- **File:** `auth_service.dart` (`login`, `_runBackgroundAuthSync`), `main.dart`.
- **Fix:** Cuối `_runBackgroundAuthSync()` gọi `await SyncService().initialDownload(uid)` (khi online) rồi `startRealtimeListeners()`. Thêm cờ `_initialDownloadDone[uid]` để không chạy trùng với `main.dart`. Phát sự kiện `SyncService.initialDownloadCompleted` để UI chờ.

### 1.3 Race tạo ví mặc định 0đ ghi đè ví thật
- **File:** `wallet_screen.dart` (`initState`), `wallet_repository.dart` (`ensureDefaultWalletExists`, `upsertFromFirestore`).
- **Fix:**
  - Bỏ gọi `ensureDefaultWalletExists` trong `WalletScreen.initState`; chỉ gọi **sau khi** `initialDownload` hoàn tất thành công.
  - Trong `ensureDefaultWalletExists`: nếu chưa xác nhận được Firestore (offline/lỗi/timeout) → **không tạo ví**, return.
  - Nếu buộc phải tạo: tạo với `syncStatus='local_only'` và **không** enqueue `INSERT`; chỉ enqueue khi đã xác nhận Firestore không có ví nào.
  - `upsertFromFirestore`: nếu bản local là `wlt_default_$uid` có `balance==0`, không có giao dịch, và Firestore có bản cùng id → cho Firestore ghi đè (bỏ qua Dirty Shield) và xóa item `sync_queue` tương ứng.

### 1.4 Ép kiểu cứng trong `fromFirestore`
- **File:** `wallet_model`, `transaction_model`, `budget_model`, `goal_model`, `notification_model`, `message_model`, `sync_service.dart:1087-1114`.
- **Fix:** Tạo `lib/core/utils/firestore_parse.dart`:
  - `DateTime? parseDate(dynamic v)` — hỗ trợ `Timestamp`, `int` (ms), `String` ISO, `DateTime`.
  - `bool parseBool(dynamic v)` — `bool`, `0/1`, `"true"`.
  - `int? parseInt(dynamic v)` — `int`, `double`, `String`.
  - `double parseDouble(dynamic v)`.
  - Thay toàn bộ `as Timestamp` / `as bool?` / `as int?` bằng helper.
  - Danh sách map: bọc từng doc trong `try/catch`, bỏ qua + log doc lỗi thay vì làm hỏng cả đợt.

### 1.5 Reconcile ghi đè số dư khi tải `transactions` lỗi
- **File:** `sync_service.dart:1104-1345`, `ledger_reconciliation_service.dart`.
- **Fix:** Thêm biến `transactionsDownloadOk`; chỉ gọi `reconcileAll` khi **cả wallets lẫn transactions** tải thành công. Trong `reconcileAll`: bỏ qua ví có `balance != initialBalance` nhưng không có giao dịch local nào (dấu hiệu chưa tải đủ).

---

## GIAI ĐOẠN 2 — Sync Engine & DB (mục 2)

| # | Fix |
|---|-----|
| 2.1 | `sync_service.dart:774-780`: tạo `const _tablesWithoutUid = {'groups','group_members','group_expenses','group_settlements'}`; với các bảng này `where: '$keyCol = ?'` không có `uid`. Thêm migration reset các item `dead` của bảng nhóm về `pending`, `retryCount=0`. |
| 2.2 | Tạo helper `SyncTrigger.requestSync()` (debounce 2s, chỉ khi online) → gọi trong `addBudget/updateBudget/deleteBudget`, `addGoal/updateGoal/deleteGoal`, notification, message, user repositories. |
| 2.3 | `user_repository.dart:264`: enqueue `{'dataUsage': {key: value}}` (map lồng) thay cho `'dataUsage.$key'` — `set(merge:true)` sẽ merge sâu đúng. |
| 2.4 | `sync_service.dart:999-1009`: thêm `confirmedAt`, `joinedAt`, `leftAt` vào `timestampFields`. |
| 2.5 | `sync_service.dart:1259-1334`: lọc `isDeleted != true` khi build `userGroupIds`; bọc từng chunk `try/catch` để 1 chunk lỗi không dừng chunk khác. |
| 2.6 | `wallet_repository.dart:439`: `FinancePrecision.roundCurrency(currentWallet.balance + amountDelta)`. |

---

## GIAI ĐOẠN 3 — Auth, phiên, xóa tài khoản, sinh trắc học (mục 3)

- **3.1** Tạo `AuthService._clearLocalSession(uid)` dùng chung cho `logout()` và `deleteAccount()`: `stopRealtimeListeners`, `SessionManager.deactivate`, xóa `_offlineUid`, xóa các key SecureStorage (`last_offline_uid`, `last_offline_email`, `saved_login_password`, `offline_auth_uid_*`, `fingerprint_enabled_$uid`, `biometric_uid`), SharedPreferences (`saved_login_email`, `saved_remember_me`), `AppWidgetService.instance.clearOnLogout()`. `_deleteUserData`: xóa thêm `categories`, `support_requests` và (tùy Q3) file Storage.
- **3.2** `updateCurrentPassword()`: sau khi đổi thành công, cập nhật hash offline + `saved_login_password` (nếu Remember-Me bật).
- **3.3** `fingerprint_unlock_screen.dart:_logoutToLogin()` → `await AuthService().logout()`; `LifecycleManager` reset `_isLocked=false` khi nhận `SessionManager` deactivate.
- **3.4** `reset_password_screen.dart`: chỉ chuyển `SuccessScreen` khi `result.success`, ngược lại hiện SnackBar lỗi.
- **3.5** `biometric_screen.dart:31,49`: dùng `AuthService().currentUid`.

---

## GIAI ĐOẠN 4 — Giao dịch, Ngân sách, Mục tiêu (mục 4)

- **4.1** `edit_transaction_screen.dart:473`: disable nút Lưu khi `_selectedWallet == null`; fallback `newWalletId = _selectedWallet?.id ?? widget.transaction.walletId`.
- **4.2** `edit_transaction_screen.dart:505-531`: dùng `widget.transaction.copyWith(...)` để giữ `transferId`, `goalId`, `groupExpenseId`. Nếu là giao dịch mục tiêu: cập nhật chênh lệch `goals.currentAmount`.
- **4.3** `add_transaction_screen.dart:499-509` + `receipt_storage_service.dart`: lưu ảnh local (nén, max 1280px, JPEG 70%) → lưu giao dịch ngay → upload Storage chạy nền có `timeout(20s)`, xong thì cập nhật `photoUrl`. Bỏ/giới hạn Base64 ≤ 200 KB (theo Q4).
- **4.4** `receipt_storage_service.dart:250-256`: chỉ set `cacheWidth/cacheHeight` khi `width.isFinite && height.isFinite`.
- **4.5** `transaction_detail_screen.dart:200-209`: nếu kết quả edit là `true` hoặc reload ra `null` → `Navigator.pop(context, true)`.
- **4.6** `add_goal_dialog.dart:352-357`: `firstDate: _deadline.isBefore(now) ? _deadline : now`.
- **4.7** `budget_and_goals_screen.dart:408-413`: nếu có ngân sách `'Tất cả'` → tổng = bản ghi đó; ngược lại cộng các ngân sách danh mục.
- **4.8** `budget_repository.dart:87-95`, `all_transactions_screen.dart:508,512,1800`: thêm `&& !tx.isSavingsGoal`.

---

## GIAI ĐOẠN 5 — Chi tiêu nhóm & `firestore.rules` (mục 5) — *phụ thuộc Q1, Q2*

- **5.1** `settlement_confirm_screen.dart:81-86`: truyền `groupId` đúng (nhận qua constructor) hoặc thêm `getSettlementById(id)`.
- **5.2** Theo Q1:
  - Tạo nhóm: ghi `memberIds: [uid]` rồi gửi lời mời cho các thành viên còn lại.
  - Mời/tham gia: tạo `group_invites/{groupId}_{uid}` (`pending`); người được mời chấp nhận → cập nhật `accepted` + `arrayUnion(uid)` trong cùng batch. `JoinGroupScreen` đọc từ Firestore qua invite thay vì SQLite.
  - Rules: sửa dòng 180 cho phép đổi `ownerId` khi caller là owner hiện tại; cho thành viên nhóm xóa/tạo `/debts` của nhóm (hoặc chuyển `recalculateDebts` sang chỉ upsert nợ thay đổi); cho phép `isDeleted/deletedAt` trong update settlement.
  - Quỹ: admin chỉ xóa `fund_transactions`, không đụng `transactions` cá nhân người khác.
- **5.3** SQLite nhóm: `ownerUid` = UID người thao tác; `delete()` expense enqueue `SOFT_DELETE` cho `transactions`; dual-ledger chỉ tạo `transactions`/trừ ví khi `payerId == currentUid`; `update()` cập nhật `expense_splits` + `ownerUid` người sửa; `upsertFromFirestore` xóa members/splits không còn trên cloud; `watchByGroupId` hủy subscription trong `onCancel`.
- **5.4** Dùng `VndSplitCalculator` cho mọi kiểu chia (equal/percentage/shares/exact); validate `customShares` null/rỗng; chặn tạo settlement khi đã có `pendingConfirmation` giữa 2 người; rời nhóm → tính lại nợ từ sổ cái trước khi kiểm tra.
- **5.5** Dùng `firestore_parse.dart` cho model nhóm; mọi `fromJson(doc.data())` → `fromJson({...doc.data()!, 'id': doc.id})`; `iconCode`/`value` parse an toàn.

---

## GIAI ĐOẠN 6 — Thống kê, AI, Thông báo, Widget, Memory leak (mục 6)

- **6.1** `ai_action_handler.dart`, `smart_notification_service.dart`: lọc `!tx.isTransfer && !tx.isSavingsGoal` trước khi cộng.
- **6.2** `_addNotificationAndPush`: khóa chống trùng theo `(uid, type, refId, day)`; trả về `bool` — chỉ set cờ `budget_warned_100_*` khi thực sự đã gửi.
- **6.3** `clearOnLogout()` xóa cả key `int`; `syncAll()` kiểm tra `AuthService().currentUid != null` trước, nếu không → `clearOnLogout()`.
- **6.4** `lifecycle_manager.dart`: lưu `StreamSubscription? _authSub`, `cancel()` trong `dispose()`.

---

## GIAI ĐOẠN 7 — TÍNH NĂNG MỚI: Thumbnail ảnh hóa đơn trong Ghi thu/chi thủ công

- **File:** `lib/modules/transaction/add_transaction_screen.dart` (biến `_pickedPhoto` dòng 90, pill dòng 1923-1937, sheet chọn ảnh dòng 790-868).
- **Thực hiện (theo đề xuất Q5=C, Q6=B):**
  1. Thêm widget `_buildReceiptThumbnail()` hiển thị khi `_pickedPhoto != null`:
     - `ClipRRect` bo góc 12, kích thước 64×64, `Image.file(File(_pickedPhoto!.path), fit: BoxFit.cover, cacheWidth: 192)`.
     - Nút ✕ góc trên phải → `setState(() => _pickedPhoto = null)`.
     - Chạm ảnh → `ReceiptStorageService.showFullScreenViewer(...)` (sau khi fix 4.4).
     - `errorBuilder` hiện icon `broken_image` nếu file không còn.
  2. Đặt ngay dưới hàng quick-option pill; dùng `AnimatedSize` cho mượt.
  3. Pill "Ảnh hóa đơn": khi đã có ảnh, đổi `label` thành `context.tr('change_photo')` (thêm key `{'vi': 'Đổi ảnh', 'en': 'Change photo'}`).
  4. Áp dụng cả khi vào từ quét hóa đơn (`initialData['photoPath']`, dòng 219-223) và trong `EditTransactionScreen` nếu có ảnh cũ (`photoLocalPath`/`photoUrl`).
- **Kiểm tra:** widget test: set `_pickedPhoto` → tìm thấy `Image` + nút ✕; bấm ✕ → biến mất.

---

## GIAI ĐOẠN 8 — Sửa chữ tiếng Việt trang Lịch sử giao dịch (`AllTransactionsScreen`)

- **Nguyên nhân đã xác định:** `all_transactions_screen.dart:1654, 1706` gọi `context.tr('total_income')`, `context.tr('total_expense')` nhưng **2 key này không tồn tại** trong `_translations` của `lib/services/language_service.dart` → hiển thị chữ thô `total_income` / `total_expense`.
- **Fix:**
  1. Thêm vào `language_service.dart` (cạnh nhóm `filter_*` ~dòng 435):
     ```dart
     'total_income': {'vi': 'Tổng thu', 'en': 'Total Income'},
     'total_expense': {'vi': 'Tổng chi', 'en': 'Total Expense'},
     ```
  2. Rà toàn bộ key `context.tr(...)` trong `all_transactions_screen.dart`, `home_screen.dart`, `statistics_screen.dart` bằng script so với `_translations` → bổ sung mọi key thiếu.
  3. Rà chuỗi tiếng Anh cứng còn sót (vd `'Search by note, category, amount...'`, `'No transactions found'`) đảm bảo đều có nhánh `isVi`.
  4. (Tùy chọn) Trong `LanguageService.t()`: khi thiếu key, log `debugPrint('Missing translation: $key')` để phát hiện sớm.

---

## Kiểm thử tổng
- `flutter analyze` sạch lỗi mới.
- `flutter test` (thêm test cho: parse Firestore, reconcile skip khi tải lỗi, sync bảng nhóm không có `uid`, `VndSplitCalculator`, translation keys đầy đủ).
- Kịch bản tay: **Máy A** tạo ví + giao dịch → **Máy B** cài mới, đăng nhập → số dư khớp, realtime cập nhật khi A thêm giao dịch.
