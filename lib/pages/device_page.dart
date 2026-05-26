import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  @override
  Widget build(BuildContext context) {
    final bt = Provider.of<BluetoothService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Device Control')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              title: const Text('Connected Device'),
              subtitle: Text(bt.connectedDevice != null ? 'Connected' : 'Disconnected'),
              trailing: ElevatedButton(
                onPressed: bt.connectedDevice == null ? null : () async {
                  await bt.disconnect();
                  Navigator.pop(context);
                },
                child: const Text('Disconnect'),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                title: Text('Time / Equivalent'),
                subtitle: Text('Adjustable time and equivalent parameters (placeholder)'),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                title: Text('Screen Settings'),
                subtitle: Text('Brightness/Display options (placeholder)'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Sound'),
                trailing: Switch(value: true, onChanged: (v) {
                  // Implement real behavior
                }),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              child: const Text('Send Example Command'),
              onPressed: () async {
                await bt.sendCommand([0x01,0x02,0x03]);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Example command sent')));
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              child: const Text('OTA Update (Placeholder)'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTA feature to be implemented')));
              },
            )
          ],
        ),
      ),
    );
  }
}
