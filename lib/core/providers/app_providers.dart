import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/theme_service.dart';
import '../../services/language_service.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../services/connectivity_service.dart';
import '../../services/sync_service.dart';

/// Provider quản lý Giao diện (Theme, Dark/Light Mode, Font scale)
final themeServiceProvider = ChangeNotifierProvider<ThemeService>((ref) => ThemeService());

/// Provider quản lý Đa ngôn ngữ (Tiếng Việt / English)
final languageServiceProvider = ChangeNotifierProvider<LanguageService>((ref) => LanguageService());

/// Provider truy xuất TransactionRepository
final transactionRepoProvider = Provider<TransactionRepository>((ref) => TransactionRepository());

/// Provider truy xuất WalletRepository
final walletRepoProvider = Provider<WalletRepository>((ref) => WalletRepository());

/// Provider truy xuất UserRepository
final userRepoProvider = Provider<UserRepository>((ref) => UserRepository());

/// Provider truy xuất NotificationRepository
final notificationRepoProvider = Provider<NotificationRepository>((ref) => NotificationRepository());

/// Provider truy xuất MessageRepository
final messageRepoProvider = Provider<MessageRepository>((ref) => MessageRepository());

/// Provider trạng thái kết nối mạng ConnectivityService
final connectivityServiceProvider = Provider<ConnectivityService>((ref) => ConnectivityService());

/// Provider đồng bộ dữ liệu đám mây SyncService
final syncServiceProvider = Provider<SyncService>((ref) => SyncService());
