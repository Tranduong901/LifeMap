import 'package:flutter/material.dart';
import '../services/location_service.dart';

class AddressFromCoordsWidget extends StatefulWidget {
  final double lat;
  final double lng;
  const AddressFromCoordsWidget({
    required this.lat,
    required this.lng,
    super.key,
  });

  @override
  State<AddressFromCoordsWidget> createState() =>
      _AddressFromCoordsWidgetState();
}

class _AddressFromCoordsWidgetState extends State<AddressFromCoordsWidget> {
  String? _address;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final String addr = await LocationService.getAddressFromLatLng(
      widget.lat,
      widget.lng,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _address = addr;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Text(
        'Đang xác định địa chỉ...',
        style: TextStyle(fontSize: 14),
      );
    }
    return Text(
      _address ?? 'Không xác định địa chỉ',
      style: const TextStyle(fontSize: 14),
    );
  }
}
