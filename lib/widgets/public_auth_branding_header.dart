import 'dart:async';

import 'package:flutter/material.dart';

import '../core/global_branding_logo_controller.dart';
import 'sos_flip_coin_button.dart';

class PublicAuthBrandingHeader extends StatefulWidget {
  const PublicAuthBrandingHeader({
    super.key,
    this.logoSize = 96,
  });

  final double logoSize;

  @override
  State<PublicAuthBrandingHeader> createState() =>
      _PublicAuthBrandingHeaderState();
}

class _PublicAuthBrandingHeaderState extends State<PublicAuthBrandingHeader> {
  final GlobalBrandingLogoController _branding =
      GlobalBrandingLogoController.instance;

  @override
  void initState() {
    super.initState();
    _branding.addListener(_onBrandingChanged);
    unawaited(_branding.ensureStarted());
  }

  @override
  void dispose() {
    _branding.removeListener(_onBrandingChanged);
    super.dispose();
  }

  void _onBrandingChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: <Widget>[
        SosFlipCoinButton(size: widget.logoSize),
        const SizedBox(height: 18),
        Text(
          _branding.systemName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _branding.systemSubtitle.toUpperCase(),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}