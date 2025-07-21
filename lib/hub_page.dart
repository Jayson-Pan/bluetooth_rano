import 'package:flutter/material.dart';
import 'bluetooth_communication_page.dart';
import 'bluetooth_car_series_page.dart';
import 'bluetooth_robot_fighter_page.dart';

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
            imagePath: 'assets/images/ble_debug.png',
            fallbackIcon: Icons.bluetooth,
            title: '通用BLE调试',
            description: '连接和调试BLE设备，发送和接收数据，支持ASCII和HEX模式',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BluetoothCommunicationPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildHubItem(
            context,
            imagePath: 'assets/images/car_series.png',
            fallbackIcon: Icons.directions_car,
            title: '蓝牙小车系列',
            description: '支持Arduino初级、中级教材配套小车，宇宙骑士，蓝牙灭火机器人，蓝牙搜救机器人等产品，支持蓝牙遥控、自定义按钮等功能',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BluetoothCarSeriesPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildHubItem(
            context,
            imagePath: 'assets/images/robot_fighter.png',
            fallbackIcon: Icons.smart_toy,
            title: '蓝牙格斗机器人',
            description: '功能与蓝牙小车系列一致，为智华集训优化了背景图片显示，在结营之后将会给优胜学校设计“冠军皮肤”',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BluetoothRobotFighterPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildHubItem(
            context,
            imagePath: 'assets/images/stacking_robot.png',
            fallbackIcon: Icons.precision_manufacturing,
            title: '码垛搬运机器人',
            description: '支持ERCC全系列码垛搬运机器人，实现了蓝牙遥控、机械臂示教、视频推流等功能',
            onTap: () {
              _showComingSoon(context, '码垛搬运机器人');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHubItem(
    BuildContext context, {
    required String imagePath,
    required IconData fallbackIcon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左侧图片/图标区域 - 调整为适中大小
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildImageWidget(imagePath, fallbackIcon),
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // 右侧箭头
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imagePath, IconData fallbackIcon) {
    return Image.asset(
      imagePath,
      width: 100,
      height: 100,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // 如果图片加载失败，显示备用图标
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            fallbackIcon,
            size: 50,
            color: Colors.blue.shade700,
          ),
        );
      },
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