import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  String? _selectedPayerId;
  List<String> _selectedParticipantIds = [];
  SplitMethod _splitMethod = SplitMethod.equal;
  String _category = 'Ăn uống';
  DateTime _selectedDate = DateTime.now();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn người trả tiền')),
      );
      return;
    }

    if (_selectedParticipantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn người tham gia')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo chi tiêu thành công')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Thêm Chi Tiêu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
                      return const Center(child: Text('Không tìm thấy dữ liệu nhóm'));
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
                              labelText: 'Tên chi tiêu',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vui lòng nhập tên chi tiêu';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            decoration: InputDecoration(
                              labelText: 'Số tiền',
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
                                return 'Vui lòng nhập số tiền';
                              }
                              if (CurrencyUtils.parseCurrency(value) <= 0) {
                                return 'Số tiền phải lớn hơn 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedPayerId,
                            decoration: InputDecoration(
                              labelText: 'Người trả tiền',
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
                                child: Text('Thành viên ${memberId.substring(0, 8)}...'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedPayerId = value);
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Người tham gia:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...members.map((memberId) {
                            return CheckboxListTile(
                              title: Text('Thành viên ${memberId.substring(0, 8)}...'),
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
                            value: _splitMethod,
                            decoration: InputDecoration(
                              labelText: 'Cách chia',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: SplitMethod.equal,
                                child: Text('Chia đều'),
                              ),
                              DropdownMenuItem(
                                value: SplitMethod.singlePayer,
                                child: Text('Một người trả'),
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
                            value: _category,
                            decoration: InputDecoration(
                              labelText: 'Danh mục',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Ăn uống', child: Text('Ăn uống')),
                              DropdownMenuItem(value: 'Di chuyển', child: Text('Di chuyển')),
                              DropdownMenuItem(value: 'Mua sắm', child: Text('Mua sắm')),
                              DropdownMenuItem(value: 'Giải trí', child: Text('Giải trí')),
                              DropdownMenuItem(value: 'Khác', child: Text('Khác')),
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
                              labelText: 'Ghi chú (tùy chọn)',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _createExpense,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Tạo Chi Tiêu',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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
                      child: Text('Lỗi: $error'),
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
