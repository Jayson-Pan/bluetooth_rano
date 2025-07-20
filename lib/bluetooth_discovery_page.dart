import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bluetooth_service.dart';

class BluetoothDiscoveryPage extends StatefulWidget {
  const BluetoothDiscoveryPage({Key? key}) : super(key: key);

  @override
  State<BluetoothDiscoveryPage> createState() => _BluetoothDiscoveryPageState();
}

class _BluetoothDiscoveryPageState extends State<BluetoothDiscoveryPage> {
  final BluetoothService _bluetoothService = BluetoothService();
  
  List<UnifiedBluetoothDevice> _devices = [];
  UnifiedBluetoothDevice? _selectedDevice;
  bool _isDiscovering = false;
  bool _isConnecting = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _listenToConnectionState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _sortDevices() {
    _devices.sort((a, b) {
      // 首先按是否有名称排序（有名称的在前）
      bool aHasName = a.name != null && a.name!.isNotEmpty;
      bool bHasName = b.name != null && b.name!.isNotEmpty;
      
      if (aHasName && !bHasName) return -1;
      if (!aHasName && bHasName) return 1;
      
      if (aHasName && bHasName) {
        // 按字典序排序
        return a.name!.toLowerCase().compareTo(b.name!.toLowerCase());
      }
      
      // 都没有名称时，按地址排序
      return a.address.compareTo(b.address);
    });
  }

  void _listenToConnectionState() {
    _bluetoothService.connectionStateStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
          _isConnecting = false;
        });
      }
    });
  }

  Future<void> _checkPermissions() async {
    // 检查并请求蓝牙权限
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = statuses.values.every((status) => status == PermissionStatus.granted);
    
    if (!allGranted) {
      _showSnackBar('需要蓝牙和位置权限才能使用此功能');
    }
  }

  Future<void> _startDiscovery() async {
    // 检查蓝牙是否启用
    bool isEnabled = await _bluetoothService.isBluetoothEnabled();
    if (!isEnabled) {
      bool enabled = await _bluetoothService.enableBluetooth();
      if (!enabled) {
        _showSnackBar('请启用蓝牙');
        return;
      }
    }

    setState(() {
      _devices.clear();
      _isDiscovering = true;
    });

    try {
      List<UnifiedBluetoothDevice> discoveredDevices = await _bluetoothService.startDiscovery();
      
      if (mounted) {
        setState(() {
          _devices = discoveredDevices;
          _sortDevices();
          _isDiscovering = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
        });
        _showSnackBar('设备发现失败: $e');
      }
    }
  }

  Future<void> _connectToDevice() async {
    if (_selectedDevice == null) {
      _showSnackBar('请先选择一个设备');
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    bool connected = await _bluetoothService.connectToDevice(_selectedDevice!);
    
    if (mounted) {
      if (connected) {
        _showSnackBar('BLE连接成功: ${_selectedDevice!.name ?? '未知设备'}');
      } else {
        setState(() {
          _isConnecting = false;
        });
        _showSnackBar('BLE连接失败');
      }
    }
  }

  void _disconnect() {
    _bluetoothService.disconnect();
    _showSnackBar('已断开BLE连接');
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE蓝牙发现'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 连接状态显示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isConnected ? Colors.green : Colors.grey,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: _isConnected ? Colors.green.shade800 : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isConnected 
                          ? 'BLE已连接: ${_bluetoothService.connectedDevice?.name ?? '未知设备'}'
                          : 'BLE未连接',
                      style: TextStyle(
                        color: _isConnected ? Colors.green.shade800 : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 操作按钮区域
            Column(
              children: [
                // 扫描按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isDiscovering ? null : _startDiscovery,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isDiscovering
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('扫描中...'),
                            ],
                          )
                        : const Text('扫描BLE设备'),
                  ),
                ),
                const SizedBox(height: 8),
                
                // 连接和断开按钮行
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_selectedDevice == null || _isConnecting || _isConnected) 
                            ? null 
                            : _connectToDevice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isConnecting
                            ? const SizedBox(
                                height: 20,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('连接中...'),
                                  ],
                                ),
                              )
                            : const Text('连接设备'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isConnected ? _disconnect : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('断开连接'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 设备选择提示
            if (_selectedDevice != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, 
                         color: Colors.blue.shade700, 
                         size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '已选择: ${_selectedDevice!.name ?? '未知设备'}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedDevice != null) const SizedBox(height: 12),
            
            // 设备列表标题和统计
            Row(
              children: [
                const Text(
                  '发现的BLE设备',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_devices.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_devices.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 设备列表
            Expanded(
              child: _buildDeviceList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty && !_isDiscovering) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '点击"扫描BLE设备"开始搜索',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        UnifiedBluetoothDevice device = _devices[index];
        return _buildDeviceListTile(device);
      },
    );
  }

  Widget _buildDeviceListTile(UnifiedBluetoothDevice device) {
    bool isSelected = _selectedDevice?.address == device.address;
    bool hasName = device.name != null && device.name!.isNotEmpty;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            hasName ? Icons.bluetooth : Icons.bluetooth_disabled,
            color: isSelected 
                ? Colors.blue.shade700 
                : (hasName ? Colors.blue.shade400 : Colors.grey.shade600),
            size: 20,
          ),
        ),
        title: Text(
          device.name ?? '未知BLE设备',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue.shade800 : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '地址: ${device.address}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasName ? Colors.green.shade100 : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hasName ? '已命名' : '未知名称',
                style: TextStyle(
                  color: hasName ? Colors.green.shade700 : Colors.orange.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: isSelected 
            ? Icon(Icons.check_circle, 
                   color: Colors.blue.shade700, 
                   size: 24)
            : Icon(Icons.radio_button_unchecked, 
                   color: Colors.grey.shade400,
                   size: 24),
        onTap: () {
          setState(() {
            _selectedDevice = isSelected ? null : device;
          });
        },
      ),
    );
  }
} 