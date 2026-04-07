# Group Expense Management Feature

## Tổng quan
Feature quản lý chi tiêu nhóm với đầy đủ chức năng: tạo nhóm, thêm chi tiêu, xem công nợ, và thanh toán.

## Luồng hoạt động chính

### 1. Tạo Nhóm (Create Group)
- Người dùng tạo nhóm mới với tên và mô tả
- Người tạo tự động trở thành admin
- Có thể thêm/xóa thành viên (chỉ admin)

**Screen:** `GroupListScreen` → `CreateGroupScreen`

### 2. Thêm Chi Tiêu (Add Expense)
- Chọn người trả tiền
- Chọn người tham gia
- Chọn cách chia: Chia đều hoặc Một người trả
- Hệ thống tự động tính toán công nợ

**Screen:** `GroupDetailScreen` → `CreateExpenseScreen`

### 3. Xem Công Nợ (View Debts)
- Hiển thị danh sách công nợ trong nhóm
- Tối ưu hóa số lượng giao dịch thanh toán
- Realtime updates qua Firestore streams

**Widget:** `DebtSummaryWidget` trong `GroupDetailScreen`

### 4. Thanh Toán (Settlement)
- Người nợ tạo thanh toán
- Người cho vay xác nhận/từ chối
- Tự động cập nhật công nợ khi xác nhận

**Screen:** `SettlementConfirmScreen`

## Cấu trúc thư mục

```
group_expense/
├── data/
│   ├── dtos/                    # Data Transfer Objects
│   │   ├── create_group_dto.dart
│   │   ├── update_group_dto.dart
│   │   ├── create_expense_dto.dart
│   │   └── create_settlement_dto.dart
│   ├── models/                  # Data Models
│   │   ├── group_model.dart
│   │   ├── expense_model.dart
│   │   ├── debt_model.dart
│   │   └── settlement_model.dart
│   └── repositories/            # Firestore Implementations
│       ├── firestore_group_repository.dart
│       ├── firestore_expense_repository.dart
│       ├── firestore_debt_repository.dart
│       └── firestore_settlement_repository.dart
├── domain/
│   ├── repositories/            # Repository Interfaces
│   │   ├── i_group_repository.dart
│   │   ├── i_expense_repository.dart
│   │   ├── i_debt_repository.dart
│   │   └── i_settlement_repository.dart
│   └── services/                # Business Logic
│       ├── group_service.dart
│       ├── expense_service.dart
│       ├── debt_calculator.dart
│       └── settlement_service.dart
└── presentation/
    ├── providers/               # Riverpod Providers
    │   └── group_expense_providers.dart
    ├── screens/                 # UI Screens
    │   ├── group_list_screen.dart
    │   ├── create_group_screen.dart
    │   ├── group_detail_screen.dart
    │   ├── create_expense_screen.dart
    │   └── settlement_confirm_screen.dart
    └── widgets/                 # Reusable Widgets
        └── debt_summary_widget.dart
```

## Tính năng chính

### Quản lý nhóm
- ✅ Tạo nhóm mới
- ✅ Cập nhật thông tin nhóm
- ✅ Thêm/xóa thành viên (admin only)
- ✅ Xóa nhóm (admin only)
- ✅ Realtime sync với Firestore

### Quản lý chi tiêu
- ✅ Thêm chi tiêu mới
- ✅ Chia đều (Equal split)
- ✅ Một người trả (Single payer)
- ✅ Tự động tính toán công nợ
- ✅ Xóa chi tiêu (creator/admin only)

### Tính toán công nợ
- ✅ Tự động tính toán từ chi tiêu
- ✅ Tối ưu hóa số lượng giao dịch
- ✅ Hiển thị balance cho từng user
- ✅ Realtime updates

### Thanh toán
- ✅ Tạo thanh toán
- ✅ Xác nhận/từ chối thanh toán
- ✅ Tự động cập nhật công nợ
- ✅ Lưu lịch sử thanh toán

## Sử dụng

### 1. Import feature
```dart
import 'package:money_tracker_app/features/group_expense/group_expense_feature.dart';
```

### 2. Wrap app với ProviderScope
```dart
void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### 3. Navigate to GroupListScreen
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const GroupListScreen(),
  ),
);
```

## Dependencies
- `cloud_firestore`: Firestore database
- `firebase_auth`: User authentication
- `flutter_riverpod`: State management
- `uuid`: Generate unique IDs
- `intl`: Format currency and dates

## Business Logic

### Equal Split Calculation
```dart
shareAmount = totalAmount / numberOfParticipants
```

### Debt Calculation
```dart
For each participant:
  debt = shareAmount - amountPaid
  
If debt > 0: participant owes money
If debt < 0: participant is owed money
```

### Debt Optimization
Sử dụng thuật toán greedy để giảm số lượng giao dịch thanh toán:
1. Tách creditors (người cho vay) và debtors (người nợ)
2. Match từng cặp với số tiền lớn nhất có thể
3. Giảm số lượng giao dịch từ O(n²) xuống O(n)

## Error Handling
- Validation ở tất cả input forms
- Permission checks (admin/member/creator)
- Try-catch với user-friendly error messages
- Firestore transaction safety

## Realtime Features
- Group list updates realtime
- Expense list updates realtime
- Debt calculations update realtime
- Settlement status updates realtime

## Security
- Firebase Auth integration
- Permission-based operations
- Admin-only actions
- Creator-only deletions

## UI/UX
- Vietnamese language
- Material Design 3
- Loading states
- Error messages
- Confirmation dialogs
- Currency formatting (VND)
- Date formatting (dd/MM/yyyy)
