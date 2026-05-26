import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TemperatureSettingBottomSheet extends StatefulWidget {
  final int initialTemp;
  final ValueChanged<int> onTempSelected;

  const TemperatureSettingBottomSheet({
    super.key,
    required this.initialTemp,
    required this.onTempSelected,
  });

  @override
  State<TemperatureSettingBottomSheet> createState() => _TemperatureSettingBottomSheetState();
}

class _TemperatureSettingBottomSheetState extends State<TemperatureSettingBottomSheet> {
  late int _selectedTemp;
  // Range: 60-300, Interval: 1
  final int _minTemp = 60;
  final int _maxTemp = 300;

  @override
  void initState() {
    super.initState();
    _selectedTemp = widget.initialTemp;
    // Ensure initial temp is valid
    if (_selectedTemp < _minTemp) {
      _selectedTemp = _minTemp;
    } else if (_selectedTemp > _maxTemp) {
      _selectedTemp = _maxTemp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialIndex = _selectedTemp - _minTemp;
    final scrollController = FixedExtentScrollController(
      initialItem: initialIndex >= 0 ? initialIndex : 0,
    );

    return Container(
      height: 350, // Slightly shorter as there is no repeat section
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E), // Dark background like the design
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF3DD6F5), // Cyan color
                      fontSize: 17,
                    ),
                  ),
                ),
                const Text(
                  'Set Temperature',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    widget.onTempSelected(_selectedTemp);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFF3DD6F5), // Cyan color
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Picker
          Expanded(
            child: CupertinoTheme(
              data: const CupertinoThemeData(
                brightness: Brightness.dark,
              ),
              child: CupertinoPicker(
                scrollController: scrollController,
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedTemp = _minTemp + index;
                  });
                },
                selectionOverlay: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                children: List.generate(_maxTemp - _minTemp + 1, (index) {
                  final temp = _minTemp + index;
                  return Center(
                    child: Text(
                      '$temp°C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
