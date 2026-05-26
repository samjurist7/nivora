import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TimeSettingBottomSheet extends StatefulWidget {
  final int initialTime;
  final ValueChanged<int> onTimeSelected;

  const TimeSettingBottomSheet({
    super.key,
    required this.initialTime,
    required this.onTimeSelected,
  });

  @override
  State<TimeSettingBottomSheet> createState() => _TimeSettingBottomSheetState();
}

class _TimeSettingBottomSheetState extends State<TimeSettingBottomSheet> {
  late int _selectedTime;
  // Range: 30-120, Interval: 1
  static const int _minTime = 30;
  static const int _maxTime = 120;
  final List<int> _timeOptions = List.generate(
    _maxTime - _minTime + 1,
    (index) => _minTime + index,
  );

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime.clamp(_minTime, _maxTime);
  }

  @override
  Widget build(BuildContext context) {
    final initialIndex = _timeOptions.indexOf(_selectedTime);
    final scrollController = FixedExtentScrollController(
      initialItem: initialIndex != -1 ? initialIndex : 0,
    );

    return Container(
      height: 400,
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
                  'Set Time',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    widget.onTimeSelected(_selectedTime);
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
                    _selectedTime = _timeOptions[index];
                  });
                },
                selectionOverlay: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                children: _timeOptions.map((time) {
                  return Center(
                    child: Text(
                      '$time min',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Repeat Section (Static as per request)
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildListItem('Repeat', 'Never'),
                const Divider(height: 1, color: Colors.white10, indent: 16),
                _buildListItem('Repeat', 'Never'),
                const Divider(height: 1, color: Colors.white10, indent: 16),
                _buildListItem('Repeat', 'Never'),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildListItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.4),
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
