import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Phân loại ví / nơi chứa tiền
class WalletType {
  static const String cash = 'cash';
  static const String bank = 'bank';
  static const String eWallet = 'e_wallet';
  static const String credit = 'credit';
  static const String savings = 'savings';
  static const String other = 'other';

  static String getDisplayName(String type) {
    switch (type) {
      case cash:
        return 'Tiền mặt';
      case bank:
        return 'Tài khoản ngân hàng';
      case eWallet:
        return 'Ví điện tử';
      case credit:
        return 'Thẻ tín dụng';
      case savings:
        return 'Sổ tiết kiệm / Heo đất';
      case other:
      default:
        return 'Khác';
    }
  }

  static IconData getDefaultIcon(String type) {
    switch (type) {
      case cash:
        return Icons.payments_rounded;
      case bank:
        return Icons.account_balance_rounded;
      case eWallet:
        return Icons.phone_android_rounded;
      case credit:
        return Icons.credit_card_rounded;
      case savings:
        return Icons.savings_rounded;
      case other:
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  static List<String> getAllTypes() {
    return [cash, bank, eWallet, credit, savings, other];
  }
}

/// Model Ví tiền / Nơi chứa tiền (Wallet / Money Store)
class WalletModel {
  final String id;
  final String uid;
  final String name;
  final String type; // 'cash', 'bank', 'e_wallet', 'credit', 'savings', 'other'
  final double balance;
  final double initialBalance;
  final String currency;
  final int iconCode;
  final int colorValue;
  final bool isDefault;
  final String accountNumber;
  final String bankName;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  WalletModel({
    required this.id,
    required this.uid,
    required this.name,
    required this.type,
    required this.balance,
    this.initialBalance = 0.0,
    this.currency = 'VND',
    required this.iconCode,
    required this.colorValue,
    this.isDefault = false,
    this.accountNumber = '',
    this.bankName = '',
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 'synced',
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
  String get typeDisplayName => WalletType.getDisplayName(type);

  // ════════ FIRESTORE ════════

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WalletModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      name: data['name'] as String? ?? '',
      type: data['type'] as String? ?? WalletType.cash,
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      initialBalance: (data['initialBalance'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? 'VND',
      iconCode: data['iconCode'] as int? ?? Icons.account_balance_wallet_rounded.codePoint,
      colorValue: data['colorValue'] as int? ?? const Color(0xFF438883).toARGB32(),
      isDefault: data['isDefault'] is bool
          ? (data['isDefault'] as bool)
          : (data['isDefault'] == 1 || data['isDefault'] == 'true'),
      accountNumber: data['accountNumber'] as String? ?? '',
      bankName: data['bankName'] as String? ?? '',
      note: data['note'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      syncStatus: 'synced',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'type': type,
      'balance': balance,
      'initialBalance': initialBalance,
      'currency': currency,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'isDefault': isDefault,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // ════════ SQLITE ════════

  factory WalletModel.fromSqlite(Map<String, dynamic> map) {
    return WalletModel(
      id: map['id'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? WalletType.cash,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      initialBalance: (map['initialBalance'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'VND',
      iconCode: map['iconCode'] as int? ?? Icons.account_balance_wallet_rounded.codePoint,
      colorValue: map['colorValue'] as int? ?? const Color(0xFF438883).toARGB32(),
      isDefault: (map['isDefault'] as int? ?? 0) == 1,
      accountNumber: map['accountNumber'] as String? ?? '',
      bankName: map['bankName'] as String? ?? '',
      note: map['note'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int? ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int? ?? 0),
      syncStatus: map['syncStatus'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'type': type,
      'balance': balance,
      'initialBalance': initialBalance,
      'currency': currency,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'isDefault': isDefault ? 1 : 0,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'note': note,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'syncStatus': syncStatus,
    };
  }

  WalletModel copyWith({
    String? id,
    String? uid,
    String? name,
    String? type,
    double? balance,
    double? initialBalance,
    String? currency,
    int? iconCode,
    int? colorValue,
    bool? isDefault,
    String? accountNumber,
    String? bankName,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return WalletModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      initialBalance: initialBalance ?? this.initialBalance,
      currency: currency ?? this.currency,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      accountNumber: accountNumber ?? this.accountNumber,
      bankName: bankName ?? this.bankName,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
