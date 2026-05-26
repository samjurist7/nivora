import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../services/user_service.dart';
import '../theme/mechanical_theme.dart';
import '../widgets/smoke_background.dart';
import 'login_page.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  int _vibrationLevel = 0;
  bool _audio = true;
  bool _bluetooth = true;
  bool _wifi = true;
  int _ledPreset = 0;

  @override
  void initState() {
    super.initState();
    _syncFromServices();
  }

  void _syncFromServices() {
    final bleService = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bleService.deviceInfo;
    if (deviceInfo != null) {
      if (deviceInfo.containsKey('lightMode')) {
        _ledPreset = deviceInfo['lightMode'] as int;
      }
      if (deviceInfo.containsKey('motorLevel')) {
        _vibrationLevel = deviceInfo['motorLevel'] as int;
      }
      if (deviceInfo.containsKey('audioSwitch')) {
        _audio = (deviceInfo['audioSwitch'] as int) == 1;
      }
    }
  }

  Future<void> _updateDeviceParameter({
    int? lightMode,
    int? motorLevel,
    bool? audioSwitch,
    bool? tempUnitIsF,
  }) async {
    final bleService = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bleService.deviceInfo;

    int setTemp = 200;
    int setTime = 60;
    int heatPreset = 0;
    int startHeating = 0;
    int boostCount = 0;

    int currentLightMode = _ledPreset;
    int currentMotorLevel = _vibrationLevel;
    int currentAudioSwitch = _audio ? 1 : 0;
    int currentTempUnit = 0;

    if (deviceInfo != null) {
      if (deviceInfo.containsKey('setTemp')) setTemp = deviceInfo['setTemp'];
      if (deviceInfo.containsKey('setTime')) setTime = deviceInfo['setTime'];
      if (deviceInfo.containsKey('heatPreset')) heatPreset = deviceInfo['heatPreset'];
      if (deviceInfo.containsKey('startHeating')) startHeating = deviceInfo['startHeating'];
      if (deviceInfo.containsKey('boostCount')) boostCount = deviceInfo['boostCount'];

      if (deviceInfo.containsKey('lightMode')) currentLightMode = deviceInfo['lightMode'];
      if (deviceInfo.containsKey('motorLevel')) currentMotorLevel = deviceInfo['motorLevel'];
      if (deviceInfo.containsKey('audioSwitch')) currentAudioSwitch = deviceInfo['audioSwitch'];
      if (deviceInfo.containsKey('tempUnit')) currentTempUnit = deviceInfo['tempUnit'];
    }

    if (lightMode != null) currentLightMode = lightMode;
    if (motorLevel != null) currentMotorLevel = motorLevel;
    if (audioSwitch != null) currentAudioSwitch = audioSwitch ? 1 : 0;
    if (tempUnitIsF != null) currentTempUnit = tempUnitIsF ? 1 : 0;

    try {
      await bleService.sendDeviceParameter(
        currentLightMode,
        setTemp,
        setTime,
        heatPreset: heatPreset,
        startHeating: startHeating,
        boostCount: boostCount,
        motorLevel: currentMotorLevel,
        audioSwitch: currentAudioSwitch,
        tempUnit: currentTempUnit,
      );
    } catch (e) {
      print('Failed to update device parameters: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update settings: $e'),
            backgroundColor: MechanicalTheme.warningRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SmokeBackground(
      smokeColor: const Color(0xFF3DD6F5),
      particleCount: 8,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildSettingRow(
                      label: 'Temperature Unit',
                      value: Consumer<UserService>(
                        builder: (context, userService, child) {
                          return Text(
                            userService.isFahrenheit ? '℉' : '℃',
                            style: const TextStyle(
                              color: MechanicalTheme.primaryCyan,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                      onTap: () {
                        final userService = Provider.of<UserService>(context, listen: false);
                        userService.toggleTempUnit();
                        _updateDeviceParameter(tempUnitIsF: userService.isFahrenheit);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingRow(
                      label: 'Vibration Level',
                      value: Text(
                        '$_vibrationLevel',
                        style: const TextStyle(
                          color: MechanicalTheme.primaryCyan,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _vibrationLevel = (_vibrationLevel + 1) % 6;
                        });
                        _updateDeviceParameter(motorLevel: _vibrationLevel);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingRow(
                      label: 'Audio',
                      value: Text(
                        _audio ? 'ON' : 'OFF',
                        style: const TextStyle(
                          color: MechanicalTheme.primaryCyan,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _audio = !_audio;
                        });
                        _updateDeviceParameter(audioSwitch: _audio);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingRow(
                      label: 'Bluetooth',
                      value: Text(
                        _bluetooth ? 'ON' : 'OFF',
                        style: const TextStyle(
                          color: MechanicalTheme.primaryCyan,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _bluetooth = !_bluetooth;
                          final bleService = Provider.of<BluetoothService>(context, listen: false);
                          if (!_bluetooth) {
                            bleService.disconnect();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingRow(
                      label: 'WI-FI',
                      value: Text(
                        _wifi ? 'ON' : 'OFF',
                        style: const TextStyle(
                          color: MechanicalTheme.primaryCyan,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _wifi = !_wifi;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingRow(
                      label: 'LED Preset',
                      value: Text(
                        '$_ledPreset',
                        style: const TextStyle(
                          color: MechanicalTheme.primaryCyan,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _ledPreset = (_ledPreset + 1) % 6;
                        });
                        _updateDeviceParameter(lightMode: _ledPreset);
                      },
                    ),
                    const SizedBox(height: 30),
                    _buildLogoutButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MechanicalTheme.bgLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MechanicalTheme.primaryCyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: MechanicalTheme.primaryCyan,
                size: 18,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'SETTINGS',
                style: TextStyle(
                  color: MechanicalTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required String label,
    required Widget value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: MechanicalTheme.createMechanicalCardStyle(
          borderRadius: 14,
          borderColor: MechanicalTheme.primaryCyan.withOpacity(0.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: MechanicalTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                value,
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: MechanicalTheme.primaryCyan.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: MechanicalTheme.primaryCyan,
                    size: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: MechanicalTheme.bgMedium,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: MechanicalTheme.primaryCyan.withOpacity(0.3)),
            ),
            title: const Text(
              'Confirm Logout',
              style: TextStyle(color: MechanicalTheme.textPrimary),
            ),
            content: const Text(
              'Are you sure you want to logout?',
              style: TextStyle(color: MechanicalTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: MechanicalTheme.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: MechanicalTheme.warningRed),
                ),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          final userService = Provider.of<UserService>(context, listen: false);
          final bt = Provider.of<BluetoothService>(context, listen: false);

          await bt.disconnect();
          await userService.logout();

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: MechanicalTheme.warningRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: MechanicalTheme.warningRed.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MechanicalTheme.warningRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout,
                color: MechanicalTheme.warningRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Logout',
              style: TextStyle(
                color: MechanicalTheme.warningRed,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
