import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/auth_gate_screen.dart';
import '../../features/home/presentation/screens/home_shell.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/auth/presentation/screens/phone_number_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/services/presentation/screens/service_list_screen.dart';
import '../../features/services/presentation/screens/service_detail_screen.dart';
import '../../features/services/presentation/screens/create_service_screen.dart';
import '../../features/services/presentation/screens/category_service_list_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_thread_screen.dart';
import '../../features/profile/presentation/screens/account_settings_screen.dart';
import '../../features/profile/presentation/screens/about_service_screen.dart';
import '../../features/profile/presentation/screens/drafts_list_screen.dart';
import '../../features/profile/presentation/screens/help_contact_screen.dart';
import '../../features/profile/presentation/screens/likes_list_screen.dart';
import '../../features/profile/presentation/screens/my_listings_screen.dart';
import '../../features/profile/presentation/screens/my_page_screen.dart';
import '../../features/profile/presentation/screens/my_transactions_screen.dart';
import '../../features/profile/presentation/screens/notification_settings_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/profile/presentation/screens/withdraw_screen.dart';
import '../../features/profile/presentation/screens/identity_verify_screen.dart';
import '../../features/notifications/presentation/screens/notification_list_screen.dart';
import '../../features/transactions/presentation/screens/transaction_detail_screen.dart';
import '../../features/transactions/presentation/screens/payment_method_screen.dart';
import '../../features/transactions/presentation/screens/purchase_complete_screen.dart';
import '../../features/services/domain/models/service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'authGate',
        builder: (context, state) => const AuthGateScreen(),
      ),
      GoRoute(
        path: '/auth/phone',
        name: 'phoneAuth',
        builder: (context, state) => const PhoneNumberScreen(),
      ),
      GoRoute(
        path: '/auth/phone/verify',
        name: 'phoneOtp',
        builder: (context, state) {
          final extra = state.extra;
          String verificationId = '';
          String? phoneNumber;
          if (extra is List && extra.isNotEmpty) {
            verificationId = extra[0] is String ? extra[0] as String : '';
            if (extra.length > 1 && extra[1] is String) {
              phoneNumber = extra[1] as String;
            }
          } else if (extra is String) {
            verificationId = extra;
          }
          return OtpVerificationScreen(
            verificationId: verificationId,
            phoneNumber: phoneNumber,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/listings',
                name: 'listings',
                builder: (context, state) => const ServiceListScreen(),
              ),
              GoRoute(
                path: '/listings/category',
                name: 'categoryListings',
                builder: (context, state) {
                  final category =
                      state.uri.queryParameters['name'] ?? 'カテゴリ';
                  return CategoryServiceListScreen(category: category);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                name: 'messages',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mypage',
                name: 'mypage',
                builder: (context, state) => const MyPageScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/create',
        name: 'create',
        builder: (context, state) => const CreateServiceScreen(),
      ),
      GoRoute(
        path: '/services/:id',
        name: 'serviceDetail',
        builder: (context, state) => ServiceDetailScreen(serviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/transactions/:id',
        name: 'transactionDetail',
        builder: (context, state) => TransactionDetailScreen(
          transactionId: state.pathParameters['id']!,
          service: state.extra is Service ? state.extra as Service : null,
        ),
        routes: [
          GoRoute(
            path: 'payment',
            name: 'paymentMethod',
            builder: (context, state) => PaymentMethodScreen(
              transactionId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/purchase-complete',
        name: 'purchaseComplete',
        builder: (context, state) => PurchaseCompleteScreen(
          transactionId: state.extra is String ? state.extra as String : '',
        ),
      ),
      GoRoute(
        path: '/chats/:id',
        name: 'chatThread',
        builder: (context, state) => ChatThreadScreen(chatId: state.pathParameters['id']!),
      ),
      // Additional nested / detail routes
      GoRoute(
        path: '/services/create',
        name: 'createService',
        builder: (context, state) => const CreateServiceScreen(),
      ),
      GoRoute(
        path: '/settings/account',
        name: 'accountSettings',
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/profile',
        name: 'profileEdit',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        name: 'notificationSettings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/mypage/likes',
        name: 'likesList',
        builder: (context, state) => const LikesListScreen(),
      ),
      GoRoute(
        path: '/mypage/drafts',
        name: 'draftsList',
        builder: (context, state) => const DraftsListScreen(),
      ),
      GoRoute(
        path: '/mypage/listings',
        name: 'myListings',
        builder: (context, state) => const MyListingsScreen(),
      ),
      GoRoute(
        path: '/mypage/transactions',
        name: 'myTransactions',
        builder: (context, state) => const MyTransactionsScreen(),
      ),
      GoRoute(
        path: '/mypage/withdraw',
        name: 'withdraw',
        builder: (context, state) => const WithdrawScreen(),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutServiceScreen(),
      ),
      GoRoute(
        path: '/help',
        name: 'help',
        builder: (context, state) => const HelpContactScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationListScreen(),
      ),
      GoRoute(
        path: '/settings/identity',
        name: 'identityVerify',
        builder: (context, state) => const IdentityVerifyScreen(),
      ),
    ],
  );
});

