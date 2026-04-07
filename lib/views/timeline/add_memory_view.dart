import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/memory_model.dart';
import '../../models/memory_topic.dart';
import '../../services/cloudinary_service.dart';
import '../../services/memory_service.dart';
import '../../services/location_service.dart';
import 'camera_capture_view.dart';

class AddMemoryView extends StatefulWidget {
  const AddMemoryView({super.key, this.initialMemory});

  final MemoryModel? initialMemory;

  @override
  State<AddMemoryView> createState() => _AddMemoryViewState();
}

class _AddMemoryViewState extends State<AddMemoryView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _customTopicController = TextEditingController();

  final MemoryService _memoryService = MemoryService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  DateTime _selectedDate = DateTime.now();
  double? _latitude;
  double? _longitude;
  double? _gpsAccuracy;
  DateTime? _lastGpsAt;

  List<String> _imageUrls = <String>[];
  String _selectedTopic = MemoryTopic.citywalk;
  bool _isSaving = false;
  bool _isLocating = false;

  bool get _isEditMode => widget.initialMemory != null;

  @override
  void initState() {
    super.initState();
    final MemoryModel? initial = widget.initialMemory;
    if (initial != null) {
      _titleController.text = initial.title;
      _descriptionController.text = initial.description;
      _addressController.text = initial.address;
      _selectedDate = initial.date;
      _latitude = initial.lat;
      _longitude = initial.lng;
      _selectedTopic = initial.topic.isEmpty
          ? MemoryTopic.citywalk
          : initial.topic;
      if (!MemoryTopic.presets.contains(_selectedTopic)) {
        _customTopicController.text = _selectedTopic;
        _selectedTopic = MemoryTopic.custom;
      }

      _imageUrls = initial.imageUrls.toList();
      if (_imageUrls.isEmpty && initial.imageUrl.trim().isNotEmpty) {
        _imageUrls = <String>[initial.imageUrl.trim()];
      }
    } else {
      Future.microtask(_initializeCreateModeAsync);
    }
  }

  Future<void> _initializeCreateModeAsync() async {
    await _detectCurrentLocation(showSuccessMessage: false);
  }

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[AddMemoryView] $message');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _customTopicController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _detectCurrentLocation({bool showSuccessMessage = true}) async {
    setState(() => _isLocating = true);

    try {
      final bool isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        _showMessage('Vui lòng bật GPS để lấy vị trí hiện tại.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Ứng dụng chưa được cấp quyền vị trí.');
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _gpsAccuracy = position.accuracy;
        _lastGpsAt = position.timestamp;
      });

      // Try to resolve address automatically if address field is empty
      try {
        final String resolved = await LocationService.getAddressFromLatLng(
          _latitude!,
          _longitude!,
        );
        if (mounted && _addressController.text.trim().isEmpty) {
          setState(() => _addressController.text = resolved);
        }
      } catch (e) {
        _logDebug('Reverse geocoding thất bại: $e');
      }

      if (showSuccessMessage) {
        _showMessage('Đã lấy vị trí GPS chính xác.');
      }
    } catch (e) {
      _showMessage('Không thể lấy GPS: $e');
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _uploadFromXFile(XFile file) async {
    final String uploadedUrl = await _cloudinaryService.uploadImageFile(
      File(file.path),
    );

    if (!uploadedUrl.contains('cloudinary.com')) {
      throw Exception('Ảnh chưa được lưu đúng trên Cloudinary.');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _imageUrls = <String>{uploadedUrl, ..._imageUrls}.toList(growable: false);
    });
  }

  Future<void> _captureAndUploadImage() async {
    try {
      setState(() => _isSaving = true);

      final XFile? image = await Navigator.of(context).push<XFile>(
        MaterialPageRoute<XFile>(
          builder: (BuildContext context) => const CameraCaptureView(),
        ),
      );

      if (image == null) {
        return;
      }

      await _uploadFromXFile(image);
      _showMessage('Tải ảnh lên Cloudinary thành công.');
    } catch (e) {
      _showMessage('Chụp hoặc tải ảnh thất bại: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickFromGalleryAndUpload() async {
    try {
      setState(() => _isSaving = true);

      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        return;
      }

      await _uploadFromXFile(picked);
      _showMessage('Tải ảnh lên Cloudinary thành công.');
    } catch (e) {
      _showMessage('Chọn hoặc tải ảnh thất bại: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  bool _isGpsFresh() {
    if (_lastGpsAt == null) {
      return false;
    }
    final Duration diff = DateTime.now().difference(_lastGpsAt!);
    return diff.inSeconds <= 20;
  }

  Future<void> _saveMemory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_imageUrls.isEmpty) {
      _showMessage('Vui lòng thêm ít nhất 1 ảnh trước khi lưu kỷ niệm.');
      return;
    }

    if (!_isGpsFresh()) {
      await _detectCurrentLocation(showSuccessMessage: false);
    }

    if (_latitude == null || _longitude == null) {
      _showMessage('Vui lòng lấy vị trí GPS trước khi lưu.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Người dùng chưa đăng nhập.');
      }

      final String finalAddress = _addressController.text.trim().isEmpty
          ? 'Tọa độ: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
          : _addressController.text.trim();

      final String customTopic = _customTopicController.text.trim();
      final String finalTopic = _selectedTopic == MemoryTopic.custom
          ? customTopic.toLowerCase()
          : _selectedTopic;

      if (finalTopic.isEmpty) {
        _showMessage('Vui lòng nhập chủ đề riêng hoặc chọn chủ đề có sẵn.');
        return;
      }

      final MemoryModel memory = MemoryModel(
        id: widget.initialMemory?.id ?? '',
        userId: currentUser.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrls.first,
        imageUrls: _imageUrls,
        topic: finalTopic,
        lat: _latitude!,
        lng: _longitude!,
        date: _selectedDate,
        address: finalAddress,
      );

      if (_isEditMode) {
        await _memoryService.updateMemory(memory);
      } else {
        await _memoryService.saveMemory(memory);
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        _isEditMode
            ? 'Cập nhật kỷ niệm thành công.'
            : 'Thêm kỷ niệm thành công.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage('Không thể lưu kỷ niệm: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF9575CD), width: 1.4),
      ),
    );
  }

  Future<void> _setLocationFromMapTap(ll.LatLng point) async {
    setState(() {
      _latitude = point.latitude;
      _longitude = point.longitude;
      _lastGpsAt = DateTime.now();
      _gpsAccuracy = null;
    });

    try {
      final String resolved = await LocationService.getAddressFromLatLng(
        point.latitude,
        point.longitude,
      );
      if (mounted) {
        setState(() => _addressController.text = resolved);
      }
    } catch (e) {
      _logDebug('Reverse geocoding từ mini-map thất bại: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String dateText = DateFormat('dd/MM/yyyy').format(_selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Chỉnh sửa kỷ niệm' : 'Thêm kỷ niệm mới',
          style: const TextStyle(
            color: Color(0xFF9575CD),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF9575CD),
        elevation: 0,
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0x2278909C)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              color: Colors.white,
              elevation: 0.8,
              shadowColor: const Color(0x2278909C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      controller: _titleController,
                      decoration: _fieldDecoration(
                        label: 'Tiêu đề kỷ niệm',
                        icon: Icons.title,
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tiêu đề.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: _fieldDecoration(
                        label: 'Nội dung',
                        icon: Icons.notes_rounded,
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập nội dung kỷ niệm.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: _fieldDecoration(
                        label: 'Địa chỉ (tùy chọn)',
                        icon: Icons.place_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTopic,
                      decoration: _fieldDecoration(
                        label: 'Chủ đề chuyến đi',
                        icon: Icons.category_outlined,
                      ),
                      items: MemoryTopic.values
                          .map(
                            (String topic) => DropdownMenuItem<String>(
                              value: topic,
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.circle,
                                    size: 12,
                                    color: MemoryTopic.color(topic),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(MemoryTopic.label(topic)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isSaving
                          ? null
                          : (String? value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _selectedTopic = value);
                            },
                    ),
                    if (_selectedTopic == MemoryTopic.custom) ...<Widget>[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customTopicController,
                        decoration: _fieldDecoration(
                          label: 'Nhập chủ đề riêng',
                          icon: Icons.edit_note_rounded,
                        ),
                        validator: (String? value) {
                          if (_selectedTopic != MemoryTopic.custom) {
                            return null;
                          }
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập chủ đề riêng.';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month),
                      title: const Text('Ngày kỷ niệm'),
                      subtitle: Text(dateText),
                      trailing: TextButton(
                        onPressed: _isSaving ? null : _pickDate,
                        child: const Text('Chọn ngày'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              elevation: 0.8,
              shadowColor: const Color(0x2278909C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.my_location),
                        SizedBox(width: 8),
                        Text(
                          'Vị trí GPS',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _latitude == null || _longitude == null
                          ? 'Chưa có vị trí'
                          : 'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                    ),
                    if (_gpsAccuracy != null)
                      Text(
                        'Độ chính xác: ±${_gpsAccuracy!.toStringAsFixed(1)} m',
                      ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFF9575CD,
                            ).withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: ll.LatLng(
                              _latitude ?? 21.0285,
                              _longitude ?? 105.8542,
                            ),
                            initialZoom: _latitude == null ? 10 : 15,
                            onTap: (_, ll.LatLng point) {
                              _setLocationFromMapTap(point);
                            },
                          ),
                          children: <Widget>[
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
                              subdomains: const <String>['a', 'b', 'c'],
                              userAgentPackageName: 'vn.edu.tlu.nhom7.lifemap',
                            ),
                            if (_latitude != null && _longitude != null)
                              MarkerLayer(
                                markers: <Marker>[
                                  Marker(
                                    point: ll.LatLng(_latitude!, _longitude!),
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: Color(0xFF9575CD),
                                      size: 34,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: (_isSaving || _isLocating)
                          ? null
                          : _detectCurrentLocation,
                      icon: _isLocating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.gps_fixed),
                      label: const Text('Lấy vị trí chính xác'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              elevation: 0.8,
              shadowColor: const Color(0x2278909C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.photo_camera_outlined),
                        SizedBox(width: 8),
                        Text(
                          'Ảnh kỷ niệm',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_imageUrls.isNotEmpty)
                      Column(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _imageUrls.first,
                              height: 190,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (
                                    BuildContext context,
                                    Widget child,
                                    ImageChunkEvent? loadingProgress,
                                  ) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }
                                    return Container(
                                      height: 190,
                                      width: double.infinity,
                                      color: Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                              errorBuilder:
                                  (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stackTrace,
                                  ) {
                                    return Container(
                                      height: 190,
                                      width: double.infinity,
                                      color: Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 66,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _imageUrls.length,
                              separatorBuilder: (_, int separatorIndex) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (BuildContext context, int index) {
                                final String url = _imageUrls[index];
                                return Stack(
                                  children: <Widget>[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        url,
                                        width: 66,
                                        height: 66,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (
                                              BuildContext context,
                                              Widget child,
                                              ImageChunkEvent? loadingProgress,
                                            ) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Container(
                                                width: 66,
                                                height: 66,
                                                color: Colors.grey.shade200,
                                                alignment: Alignment.center,
                                                child: const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              );
                                            },
                                        errorBuilder:
                                            (
                                              BuildContext context,
                                              Object error,
                                              StackTrace? stackTrace,
                                            ) {
                                              return Container(
                                                width: 66,
                                                height: 66,
                                                color: Colors.grey.shade200,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: InkWell(
                                        onTap: _isSaving
                                            ? null
                                            : () {
                                                setState(() {
                                                  _imageUrls.removeAt(index);
                                                });
                                              },
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 130,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFF0F2F5),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Chưa có ảnh'),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : _captureAndUploadImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9575CD),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Mở máy ảnh'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : _pickFromGalleryAndUpload,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Chọn từ thư viện'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveMemory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9575CD),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEditMode ? 'Cập nhật kỷ niệm' : 'Lưu kỷ niệm'),
            ),
          ],
        ),
      ),
    );
  }
}
