import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../providers/user_settings_provider.dart';
import '../style.dart';

/// Warns that microphone detection is monophonic before connecting it.
///
/// Returns true when the user chose to continue. When the "don't show again"
/// checkbox is checked and the user continues, the preference is persisted.
Future<bool> showMicrophoneWarningDialog(
  BuildContext context,
  UserSettingsProvider settings,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _MicrophoneWarningDialog(settings: settings),
  );
  return result ?? false;
}

class _MicrophoneWarningDialog extends StatefulWidget {
  final UserSettingsProvider settings;

  const _MicrophoneWarningDialog({required this.settings});

  @override
  State<_MicrophoneWarningDialog> createState() =>
      _MicrophoneWarningDialogState();
}

class _MicrophoneWarningDialogState extends State<_MicrophoneWarningDialog> {
  bool _dontShowAgain = false;

  Future<void> _continue() async {
    if (_dontShowAgain) {
      await widget.settings.setHideMicrophoneWarning(true);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.microphoneWarningTitle, style: AppTextStyles.header),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Text(l10n.microphoneWarningMessage, style: AppTextStyles.normal),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              l10n.microphoneWarningDontShowAgain,
              style: AppTextStyles.normal,
            ),
            value: _dontShowAgain,
            onChanged: (value) {
              setState(() => _dontShowAgain = value ?? false);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          style: AppTheme.flatButtonStyle,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.feedbackCancel),
        ),
        ElevatedButton(
          style: AppTheme.filledButtonStyle,
          onPressed: _continue,
          child: Text(l10n.microphoneWarningContinue),
        ),
      ],
    );
  }
}
