import 'package:flutter/material.dart';

class MainNavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void updateSelectedIndex(int newIndex) {
    if (newIndex == _selectedIndex) {
      return;
    }

    _selectedIndex = newIndex;
    notifyListeners();
  }
}
