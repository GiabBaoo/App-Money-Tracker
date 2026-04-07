class CreateSettlementDto {
  final String groupId;
  final String payerId;
  final String payeeId;
  final double amount;
  final String? notes;
  final String? proofPhotoUrl;

  CreateSettlementDto({
    required this.groupId,
    required this.payerId,
    required this.payeeId,
    required this.amount,
    this.notes,
    this.proofPhotoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'payerId': payerId,
      'payeeId': payeeId,
      'amount': amount,
      'notes': notes,
      'proofPhotoUrl': proofPhotoUrl,
    };
  }
}
