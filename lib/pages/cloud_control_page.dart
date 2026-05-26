import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../services/websocket_service.dart';
import '../models/device.dart';
import '../models/device_update.dart';

/// Cloud device control page
class CloudControlPage extends StatefulWidget {
  final Device device;

  const CloudControlPage({super.key, required this.device});

  @override
  State<CloudControlPage> createState() => _CloudControlPageState();
}

class _CloudControlPageState extends State<CloudControlPage> {
  // Device realtime status
  bool _relay = false;
  int _ledLevel = 0;
  int _setTemp = 200;
  int _setTime = 60;
  int? _rssi;

  // Scroll controllers
  FixedExtentScrollController? _tempScrollController;
  FixedExtentScrollController? _timeScrollController;

  // Temperature and time range
  static const int _minTemp = 150;
  static const int _maxTemp = 280;
  static const int _tempStep = 1;
  static const int _minTime = 30;
  static const int _maxTime = 120;

  List<int> get _tempValues =>
      List.generate(((_maxTemp - _minTemp) ~/ _tempStep) + 1, (i) => _minTemp + i * _tempStep);
  List<int> get _timeValues =>
      List.generate(_maxTime - _minTime + 1, (i) => _minTime + i);

  // Command sending status
  bool _sendingCommand = false;

  // Preset image update
  int _selectedPresetNum = 0;
  bool _uploadingPreset = false;
  String _presetStatus = '';

  // Screensaver animation update
  bool _uploadingScreensaver = false;
  bool _screensaverConverted = false;
  String _screensaverStatus = '';
  double? _screensaverSizeKb;

  // WebSocket subscription
  StreamSubscription<DeviceUpdate>? _wsSubscription;

  // Whether user is scrolling
  bool _isUserScrollingTemp = false;
  bool _isUserScrollingTime = false;

  // Last synced values (to prevent duplicate sync)
  int _lastSyncedTemp = 0;
  int _lastSyncedTime = 0;

  @override
  void initState() {
    super.initState();
    _initializeFromDevice();
    _initScrollControllers();
    _listenToWebSocket();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _tempScrollController?.dispose();
    _timeScrollController?.dispose();
    super.dispose();
  }

  /// Initialize from device
  void _initializeFromDevice() {
    final realtimeStatus = widget.device.realtimeStatus;
    if (realtimeStatus != null) {
      _relay = realtimeStatus.relay ?? false;
      _ledLevel = realtimeStatus.ledLevel ?? 0;
      _setTemp = realtimeStatus.setTemp ?? 200;
      _setTime = realtimeStatus.setTime ?? 60;
      _rssi = realtimeStatus.rssi;
    }
    _lastSyncedTemp = _setTemp;
    _lastSyncedTime = _setTime;
  }

  /// Initialize scroll controllers
  void _initScrollControllers() {
    final tempIndex = _tempValues.indexOf(_setTemp);
    final timeIndex = _timeValues.indexOf(_setTime);

    _tempScrollController = FixedExtentScrollController(
      initialItem: tempIndex >= 0 ? tempIndex : (_tempValues.length ~/ 2),
    );
    _timeScrollController = FixedExtentScrollController(
      initialItem: timeIndex >= 0 ? timeIndex : 0,
    );
  }

  /// Listen to WebSocket device updates
  void _listenToWebSocket() {
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    _wsSubscription = wsService.deviceUpdates.listen((update) {
      if (update.deviceId == widget.device.deviceId) {
        setState(() {
          if (update.data.relay != null) _relay = update.data.relay!;
          if (update.data.ledLevel != null) _ledLevel = update.data.ledLevel!;
          if (update.data.rssi != null) _rssi = update.data.rssi;

          // Update temperature and time only when user is not scrolling
          if (!_isUserScrollingTemp && update.data.setTemp != null) {
            final newTemp = update.data.setTemp!;
            if (newTemp != _lastSyncedTemp) {
              _setTemp = newTemp;
              _lastSyncedTemp = newTemp;
              final tempIndex = _tempValues.indexOf(newTemp);
              if (tempIndex >= 0) {
                _tempScrollController?.jumpToItem(tempIndex);
              }
            }
          }

          if (!_isUserScrollingTime && update.data.setTime != null) {
            final newTime = update.data.setTime!;
            if (newTime != _lastSyncedTime) {
              _setTime = newTime;
              _lastSyncedTime = newTime;
              final timeIndex = _timeValues.indexOf(newTime);
              if (timeIndex >= 0) {
                _timeScrollController?.jumpToItem(timeIndex);
              }
            }
          }
        });
      }
    });
  }

  /// Send control command
  Future<void> _sendControl(String action, {int? level, int? value}) async {
    if (_sendingCommand) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    final token = userService.jwtToken;

    if (token == null) {
      _showError('Not logged in, please login first');
      return;
    }

    setState(() => _sendingCommand = true);

    try {
      await apiService.controlDevice(
        token,
        widget.device.deviceId,
        action,
        level: level,
        value: value,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Command sent: $action'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to send command: $e');
    } finally {
      if (mounted) {
        setState(() => _sendingCommand = false);
      }
    }
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Trigger OTA update
  Future<void> _triggerOTA() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firmware Update'),
        content: const Text('Are you sure you want to update the firmware for this device?\nDo not disconnect power during the update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    final token = userService.jwtToken;

    if (token == null) {
      _showError('Not logged in, please login first');
      return;
    }

    setState(() => _sendingCommand = true);

    try {
      await apiService.triggerOTA(token, widget.device.deviceId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTA update triggered, device will automatically download and install firmware'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to trigger OTA: $e');
    } finally {
      if (mounted) {
        setState(() => _sendingCommand = false);
      }
    }
  }

  /// Trigger SD card update
  Future<void> _triggerSdcardUpdate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SD Card Update'),
        content: const Text('Are you sure you want to update the SD card files for this device?\nThe device will download sdcard.tar and restart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    final token = userService.jwtToken;

    if (token == null) {
      _showError('Not logged in, please login first');
      return;
    }

    setState(() => _sendingCommand = true);

    try {
      await apiService.triggerSdcardUpdate(token, widget.device.deviceId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SD card update command sent'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to trigger SD card update: $e');
    } finally {
      if (mounted) {
        setState(() => _sendingCommand = false);
      }
    }
  }

  /// Trigger SPIFFS OTA update
  Future<void> _triggerSpiffsOta() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SPIFFS OTA Update'),
        content: const Text('Are you sure you want to update the SPIFFS partition for this device?\nThe device will download spiffs.bin, flash the SPIFFS partition, and restart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    final token = userService.jwtToken;

    if (token == null) {
      _showError('Not logged in, please login first');
      return;
    }

    setState(() => _sendingCommand = true);

    try {
      await apiService.triggerSpiffsOta(token, widget.device.deviceId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SPIFFS OTA triggered, device will download and flash SPIFFS partition'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to trigger SPIFFS OTA: $e');
    } finally {
      if (mounted) {
        setState(() => _sendingCommand = false);
      }
    }
  }

  /// Pick, crop and upload a preset image
  Future<void> _pickCropAndUploadPreset() async {
    // Reset status at the start of every attempt
    setState(() => _presetStatus = '');

    final apiService = Provider.of<ApiService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    final token = userService.jwtToken;

    if (token == null) {
      _showError('Not logged in, please login first');
      return;
    }

    // Step 1: Pick image — create a fresh ImagePicker each time
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) {
      setState(() => _presetStatus = 'No image selected');
      return;
    }

    // Step 2: Crop to exact 358×201 PNG (cropper handles resize natively)
    setState(() => _presetStatus = 'Cropping...');
    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 358, ratioY: 201),
        maxWidth: 358,
        maxHeight: 201,
        compressFormat: ImageCompressFormat.png,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Preset Image',
            toolbarColor: const Color(0xFF3DD6F5),
            toolbarWidgetColor: Colors.black,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Preset Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
          WebUiSettings(context: context),
        ],
      );
    } catch (e) {
      setState(() => _presetStatus = 'Crop error: $e');
      return;
    }

    if (cropped == null) {
      setState(() => _presetStatus = 'Crop cancelled');
      return;
    }

    // Step 3: Read bytes directly — no extra processing needed
    final pngBytes = await cropped.readAsBytes();

    // Step 4: Upload and push to device
    final filename = 'preset_$_selectedPresetNum.png';
    final spiffsPath = '/spiffs/heatPreset/preset_$_selectedPresetNum.png';

    setState(() {
      _uploadingPreset = true;
      _presetStatus =
          'Uploading $filename (${(pngBytes.length / 1024).toStringAsFixed(1)}KB)...';
    });

    try {
      final uploadData = await apiService.uploadPresetImage(
          token, _selectedPresetNum, pngBytes, filename);
      final sizeKb = ((uploadData['size'] as num?) ?? pngBytes.length) / 1024;

      setState(() {
        _presetStatus =
            'Uploaded (${sizeKb.toStringAsFixed(1)}KB), pushing to device...';
      });

      await apiService.triggerPresetPush(
          token, widget.device.deviceId, filename, spiffsPath);

      if (!mounted) return;
      setState(() {
        _presetStatus = 'Done! Device is writing $spiffsPath';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preset $_selectedPresetNum updated successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _presetStatus = 'Upload error: $e');
    } finally {
      if (mounted) setState(() => _uploadingPreset = false);
    }
  }

  /// Pick a video and upload to server for screensaver GIF conversion
  Future<void> _pickAndUploadScreensaver() async {
    setState(() {
      _screensaverStatus = '';
      _screensaverConverted = false;
      _screensaverSizeKb = null;
    });

    final userService = Provider.of<UserService>(context, listen: false);
    final token = userService.jwtToken;
    if (token == null) {
      _showError('Not logged in, please login first');
      return;
    }

    final picked =
        await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) {
      setState(() => _screensaverStatus = 'No video selected');
      return;
    }

    final videoBytes = await picked.readAsBytes();
    final filename = picked.name;

    setState(() {
      _uploadingScreensaver = true;
      _screensaverStatus =
          'Uploading and converting (${(videoBytes.length / 1024 / 1024).toStringAsFixed(1)}MB), please wait...';
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.uploadAndConvertScreensaver(
          token, videoBytes, filename);

      final sizeKb = ((result['size'] as num?) ?? 0) / 1024;
      if (!mounted) return;
      setState(() {
        _screensaverSizeKb = sizeKb;
        _screensaverConverted = true;
        _screensaverStatus =
            'Converted! GIF size: ${sizeKb.toStringAsFixed(1)}KB';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _screensaverStatus = 'Error: $e');
    } finally {
      if (mounted) setState(() => _uploadingScreensaver = false);
    }
  }

  /// Push the converted screensaver GIF to the device
  Future<void> _pushScreensaverToDevice() async {
    final userService = Provider.of<UserService>(context, listen: false);
    final token = userService.jwtToken;
    if (token == null) {
      _showError('Not logged in, please login first');
      return;
    }

    setState(() {
      _uploadingScreensaver = true;
      _screensaverStatus = 'Pushing to device...';
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.triggerPresetPush(
        token,
        widget.device.deviceId,
        'screensaver_output.gif',
        '/spiffs/gif/output.gif',
      );

      if (!mounted) return;
      setState(() =>
          _screensaverStatus = 'Done! Device is writing /spiffs/gif/output.gif');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Screensaver pushed to device'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _screensaverStatus = 'Push error: $e');
    } finally {
      if (mounted) setState(() => _uploadingScreensaver = false);
    }
  }

  /// Temperature change callback
  void _onTempChanged(int index) {
    if (index < 0 || index >= _tempValues.length) return;

    setState(() {
      _setTemp = _tempValues[index];
      _isUserScrollingTemp = true;
    });

    // Release edit lock after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isUserScrollingTemp = false);
      }
    });
  }

  /// Time change callback
  void _onTimeChanged(int index) {
    if (index < 0 || index >= _timeValues.length) return;

    setState(() {
      _setTime = _timeValues[index];
      _isUserScrollingTime = true;
    });

    // Release edit lock after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isUserScrollingTime = false);
      }
    });
  }

  /// Apply temperature and time settings
  Future<void> _applyTempTime() async {
    // Send temperature setting
    await _sendControl('set_temp', value: _setTemp);
    await Future.delayed(const Duration(milliseconds: 200));
    // Send time setting
    await _sendControl('set_time', value: _setTime);
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.device.status == 'online';

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
              _buildHeader(isOnline),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildDeviceInfo(isOnline),
                      const SizedBox(height: 30),
                      _buildRelayControl(isOnline),
                      const SizedBox(height: 30),
                      _buildLEDControl(isOnline),
                      const SizedBox(height: 30),
                      _buildTempTimeControl(isOnline),
                      const SizedBox(height: 30),
                      _buildOTAButton(isOnline),
                      const SizedBox(height: 30),
                      _buildSpiffsOTAButton(isOnline),
                      const SizedBox(height: 30),
                      _buildPresetImgUpdate(isOnline),
                      const SizedBox(height: 30),
                      _buildScreensaverUpdate(isOnline),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build top navigation bar
  Widget _buildHeader(bool isOnline) {
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.device.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.device.deviceId,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Online status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOnline
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: isOnline ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: isOnline ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build device info
  Widget _buildDeviceInfo(bool isOnline) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3DD6F5).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                icon: Icons.thermostat,
                label: 'Temperature',
                value: '$_setTemp°C',
                color: Colors.red,
              ),
              _buildInfoItem(
                icon: Icons.timer,
                label: 'Time',
                value: '$_setTime min',
                color: Colors.blue,
              ),
            ],
          ),
          if (_rssi != null) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.signal_cellular_alt,
                  color: Colors.white.withOpacity(0.6),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Signal: $_rssi dBm',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Build relay control
  Widget _buildRelayControl(bool isOnline) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _relay
              ? Colors.orange.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.power,
                color: _relay ? Colors.orange : Colors.grey,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                _relay ? 'Heating ON' : 'Heating OFF',
                style: TextStyle(
                  color: _relay ? Colors.orange : Colors.white70,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isOnline && !_sendingCommand
                      ? () => _sendControl('relay_on')
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Turn ON',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: isOnline && !_sendingCommand
                      ? () => _sendControl('relay_off')
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Turn OFF',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build LED control
  Widget _buildLEDControl(bool isOnline) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3DD6F5).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb,
                color: Color(0xFF3DD6F5),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'LED Level: $_ledLevel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(6, (index) {
              final isCurrent = index == _ledLevel;
              return GestureDetector(
                onTap: isOnline && !_sendingCommand
                    ? () => _sendControl('led_level', level: index)
                    : null,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? const Color(0xFF3DD6F5).withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFF3DD6F5)
                          : Colors.white.withOpacity(0.2),
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        color: isCurrent
                            ? const Color(0xFF3DD6F5)
                            : Colors.white70,
                        fontSize: 20,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: isOnline && !_sendingCommand
                ? () => _sendControl('led_off')
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.withOpacity(0.3),
            ),
            child: const Text('Turn Off LED'),
          ),
        ],
      ),
    );
  }

  /// Build temperature and time control
  Widget _buildTempTimeControl(bool isOnline) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Temperature & Time Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Temperature scroll selector
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Temperature',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListWheelScrollView.useDelegate(
                        controller: _tempScrollController,
                        itemExtent: 40,
                        physics: const FixedExtentScrollPhysics(),
                        perspective: 0.002,
                        diameterRatio: 1.2,
                        onSelectedItemChanged: _onTempChanged,
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _tempValues.length,
                          builder: (context, index) {
                            return Center(
                              child: Text(
                                '${_tempValues[index]}°C',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Time scroll selector
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Time',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListWheelScrollView.useDelegate(
                        controller: _timeScrollController,
                        itemExtent: 40,
                        physics: const FixedExtentScrollPhysics(),
                        perspective: 0.002,
                        diameterRatio: 1.2,
                        onSelectedItemChanged: _onTimeChanged,
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _timeValues.length,
                          builder: (context, index) {
                            return Center(
                              child: Text(
                                '${_timeValues[index]} min',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isOnline && !_sendingCommand ? _applyTempTime : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3DD6F5),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.withOpacity(0.3),
            ),
            child: _sendingCommand
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text(
                    'Apply Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  /// Build SPIFFS OTA button
  Widget _buildSpiffsOTAButton(bool isOnline) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6f42c1).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_special,
                color: Color(0xFF6f42c1),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'SPIFFS OTA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Flash SPIFFS partition with spiffs.bin',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isOnline && !_sendingCommand ? _triggerSpiffsOta : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6f42c1),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.withOpacity(0.3),
            ),
            child: const Text(
              'Trigger SPIFFS OTA',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Build preset image update section
  Widget _buildPresetImgUpdate(bool isOnline) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.image, color: Colors.orange, size: 24),
              SizedBox(width: 12),
              Text(
                'Update Preset Image',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Upload and push a 358×201 PNG to device SPIFFS',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Preset:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedPresetNum,
                      dropdownColor: const Color(0xFF1A1A2E),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onChanged: _uploadingPreset
                          ? null
                          : (v) => setState(() => _selectedPresetNum = v ?? 0),
                      items: List.generate(
                        6,
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text('Preset $i'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_presetStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _presetStatus,
                style: TextStyle(
                  color: _presetStatus.startsWith('Error')
                      ? Colors.red
                      : _presetStatus.startsWith('Done')
                          ? Colors.green
                          : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: isOnline && !_sendingCommand && !_uploadingPreset
                ? _pickCropAndUploadPreset
                : null,
            icon: _uploadingPreset
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.upload, size: 18),
            label: Text(
              _uploadingPreset ? 'Uploading...' : 'Pick Image & Upload',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  /// Build screensaver animation update section
  Widget _buildScreensaverUpdate(bool isOnline) {
    final busy = _uploadingScreensaver;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0d6efd).withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gif_box, color: Color(0xFF0d6efd), size: 24),
              SizedBox(width: 12),
              Text(
                'Update Screensaver GIF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a video, convert to GIF and push to /spiffs/gif/output.gif',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          if (_screensaverStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _screensaverStatus,
                style: TextStyle(
                  color: _screensaverStatus.startsWith('Error') ||
                          _screensaverStatus.startsWith('Push error')
                      ? Colors.red
                      : _screensaverStatus.startsWith('Done') ||
                              _screensaverStatus.startsWith('Converted')
                          ? Colors.green
                          : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: isOnline && !busy ? _pickAndUploadScreensaver : null,
            icon: busy && !_screensaverConverted
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.video_library, size: 18),
            label: Text(
              busy && !_screensaverConverted
                  ? 'Converting...'
                  : 'Pick Video & Convert',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0d6efd),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.withOpacity(0.3),
            ),
          ),
          if (_screensaverConverted) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isOnline && !busy ? _pushScreensaverToDevice : null,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload, size: 18),
              label: Text(
                busy ? 'Pushing...' : 'Push to Device',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build OTA update button
  Widget _buildOTAButton(bool isOnline) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Firmware Update',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (widget.device.firmwareVersion != null) ...[
            const SizedBox(height: 8),
            Text(
              'Current Version: ${widget.device.firmwareVersion}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // OTA network update button
          ElevatedButton(
            onPressed: isOnline && !_sendingCommand ? _triggerOTA : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.withOpacity(0.3),
            ),
            child: const Text(
              'Trigger OTA Update',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          // OTA SD card update button
          ElevatedButton(
            onPressed: isOnline && !_sendingCommand ? _triggerSdcardUpdate : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.withOpacity(0.3),
            ),
            child: const Text(
              'OTA SD Card',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
