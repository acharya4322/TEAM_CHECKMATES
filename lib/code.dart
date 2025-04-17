// import 'package:car/second_tab.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter/services.dart';

// void main() {
//   runApp(CarControlApp());
// }

// class CarControlApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData.dark(),
//       home: CarController(),
//     );
//   }
// }

// class CarController extends StatefulWidget {
//   @override
//   _CarControllerState createState() => _CarControllerState();
// }

// class _CarControllerState extends State<CarController>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   final String espIP =
//       "http://192.168.215.163"; // Replace with your ESP8266's IP

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black87,
//       appBar: AppBar(
//         title: Text("Hiii!!!", style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.black,
//         centerTitle: true,
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: Colors.blue,
//           tabs: [
//             Tab(icon: Icon(Icons.gamepad), text: "Manual Control"),
//             Tab(icon: Icon(Icons.route), text: "Path Control"),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           ManualControlTab(espIP: espIP),
//           PathControlTab(espIP: espIP), // Using the imported tab
//         ],
//       ),
//     );
//   }
// }

// // class ManualControlTab extends StatefulWidget {
// //   final String espIP;

// //   ManualControlTab({required this.espIP});

// //   @override
// //   _ManualControlTabState createState() => _ManualControlTabState();
// // }

// // class _ManualControlTabState extends State<ManualControlTab> {
// //   double speed = 204; // Default speed (Range: 0-1023)

// //   void sendCommand(String command) async {
// //     try {
// //       HapticFeedback.mediumImpact(); // Add vibration feedback
// //       await http.get(Uri.parse("${widget.espIP}/$command"));
// //     } catch (e) {
// //       print("Error: $e");
// //     }
// //   }

// //   void setSpeed(double value) async {
// //     try {
// //       await http.get(Uri.parse("${widget.espIP}/speed?value=${value.toInt()}"));
// //     } catch (e) {
// //       print("Error: $e");
// //     }
// //   }

// //   Widget buildControlButton(String command, IconData icon) {
// //     return GestureDetector(
// //       onTapDown: (_) => sendCommand(command), // Send command on touch
// //       onTapUp: (_) => sendCommand("stop"), // Stop when released
// //       onTapCancel: () => sendCommand("stop"), // Stop if touch is canceled
// //       child: Container(
// //         width: 80,
// //         height: 80,
// //         decoration: BoxDecoration(
// //           gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
// //           shape: BoxShape.circle,
// //           boxShadow: [
// //             BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 1)
// //           ],
// //         ),
// //         child: Icon(icon, color: Colors.white, size: 40),
// //       ),
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Column(
// //       mainAxisAlignment: MainAxisAlignment.center,
// //       children: [
// //         buildControlButton("forward", Icons.arrow_upward), // Forward ↑
// //         SizedBox(height: 30),
// //         Row(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             buildControlButton("left", Icons.arrow_back), // Left ←
// //             SizedBox(width: 50),
// //             buildControlButton("right", Icons.arrow_forward), // Right →
// //           ],
// //         ),
// //         SizedBox(height: 30),
// //         buildControlButton("backward", Icons.arrow_downward), // Backward ↓
// //         SizedBox(height: 40),
// //         Text("Speed: ${speed.toInt()}",
// //             style: TextStyle(
// //                 color: Colors.white,
// //                 fontSize: 20,
// //                 fontWeight: FontWeight.bold)),
// //         Slider(
// //           value: speed,
// //           min: 0,
// //           max: 1023,
// //           divisions: 10,
// //           activeColor: Colors.blue,
// //           label: speed.toInt().toString(),
// //           onChanged: (value) {
// //             setState(() {
// //               speed = value;
// //             });
// //             setSpeed(value);
// //           },
// //         ),
// //       ],
// //     );
// //   }
// // }
