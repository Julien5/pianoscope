import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../providers/user_settings_provider.dart';
import '../rust/api/report.dart';
import '../style.dart';

enum FeedbackMode { feedback, crashReport }

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// The answer collected by [FeedbackDialog]. It is null when the user
/// cancels. In [FeedbackMode.crashReport] the input fields are hidden, so
/// [email] and [message] are empty and the caller uploads the pending report
/// files itself.
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

typedef ReportCallback = void Function(String);

/// The work the dialog runs on submit, and the way to stop it.
abstract class UploadHandler {
  ReportCallback? reportCallback;
  final UploadSession session;
  UploadHandler({required this.session});

  void setReportCallback(ReportCallback callback) {
    reportCallback = callback;
  }

  Future<void> onSubmit(FeedbackRequest request);

  void onCancel() {
    session.cancel();
  }
}

class FeedbackDialog extends StatefulWidget {
  final FeedbackMode mode;
  final List<String> filenames;

  final UploadHandler uploadHandler;

  const FeedbackDialog({
    super.key,
    required this.mode,
    required this.filenames,
    required this.uploadHandler,
  });

  /// Shows the dialog and returns once the work [UploadHandler.onSubmit] is
  /// doing has settled -- the dialog closes by itself, with nothing to hand
  /// back.
  static Future<void> show(
    BuildContext context, {
    required FeedbackMode mode,
    required List<String> filenames,
    required UploadHandler handler,
  }) {
    return showDialog<void>(
      context: context,
      // The work runs while the dialog is up, so a stray tap outside must not
      // dismiss it. Stopping is deliberate, through the stop button.
      barrierDismissible: false,
      builder: (context) => FeedbackDialog(
        mode: mode,
        filenames: filenames,
        uploadHandler: handler,
      ),
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
  bool _busy = false;
  String _progress = '';

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

  /// Validates the inputs and remembers the email. Returns null when the form
  /// is invalid, or once this State is gone; either way the caller must leave
  /// the dialog open and not start any work.
  Future<FeedbackRequest?> _collectRequest() async {
    if (!_isCrashReport && _formKey.currentState?.validate() != true) {
      return null;
    }
    final email = _isCrashReport ? '' : _email.text.trim();
    if (!_isCrashReport) {
      await context.read<UserSettingsProvider>().setEmail(email);
    }
    if (!mounted) return null;
    return FeedbackRequest(
      email: email,
      message: _isCrashReport ? '' : _message.text.trim(),
      withScreenshot: !_isCrashReport && _withScreenshot,
    );
  }

  Future<void> _submit() async {
    final request = await _collectRequest();
    if (request == null) return;
    if (!mounted) return;
    setState(() => _busy = true);
    Object? failure;
    StackTrace? failureStack;
    try {
      widget.uploadHandler.setReportCallback((text) {
        if (mounted) setState(() => _progress = text);
      });
      await widget.uploadHandler.onSubmit(request);
    } catch (e, s) {
      failure = e;
      failureStack = s;
    }
    // Close even on failure: leaving the dialog up with a disabled submit
    // would trap the user in a dialog they cannot get out of. A stop is not a
    // failure -- the caller handles it without throwing.
    if (mounted) Navigator.of(context).pop();
    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
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
        mainAxisSize: MainAxisSize.max,
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
          Expanded(
            child: TextFormField(
              expands: true,
              controller: _message,
              style: AppTextStyles.normal,
              decoration: InputDecoration(
                labelText: l10n.feedbackMessage,
                hintText: l10n.feedbackMessageHint,
                border: const OutlineInputBorder(),
              ),
              validator: _validateMessage,
              minLines: null,
              maxLines: null,
            ),
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

  Widget _reportsNotice(AppLocalizations l10n) {
    return Text(
      l10n.reportsNotice(widget.filenames.length),
      style: AppTextStyles.normal,
    );
  }

  Widget _progressView() {
    return Text(_progress, style: AppTextStyles.normal);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget content;
    if (_busy) {
      content = _progressView();
    } else if (_isCrashReport) {
      content = _reportsNotice(l10n);
    } else {
      content = _feedbackFields(l10n);
    }
    if (!_isCrashReport) {
      content = SizedBox(
        width: MediaQuery.of(context).size.width, // Full screen width
        height: MediaQuery.of(context).size.height,
        child: content,
      );
    }
    return AlertDialog(
      title: Text(
        _isCrashReport ? l10n.crashReportTitle : l10n.feedbackTitle,
        style: AppTextStyles.header,
      ),
      insetPadding: EdgeInsets.all(5),
      content: content,
      actions: [
        TextButton(
          onPressed: _busy
              ? widget.uploadHandler.onCancel
              : () => Navigator.of(context).pop(),
          child: Text(_busy ? l10n.uploadStop : l10n.feedbackCancel),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.feedbackSubmit),
        ),
      ],
    );
  }
}
