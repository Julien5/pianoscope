import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../providers/user_settings_provider.dart';
import '../style.dart';

enum FeedbackMode { feedback, crashReport }

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// The answer collected by [FeedbackDialog]. It is null when the user
/// cancels. In [FeedbackMode.crashReport] the input fields are hidden, so
/// [email] and [message] are empty and the caller is expected to read the
/// pending report files itself.
class FeedbackRequest {
  final String email;
  final String message;
  final bool withScreenshot;

  const FeedbackRequest({
    required this.email,
    required this.message,
    required this.withScreenshot,
  });
}

class FeedbackDialog extends StatefulWidget {
  final FeedbackMode mode;
  final int crashReportCount;

  const FeedbackDialog({
    super.key,
    required this.mode,
    this.crashReportCount = 0,
  });

  /// Returns the user's answer, or null if the dialog was cancelled.
  static Future<FeedbackRequest?> show(
    BuildContext context, {
    required FeedbackMode mode,
    int crashReportCount = 0,
  }) {
    return showDialog<FeedbackRequest>(
      context: context,
      builder: (context) =>
          FeedbackDialog(mode: mode, crashReportCount: crashReportCount),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _message = TextEditingController();
  bool _withScreenshot = false;

  bool get _isCrashReport => widget.mode == FeedbackMode.crashReport;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(
      text: context.read<UserSettingsProvider>().email,
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _isCrashReport || _formKey.currentState?.validate() == true;
    if (!isValid) return;
    final settings = context.read<UserSettingsProvider>();
    if (!_isCrashReport) {
      await settings.setEmail(_email.text.trim());
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      FeedbackRequest(
        email: _isCrashReport ? '' : _email.text.trim(),
        message: _isCrashReport ? '' : _message.text.trim(),
        withScreenshot: !_isCrashReport && _withScreenshot,
      ),
    );
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty || _emailPattern.hasMatch(text)) return null;
    return AppLocalizations.of(context)!.feedbackEmailInvalid;
  }

  String? _validateMessage(String? value) {
    if ((value ?? '').trim().isNotEmpty) return null;
    return AppLocalizations.of(context)!.feedbackMessageRequired;
  }

  Widget _feedbackFields(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          TextFormField(
            controller: _email,
            style: AppTextStyles.normal,
            decoration: InputDecoration(
              labelText: l10n.feedbackEmail,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: _validateEmail,
          ),
          TextFormField(
            controller: _message,
            style: AppTextStyles.normal,
            decoration: InputDecoration(
              labelText: l10n.feedbackMessage,
              hintText: l10n.feedbackMessageHint,
              border: const OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 6,
            validator: _validateMessage,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l10n.feedbackScreenshot, style: AppTextStyles.normal),
            value: _withScreenshot,
            onChanged: (value) {
              setState(() => _withScreenshot = value ?? false);
            },
          ),
        ],
      ),
    );
  }

  Widget _crashReportNotice(AppLocalizations l10n) {
    return Text(
      l10n.crashReportNotice(widget.crashReportCount),
      style: AppTextStyles.normal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(_isCrashReport ? l10n.crashReportTitle : l10n.feedbackTitle),
      content: _isCrashReport
          ? _crashReportNotice(l10n)
          : _feedbackFields(l10n),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.feedbackCancel),
        ),
        ElevatedButton(onPressed: _submit, child: Text(l10n.feedbackSubmit)),
      ],
    );
  }
}
