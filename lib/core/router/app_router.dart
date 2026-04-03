import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/auth_gate_screen.dart';
import '../../features/home/presentation/screens/home_shell.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/auth/presentation/screens/phone_number_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/services/presentation/screens/service_detail_screen.dart';
import '../../features/services/presentation/screens/service_request_screen.dart';
import '../../features/board/presentation/screens/people_board_screen.dart';
import '../../features/board/presentation/screens/text_board_screen.dart';
import '../../features/board/presentation/screens/person_profile_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_thread_screen.dart';
import '../../features/profile/presentation/screens/account_settings_screen.dart';
import '../../features/profile/presentation/screens/phone_number_edit_screen.dart';
import '../../features/profile/presentation/screens/about_service_screen.dart';
import '../../features/profile/presentation/screens/drafts_list_screen.dart';
import '../../features/profile/presentation/screens/help_contact_screen.dart';
import '../../features/profile/presentation/screens/likes_list_screen.dart';
import '../../features/profile/presentation/screens/my_listings_screen.dart';
import '../../features/profile/presentation/screens/my_page_screen.dart';
import '../../features/profile/presentation/screens/my_transactions_screen.dart';
import '../../features/profile/presentation/screens/my_requests_screen.dart';
import '../../features/profile/presentation/screens/completed_items_screen.dart';
import '../../features/profile/presentation/screens/notification_settings_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/profile/presentation/screens/withdraw_screen.dart';
import '../../features/profile/presentation/screens/identity_verify_screen.dart';
import '../../features/profile/presentation/screens/stripe_account_screen.dart';
import '../../features/reservations/presentation/screens/reservations_screen.dart';
import '../../features/notifications/presentation/screens/notification_list_screen.dart';
import '../../features/transactions/presentation/screens/transaction_detail_screen.dart';
import '../../features/transactions/presentation/screens/payment_method_screen.dart';
import '../../features/transactions/presentation/screens/purchase_complete_screen.dart';
import '../../features/transactions/presentation/screens/transaction_completed_screen.dart';
import '../../features/transactions/presentation/screens/rate_transaction_screen.dart';
import '../../features/transactions/presentation/screens/rate_buyer_screen.dart';
import '../../features/transactions/presentation/screens/seller_requests_list_screen.dart';
import '../../features/transactions/presentation/screens/seller_request_detail_screen.dart';
import '../../features/transactions/presentation/screens/revision_or_dispute_screen.dart';
import '../../features/services/domain/models/service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

final GoRouter _appRouter = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final uri = state.uri;

      // iOS Firebase Auth callbacks (Phone/Auth reCAPTCHA) can arrive as
      // custom scheme URLs and should not be treated as app navigation routes.
      final isFirebaseAuthCustomSchemeCallback =
          uri.scheme.startsWith('com.googleusercontent.apps.') &&
          uri.host == 'firebaseauth' &&
          uri.path == '/link';
      if (isFirebaseAuthCustomSchemeCallback) {
        return '/';
      }

      return null;
    },
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
                path: '/reservations',
                name: 'reservations',
                builder: (context, state) => const ReservationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/board',
                name: 'board',
                builder: (context, state) => const TextBoardScreen(),
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
        redirect: (context, state) => '/listings',
      ),
      // People listings (kept as non-tab route)
      GoRoute(
        path: '/listings',
        name: 'listings',
        builder: (context, state) => PeopleBoardScreen(
          initialQuery: state.uri.queryParameters['q'],
        ),
      ),
      GoRoute(
        path: '/listings/category',
        name: 'categoryListings',
        builder: (context, state) {
          final category = state.uri.queryParameters['name'] ?? 'カテゴリ';
          return PeopleBoardScreen(initialCategory: category);
        },
      ),
      GoRoute(
        path: '/services/:id',
        name: 'serviceDetail',
        builder: (context, state) => ServiceDetailScreen(serviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/services/:id/request',
        name: 'serviceRequest',
        builder: (context, state) => ServiceRequestScreen(serviceId: state.pathParameters['id']!),
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
              clientSecret: state.extra is String ? state.extra as String : null,
            ),
          ),
          GoRoute(
            path: 'completed',
            name: 'transactionCompleted',
            builder: (context, state) => TransactionCompletedScreen(
              transactionId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'rate',
            name: 'rateTransaction',
            builder: (context, state) => RateTransactionScreen(
              transactionId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'rate-buyer',
            name: 'rateBuyer',
            builder: (context, state) => RateBuyerScreen(
              transactionId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'issues',
            name: 'revisionOrDispute',
            builder: (context, state) => RevisionOrDisputeScreen(
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
        path: '/seller/requests',
        name: 'sellerRequests',
        builder: (context, state) => const SellerRequestsListScreen(),
      ),
      GoRoute(
        path: '/seller/requests/:id',
        name: 'sellerRequestDetail',
        builder: (context, state) =>
            SellerRequestDetailScreen(requestId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chats/:id',
        name: 'chatThread',
        builder: (context, state) => ChatThreadScreen(chatId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/people/:id',
        name: 'personProfile',
        builder: (context, state) =>
            PersonProfileScreen(userId: state.pathParameters['id']!),
      ),
      // Additional nested / detail routes
      GoRoute(
        path: '/services/create',
        name: 'createService',
        redirect: (context, state) => '/listings',
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
        path: '/settings/phone',
        name: 'phoneNumberEdit',
        builder: (context, state) => const PhoneNumberEditScreen(),
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
        path: '/mypage/completed',
        name: 'completedItems',
        builder: (context, state) => const CompletedItemsScreen(),
      ),
      GoRoute(
        path: '/mypage/requests',
        name: 'myRequests',
        builder: (context, state) => const MyRequestsScreen(),
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
      GoRoute(
        path: '/mypage/stripe',
        name: 'stripeAccount',
        builder: (context, state) => const StripeAccountScreen(),
      ),
    ],
  );

final appRouterProvider = Provider<GoRouter>((ref) => _appRouter);

