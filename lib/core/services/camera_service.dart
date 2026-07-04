import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService();
});

class CameraService {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _initialized = false;

  List<CameraDescription> get cameras => _cameras;
  CameraController? get controller => _controller;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _cameras = await availableCameras();
    _initialized = true;
  }

  Future<CameraController> getController({CameraDescription? camera}) async {
    await initialize();
    final cam = camera ?? _cameras.first;
    
    if (_controller != null) {
      if (_controller!.description == cam) {
        return _controller!;
      }
      await _controller!.dispose();
    }
    
    _controller = CameraController(
      cam,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    
    await _controller!.initialize();
    return _controller!;
  }

  Future<File?> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return null;
    }
    if (_controller!.value.isTakingPicture) {
      return null;
    }
    try {
      final xfile = await _controller!.takePicture();
      // Persist into the app documents directory so scans survive OS temp
      // purges (the camera plugin writes originals to a cache dir).
      final dir = await _scansDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedFile = await File(xfile.path).copy(
        '${dir.path}/scan_$timestamp.jpg',
      );
      return savedFile;
    } catch (e) {
      return null;
    }
  }

  /// Copies an externally-sourced image (e.g. gallery pick) into the
  /// persistent scans directory and returns the persisted file.
  static Future<File> persistImage(File source) async {
    final dir = await _scansDir();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = source.path.split('.').last;
    return source.copy('${dir.path}/import_$timestamp.$ext');
  }

  /// Persistent directory for captured scans (survives temp-dir purges).
  static Future<Directory> _scansDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${baseDir.path}/scans');
    if (!scansDir.existsSync()) {
      await scansDir.create(recursive: true);
    }
    return scansDir;
  }

  Future<void> toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final current = _controller!.value.flashMode;
    await _controller!.setFlashMode(
      current == FlashMode.off ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _initialized = false;
  }
}
