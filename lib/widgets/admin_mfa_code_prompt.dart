import 'package:flutter/material.dart';

/// Only returns a transient code. Nothing is written to local storage.
Future<String?> requestAdminMfaCode(BuildContext context) {
  String code = '';
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Account verification'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Enter the 6-digit code from your authenticator app. '
                'If you lost access, enter an unused recovery code.',
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Authenticator or recovery code',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => code = value.trim(),
                onSubmitted: (_) => Navigator.of(dialogContext).pop(code),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(code),
          child: const Text('Verify'),
        ),
      ],
    ),
  );
}
