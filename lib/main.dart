import 'package:car/map_tab.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:car/second_tab.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(CarControlApp());
}

class CarControlApp extends StatelessWidget {
  const CarControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: CarController(),
    );
  }
}

class CarController extends StatefulWidget {
  const CarController({super.key});

  @override
  _CarControllerState createState() => _CarControllerState();
}

class _CarControllerState extends State<CarController>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String espIP = "http://192.168.134.163"; // Default IP
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Now 3 tabs
    _loadSavedIP();
  }

  // Load saved IP from SharedPreferences
  Future<void> _loadSavedIP() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIP = prefs.getString('esp_ip');
      if (savedIP != null && savedIP.isNotEmpty) {
        setState(() {
          espIP = savedIP.startsWith('http://') ? savedIP : 'http://$savedIP';
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading saved IP: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Update IP and save to SharedPreferences
  Future<void> updateIP(String newIP) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final formattedIP = newIP.startsWith('http://') ? newIP : 'http://$newIP';
      await prefs.setString('esp_ip', formattedIP);
      setState(() {
        espIP = formattedIP;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('IP address updated successfully')),
      );
    } catch (e) {
      print("Error saving IP: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save IP address')),
      );
    }
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.grey[900],
          child: Container(
            padding: EdgeInsets.all(20),
            constraints: BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: SettingsTab(
              currentIP: espIP,
              onIPUpdated: (newIP) {
                updateIP(newIP);
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title:
            Text("Smart Car Controller", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
            onPressed: _openSettingsDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          tabs: [
            Tab(icon: Icon(Icons.gamepad), text: "Manual Control"),
            Tab(icon: Icon(Icons.route), text: "Path Control"),
            Tab(icon: Icon(Icons.map), text: "Auto Drive"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ManualControlTab(espIP: espIP),
          PathControlTab(espIP: espIP),
          AutoDriveTab(espIP: espIP),
        ],
      ),
    );
  }
}

class SettingsTab extends StatefulWidget {
  final String currentIP;
  final Function(String) onIPUpdated;

  const SettingsTab({
    super.key,
    required this.currentIP,
    required this.onIPUpdated,
  });

  @override
  _SettingsTabState createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late TextEditingController _ipController;
  bool _isValidating = false;
  String _validationMessage = '';
  bool _isValidIP = true;

  @override
  void initState() {
    super.initState();
    // Remove http:// prefix for display
    String displayIP = widget.currentIP.replaceAll('http://', '');
    _ipController = TextEditingController(text: displayIP);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  // Validate IP address format
  bool _validateIPFormat(String ip) {
    RegExp ipRegex = RegExp(
        r'^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$');

    // Allow IP:PORT format as well
    RegExp ipPortRegex = RegExp(
        r'^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]):([0-9]{1,5})$');

    return ipRegex.hasMatch(ip) || ipPortRegex.hasMatch(ip);
  }

  // Test the connection to the ESP8266
  Future<void> _testConnection(String ip) async {
    setState(() {
      _isValidating = true;
      _validationMessage = '';
    });

    try {
      final formattedIP = ip.startsWith('http://') ? ip : 'http://$ip';
      final response = await http
          .get(
            Uri.parse("$formattedIP/status"),
          )
          .timeout(Duration(seconds: 3));

      setState(() {
        _isValidating = false;
        if (response.statusCode == 200) {
          _validationMessage = 'Connection successful!';
          _isValidIP = true;
        } else {
          _validationMessage = 'Connection failed: HTTP ${response.statusCode}';
          _isValidIP = false;
        }
      });
    } catch (e) {
      setState(() {
        _isValidating = false;
        _validationMessage = 'Connection failed: ${e.toString()}';
        _isValidIP = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ESP8266 Configuration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        SizedBox(height: 16),
        Text(
          'Current IP Address:',
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.currentIP,
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Update IP Address:',
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _ipController,
          decoration: InputDecoration(
            hintText: '192.168.1.100',
            prefixText: 'http://',
            border: OutlineInputBorder(),
            suffixIcon: _isValidating
                ? Container(
                    width: 20,
                    height: 20,
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.wifi),
          ),
          keyboardType: TextInputType.text,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'[0-9\.:_]')), // Allow digits, dots, colons
          ],
        ),
        SizedBox(height: 8),
        if (_validationMessage.isNotEmpty)
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isValidIP
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  _isValidIP ? Icons.check_circle : Icons.error,
                  color: _isValidIP ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _validationMessage,
                    style: TextStyle(
                      color: _isValidIP ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.check),
              label: Text('Test Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                _testConnection(_ipController.text);
              },
            ),
            SizedBox(width: 12),
            ElevatedButton.icon(
              icon: Icon(Icons.save),
              label: Text('Save IP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onPressed: () {
                if (_validateIPFormat(_ipController.text)) {
                  widget.onIPUpdated(_ipController.text);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid IP address'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
        SizedBox(height: 16),
        Divider(),
        ListTile(
          dense: true,
          leading: Icon(Icons.info_outline, size: 20),
          title: Text('IP Address Format'),
          subtitle: Text(
              'Enter the IP address of your ESP8266 without http:// prefix'),
        ),
        ListTile(
          dense: true,
          leading: Icon(Icons.help_outline, size: 20),
          title: Text('Connection Issues?'),
          subtitle: Text(
              'Make sure your ESP8266 is powered on and connected to the same WiFi network'),
        ),
      ],
    );
  }
}

class ManualControlTab extends StatefulWidget {
  final String espIP;

  const ManualControlTab({super.key, required this.espIP});

  @override
  _ManualControlTabState createState() => _ManualControlTabState();
}

class _ManualControlTabState extends State<ManualControlTab> {
  double speed = 204; // Default speed (Range: 0-1023)
  bool obstacleDetected = false;
  double obstacleDistance = 0.0;
  Timer? _statusTimer;
  bool _showingDialog = false;

  @override
  void initState() {
    super.initState();
    // Check sensor status every 500ms
    _statusTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      checkSensorStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  // Check sensor status from ESP8266
  Future<void> checkSensorStatus() async {
    try {
      final response = await http.get(Uri.parse("${widget.espIP}/status"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          obstacleDistance = data['distance'].toDouble();
          bool newObstacleState = data['obstacle'];

          // Only show dialog when obstacle is first detected
          if (newObstacleState && !obstacleDetected && !_showingDialog) {
            _showObstacleDialog();
          }

          obstacleDetected = newObstacleState;
        });
      }
    } catch (e) {
      print("Error checking sensor status: $e");
    }
  }

  // Show obstacle detected dialog
  void _showObstacleDialog() {
    if (_showingDialog) return;

    _showingDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Obstacle Detected!"),
          content: Text(
              "Obstacle detected at ${obstacleDistance.toStringAsFixed(1)} cm. Car has stopped for safety."),
          backgroundColor: Colors.red[900],
          titleTextStyle: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          contentTextStyle: TextStyle(color: Colors.white, fontSize: 16),
          actions: [
            TextButton(
              child: Text("OK", style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                _showingDialog = false;
              },
            ),
          ],
        );
      },
    ).then((_) => _showingDialog = false);
  }

  void sendCommand(String command) async {
    try {
      HapticFeedback.mediumImpact(); // Add vibration feedback

      // Don't send movement commands if obstacle is detected (except "stop" and "backward")
      if (obstacleDetected && command != "stop" && command != "backward") {
        _showObstacleDialog();
        return;
      }

      await http.get(Uri.parse("${widget.espIP}/$command"));
    } catch (e) {
      print("Error: $e");
    }
  }

  void setSpeed(double value) async {
    try {
      await http.get(Uri.parse("${widget.espIP}/speed?value=${value.toInt()}"));
    } catch (e) {
      print("Error: $e");
    }
  }

  Widget buildControlButton(String command, IconData icon) {
    // Disable forward, left, right buttons if obstacle detected
    bool isDisabled = obstacleDetected &&
        (command == "forward" || command == "left" || command == "right");

    return GestureDetector(
      onTapDown: isDisabled
          ? null
          : (_) => sendCommand(command), // Send command on touch
      onTapUp:
          isDisabled ? null : (_) => sendCommand("stop"), // Stop when released
      onTapCancel: isDisabled
          ? null
          : () => sendCommand("stop"), // Stop if touch is canceled
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: isDisabled
                  ? [Colors.grey.shade700, Colors.grey.shade800]
                  : [Colors.blue, Colors.purple]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 1)
          ],
        ),
        child: Icon(icon,
            color: isDisabled ? Colors.grey : Colors.white, size: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Obstacle status indicator
        if (obstacleDetected)
          Container(
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  "Obstacle at ${obstacleDistance.toStringAsFixed(1)} cm",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

        buildControlButton("forward", Icons.arrow_upward), // Forward ↑
        SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildControlButton("left", Icons.arrow_back), // Left ←
            SizedBox(width: 50),
            buildControlButton("right", Icons.arrow_forward), // Right →
          ],
        ),
        SizedBox(height: 30),
        buildControlButton("backward", Icons.arrow_downward), // Backward ↓
        SizedBox(height: 40),
        Text("Speed: ${speed.toInt()}",
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Slider(
          value: speed,
          min: 0,
          max: 1023,
          divisions: 10,
          activeColor: Colors.blue,
          label: speed.toInt().toString(),
          onChanged: (value) {
            setState(() {
              speed = value;
            });
            setSpeed(value);
          },
        ),

        // Display distance indicator
        SizedBox(height: 20),
        Text(
          "Distance: ${obstacleDistance.toStringAsFixed(1)} cm",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }
}
