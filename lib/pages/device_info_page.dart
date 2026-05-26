import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../theme/mechanical_theme.dart';
import '../widgets/smoke_background.dart';

/// Device Info 页面 - 机械风重新设计
class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({super.key});

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  Map<String, String> _deviceInfo = {};
  bool _isLoading = true;
  bool _showAllServices = false;
  Map<String, dynamic> _allServicesInfo = {};
  int? _tcrInit;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
      bluetoothService.addListener(_updateTcrInit);
      _updateTcrInit();
    });
  }

  @override
  void dispose() {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    bluetoothService.removeListener(_updateTcrInit);
    super.dispose();
  }

  void _updateTcrInit() {
    if (!mounted) return;

    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bluetoothService.getDeviceInfo();

    if (deviceInfo != null && deviceInfo.containsKey('tcr_init')) {
      final newTcrInit = deviceInfo['tcr_init'] as int;
      if (newTcrInit != _tcrInit) {
        setState(() {
          _tcrInit = newTcrInit;
        });
      }
    }
  }

  Future<void> _loadDeviceInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
      final info = await bluetoothService.readDeviceInfoCharacteristics();
      final allServices = await bluetoothService.getAllServicesInfo();

      if (mounted) {
        setState(() {
          _deviceInfo = info;
          _allServicesInfo = allServices;
          _isLoading = false;
        });

        _updateTcrInit();
      }
    } catch (e) {
      print('Failed to load device info: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load device info: $e'),
            backgroundColor: MechanicalTheme.warningRed,
          ),
        );
      }
    }
  }

  Future<void> _onResetPressed() async {
    try {
      final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
      await bluetoothService.sendResetCommand();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset command sent successfully'),
          backgroundColor: MechanicalTheme.coolGreen,
        ),
      );
    } catch (e) {
      print('Failed to send reset command: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reset command: $e'),
          backgroundColor: MechanicalTheme.warningRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SmokeBackground(
      smokeColor: MechanicalTheme.warningYellow,
      particleCount: 8,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildTabSwitcher(),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? _buildLoadingView()
                    : _showAllServices
                        ? _buildAllServicesView()
                        : _deviceInfo.isEmpty
                            ? _buildNoDeviceInfoView()
                            : _buildDeviceInfoList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: MechanicalTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'DEVICE INFO',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MechanicalTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: MechanicalTheme.primaryCyan),
            onPressed: _isLoading ? null : _loadDeviceInfo,
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTabButton('DEVICE INFO', false),
          const SizedBox(width: 12),
          _buildTabButton('ALL SERVICES', true),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isServices) {
    final isSelected = _showAllServices == isServices;
    return GestureDetector(
      onTap: () {
        setState(() {
          _showAllServices = isServices;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? MechanicalTheme.primaryCyan.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? MechanicalTheme.primaryCyan.withOpacity(0.5)
                : MechanicalTheme.primaryCyan.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? MechanicalTheme.primaryCyan
                : MechanicalTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: MechanicalTheme.primaryCyan,
          ),
          SizedBox(height: 20),
          Text(
            'Reading device information...',
            style: TextStyle(
              color: MechanicalTheme.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDeviceInfoView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            color: MechanicalTheme.textSecondary.withOpacity(0.5),
            size: 72,
          ),
          const SizedBox(height: 20),
          const Text(
            'No device information available',
            style: TextStyle(
              color: MechanicalTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Device may not support Device Information Service',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MechanicalTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showAllServices = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MechanicalTheme.primaryCyan,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'CHECK ALL SERVICES',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _buildTcrInitCard(),
        const SizedBox(height: 16),
        ..._deviceInfo.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildInfoCard(entry.key, entry.value),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildAllServicesView() {
    if (_allServicesInfo.isEmpty) {
      return Center(
        child: Text(
          'No services found',
          style: TextStyle(
            color: MechanicalTheme.textSecondary,
            fontSize: 15,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: _allServicesInfo.entries.map((serviceEntry) {
        final serviceUuid = serviceEntry.key;
        final characteristics = serviceEntry.value['characteristics'] as List<Map<String, dynamic>>;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildServiceCard(serviceUuid, characteristics),
        );
      }).toList(),
    );
  }

  Widget _buildTcrInitCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: MechanicalTheme.createMechanicalCardStyle(
        borderRadius: 16,
        borderColor: MechanicalTheme.warningYellow.withOpacity(0.4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.memory,
                      color: MechanicalTheme.warningYellow,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TCR Init',
                      style: TextStyle(
                        color: MechanicalTheme.warningYellow,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _tcrInit != null
                      ? '$_tcrInit (0x${_tcrInit!.toRadixString(16).toUpperCase().padLeft(4, '0')})'
                      : 'No data',
                  style: const TextStyle(
                    color: MechanicalTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _onResetPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: MechanicalTheme.warningRed,
                borderRadius: BorderRadius.circular(12),
                boxShadow: MechanicalTheme.createGlowShadow(MechanicalTheme.warningRed, intensity: 0.5),
              ),
              child: const Text(
                'RESET',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: MechanicalTheme.createMechanicalCardStyle(
        borderRadius: 14,
        borderColor: MechanicalTheme.primaryCyan.withOpacity(0.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tag,
                color: MechanicalTheme.primaryCyan,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: MechanicalTheme.primaryCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: MechanicalTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(String serviceUuid, List<Map<String, dynamic>> characteristics) {
    return Container(
      decoration: MechanicalTheme.createMechanicalCardStyle(
        borderRadius: 16,
        borderColor: MechanicalTheme.warningYellow.withOpacity(0.3),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(
            Icons.dns,
            color: MechanicalTheme.warningYellow,
            size: 20,
          ),
          title: Text(
            'Service',
            style: TextStyle(
              color: MechanicalTheme.warningYellow,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          subtitle: Text(
            serviceUuid,
            style: const TextStyle(
              color: MechanicalTheme.textSecondary,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          iconColor: MechanicalTheme.warningYellow,
          collapsedIconColor: MechanicalTheme.warningYellow,
          children: characteristics.map((char) {
            final charUuid = char['uuid'] as String;
            final canRead = char['read'] as bool;
            final canWrite = char['write'] as bool;
            final canNotify = char['notify'] as bool;

            List<String> properties = [];
            if (canRead) properties.add('Read');
            if (canWrite) properties.add('Write');
            if (canNotify) properties.add('Notify');

            return Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: MechanicalTheme.bgDark.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: MechanicalTheme.primaryCyan.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.usb,
                        color: MechanicalTheme.primaryCyan,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Characteristic',
                        style: TextStyle(
                          color: MechanicalTheme.primaryCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    charUuid,
                    style: const TextStyle(
                      color: MechanicalTheme.textPrimary,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Properties: ${properties.join(', ')}',
                    style: TextStyle(
                      color: MechanicalTheme.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
