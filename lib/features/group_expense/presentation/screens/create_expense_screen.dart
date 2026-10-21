import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/animated_scale_button.dart';
import '../../../../widgets/mono_toast.dart';
import '../../../../utils/currency_format_utils.dart';
import '../../data/dtos/create_expense_dto.dart';
import '../../data/models/expense_model.dart';
import '../providers/group_expense_providers.dart';

class CreateExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;

  const CreateExpenseScreen({super.key, required this.groupId});

  @override
  ConsumerState<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends ConsumerState<CreateExpenseScreen> {
  bool get isVi => LanguageService.instance.isVietnamese;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  String? _selectedPayerId;
  final List<String> _selectedParticipantIds = [];
  SplitMethod _splitMethod = SplitMethod.equal;
  String _category = 'Ăn uống';
  final DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPayerId == null) {
      MonoToast.warning(
        context,
        isVi ? 'Vui lòng chọn người trả tiền' : 'Please select a payer',
      );
      return;
    }

    if (_selectedParticipantIds.isEmpty) {
      MonoToast.warning(
        context,
        isVi ? 'Vui lòng chọn người tham gia' : 'Please select participants',
      );
      return;
    }

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final dto = CreateExpenseDto(
        groupId: widget.groupId,
        name: _nameController.text.trim(),
        amount: CurrencyUtils.parseCurrency(_amountController.text),
        payerId: _selectedPayerId!,
        participantIds: _selectedParticipantIds,
        splitMethod: _splitMethod,
        category: _category,
        date: _selectedDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await ref.read(expenseServiceProvider).createExpense(dto, userId);

      if (mounted) {
        Navigator.pop(context);
        MonoToast.success(
          context,
          isVi ? 'Tạo chi tiêu thành công' : 'Expense created successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        MonoToast.error(
          context,
          '${isVi ? 'Lỗi' : 'Error'}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupStreamProvider(widget.groupId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    isVi ? 'Thêm Chi Tiêu' : 'Add Expense',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: groupAsync.when(
                  data: (group) {
                    if (group == null) {
                      return Center(child: Text(isVi ? 'Không tìm thấy dữ liệu nhóm' : 'Group data not found'));
                    }
                    final members = group.memberIds;

                    if (_selectedPayerId == null && members.isNotEmpty) {
                      _selectedPayerId = members.first;
                    }

                    return Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: isVi ? 'Tên chi tiêu' : 'Expense name',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return isVi ? 'Vui lòng nhập tên chi tiêu' : 'Please enter expense name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            decoration: InputDecoration(
                              labelText: isVi ? 'Số tiền' : 'Amount',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              suffixText: 'đ',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return isVi ? 'Vui lòng nhập số tiền' : 'Please enter amount';
                              }
                              if (CurrencyUtils.parseCurrency(value) <= 0) {
                                return isVi ? 'Số tiền phải lớn hơn 0' : 'Amount must be greater than 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedPayerId,
                            decoration: InputDecoration(
                              labelText: isVi ? 'Người trả tiền' : 'Payer',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: members.map((memberId) {
                              return DropdownMenuItem(
                                value: memberId,
                                child: Text('${isVi ? 'Thành viên' : 'Member'} ${memberId.substring(0, 8)}...'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedPayerId = value);
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            isVi ? 'Người tham gia:' : 'Participants:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...members.map((memberId) {
                            return CheckboxListTile(
                              title: Text('${isVi ? 'Thành viên' : 'Member'} ${memberId.substring(0, 8)}...'),
                              value: _selectedParticipantIds.contains(memberId),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedParticipantIds.add(memberId);
                                  } else {
                                    _selectedParticipantIds.remove(memberId);
                                  }
                                });
                              },
                            );
                          }),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<SplitMethod>(
                            initialValue: _splitMethod,
                            decoration: InputDecoration(
                              labelText: isVi ? 'Cách chia' : 'Split method',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: SplitMethod.equal,
                                child: Text(isVi ? 'Chia đều' : 'Split equally'),
                              ),
                              DropdownMenuItem(
                                value: SplitMethod.singlePayer,
                                child: Text(isVi ? 'Một người trả' : 'Single payer'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _splitMethod = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: InputDecoration(
                              labelText: isVi ? 'Danh mục' : 'Category',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: [
                              DropdownMenuItem(value: 'Ăn uống', child: Text(isVi ? 'Ăn uống' : 'Food & Dining')),
                              DropdownMenuItem(value: 'Di chuyển', child: Text(isVi ? 'Di chuyển' : 'Transport')),
                              DropdownMenuItem(value: 'Mua sắm', child: Text(isVi ? 'Mua sắm' : 'Shopping')),
                              DropdownMenuItem(value: 'Giải trí', child: Text(isVi ? 'Giải trí' : 'Entertainment')),
                              DropdownMenuItem(value: 'Khác', child: Text(isVi ? 'Khác' : 'Other')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _category = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              labelText: isVi ? 'Ghi chú (tùy chọn)' : 'Notes (optional)',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            maxLines: 3,
                          ),
                          // Submit button
                          AnimatedScaleButton(
                            onTap: _isLoading
                                ? null
                                : () {
                                    HapticFeedback.mediumImpact();
                                    _createExpense();
                                  },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: _isLoading
                                    ? primaryColor.withValues(alpha: 0.5)
                                    : primaryColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _isLoading
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: primaryColor.withValues(alpha: 0.35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isVi ? 'Tạo Chi Tiêu' : 'Create Expense',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('${isVi ? 'Lỗi' : 'Error'}: $error'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
