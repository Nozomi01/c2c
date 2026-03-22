/// OAuth **Web client** (type 3) from `android/app/google-services.json` → `oauth_client`
/// where `client_type` is `3`. Required for [GoogleSignIn] on Android when using Firebase Auth
/// so the plugin can obtain an ID token (`serverClientId`).
///
/// If you regenerate Firebase config, update this string to match the Web client in Console.
const String kGoogleSignInServerClientId =
    '1060651929162-ju2vhdbks39bj2pt2lmr2li6h2f25a97.apps.googleusercontent.com';
