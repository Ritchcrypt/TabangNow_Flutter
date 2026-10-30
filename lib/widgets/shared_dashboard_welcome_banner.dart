import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/dashboard_welcome_photo_service.dart';
import '../services/dao_news_service.dart';
import 'dao_news_manager.dart';

/// Shared dashboard banner for all roles. No changes to Firebase or alerts.
class SharedDashboardWelcomeBanner extends StatefulWidget {
  const SharedDashboardWelcomeBanner({
    super.key,
    required this.authService,
    required this.userName,
    required this.isAdmin,
  });

  final AuthService authService;
  final String userName;
  final bool isAdmin;

  @override
  State<SharedDashboardWelcomeBanner> createState() =>
      _SharedDashboardWelcomeBannerState();
}

class _SharedDashboardWelcomeBannerState
    extends State<SharedDashboardWelcomeBanner> with WidgetsBindingObserver {
  late final DashboardWelcomePhotoService _service;
  Timer? _refreshTimer;
  Timer? _slideTimer;
  Timer? _newsTimer;
  late final DaoNewsService _newsService;
  List<DaoNewsStory> _stories = <DaoNewsStory>[];
  int _slideIndex = 0;
  bool _newsBusy = false;
  String? _version;
  Uint8List? _imageBytes;
  bool _checking = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = DashboardWelcomePhotoService(authService: widget.authService);
    _newsService = DaoNewsService(authService: widget.authService);
    unawaited(_loadNews());
    _startNewsTimers();
    unawaited(_refresh(force: true));
    _startRefresh();
  }

  void _startRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_refresh()),
    );
  }

  void _startNewsTimers() {
    _slideTimer?.cancel();
    _newsTimer?.cancel();
    _slideTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && _stories.isNotEmpty) {
        setState(() => _slideIndex = (_slideIndex + 1) % (_stories.length + 1));
      }
    });
    _newsTimer = Timer.periodic(const Duration(seconds: 60), (_) => unawaited(_loadNews()));
  }

  Future<void> _loadNews() async {
    if (_newsBusy) return;
    _newsBusy = true;
    try {
      final stories = await _newsService.stories();
      if (!mounted) return;
      setState(() {
        _stories = stories;
        if (_slideIndex > _stories.length) _slideIndex = 0;
      });
    } catch (_) {
      // Backend route may not be installed yet; retain the welcome photo.
      // Existing slides remain available during transient loss of connection.
    } finally {
      _newsBusy = false;
    }
  }

  void _shift(int direction) {
    if (_stories.isEmpty || !mounted) return;
    setState(() {
      final total = _stories.length + 1;
      _slideIndex = (_slideIndex + direction + total) % total;
    });
  }

  Future<void> _openCurrent() async {
    if (_slideIndex == 0 || _slideIndex > _stories.length) return;
    final uri = _stories[_slideIndex - 1].safeUri;
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) _message('Unable to open the publisher.');
    } catch (_) {
      _message('Unable to open the publisher.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRefresh();
      _startNewsTimers();
      unawaited(_refresh());
      unawaited(_loadNews());
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _slideTimer?.cancel();
      _newsTimer?.cancel();
    }
  }

  Future<void> _refresh({bool force = false}) async {
    if (_checking || _uploading && !force) return;
    _checking = true;
    try {
      final nextVersion = await _service.version();
      if (!mounted) return;
      if (force || nextVersion != _version || _imageBytes == null) {
        final nextImage = await _service.photoBytes();
        if (!mounted) return;
        setState(() {
          _imageBytes = nextImage;
          _version = nextVersion;
        });
      }
    } catch (_) {
      // Offline / API not yet deployed: show the existing neutral banner.
      // Never disrupt dashboard loading or notification delivery.
    } finally {
      _checking = false;
    }
  }

  Future<void> _choosePhoto() async {
    if (!widget.isAdmin || _uploading) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.single;
      const maxBytes = 5 * 1024 * 1024;
      const allowed = <String>{'jpg', 'jpeg', 'png', 'webp'};
      if (file.size > maxBytes || !allowed.contains(file.extension?.toLowerCase())) {
        _message('Choose a JPG, PNG or WebP image up to 5 MB.');
        return;
      }
      setState(() => _uploading = true);
      await _service.upload(file);
      // Show the new photo immediately on this device; other users poll.
      await _refresh(force: true);
      if (mounted) _message('Dashboard photo updated for all roles.');
    } on Exception catch (error) {
      if (mounted) {
        _message(error is AuthException ? error.userMessage :
          'Unable to upload the dashboard photo.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _slideTimer?.cancel();
    _newsTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final article = _slideIndex > 0 && _slideIndex <= _stories.length
        ? _stories[_slideIndex - 1] : null;
    final total = _stories.length + 1;
    const colorSets = <List<Color>>[
      <Color>[Color(0xFF061B33), Color(0xFF245968)],
      <Color>[Color(0xFF172A40), Color(0xFF25605B)],
      <Color>[Color(0xFF18223D), Color(0xFF42496F)],
      <Color>[Color(0xFF1D3040), Color(0xFF506441)],
    ];
    final newsColors = colorSets[_slideIndex == 0 ? 0 : (_slideIndex - 1) % colorSets.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 166,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (detail) {
                final velocity = detail.primaryVelocity ?? 0;
                if (velocity < -50) _shift(1);
                if (velocity > 50) _shift(-1);
              },
              child: Stack(fit: StackFit.expand, children: <Widget>[
                if (article == null && _imageBytes != null)
                  Image.memory(_imageBytes!, fit: BoxFit.cover, gaplessPlayback: true)
                else
                  DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: article == null
                          ? const <Color>[Color(0xFF111C34), Color(0xFF234861)]
                          : newsColors,
                    ),
                  )),
                const DecoratedBox(decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                    colors: <Color>[Color(0xE6091428), Color(0x99091428), Color(0x1A091428)],
                  ),
                )),
                IgnorePointer(child: Padding(
                  padding: EdgeInsets.fromLTRB(20, widget.isAdmin ? 42 : 18, 20, 29),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: article == null ? <Widget>[
                      const Text('Welcome back,', style: TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(widget.userName, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 25,
                          fontWeight: FontWeight.w800)),
                    ] : <Widget>[
                      const Text('DAO, CAPIZ', style: TextStyle(
                        color: Color(0xFFBFE9FF), fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 7),
                      Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 19,
                          fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text('${article.source} · ${article.published ?? ''}',
                        style: const TextStyle(color: Color(0xFFE4F1FF), fontSize: 11)),
                    ],
                  ),
                )),
                // These transparent tap zones have NO visible arrow buttons.
                Positioned.fill(child: Row(children: <Widget>[
                  Expanded(flex: 18, child: Semantics(
                    button: true, label: 'Previous slide',
                    child: GestureDetector(behavior: HitTestBehavior.opaque,
                      onTap: () => _shift(-1)),
                  )),
                  Expanded(flex: 64, child: Semantics(
                    button: article != null,
                    label: article == null ? 'Welcome photo' : 'Tap center to open',
                    child: GestureDetector(behavior: HitTestBehavior.opaque,
                      onTap: _openCurrent),
                  )),
                  Expanded(flex: 18, child: Semantics(
                    button: true, label: 'Next slide',
                    child: GestureDetector(behavior: HitTestBehavior.opaque,
                      onTap: () => _shift(1)),
                  )),
                ])),
                Positioned(left: 12, bottom: 7, child: IgnorePointer(child: Text(
                  article == null ? 'Tap edges to browse' : 'Tap edges to browse · Tap center to open',
                  style: const TextStyle(color: Color(0xFFE8F1FC), fontSize: 10),
                ))),
                Positioned(right: 12, bottom: 7, child: IgnorePointer(child: Text(
                  '${_slideIndex + 1} / $total',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ))),
                if (widget.isAdmin)
                  Positioned(top: 10, right: 10, child: Semantics(
                    button: true, label: 'Change dashboard photo',
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : _choosePhoto,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xDD101A31),
                        side: const BorderSide(color: Color(0xCCFFFFFF)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: _uploading
                          ? const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.camera_alt_outlined, size: 17),
                      label: Text(_uploading ? 'Uploading...' : 'Change photo',
                        style: const TextStyle(fontSize: 12)),
                    ),
                  )),
              ]),
            ),
          ),
        ),
        if (widget.isAdmin)
          DaoNewsManager(service: _newsService, onChanged: () => unawaited(_loadNews())),
      ],
    );
  }
}
