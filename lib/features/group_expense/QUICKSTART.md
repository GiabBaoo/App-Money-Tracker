# Quick Start Guide - Group Expense Management

## Bước 1: Setup Firebase (Đã có sẵn)
✅ Firebase đã được cấu hình trong project
✅ Firestore đã được enable
✅ Firebase Auth đã được setup

## Bước 2: Thêm vào Main App

### Option A: Thêm vào existing navigation
```dart
import 'package:money_tracker_app/features/group_expense/presentation/screens/group_list_screen.dart';

// Trong navigation menu hoặc home screen
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GroupListScreen(),
      ),
    );
  },
  child: const Text('Quản lý chi tiêu nhóm'),
)
```

### Option B: Test standalone
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:money_tracker_app/features/group_expense/presentation/screens/group_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(
    const ProviderScope(
      child: MaterialApp(
        home: GroupListScreen(),
      ),
    ),
  );
}
```

## Bước 3: Test Complete Flow

### 3.1 Tạo Nhóm
1. Mở `GroupListScreen`
2. Nhấn nút FAB (+)
3. Nhập tên nhóm: "Du lịch Đà Lạt"
4. Nhập mô tả: "Chuyến đi cuối tuần"
5. Nhấn "Tạo Nhóm"

### 3.2 Thêm Chi Tiêu
1. Chọn nhóm vừa tạo
2. Nhấn nút FAB (+)
3. Nhập thông tin:
   - Tên: "Ăn tối"
   - Số tiền: 500000
   - Người trả: Chọn từ danh sách
   - Người tham gia: Chọn tất cả
   - Cách chia: "Chia đều"
   - Danh mục: "Ăn uống"
4. Nhấn "Tạo Chi Tiêu"

### 3.3 Xem Công Nợ
1. Quay lại `GroupDetailScreen`
2. Xem phần "Công Nợ"
3. Hệ thống tự động tính toán và hiển thị

### 3.4 Thanh Toán
1. Người nợ nhấn nút "Thanh toán"
2. Xác nhận số tiền
3. Chờ người cho vay xác nhận
4. Người cho vay mở `SettlementConfirmScreen`
5. Nhấn "Xác Nhận Đã Nhận Tiền"
6. Công nợ tự động cập nhật

## Firestore Collections

Feature sẽ tạo các collections sau:

### `groups`
```json
{
  "id": "uuid",
  "name": "Du lịch Đà Lạt",
  "description": "Chuyến đi cuối tuần",
  "adminId": "user_id",
  "memberIds": ["user_id_1", "user_id_2"],
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "isDeleted": false
}
```

### `expenses`
```json
{
  "id": "uuid",
  "groupId": "group_id",
  "name": "Ăn tối",
  "amount": 500000,
  "payerId": "user_id",
  "participantIds": ["user_id_1", "user_id_2"],
  "splitMethod": "equal",
  "shares": {
    "user_id_1": 250000,
    "user_id_2": 250000
  },
  "category": "Ăn uống",
  "date": "timestamp",
  "createdBy": "user_id",
  "createdAt": "timestamp"
}
```

### `debts`
```json
{
  "id": "uuid",
  "groupId": "group_id",
  "debtorId": "user_id_1",
  "creditorId": "user_id_2",
  "amount": 250000,
  "status": "active",
  "createdAt": "timestamp"
}
```

### `settlements`
```json
{
  "id": "uuid",
  "groupId": "group_id",
  "payerId": "user_id_1",
  "payeeId": "user_id_2",
  "amount": 250000,
  "status": "pendingConfirmation",
  "createdAt": "timestamp"
}
```

## Firestore Security Rules (Recommended)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Groups
    match /groups/{groupId} {
      allow read: if request.auth != null && 
                     request.auth.uid in resource.data.memberIds;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
                       request.auth.uid == resource.data.adminId;
      allow delete: if request.auth != null && 
                       request.auth.uid == resource.data.adminId;
    }
    
    // Expenses
    match /expenses/{expenseId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow delete: if request.auth != null && 
                       (request.auth.uid == resource.data.createdBy ||
                        request.auth.uid == get(/databases/$(database)/documents/groups/$(resource.data.groupId)).data.adminId);
    }
    
    // Debts
    match /debts/{debtId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Settlements
    match /settlements/{settlementId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
                       request.auth.uid == resource.data.payeeId;
      allow delete: if request.auth != null && 
                       request.auth.uid == resource.data.payerId;
    }
  }
}
```

## Troubleshooting

### Lỗi: "User not authenticated"
- Đảm bảo Firebase Auth đã được setup
- User phải đăng nhập trước khi sử dụng feature

### Lỗi: "Permission denied"
- Kiểm tra Firestore Security Rules
- Đảm bảo user có quyền truy cập

### Lỗi: "Group not found"
- Kiểm tra groupId có đúng không
- Đảm bảo group chưa bị xóa (isDeleted = false)

### Debts không cập nhật
- Kiểm tra `DebtCalculator.recalculateDebts()` được gọi sau mỗi expense
- Kiểm tra Firestore indexes

## Next Steps

1. ✅ Thêm user profile display (thay vì hiển thị user ID)
2. ✅ Thêm photo upload cho expenses
3. ✅ Thêm custom split method
4. ✅ Thêm expense categories management
5. ✅ Thêm export to PDF/CSV
6. ✅ Thêm notifications cho settlements
7. ✅ Thêm group statistics/charts

## Support

Nếu gặp vấn đề, kiểm tra:
1. Firebase console logs
2. Flutter debug console
3. Firestore data structure
4. Network connectivity
