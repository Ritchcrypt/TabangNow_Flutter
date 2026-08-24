import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/mobile_update_service.dart';

class MobileUpdateGate extends StatefulWidget {
  const MobileUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  State<MobileUpdateGate> createState() => _MobileUpdateGateState();
}

class _MobileUpdateGateState extends State<MobileUpdateGate> {
  bool _checkStarted = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runUpdateCheck();
    });
  }

  Future<void> _runUpdateCheck() async {
    if (_checkStarted || !mounted) {
      return;
    }

    _checkStarted = true;

    const service = MobileUpdateService();
    final check = await service.check();

    if (!mounted ||
        check.requirement == MobileUpdateRequirement.none ||
        check.requirement == MobileUpdateRequirement.unavailable) {
      return;
    }

    await _showUpdateDialog(check);
  }

  Future<void> _showUpdateDialog(MobileUpdateCheck check) async {
    final isRequired = check.requirement == MobileUpdateRequirement.required;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isRequired,
      builder: (dialogContext) {
        return PopScope(
          canPop: !isRequired,
          child: AlertDialog(
            title: Text(
              isRequired
                  ? 'TabangNow update required'
                  : 'TabangNow update available',
            ),
            content: Text(
              '${check.message}\n\n'
              'Installed: ${check.installedVersion} '
              '(build ${check.installedBuildNumber})\n'
              'Latest: ${check.latestVersion} '
              '(build ${check.latestBuildNumber})',
            ),
            actions: [
              if (!isRequired)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Later'),
                ),
              FilledButton(
                onPressed: () async {
                  final uri = Uri.tryParse(check.downloadUrl);
                  if (uri == null || !uri.hasScheme) {
                    _showOpenFailure();
                    return;
                  }

                  try {
                    final launched = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );

                    if (!launched) {
                      _showOpenFailure();
                      return;
                    }

                    if (!isRequired && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } on Object {
                    _showOpenFailure();
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOpenFailure() {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to open the TabangNow download page. Please try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
