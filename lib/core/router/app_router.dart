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
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_thread_screen.dart';
import '../../features/profile/presentation/screens/my_page_screen.dart';
import '../../features/transactions/presentation/screens/transaction_detail_screen.dart';

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
          final verificationId = state.extra as String?;
          return OtpVerificationScreen(
            verificationId: verificationId ?? '',
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
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/create',
                name: 'create',
                builder: (context, state) => const CreateServiceScreen(),
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
        path: '/services/:id',
        name: 'serviceDetail',
        builder: (context, state) => ServiceDetailScreen(serviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/transactions/:id',
        name: 'transactionDetail',
        builder: (context, state) => TransactionDetailScreen(transactionId: state.pathParameters['id']!),
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
    ],
  );
});

