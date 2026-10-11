import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

Future<PlatformFile?> capturePhotoInApp(
  BuildContext context, {
  required String title,
}) {
  return Navigator.of(context).push<PlatformFile>(
    MaterialPageRoute<PlatformFile>(
      builder: (_) => PhotoCaptureScreen(title: title),
    ),
  );
}

class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({super.key, required this.title});

  final String title;

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  XFile? _capturedPhoto;

  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _disposeCamera();
      return;
    }

    if (state == AppLifecycleState.resumed && _capturedPhoto == null) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }

    try {
      await _disposeCamera();

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No device camera is available.');
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializing = false;
        _error = null;
      });
    } on CameraException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _initializing = false;
        _error = _cameraErrorMessage(exception);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _initializing = false;
        _error = 'Unable to start the camera.';
      });
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _controller;
    _controller = null;

    if (controller != null) {
      await controller.dispose();
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;

    if (_capturing ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() {
      _capturing = true;
      _error = null;
    });

    try {
      final captured = await controller.takePicture();
      final file = File(captured.path);

      if (!await file.exists() || await file.length() < 1) {
        throw CameraException(
          'InvalidCapture',
          'The captured photo is empty or unavailable.',
        );
      }

      if (!mounted) {
        return;
      }

      await _disposeCamera();

      setState(() {
        _capturedPhoto = captured;
        _capturing = false;
      });
    } on CameraException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _capturing = false;
        _error = _cameraErrorMessage(exception);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _capturing = false;
        _error = 'Unable to capture the photo.';
      });
    }
  }

  Future<void> _retake() async {
    setState(() {
      _capturedPhoto = null;
      _error = null;
    });

    await _initializeCamera();
  }

  Future<void> _usePhoto() async {
    final captured = _capturedPhoto;

    if (captured == null) {
      return;
    }

    final file = File(captured.path);

    if (!await file.exists()) {
      if (mounted) {
        setState(() {
          _error = 'The captured photo could not be accessed.';
        });
      }

      return;
    }

    final size = await file.length();

    if (size < 1) {
      if (mounted) {
        setState(() {
          _error = 'The captured photo is empty or invalid.';
        });
      }

      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(
      PlatformFile(name: _fileName(captured), size: size, path: captured.path),
    );
  }

  String _fileName(XFile captured) {
    final preferred = captured.name.trim();

    if (preferred.isNotEmpty) {
      return preferred;
    }

    final normalized = captured.path.replaceAll(r'\', '/');
    final segments = normalized.split('/');

    if (segments.isNotEmpty && segments.last.trim().isNotEmpty) {
      return segments.last.trim();
    }

    return 'tabangnow_photo.jpg';
  }

  String _cameraErrorMessage(CameraException exception) {
    return switch (exception.code) {
      'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
        'Camera access is required to take an evidence photo.',
      'CameraAccessRestricted' => 'Camera access is restricted on this device.',
      'NoCamera' => 'No device camera is available.',
      _ =>
        exception.description?.trim().isNotEmpty == true
            ? exception.description!.trim()
            : 'Unable to use the camera.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final captured = _capturedPhoto;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Column(
                children: <Widget>[
                  Expanded(child: ClipRect(child: _cameraBody(captured))),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: captured == null
                        ? _captureControls()
                        : _previewControls(),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: SafeArea(
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraBody(XFile? captured) {
    if (captured != null) {
      return SizedBox.expand(
        child: Image.file(
          File(captured.path),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, _, _) => const Center(
            child: Text(
              'Unable to preview the captured photo.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    final controller = _controller;

    if (_error != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: OutlinedButton.icon(
            onPressed: _initializeCamera,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Camera Again'),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;

        if (previewSize == null ||
            previewSize.width <= 0 ||
            previewSize.height <= 0) {
          return const Center(child: CircularProgressIndicator());
        }

        final viewportAspectRatio =
            constraints.maxWidth / constraints.maxHeight;

        final cameraAspectRatio = previewSize.height / previewSize.width;

        var scale = cameraAspectRatio / viewportAspectRatio;

        if (scale < 1) {
          scale = 1 / scale;
        }

        return ClipRect(
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Center(
              child: AspectRatio(
                aspectRatio: cameraAspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _captureControls() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _initializing || _capturing ? null : _takePhoto,
        icon: _capturing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt_rounded),
        label: Text(_capturing ? 'Capturing...' : 'Take Photo'),
      ),
    );
  }

  Widget _previewControls() {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _retake,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retake'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _usePhoto,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Use Photo'),
          ),
        ),
      ],
    );
  }
}
