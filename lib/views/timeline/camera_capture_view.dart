import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraCaptureView extends StatefulWidget {
  const CameraCaptureView({super.key});

  @override
  State<CameraCaptureView> createState() => _CameraCaptureViewState();
}

class _CameraCaptureViewState extends State<CameraCaptureView> {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'Không tìm thấy camera trên thiết bị.';
          _isInitializing = false;
        });
        return;
      }

      CameraDescription selected = cameras.first;
      for (final CameraDescription camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selected = camera;
          break;
        }
      }

      final CameraController controller = CameraController(
        selected,
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
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Không thể khởi tạo camera: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final XFile photo = await controller.takePicture();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop<XFile>(photo);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chụp ảnh thất bại: $e')));
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop<XFile>(picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chọn ảnh thất bại: $e')));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Chụp ảnh kỷ niệm'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Chọn ảnh từ thư viện'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: <Widget>[
                Positioned.fill(child: CameraPreview(_controller!)),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: FloatingActionButton(
                      onPressed: _isCapturing ? null : _takePhoto,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      child: _isCapturing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.camera_alt),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
