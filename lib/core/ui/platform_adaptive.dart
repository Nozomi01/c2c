import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

bool isCupertinoPlatform(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

Future<T?> showPlatformAlertDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'OK',
  String cancelText = 'キャンセル',
  bool isDestructive = false,
}) {
  if (isCupertinoPlatform(context)) {
    return showCupertinoDialog<T>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

Future<void> showPlatformInfoDialog({
  required BuildContext context,
  required String title,
  required String message,
  String closeText = '閉じる',
}) async {
  if (isCupertinoPlatform(context)) {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(closeText),
          ),
        ],
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(closeText),
        ),
      ],
    ),
  );
}

PreferredSizeWidget platformAppBar({
  required BuildContext context,
  required String title,
  List<Widget>? actions,
}) {
  if (isCupertinoPlatform(context)) {
    return CupertinoNavigationBar(
      middle: Text(title),
      trailing: actions == null || actions.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: actions),
      backgroundColor: Colors.white,
      border: null,
    );
  }

  return AppBar(
    title: Text(title),
    actions: actions,
  );
}
