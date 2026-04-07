import '../models/expense_model.dart';

class CreateExpenseDto {
  final String groupId;
  final String name;
  final double amount;
  final String payerId;
  final List<String> participantIds;
  final SplitMethod splitMethod;
  final Map<String, double>? customShares;
  final String category;
  final DateTime date;
  final String? notes;
  final List<String> photoUrls;

  CreateExpenseDto({
    required this.groupId,
    required this.name,
    required this.amount,
    required this.payerId,
    required this.participantIds,
    required this.splitMethod,
    this.customShares,
    required this.category,
    required this.date,
    this.notes,
    this.photoUrls = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'name': name,
      'amount': amount,
      'payerId': payerId,
      'participantIds': participantIds,
      'splitMethod': splitMethod.toString().split('.').last,
      'customShares': customShares,
      'category': category,
      'date': date,
      'notes': notes,
      'photoUrls': photoUrls,
    };
  }
}
