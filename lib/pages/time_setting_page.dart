import 'package:flutter/material.dart';

/// 时间设置页面
class TimeSettingPage extends StatefulWidget {
  final int initialTime;
  final ValueChanged<int> onTimeChanged;

  const TimeSettingPage({super.key, 
    required this.initialTime,
    required this.onTimeChanged,
  });

  @override
  State<TimeSettingPage> createState() => _TimeSettingPageState();
}

class _TimeSettingPageState extends State<TimeSettingPage> {
  late int _time;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      appBar: AppBar(
        title: const Text('Set Time', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_time min',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 80,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            Slider(
              value: _time.toDouble(),
              min: 30,
              max: 120,
              divisions: 90,
              label: '$_time min',
              activeColor: Colors.teal,
              onChanged: (value) {
                setState(() {
                  _time = value.toInt();
                });
              },
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.remove),
                  label: const Text('-10'),
                  onPressed: () {
                    if (_time > 30) {
                      setState(() {
                        _time = (_time - 10).clamp(30, 120);
                      });
                    }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('+10'),
                  onPressed: () {
                    if (_time < 120) {
                      setState(() {
                        _time = (_time + 10).clamp(30, 120);
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () {
                widget.onTimeChanged(_time);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

