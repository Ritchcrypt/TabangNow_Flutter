import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/global_branding_logo_controller.dart';
import 'global_sos_overlay.dart';

class SosFlipCoinButton extends StatefulWidget {
  const SosFlipCoinButton({
    super.key,
    this.size = 96,
    this.showShadow = true,
    this.logoFit = BoxFit.cover,
    this.flipInterval = const Duration(seconds: 10),
  });

  final double size;
  final bool showShadow;
  final BoxFit logoFit;

  final Duration flipInterval;

  @override
  State<SosFlipCoinButton> createState() => _SosFlipCoinButtonState();
}

class _SosFlipCoinButtonState extends State<SosFlipCoinButton> {
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
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _openSos() async {
    await GlobalSosOverlay.open(context);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: _LogoFace(
        size: widget.size,
        logoBytes: _branding.logoBytes,
        onTap: _openSos,
        showShadow: widget.showShadow,
        logoFit: widget.logoFit,
      ),
    );
  }
}

class _LogoFace extends StatelessWidget {
  const _LogoFace({
    required this.size,
    required this.logoBytes,
    required this.onTap,
    required this.showShadow,
    required this.logoFit,
  });

  final double size;
  final Uint8List? logoBytes;
  final VoidCallback onTap;
  final bool showShadow;
  final BoxFit logoFit;

  @override
  Widget build(BuildContext context) {
    final customLogo = logoBytes;

    return Semantics(
      button: true,
      enabled: true,
      label: 'Emergency SOS',
      hint: 'Tap the TabangNow logo to open the emergency confirmation.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              boxShadow: showShadow
                  ? <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: size < 60 ? 8 : 18,
                        offset: Offset(0, size < 60 ? 3 : 8),
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: ClipOval(
              child: SizedBox.square(
                dimension: size,
                child: customLogo != null && customLogo.isNotEmpty
                    ? Image.memory(
                        customLogo,
                        width: size,
                        height: size,
                        fit: logoFit,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) {
                          return _bundledLogo();
                        },
                      )
                    : _bundledLogo(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bundledLogo() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF8FAFC),
      ),
      child: Center(
        child: Text(
          'TN',
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontSize: size * 0.26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
