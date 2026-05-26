import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/bluetooth_service.dart';
import '../services/user_service.dart';
import '../services/websocket_service.dart';
import '../models/device.dart';
import '../models/device_update.dart';
import 'cloud_control_page.dart';
import 'dart:async';

/// Cloud device list page
class CloudDevicesPage extends StatefulWidget {
  const CloudDevicesPage({super.key});

  @override
  State<CloudDevicesPage> createState() => _CloudDevicesPageState();
}

class _CloudDevicesPageState extends State<CloudDevicesPage> {
  List<Device> _devices = [];
  bool _loading = false;
  StreamSubscription<DeviceUpdate>? _wsSubscription;

  // Add device dialog controllers
  final _deviceIdController = TextEditingController();
  final _deviceNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _listenToWebSocket();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  /// Listen to WebSocket device updates
  void _listenToWebSocket() {
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    _wsSubscription = wsService.deviceUpdates.listen((update) {
      // Update realtime status in device list
      setState(() {
        final index = _devices.indexWhere((d) => d.deviceId == update.deviceId);
        if (index != -1) {
          _devices[index] = _devices[index].copyWith(
            status: update.data.status ?? _devices[index].status,
            realtimeStatus: RealtimeStatus(
              relay: update.data.relay,
              ledLevel: update.data.ledLevel,
              setTime: update.data.setTime,
              setTemp: update.data.setTemp,
              rssi: update.data.rssi,
            ),
          );
        }
      });
    });
  }

  /// Load device list
  Future<void> _loadDevices() async {
    setState(() => _loading = true);

    final apiService = Provider.of<ApiService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    final token = userService.jwtToken;

    if (token == null) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in, please login first')),
      );
      return;
    }

    try {
      final devices = await apiService.getDevices(token);
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load devices: $e')),
      );
    }
  }

  /// Show add device dialog
  void _showAddDeviceDialog() {
    _deviceIdController.clear();
    _deviceNameController.clear();

    // Auto-fill device ID from connected Bluetooth device
    final bleService = Provider.of<BluetoothService>(context, listen: false);
    if (bleService.connectedDevice != null) {
      if (kIsWeb) {
        _deviceIdController.text = 'Connected Device';
      } else {
        var name = bleService.connectedDevice!.platformName;
        // If device name starts with "VOLTA_", replace with "ESP32_"
        if (name.startsWith('VOLTA_')) {
          name = name.replaceFirst('VOLTA_', 'ESP32_');
        }
        _deviceIdController.text = name.isNotEmpty ? name : 'Unknown Device';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _deviceIdController,
              decoration: const InputDecoration(
                labelText: 'Device ID',
                hintText: 'e.g. ESP32_DB56BDE0',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(
                labelText: 'Device Name (Optional)',
                hintText: 'e.g. Bedroom Device',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addDevice,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Add device
  Future<void> _addDevice() async {
    var deviceId = _deviceIdController.text.trim();
    final deviceName = _deviceNameController.text.trim();

    // If device ID starts with "VOLTA_", replace with "ESP32_"
    if (deviceId.startsWith('VOLTA_')) {
      deviceId = deviceId.replaceFirst('VOLTA_', 'ESP32_');
    }

    if (deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter device ID')),
      );
      return;
    }

    Navigator.pop(context); // Close dialog

    final apiService = Provider.of<ApiService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    final token = userService.jwtToken!;

    try {
      await apiService.addDevice(
        token,
        deviceId,
        deviceName.isEmpty ? deviceId : deviceName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device added successfully')),
      );

      // Reload device list
      _loadDevices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add device: $e')),
      );
    }
  }

  /// Delete device
  Future<void> _deleteDevice(Device device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete device "${device.name}"?\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    final token = userService.jwtToken!;

    try {
      await apiService.deleteDevice(token, device.deviceId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device deleted successfully')),
      );

      // Reload device list
      _loadDevices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete device: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_main.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top navigation bar
              _buildHeader(),

              // Device list
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF3DD6F5),
                        ),
                      )
                    : _devices.isEmpty
                        ? _buildEmptyState()
                        : _buildDeviceList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDeviceDialog,
        backgroundColor: const Color(0xFF3DD6F5),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Build top navigation bar
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Cloud Devices',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // WebSocket connection status indicator
          Consumer<WebSocketService>(
            builder: (context, wsService, child) {
              Color statusColor;
              IconData statusIcon;

              switch (wsService.status) {
                case WebSocketStatus.connected:
                  statusColor = Colors.green;
                  statusIcon = Icons.cloud_done;
                  break;
                case WebSocketStatus.connecting:
                case WebSocketStatus.reconnecting:
                  statusColor = Colors.orange;
                  statusIcon = Icons.cloud_sync;
                  break;
                case WebSocketStatus.disconnected:
                  statusColor = Colors.red;
                  statusIcon = Icons.cloud_off;
                  break;
              }

              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'No Devices',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap the + button in the bottom right to add a device',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Build device list
  Widget _buildDeviceList() {
    return RefreshIndicator(
      onRefresh: _loadDevices,
      color: const Color(0xFF3DD6F5),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          return _buildDeviceCard(_devices[index]);
        },
      ),
    );
  }

  /// Build device card
  Widget _buildDeviceCard(Device device) {
    final isOnline = device.status == 'online';
    final realtimeStatus = device.realtimeStatus;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CloudControlPage(device: device),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOnline
                ? const Color(0xFF3DD6F5).withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    device.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Device ID
            Text(
              'ID: ${device.deviceId}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),

            // Firmware version
            if (device.firmwareVersion != null) ...[
              const SizedBox(height: 4),
              Text(
                'Firmware: ${device.firmwareVersion}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],

            // Realtime status
            if (realtimeStatus != null && isOnline) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (realtimeStatus.relay != null)
                    _buildStatusChip(
                      icon: Icons.power,
                      label: realtimeStatus.relay! ? 'Heating' : 'Off',
                      color: realtimeStatus.relay! ? Colors.orange : Colors.grey,
                    ),
                  if (realtimeStatus.ledLevel != null)
                    _buildStatusChip(
                      icon: Icons.lightbulb,
                      label: 'LED ${realtimeStatus.ledLevel}',
                      color: const Color(0xFF3DD6F5),
                    ),
                  if (realtimeStatus.setTemp != null)
                    _buildStatusChip(
                      icon: Icons.thermostat,
                      label: '${realtimeStatus.setTemp}°C',
                      color: Colors.red,
                    ),
                  if (realtimeStatus.setTime != null)
                    _buildStatusChip(
                      icon: Icons.timer,
                      label: '${realtimeStatus.setTime}min',
                      color: Colors.blue,
                    ),
                ],
              ),
            ],

            // Action buttons
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _deleteDevice(device),
                  icon: const Icon(Icons.delete),
                  color: Colors.red.withOpacity(0.7),
                  iconSize: 20,
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CloudControlPage(device: device),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3DD6F5),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Control'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build status chip
  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
