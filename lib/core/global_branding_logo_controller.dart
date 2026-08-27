import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../services/public_branding_logo_service.dart';

class GlobalBrandingLogoController extends ChangeNotifier {
  GlobalBrandingLogoController._();

  static final GlobalBrandingLogoController instance =
      GlobalBrandingLogoController._();

  static const Duration _refreshInterval = Duration(seconds: 15);
  static const String _cacheFileName = 'tabangnow_system_logo.cache';

  final PublicBrandingLogoService _service = PublicBrandingLogoService();

  Timer? _timer;
  Uint8List? _logoBytes;
  bool _started = false;
  bool _loaded = false;
  bool _loading = false;

  Uint8List? get logoBytes => _logoBytes;
  bool get hasCustomLogo => _logoBytes != null && _logoBytes!.isNotEmpty;
  bool get loaded => _loaded;

  Future<void> ensureStarted() async {
    _timer ??= Timer.periodic(_refreshInterval, (_) {
      unawaited(refresh());
    });

    if (_started) {
      return;
    }

    _started = true;

    // Restore the last successfully downloaded logo before touching the
    // network. This keeps the configured TabangNow branding visible after an
    // app restart even when the device is offline.
    await _restoreCachedLogo();

    // Refresh in the foreground once at startup. A network failure leaves the
    // cached logo untouched, and the periodic refresh will retry later.
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading) {
      return;
    }

    _loading = true;

    try {
      final fetchedLogo = await _service.fetchLogoBytes();
      final nextLogo = fetchedLogo == null || fetchedLogo.isEmpty
          ? null
          : Uint8List.fromList(fetchedLogo);

      _loaded = true;

      if (nextLogo == null) {
        // A successful 404/no-logo response means branding was intentionally
        // removed on the server, so the persistent custom-logo cache must also
        // be removed. Network exceptions never enter this branch.
        await _deleteCachedLogo();
      } else {
        await _writeCachedLogo(nextLogo);
      }

      if (!_sameBytes(_logoBytes, nextLogo)) {
        _logoBytes = nextLogo;
        notifyListeners();
      }
    } catch (_) {
      // Keep the last known in-memory/disk logo if the public branding asset
      // is temporarily unavailable. Offline mode must never erase branding.
      _loaded = true;
    } finally {
      _loading = false;
    }
  }

  void applyLogoBytes(Uint8List? bytes) {
    final normalized = bytes == null || bytes.isEmpty
        ? null
        : Uint8List.fromList(bytes);

    _loaded = true;

    if (normalized == null) {
      unawaited(_deleteCachedLogo());
    } else {
      unawaited(_writeCachedLogo(normalized));
    }

    if (_sameBytes(_logoBytes, normalized)) {
      return;
    }

    _logoBytes = normalized;
    notifyListeners();
  }

  Future<void> _restoreCachedLogo() async {
    try {
      final file = await _cacheFile();

      if (!await file.exists()) {
        return;
      }

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        await file.delete();
        return;
      }

      final cachedLogo = Uint8List.fromList(bytes);

      if (_sameBytes(_logoBytes, cachedLogo)) {
        return;
      }

      _logoBytes = cachedLogo;
      notifyListeners();
    } catch (_) {
      // Cache access is best-effort. The APK-bundled logo remains the final
      // fallback even if device storage is temporarily unavailable.
    }
  }

  Future<void> _writeCachedLogo(Uint8List bytes) async {
    try {
      final file = await _cacheFile();
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // A cache write failure must not hide a logo that is already in memory.
    }
  }

  Future<void> _deleteCachedLogo() async {
    try {
      final file = await _cacheFile();

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Cache cleanup is best-effort.
    }
  }

  Future<File> _cacheFile() async {
    final directory = await getApplicationSupportDirectory();

    return File('${directory.path}${Platform.pathSeparator}$_cacheFileName');
  }

  bool _sameBytes(Uint8List? left, Uint8List? right) {
    if (identical(left, right)) {
      return true;
    }

    if (left == null || right == null || left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}
