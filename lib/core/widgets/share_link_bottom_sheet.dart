import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'リンクを共有',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: const Text('SMS'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _launchSms(context, shareMessage);
                },
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('メール'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _launchMail(
                    context,
                    subject: emailSubject,
                    body: shareMessage,
                  );
                },
              ),
              ListTile(
                leading: _lineLeadingIcon(),
                title: const Text('LINE'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _launchLine(context, shareMessage);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('URLをコピー'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Clipboard.setData(ClipboardData(text: url));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('コピーしました\n$url')),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

Widget _lineLeadingIcon() {
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: const Color(0xFF06C755),
      borderRadius: BorderRadius.circular(8),
    ),
    alignment: Alignment.center,
    child: const Text(
      'LINE',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 11,
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

Future<void> _launchMail(
  BuildContext context, {
  required String subject,
  required String body,
}) async {
  try {
    // Prefer manual query encoding for mailto (see Dart Uri + non-http schemes).
    final uri = Uri.parse(
      'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールアプリを開けませんでした')),
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
