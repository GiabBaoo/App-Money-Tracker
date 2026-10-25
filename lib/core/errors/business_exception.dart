enum BusinessErrorCode {
  unauthenticated, // Không có phiên hợp lệ
  invalidUid, // UID sai định dạng
  ownershipViolation, // Model mang uid khác phiên
  notFound, // Không tồn tại hoặc không thuộc phiên
  sessionChanged, // Phiên đổi giữa chừng (epoch mismatch)
  destructiveOpDisabled, // Hàm nguy hiểm đã bị khóa
  pendingSyncExists, // Còn dữ liệu chưa đồng bộ
  sameWalletTransfer, // Ví nguồn và ví đích không được trùng nhau
  invalidAmount, // Số tiền không hợp lệ hoặc <= 0
  insufficientBalance, // Số dư ví không đủ
  cannotLeaveWithDebt, // Thành viên còn nợ nhóm, không thể rời nhóm
  cannotLeaveWithCredit, // Nhóm còn nợ thành viên, không thể rời nhóm
  pendingSettlementExists, // Còn quyết toán pending
  invalidMember, // Thành viên không hợp lệ hoặc không thuộc nhóm
  permissionDenied, // Không có quyền thực hiện
  settlementAlreadyProcessed, // Quyết toán đã được xử lý
  groupNotFound, // Không tìm thấy nhóm
  walletNotFound, // Không tìm thấy ví
}

class BusinessException implements Exception {
  final BusinessErrorCode code;
  final String message;
  final Object? cause;

  const BusinessException(this.code, this.message, {this.cause});

  @override
  String toString() => 'BusinessException(${code.name}): $message';
}
