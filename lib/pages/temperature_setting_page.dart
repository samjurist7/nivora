import 'package:flutter/material.dart';

/// 温度设置页面
class TemperatureSettingPage extends StatefulWidget {
  final int initialTemp;
  final ValueChanged<int> onTempChanged;

  const TemperatureSettingPage({super.key, 
    required this.initialTemp,
    required this.onTempChanged,
  });

  @override
  State<TemperatureSettingPage> createState() => _TemperatureSettingPageState();
}

class _TemperatureSettingPageState extends State<TemperatureSettingPage> {
  late int _temp;

  @override
  void initState() {
    super.initState();
    _temp = widget.initialTemp;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      appBar: AppBar(
        title: const Text('Set Temperature', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_temp°C',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 80,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            Slider(
              value: _temp.toDouble(),
              min: 60,
              max: 300,
              divisions: 240,
              label: '$_temp°C',
              activeColor: Colors.teal,
              onChanged: (value) {
                setState(() {
                  _temp = value.toInt();
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
                    if (_temp > 60) {
                      setState(() {
                        _temp = (_temp - 10).clamp(60, 300);
                      });
                    }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('+10'),
                  onPressed: () {
                    if (_temp < 300) {
                      setState(() {
                        _temp = (_temp + 10).clamp(60, 300);
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () {
                widget.onTempChanged(_temp);
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

