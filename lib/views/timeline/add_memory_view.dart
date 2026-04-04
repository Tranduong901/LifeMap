import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/memory_model.dart';
import '../../models/memory_topic.dart';
import '../../services/cloudinary_service.dart';
import '../../services/memory_service.dart';
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
      _detectCurrentLocation(showSuccessMessage: false);
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

  @override
  Widget build(BuildContext context) {
    final String dateText = DateFormat('dd/MM/yyyy').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Chỉnh sửa kỷ niệm' : 'Thêm kỷ niệm mới'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.indigo.withValues(alpha: 0.07),
              Colors.white,
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Tiêu đề kỷ niệm',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: 'Nội dung',
                          prefixIcon: Icon(Icons.notes_rounded),
                          border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ (tùy chọn)',
                          prefixIcon: Icon(Icons.place_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTopic,
                        decoration: const InputDecoration(
                          labelText: 'Chủ đề chuyến đi',
                          prefixIcon: Icon(Icons.category_outlined),
                          border: OutlineInputBorder(),
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
                          decoration: const InputDecoration(
                            labelText: 'Nhập chủ đề riêng',
                            prefixIcon: Icon(Icons.edit_note_rounded),
                            border: OutlineInputBorder(),
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
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
                      OutlinedButton.icon(
                        onPressed: (_isSaving || _isLocating)
                            ? null
                            : _detectCurrentLocation,
                        icon: _isLocating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
                            color: Colors.indigo.withValues(alpha: 0.08),
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
                                backgroundColor: Colors.indigo,
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
                  backgroundColor: Colors.indigo,
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
      ),
    );
  }
}
