import '../../firebase_options.dart';

/// Public URLs for sharing (e.g. Firebase Hosting for Flutter web).
class AppLinks {
  AppLinks._();

  /// Base URL for the deployed web app (hash routing: `/#/path`).
  static String get _hostBaseUrl =>
      'https://${DefaultFirebaseOptions.web.projectId}.web.app';

  /// Link to open this transaction in the web app (same route as mobile).
  static String transactionShareUrl(String transactionId) =>
      '$_hostBaseUrl/#/transactions/$transactionId';

  /// Link to the service request form for a listing (same route as mobile).
  static String serviceRequestShareUrl(String serviceId) =>
      '$_hostBaseUrl/#/services/$serviceId/request';

  /// 利用規約（ホスティングにページを置いたらパスを合わせてください）
  static String get termsOfServiceUrl => '$_hostBaseUrl/terms';

  /// プライバシーポリシー
  static String get privacyPolicyUrl => '$_hostBaseUrl/privacy';
}
