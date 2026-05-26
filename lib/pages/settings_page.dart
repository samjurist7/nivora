import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import '../services/bluetooth_service.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool soundOn = true;
  double brightness = 0.8;
  bool use24Hour = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      soundOn = sp.getBool('soundOn') ?? true;
      brightness = sp.getDouble('brightness') ?? 0.8;
      use24Hour = sp.getBool('use24Hour') ?? true;
    });
  }

  void _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('soundOn', soundOn);
    await sp.setDouble('brightness', brightness);
    await sp.setBool('use24Hour', use24Hour);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SwitchListTile(title: const Text('Sound'), value: soundOn, onChanged: (v) => setState(() => soundOn = v)),
            ListTile(
              title: const Text('Screen Brightness'),
              subtitle: Slider(value: brightness, onChanged: (v) => setState(() => brightness = v)),
            ),
            SwitchListTile(title: const Text('24-Hour Format'), value: use24Hour, onChanged: (v) => setState(() => use24Hour = v)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _save, child: const Text('Save Settings')),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            // Logout button
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  final userService = Provider.of<UserService>(context, listen: false);
                  final bt = Provider.of<BluetoothService>(context, listen: false);

                  // Disconnect Bluetooth
                  await bt.disconnect();

                  // Logout
                  await userService.logout();

                  // Navigate to login page
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
