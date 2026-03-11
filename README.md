# Wanty – Peer-to-Peer Service Marketplace (Flutter)

Wanty is a mobile marketplace where users can list themselves as a service and other users can purchase those services with escrow payments via Stripe Connect.

This repository contains:

- Flutter app (iOS / Android) with Clean Architecture + MVVM
- Firebase (Auth, Firestore, Storage, Cloud Functions, FCM)
- Stripe Connect escrow integration (via Cloud Functions)
- Riverpod state management
- GoRouter navigation

## Project Structure

```text
lib/
  core/           # theme, router, shared config
  features/
    auth/
    home/
    services/
    chat/
    transactions/
    reviews/
    profile/
    wallet/
  services/       # Firebase, Stripe setup
  widgets/        # Shared UI components
functions/        # Firebase Cloud Functions for Stripe escrow & payouts
```

## Getting Started

1. Install dependencies:

```bash
flutter pub get
```

2. Configure Firebase:

- Run `dart pub global activate flutterfire_cli`
- Run `flutterfire configure` and generate `firebase_options.dart`
- Replace `lib/services/firebase/firebase_options_stub.dart` with generated options and update imports if needed.

3. Stripe Setup:

- Create a Stripe account and enable Connect
- Create a publishable key and secret key
- Set `StripeConfig.publishableKey` in `lib/services/firebase/firebase_initializer.dart`
- In Cloud Functions, set environment variables:

```bash
cd functions
npm install
firebase functions:config:set stripe.secret="sk_test_..."
firebase deploy --only functions
```

4. Run the app:

```bash
flutter run
```

## Notes

- Firestore models are implemented with `freezed` and `json_serializable`. Run `dart run build_runner build --delete-conflicting-outputs` after editing models.
- UI mimics modern Japanese marketplace apps (e.g. Mercari) with rounded cards, bottom navigation, shimmer loaders, and pull-to-refresh.
- Security rules, Apple/LINE/Facebook auth providers, and full payout lifecycle should be wired based on your Firebase project settings before going to production.

# c2c

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
