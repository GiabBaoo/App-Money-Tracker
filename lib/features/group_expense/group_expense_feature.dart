// Group Expense Management Feature
// Complete flow: Create Group → Add Expense → View Debts → Settlement

export 'data/dtos/create_expense_dto.dart';
export 'data/dtos/create_group_dto.dart';
export 'data/dtos/create_settlement_dto.dart';
export 'data/dtos/update_group_dto.dart';

export 'data/models/debt_model.dart';
export 'data/models/expense_model.dart';
export 'data/models/group_model.dart';
export 'data/models/settlement_model.dart';

export 'data/repositories/firestore_debt_repository.dart';
export 'data/repositories/firestore_expense_repository.dart';
export 'data/repositories/firestore_group_repository.dart';
export 'data/repositories/firestore_settlement_repository.dart';

export 'domain/repositories/i_debt_repository.dart';
export 'domain/repositories/i_expense_repository.dart';
export 'domain/repositories/i_group_repository.dart';
export 'domain/repositories/i_settlement_repository.dart';

export 'domain/services/debt_calculator.dart';
export 'domain/services/expense_service.dart';
export 'domain/services/group_service.dart';
export 'domain/services/settlement_service.dart';

export 'presentation/providers/group_expense_providers.dart';

export 'presentation/screens/create_expense_screen.dart';
export 'presentation/screens/create_group_screen.dart';
export 'presentation/screens/group_detail_screen.dart';
export 'presentation/screens/group_list_screen.dart';
export 'presentation/screens/settlement_confirm_screen.dart';

export 'presentation/widgets/debt_summary_widget.dart';
