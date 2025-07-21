import 'package:flutter/material.dart';
import 'bluetooth_communication_page.dart';
import 'bluetooth_remote_control_page.dart';

class HubPage extends StatelessWidget {
  const HubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('功能中心'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _buildHubItem(
            context,
            icon: Icons.bluetooth,
            title: '通用BLE调试',
            description: '连接和调试BLE设备，发送和接收数据',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BluetoothCommunicationPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildHubItem(
            context,
            icon: Icons.gamepad,
            title: '蓝牙小车控制',
            description: '使用方向键控制蓝牙小车移动',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BluetoothRemoteControlPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildHubItem(
            context,
            icon: Icons.speaker,
            title: '蓝牙音响',
            description: '连接和控制蓝牙音响设备',
            onTap: () {
              _showComingSoon(context, '蓝牙音响');
            },
          ),
          const SizedBox(height: 12),
          _buildHubItem(
            context,
            icon: Icons.lightbulb,
            title: '智能灯光',
            description: '控制智能灯光的亮度和颜色',
            onTap: () {
              _showComingSoon(context, '智能灯光');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHubItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // 左侧图标
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                icon,
                size: 32,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 16),
            
            // 右侧文字内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            
            // 右侧箭头
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$feature 功能'),
        content: const Text('此功能即将推出，敬请期待！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
} 