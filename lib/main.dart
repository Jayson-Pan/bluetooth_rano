import 'package:flutter/material.dart';
import 'bluetooth_discovery_page.dart';
import 'bluetooth_communication_page.dart';

void main() {
  runApp(const BluetoothApp());
}

class BluetoothApp extends StatelessWidget {
  const BluetoothApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE蓝牙控制应用',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const BluetoothDiscoveryPage(),
    const BluetoothCommunicationPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth_searching),
            label: 'BLE发现',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'BLE通信',
          ),
        ],
      ),
    );
  }
}
