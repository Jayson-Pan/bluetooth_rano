import 'package:flutter/material.dart';
import 'bluetooth_service.dart';
import 'dart:async';

class BluetoothRemoteControlPage extends StatefulWidget {
  const BluetoothRemoteControlPage({super.key});

  @override
  State<BluetoothRemoteControlPage> createState() => _BluetoothRemoteControlPageState();
}

class _BluetoothRemoteControlPageState extends State<BluetoothRemoteControlPage> {
  final BluetoothService _bluetoothService = BluetoothService();
  StreamSubscription<bool>? _connectionSubscription;
  
  bool _isConnected = false;
  String _lastCommand = '';
  DateTime? _lastCommandTime;

  @override
  void initState() {
    super.initState();
    _listenToConnectionState();
    _updateConnectionState();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _listenToConnectionState() {
    _connectionSubscription = _bluetoothService.connectionStateStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    });
  }

  void _updateConnectionState() {
    setState(() {
      _isConnected = _bluetoothService.isConnected;
    });
  }

  Future<void> _sendCommand(String command) async {
    if (!_isConnected) {
      _showSnackBar('未连接到蓝牙设备');
      return;
    }

    bool sent = await _bluetoothService.sendMessage(command);
    if (sent) {
      setState(() {
        _lastCommand = command;
        _lastCommandTime = DateTime.now();
      });
      _showSnackBar('发送命令: $command');
    } else {
      _showSnackBar('命令发送失败');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('蓝牙遥控'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 连接状态显示
            Container(
              width: double.infinity,
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
                          ? '已连接: ${_bluetoothService.connectedDevice?.name ?? '未知设备'}'
                          : '未连接到蓝牙设备',
                      style: TextStyle(
                        color: _isConnected ? Colors.green.shade800 : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            if (!_isConnected) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '请先使用"通用BLE调试"功能连接到蓝牙设备',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            
            // 最后发送的命令显示
            if (_lastCommand.isNotEmpty && _lastCommandTime != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '最后发送的命令:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastCommand,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    Text(
                      '时间: ${_lastCommandTime!.hour.toString().padLeft(2, '0')}:${_lastCommandTime!.minute.toString().padLeft(2, '0')}:${_lastCommandTime!.second.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 32),
            
            // 控制说明
            const Text(
              '方向控制',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击方向按钮控制设备移动',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 方向控制区域
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: Stack(
                    children: [
                      // 向前按钮
                      Positioned(
                        top: 0,
                        left: 90,
                        child: _buildDirectionButton(
                          icon: Icons.keyboard_arrow_up,
                          label: '前进',
                          command: 'F',
                          color: Colors.green,
                        ),
                      ),
                      
                      // 向左按钮
                      Positioned(
                        top: 90,
                        left: 0,
                        child: _buildDirectionButton(
                          icon: Icons.keyboard_arrow_left,
                          label: '左转',
                          command: 'L',
                          color: Colors.blue,
                        ),
                      ),
                      
                      // 停止按钮
                      Positioned(
                        top: 90,
                        left: 90,
                        child: _buildDirectionButton(
                          icon: Icons.stop,
                          label: '停止',
                          command: 'S',
                          color: Colors.red,
                          isStop: true,
                        ),
                      ),
                      
                      // 向右按钮
                      Positioned(
                        top: 90,
                        right: 0,
                        child: _buildDirectionButton(
                          icon: Icons.keyboard_arrow_right,
                          label: '右转',
                          command: 'R',
                          color: Colors.blue,
                        ),
                      ),
                      
                      // 向后按钮
                      Positioned(
                        bottom: 0,
                        left: 90,
                        child: _buildDirectionButton(
                          icon: Icons.keyboard_arrow_down,
                          label: '后退',
                          command: 'B',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 快捷命令区域
            const Text(
              '快捷命令',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickCommandButton('开启灯光', 'LED_ON'),
                _buildQuickCommandButton('关闭灯光', 'LED_OFF'),
                _buildQuickCommandButton('鸣笛', 'HORN'),
                _buildQuickCommandButton('状态查询', 'STATUS'),
              ],
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionButton({
    required IconData icon,
    required String label,
    required String command,
    required Color color,
    bool isStop = false,
  }) {
    return GestureDetector(
      onTap: _isConnected ? () => _sendCommand(command) : null,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: _isConnected 
              ? (isStop ? color : color.withValues(alpha: 0.8))
              : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isConnected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 36,
              color: _isConnected ? Colors.white : Colors.grey.shade500,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _isConnected ? Colors.white : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCommandButton(String label, String command) {
    return ElevatedButton(
      onPressed: _isConnected ? () => _sendCommand(command) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isConnected ? Colors.purple.shade400 : Colors.grey.shade300,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
} 