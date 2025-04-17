import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

enum ExecutionMode { once, continuous, bidirectional }

class PathControlTab extends StatefulWidget {
  final String espIP;

  const PathControlTab({super.key, required this.espIP});

  @override
  _PathControlTabState createState() => _PathControlTabState();
}

class _PathControlTabState extends State<PathControlTab> {
  List<PathStep> steps = [];
  bool isExecuting = false;
  int currentStepIndex = -1;
  int speed = 150; // Setting default speed
  ExecutionMode executionMode = ExecutionMode.once;
  int loopCount = 0;
  int maxLoops = 3; // Default number of times to repeat the pattern
  bool infiniteLoop = false; // New flag for infinite looping
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Speed controller slider
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.speed, color: Colors.white70),
                  SizedBox(width: 8),
                  Text(
                    "Speed: $speed",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              Slider(
                value: speed.toDouble(),
                min: 100,
                max: 255,
                divisions: 155,
                activeColor: Colors.blue,
                inactiveColor: Colors.grey,
                onChanged: isExecuting
                    ? null
                    : (value) {
                        setState(() {
                          speed = value.round();
                        });
                      },
              ),
            ],
          ),
        ),

        // Obstacle status indicator
        if (obstacleDetected)
          Container(
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

        // Execution mode selector
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.repeat, color: Colors.white70),
                  SizedBox(width: 8),
                  Text(
                    "Execution Mode:",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildModeButton(
                      "Once", ExecutionMode.once, Icons.arrow_forward),
                  _buildModeButton(
                      "Loop", ExecutionMode.continuous, Icons.loop),
                  _buildModeButton("Bidirectional", ExecutionMode.bidirectional,
                      Icons.swap_horiz),
                ],
              ),
              if (executionMode != ExecutionMode.once) ...[
                SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      "Repeat count: ",
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: infiniteLoop || isExecuting || maxLoops <= 1
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.remove, color: Colors.white),
                        onPressed: infiniteLoop || isExecuting || maxLoops <= 1
                            ? null
                            : () {
                                setState(() {
                                  maxLoops--;
                                });
                              },
                      ),
                    ),
                    SizedBox(width: 16),
                    infiniteLoop
                        ? Icon(
                            Icons.all_inclusive,
                            color: Colors.white,
                            size: 24,
                          )
                        : Text(
                            "$maxLoops",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    SizedBox(width: 16),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: infiniteLoop || isExecuting || maxLoops >= 10
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.add, color: Colors.white),
                        onPressed: infiniteLoop || isExecuting || maxLoops >= 10
                            ? null
                            : () {
                                setState(() {
                                  maxLoops++;
                                });
                              },
                      ),
                    ),
                    SizedBox(width: 16),
                    // Infinity toggle button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isExecuting
                            ? Colors.purple.withOpacity(0.2)
                            : infiniteLoop
                                ? Colors.purple
                                : Colors.purple.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.all_inclusive,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: isExecuting
                            ? null
                            : () {
                                setState(() {
                                  infiniteLoop = !infiniteLoop;
                                });
                              },
                        tooltip: "Toggle infinite looping",
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: steps.isEmpty
              ? Center(
                  child: Text(
                    "Add movement steps to create a path",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    if (isExecuting)
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          infiniteLoop
                              ? "Running: Loop ${loopCount + 1} (∞)"
                              : "Iteration: ${loopCount + 1}/$maxLoops",
                          style: TextStyle(color: Colors.amber, fontSize: 16),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: steps.length,
                        itemBuilder: (context, index) {
                          return PathStepCard(
                            step: steps[index],
                            index: index,
                            isActive: index == currentStepIndex,
                            onDelete: () {
                              if (!isExecuting) {
                                setState(() {
                                  steps.removeAt(index);
                                });
                              }
                            },
                            onMoveUp: index > 0 && !isExecuting
                                ? () {
                                    setState(() {
                                      PathStep step = steps.removeAt(index);
                                      steps.insert(index - 1, step);
                                    });
                                  }
                                : null,
                            onMoveDown: index < steps.length - 1 && !isExecuting
                                ? () {
                                    setState(() {
                                      PathStep step = steps.removeAt(index);
                                      steps.insert(index + 1, step);
                                    });
                                  }
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        Container(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAddStepButton(
                    "forward",
                    Icons.arrow_upward,
                    Colors.blue,
                  ),
                  _buildAddStepButton(
                    "backward",
                    Icons.arrow_downward,
                    Colors.orange,
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAddStepButton(
                    "left",
                    Icons.arrow_back,
                    Colors.green,
                  ),
                  _buildAddStepButton(
                    "hold",
                    Icons.pause,
                    Colors.amber,
                  ),
                  _buildAddStepButton(
                    "right",
                    Icons.arrow_forward,
                    Colors.purple,
                  ),
                ],
              ),
              SizedBox(height: 20),
              // Display distance indicator
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  "Distance: ${obstacleDistance.toStringAsFixed(1)} cm",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isExecuting ? Colors.red : Colors.blue,
                        minimumSize: Size(double.infinity, 50),
                      ),
                      onPressed: isExecuting ? _stopExecution : _executePath,
                      child: Text(
                        isExecuting ? "STOP EXECUTION" : "EXECUTE PATH",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.red.withOpacity(isExecuting ? 0.5 : 1.0),
                      minimumSize: Size(60, 50),
                    ),
                    onPressed: isExecuting
                        ? null
                        : () {
                            setState(() {
                              steps.clear();
                            });
                          },
                    child: Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton(String label, ExecutionMode mode, IconData icon) {
    final isSelected = executionMode == mode;
    return InkWell(
      onTap: isExecuting
          ? null
          : () {
              setState(() {
                executionMode = mode;
              });
            },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddStepButton(String direction, IconData icon, Color color) {
    return InkWell(
      onTap: isExecuting ? null : () => _showAddStepDialog(direction),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isExecuting ? color.withOpacity(0.5) : color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }

  void _showAddStepDialog(String direction) {
    TextEditingController distanceController =
        TextEditingController(text: "50");
    TextEditingController durationController = TextEditingController(text: "2");
    TextEditingController angleController = TextEditingController(text: "90");

    String dialogTitle;
    String description;
    bool showDistanceField = true;
    bool showDurationField = false;
    bool showAngleField = false;
    bool showMeasurementOption = false;

    switch (direction) {
      case "forward":
        dialogTitle = "Move Forward";
        description = "Car will move forward in a straight line";
        showMeasurementOption =
            true; // Enable measurement for forward direction
        break;
      case "backward":
        dialogTitle = "Move Backward";
        description = "Car will move backward in a straight line";
        showMeasurementOption =
            true; // Enable measurement for backward direction
        break;
      case "left":
        dialogTitle = "Turn Left";
        description = "Car will turn left by specified angle";
        showDistanceField = false;
        showAngleField = true;
        showMeasurementOption = true; // Enable measurement for left turns
        break;
      case "right":
        dialogTitle = "Turn Right";
        description = "Car will turn right by specified angle";
        showDistanceField = false;
        showAngleField = true;
        showMeasurementOption = true; // Enable measurement for right turns
        break;
      case "hold":
        dialogTitle = "Hold Position";
        description = "Car will pause movement for specified duration";
        showDistanceField = false;
        showDurationField = true;
        break;
      default:
        dialogTitle = "Add Movement";
        description = "Car will follow the specified path";
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(dialogTitle, style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (showDistanceField) ...[
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: distanceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Distance (cm)",
                        labelStyle: TextStyle(color: Colors.blue),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  if (showMeasurementOption) ...[
                    SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                      child: Text("Measure"),
                      onPressed: () {
                        Navigator.pop(context);
                        _startDistanceMeasurement(direction);
                      },
                    ),
                  ],
                ],
              ),
            ],
            if (showAngleField) ...[
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: angleController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Angle (degrees)",
                        labelStyle: TextStyle(
                          color: direction == "left"
                              ? Colors.green
                              : Colors.purple,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: direction == "left"
                                ? Colors.green
                                : Colors.purple,
                          ),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  if (showMeasurementOption) ...[
                    SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                      child: Text("Measure"),
                      onPressed: () {
                        Navigator.pop(context);
                        _startAngleMeasurement(direction);
                      },
                    ),
                  ],
                ],
              ),
            ],
            if (showDurationField) ...[
              SizedBox(height: 20),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Duration (seconds)",
                  labelStyle: TextStyle(color: Colors.amber),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.amber),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            child: Text("CANCEL", style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text("ADD"),
            onPressed: () {
              setState(() {
                if (direction == "hold") {
                  steps.add(PathStep(
                    direction: direction,
                    distance: 0,
                    duration: int.tryParse(durationController.text) ?? 2,
                  ));
                } else if (direction == "left" || direction == "right") {
                  steps.add(PathStep(
                    direction: direction,
                    distance: 0,
                    angle: int.tryParse(angleController.text) ?? 90,
                  ));
                } else {
                  steps.add(PathStep(
                    direction: direction,
                    distance: showDistanceField
                        ? (int.tryParse(distanceController.text) ?? 50)
                        : 0,
                  ));
                }
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
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
              "Obstacle detected at ${obstacleDistance.toStringAsFixed(1)} cm. Path execution paused for safety."),
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

  // New method to handle angle measurement
  void _startAngleMeasurement(String direction) {
    bool isMeasuring = true;
    int measuredAngle = 0;
    int startTime = DateTime.now().millisecondsSinceEpoch;

    // Show measurement overlay/dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text("Measuring ${direction.toUpperCase()} Angle",
                style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Use the controls below to turn the car to the desired angle.",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 20),
                Text(
                  "Estimated angle: $measuredAngle°",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Start button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: Size(100, 50),
                      ),
                      onPressed: isMeasuring
                          ? () async {
                              // Start the movement
                              try {
                                startTime =
                                    DateTime.now().millisecondsSinceEpoch;
                                await http.get(Uri.parse(
                                    "${widget.espIP}/speed?value=$speed"));
                                await http.get(
                                    Uri.parse("${widget.espIP}/$direction"));
                                // Start timer to update estimated angle
                                Timer.periodic(Duration(milliseconds: 100),
                                    (timer) {
                                  if (!isMeasuring) {
                                    timer.cancel();
                                    return;
                                  }
                                  // Calculate estimated angle based on elapsed time and speed
                                  int elapsedMs =
                                      DateTime.now().millisecondsSinceEpoch -
                                          startTime;
                                  double speedFactor = speed / 150.0;
                                  // 590ms for 90-degree turn at speed 150
                                  int estimatedAngle =
                                      ((elapsedMs / 590) * 90 * speedFactor)
                                          .round();

                                  // Cap the angle at 360 degrees max
                                  if (estimatedAngle > 360) {
                                    estimatedAngle = 360;
                                  }

                                  setDialogState(() {
                                    measuredAngle = estimatedAngle;
                                  });
                                });
                              } catch (e) {
                                print("Error during angle measurement: $e");
                              }
                            }
                          : null,
                      child: Text("START"),
                    ),
                    // Stop button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: Size(100, 50),
                      ),
                      child: Text("STOP"),
                      onPressed: () async {
                        try {
                          await http.get(Uri.parse("${widget.espIP}/stop"));
                          setDialogState(() {
                            isMeasuring = false;
                          });
                        } catch (e) {
                          print("Error stopping measurement: $e");
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text("CANCEL", style: TextStyle(color: Colors.white70)),
                onPressed: () async {
                  // Ensure the car stops
                  try {
                    await http.get(Uri.parse("${widget.espIP}/stop"));
                  } catch (e) {
                    print("Error stopping: $e");
                  }
                  Navigator.pop(context);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.blue.withOpacity(0.3),
                ),
                onPressed: !isMeasuring
                    ? () {
                        // Add the step with measured angle
                        setState(() {
                          steps.add(PathStep(
                            direction: direction,
                            distance: 0,
                            angle: measuredAngle,
                          ));
                        });
                        Navigator.pop(context);
                      }
                    : null,
                child: Text("CONFIRM"),
              ),
            ],
          );
        });
      },
    );
  }

  // Method to handle distance measurement (unchanged from original)
  void _startDistanceMeasurement(String direction) {
    bool isMeasuring = true;
    int startTime = DateTime.now().millisecondsSinceEpoch;
    int measuredDistance = 0;

    // Show measurement overlay/dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text("Measuring ${direction.toUpperCase()} Distance",
                style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Use the controls below to move the car to the desired distance.",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 20),
                Text(
                  "Estimated distance: $measuredDistance cm",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Start button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: Size(100, 50),
                      ),
                      onPressed: isMeasuring
                          ? () async {
                              // Start the movement
                              try {
                                startTime =
                                    DateTime.now().millisecondsSinceEpoch;
                                await http.get(Uri.parse(
                                    "${widget.espIP}/speed?value=$speed"));
                                await http.get(
                                    Uri.parse("${widget.espIP}/$direction"));
                                // Start timer to update estimated distance
                                Timer.periodic(Duration(milliseconds: 100),
                                    (timer) {
                                  if (!isMeasuring) {
                                    timer.cancel();
                                    return;
                                  }
                                  // Calculate estimated distance based on elapsed time and speed
                                  int elapsedMs =
                                      DateTime.now().millisecondsSinceEpoch -
                                          startTime;
                                  double speedFactor = speed / 150.0;
                                  int estimatedDistance =
                                      ((elapsedMs / 100) * speedFactor).round();

                                  setDialogState(() {
                                    measuredDistance = estimatedDistance;
                                  });
                                });
                              } catch (e) {
                                print("Error during measurement: $e");
                              }
                            }
                          : null,
                      child: Text("START"),
                    ),
                    // Stop button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: Size(100, 50),
                      ),
                      child: Text("STOP"),
                      onPressed: () async {
                        try {
                          await http.get(Uri.parse("${widget.espIP}/stop"));
                          setDialogState(() {
                            isMeasuring = false;
                          });
                        } catch (e) {
                          print("Error stopping measurement: $e");
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text("CANCEL", style: TextStyle(color: Colors.white70)),
                onPressed: () async {
                  // Ensure the car stops
                  try {
                    await http.get(Uri.parse("${widget.espIP}/stop"));
                  } catch (e) {
                    print("Error stopping: $e");
                  }
                  Navigator.pop(context);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.blue.withOpacity(0.3),
                ),
                onPressed: !isMeasuring
                    ? () {
                        // Add the step with measured distance
                        setState(() {
                          steps.add(PathStep(
                            direction: direction,
                            distance: measuredDistance,
                          ));
                        });
                        Navigator.pop(context);
                      }
                    : null,
                child: Text("CONFIRM"),
              ),
            ],
          );
        });
      },
    );
  }

  void _executePath() async {
    if (steps.isEmpty) return;

    setState(() {
      isExecuting = true;
      currentStepIndex = -1;
      loopCount = 0;
    });

    // Set the speed first
    try {
      await http.get(Uri.parse("${widget.espIP}/speed?value=$speed"));
    } catch (e) {
      print("Error setting speed: $e");
    }

    // Execute based on the selected mode
    while (isExecuting && (infiniteLoop || loopCount < maxLoops)) {
      // Execute forward path
      await _executeSteps(steps);

      if (!isExecuting) break;

      if (executionMode == ExecutionMode.once) {
        break; // Exit after one execution
      } else if (executionMode == ExecutionMode.continuous) {
        // For continuous mode, update loop count and continue
        setState(() {
          loopCount++;
        });
        // Small pause between loops
        await Future.delayed(Duration(milliseconds: 1000));
      } else if (executionMode == ExecutionMode.bidirectional) {
        // For bidirectional, execute steps in reverse order
        await _executeSteps(_reverseSteps(steps));

        if (!isExecuting) break;

        setState(() {
          loopCount++;
        });
        // Small pause between iterations
        await Future.delayed(Duration(milliseconds: 1000));
      }
    }

    // Ensure the car stops when done
    try {
      await http.get(Uri.parse("${widget.espIP}/stop"));
    } catch (e) {
      print("Error stopping: $e");
    }

    setState(() {
      isExecuting = false;
      currentStepIndex = -1;
    });
  }

  // Execute a list of steps
  Future<void> _executeSteps(List<PathStep> stepsToExecute) async {
    for (int i = 0; i < stepsToExecute.length; i++) {
      if (!isExecuting) break; // Stop if execution was cancelled

      setState(() {
        currentStepIndex = i;
      });

      PathStep step = stepsToExecute[i];

      try {
        if (step.direction == "hold") {
          // For hold, we just wait for the specified duration
          await Future.delayed(Duration(seconds: step.duration ?? 2));
        } else {
          // Check for obstacles before movement (except for backward which is safe)
          if (obstacleDetected && step.direction != "backward") {
            _showObstacleDialog();
            // Pause execution until obstacle is cleared
            while (obstacleDetected && isExecuting) {
              await Future.delayed(Duration(milliseconds: 500));
            }
            if (!isExecuting)
              break; // Stop if execution was cancelled during pause
          }

          String command;
          // For left and right, send command with angle parameter
          if (step.direction == "left" || step.direction == "right") {
            command = "${step.direction}?angle=${step.angle ?? 90}";
          } else {
            // For forward and backward, include distance parameter
            command = "${step.direction}?distance=${step.distance}";
          }

          await http.get(Uri.parse("${widget.espIP}/$command"));

          // Calculate waiting time based on the type of movement
          int waitTimeMs;
          if (step.direction == "left" || step.direction == "right") {
            // Dynamic time based on angle for turns
            waitTimeMs = _estimateTimeFromAngle(step.angle ?? 90);
          } else {
            // Dynamic time based on distance for forward/backward
            waitTimeMs = _estimateTimeFromDistance(step.distance);
          }

          // Continuously check for obstacles while executing the step
          int elapsedTime = 0;
          while (elapsedTime < waitTimeMs && isExecuting) {
            // If obstacle detected during forward/turning movement, stop immediately
            if (obstacleDetected && step.direction != "backward") {
              await http.get(Uri.parse("${widget.espIP}/stop"));
              _showObstacleDialog();
              // Wait until obstacle is cleared
              while (obstacleDetected && isExecuting) {
                await Future.delayed(Duration(milliseconds: 500));
              }
              if (!isExecuting) break;

              // Resume movement
              await http.get(Uri.parse("${widget.espIP}/$command"));
            }

            await Future.delayed(Duration(milliseconds: 100));
            elapsedTime += 100;
          }

          // Send stop command after the movement completes
          if (isExecuting) {
            await http.get(Uri.parse("${widget.espIP}/stop"));
            // Small pause between movements
            await Future.delayed(Duration(milliseconds: 500));
          }
        }
      } catch (e) {
        print("Error executing step: $e");
      }
    }
  }

  // Create reversed steps for bidirectional mode
  List<PathStep> _reverseSteps(List<PathStep> originalSteps) {
    List<PathStep> reversedSteps = [];

    // Go through the steps in reverse order
    for (int i = originalSteps.length - 1; i >= 0; i--) {
      PathStep original = originalSteps[i];
      String newDirection;

      // Invert the direction
      switch (original.direction) {
        case "forward":
          newDirection = "backward";
          break;
        case "backward":
          newDirection = "forward";
          break;
        case "left":
          newDirection = "right";
          break;
        case "right":
          newDirection = "left";
          break;
        case "hold":
          newDirection = "hold";
          break;
        default:
          newDirection = original.direction;
      }

      // Create the new step with inverted direction
      reversedSteps.add(PathStep(
        direction: newDirection,
        distance: original.distance,
        duration: original.duration,
        angle: original.angle,
      ));
    }

    return reversedSteps;
  }

  // Helper function to estimate time needed for a given distance
  int _estimateTimeFromDistance(int distance) {
    // This is an approximation - adjust based on your car's speed
    // For higher speeds, we need less time
    double speedFactor = speed / 150.0; // Normalize against default speed
    return (distance * 100 / speedFactor).round();
  }

  // New helper function to estimate time needed for a given angle
  int _estimateTimeFromAngle(int angle) {
    // This is an approximation - 590ms for a 90-degree turn at speed 150
    double speedFactor = speed / 150.0; // Normalize against default speed
    return ((angle * 3600) / 90 / speedFactor).round();
  }

  void _stopExecution() {
    setState(() {
      isExecuting = false;
    });

    try {
      http.get(Uri.parse("${widget.espIP}/stop"));
    } catch (e) {
      print("Error stopping: $e");
    }
  }
}

class PathStep {
  final String direction;
  final int distance;
  final int? duration; // For hold steps
  final int? angle; // For turn steps

  PathStep({
    required this.direction,
    required this.distance,
    this.duration,
    this.angle,
  });
}

class PathStepCard extends StatelessWidget {
  final PathStep step;
  final int index;
  final bool isActive;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const PathStepCard({
    super.key,
    required this.step,
    required this.index,
    required this.isActive,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    IconData directionIcon;
    Color stepColor;
    String directionText;

    switch (step.direction) {
      case "forward":
        directionIcon = Icons.arrow_upward;
        stepColor = Colors.blue;
        directionText = "Move Forward";
        break;
      case "backward":
        directionIcon = Icons.arrow_downward;
        stepColor = Colors.orange;
        directionText = "Move Backward";
        break;
      case "left":
        directionIcon = Icons.arrow_back;
        stepColor = Colors.green;
        directionText = "Turn Left";
        break;
      case "right":
        directionIcon = Icons.arrow_forward;
        stepColor = Colors.purple;
        directionText = "Turn Right";
        break;
      case "hold":
        directionIcon = Icons.pause;
        stepColor = Colors.amber;
        directionText = "Hold Position";
        break;
      default:
        directionIcon = Icons.help;
        stepColor = Colors.grey;
        directionText = "Unknown";
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isActive ? Colors.grey[800] : Colors.grey[900],
      elevation: isActive ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side:
            isActive ? BorderSide(color: stepColor, width: 2) : BorderSide.none,
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: stepColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                directionIcon,
                color: Colors.white,
              ),
            ),
            title: Text(
              "${index + 1}. $directionText",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            subtitle: _buildSubtitle(step),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          if (onMoveUp != null || onMoveDown != null)
            Padding(
              padding: EdgeInsets.only(right: 8, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_upward,
                        color: onMoveUp != null ? Colors.white70 : Colors.grey),
                    onPressed: onMoveUp,
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_downward,
                        color:
                            onMoveDown != null ? Colors.white70 : Colors.grey),
                    onPressed: onMoveDown,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildSubtitle(PathStep step) {
    if (step.direction == "left" || step.direction == "right") {
      return Text(
        "Angle: ${step.angle ?? 90}°",
        style: TextStyle(color: Colors.white70),
      );
    } else if (step.direction == "hold") {
      return Text(
        "Duration: ${step.duration} seconds",
        style: TextStyle(color: Colors.white70),
      );
    } else {
      return Text(
        "Distance: ${step.distance} cm",
        style: TextStyle(color: Colors.white70),
      );
    }
  }
}
