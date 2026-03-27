import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_links.dart';
import '../config/app_theme.dart';
import '../ui/app_icons.dart';

/// Same share flow as the service request screen: request URL + SMS / Mail / LINE / copy.
Future<void> showServiceRequestShareSheet(
  BuildContext context,
  String serviceId,
) async {
  final url = AppLinks.serviceRequestShareUrl(serviceId);
  final shareMessage = 'Wanty サービス依頼\n$url';
  await showShareLinkBottomSheet(
    context,
    url: url,
    shareMessage: shareMessage,
    emailSubject: 'Wanty サービス依頼',
  );
}

/// Bottom sheet: SMS, Mail, LINE, copy URL.
Future<void> showShareLinkBottomSheet(
  BuildContext context, {
  required String url,
  required String shareMessage,
  String emailSubject = 'Wanty',
}) async {
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  'リンクを共有',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ShareSheetRowItem(
                      icon: const Icon(AppIcons.sms_outlined, size: 28),
                      label: 'SMS',
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _launchSms(context, shareMessage);
                      },
                    ),
                  ),
                  Expanded(
                    child: _ShareSheetRowItem(
                      icon: const Icon(AppIcons.mail_outline, size: 28),
                      label: 'メール',
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _launchMail(
                          context,
                          subject: emailSubject,
                          body: shareMessage,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _ShareSheetRowItem(
                      icon: _lineLeadingIcon(size: 44),
                      label: 'LINE',
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _launchLine(context, shareMessage);
                      },
                    ),
                  ),
                  Expanded(
                    child: _ShareSheetRowItem(
                      icon: const Icon(AppIcons.link, size: 28),
                      label: 'コピー',
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await Clipboard.setData(ClipboardData(text: url));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('コピーしました\n$url')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// One tap target in the horizontal share row (icon above label).
class _ShareSheetRowItem extends StatelessWidget {
  const _ShareSheetRowItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 44,
                child: Center(child: icon),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _lineLeadingIcon({double size = 40}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF06C755),
      borderRadius: BorderRadius.circular(AppRadii.xs),
    ),
    alignment: Alignment.center,
    child: Text(
      'LINE',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: size > 42 ? 12 : 11,
      ),
    ),
  );
}

Future<void> _launchSms(BuildContext context, String body) async {
  try {
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(body)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMSアプリを開けませんでした')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SMSを開けませんでした: $e')),
      );
    }
  }
}

/// Encodes mailto query params. Required for non-http(s) schemes — see
/// https://pub.dev/packages/url_launcher#encoding-urls (Dart Uri + spaces / `+`).
String _encodeMailtoQuery(Map<String, String> params) {
  return params.entries
      .map(
        (e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');
}

Future<void> _launchMail(
  BuildContext context, {
  required String subject,
  required String body,
}) async {
  final query = _encodeMailtoQuery(<String, String>{
    'subject': subject,
    'body': body,
  });
  // No recipient: `mailto:?subject=...&body=...`
  final uri = Uri.parse('mailto:?${query}');

  Future<void> copyMailFallback() async {
    final text = '件名: $subject\n\n$body';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'メールアプリが見つかりませんでした。件名と本文をコピーしました。メールに貼り付けてご利用ください。',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  try {
    // Prefer externalApplication: matches ACTION_VIEW + mailto on Android.
    var ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
    if (ok) return;
    await copyMailFallback();
  } on PlatformException catch (e) {
    // ACTIVITY_NOT_FOUND: no handler, or (before manifest fix) visibility hid mail apps.
    if (e.code == 'ACTIVITY_NOT_FOUND') {
      await copyMailFallback();
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メールを開けませんでした: $e')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メールを開けませんでした: $e')),
      );
    }
  }
}

Future<void> _launchLine(BuildContext context, String text) async {
  try {
    final uri = Uri.parse(
      'https://line.me/R/msg/text/?${Uri.encodeComponent(text)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LINEを開けませんでした')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('LINEを開けませんでした: $e')),
      );
    }
  }
}
