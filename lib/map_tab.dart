import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class AutoDriveTab extends StatefulWidget {
  final String espIP;

  const AutoDriveTab({super.key, required this.espIP});

  @override
  _AutoDriveTabState createState() => _AutoDriveTabState();
}

class _AutoDriveTabState extends State<AutoDriveTab>
    with AutomaticKeepAliveClientMixin {
  // Map controller
  GoogleMapController? _mapController;

  // Location tracking
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Route information
  LatLng? _destinationLocation;
  String _destinationAddress = "";
  List<LatLng> _routePoints = [];
  Map<String, dynamic>? _routeInfo;

  // Status flags
  bool _isMapReady = false;
  bool _isLoading = false;
  bool _isRouteReady = false;
  bool _isAutoDriveActive = false;

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  // Auto-drive variables
  Timer? _navigationTimer;
  int _currentRouteIndex = 0;
  final double _currentSpeed = 204; // Default speed (0-1023)

  // Obstacle detection variables
  bool obstacleDetected = false;
  double obstacleDistance = 0.0;
  Timer? _statusTimer;
  bool _showingDialog = false;

  // API key for maps
  final String _mapApiKey =
      "AIzaSyBsx2D10ik78UQSFlbrxdQDVYYGexAWrJI"; // Replace with your actual API key

  // Initial camera position
  CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(20.5937, 78.9629), // Default to center of India
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    // Check sensor status every 500ms
    _statusTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      checkSensorStatus();
    });
  }

  @override
  void dispose() {
    _stopNavigation();
    _mapController?.dispose();
    _searchController.dispose();
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

          // If obstacle detected during auto drive, stop the car
          if (newObstacleState && _isAutoDriveActive) {
            _pauseForObstacle();
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

  // Pause auto-drive due to obstacle
  void _pauseForObstacle() {
    _sendCommand("stop");
    _stopNavigation();

    // We don't fully deactivate auto-drive, just pause it
    // The navigation will resume when obstacle is cleared
  }

  // Get user's current location
  void _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled')),
      );
      return;
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Location permissions are permanently denied')),
      );
      return;
    }

    // Get current position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _initialCameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15,
        );
        _isLoading = false;

        if (_isMapReady && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(_initialCameraPosition),
          );

          // Add marker for current location
          _updateCurrentLocationMarker();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Error getting current location: $e");
    }
  }

  // Update current location marker
  void _updateCurrentLocationMarker() {
    if (_currentPosition == null) return;

    setState(() {
      // Remove previous current location marker
      _markers.removeWhere(
          (marker) => marker.markerId == const MarkerId('currentLocation'));

      // Add new current location marker
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  // Search for places
  void _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final String url =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$_mapApiKey&components=country:IND";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(json.decode(response.body));

        if (data["status"] == "OK") {
          setState(() {
            _searchResults = data["predictions"];
            _isSearching = false;
          });
        } else {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      print("Error searching places: $e");
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  // Select a place from search results
  void _selectPlace(dynamic place) async {
    final placeId = place["place_id"];
    final String mainText = place["structured_formatting"]["main_text"];

    setState(() {
      _searchController.text = mainText;
      _searchResults = [];
      _isLoading = true;
    });

    try {
      final String url =
          "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_mapApiKey";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(json.decode(response.body));

        if (data["status"] == "OK") {
          final result = data["result"];
          final location = result["geometry"]["location"];
          final lat = location["lat"];
          final lng = location["lng"];
          final address = result["formatted_address"];

          setState(() {
            _destinationLocation = LatLng(lat, lng);
            _destinationAddress = address;

            // Add destination marker
            _markers.removeWhere(
                (m) => m.markerId == const MarkerId('destination'));
            _markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(title: mainText, snippet: address),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
              ),
            );
          });

          // Get directions
          _getDirections();
        }
      }
    } catch (e) {
      print("Error getting place details: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Get directions from current location to destination
  void _getDirections() async {
    if (_currentPosition == null || _destinationLocation == null) return;

    setState(() {
      _isLoading = true;
      _polylines.clear();
    });

    try {
      final String url = "https://maps.googleapis.com/maps/api/directions/json"
          "?origin=${_currentPosition!.latitude},${_currentPosition!.longitude}"
          "&destination=${_destinationLocation!.latitude},${_destinationLocation!.longitude}"
          "&key=$_mapApiKey";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(json.decode(response.body));

        if (data["status"] == "OK") {
          // Extract route information
          final routes = data["routes"];
          if (routes.isNotEmpty) {
            final route = routes[0];
            final leg = route["legs"][0];
            final steps = leg["steps"];

            // Extract polyline
            final polyline = route["overview_polyline"]["points"];
            List<LatLng> polylineCoordinates = [];

            // Decode polyline
            PolylinePoints polylinePoints = PolylinePoints();
            List<PointLatLng> decodedPolyline =
                polylinePoints.decodePolyline(polyline);

            for (var point in decodedPolyline) {
              polylineCoordinates.add(LatLng(point.latitude, point.longitude));
            }

            setState(() {
              _routePoints = polylineCoordinates;
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId("route"),
                  color: Colors.blue,
                  points: polylineCoordinates,
                  width: 5,
                ),
              );

              _routeInfo = {
                "distance": leg["distance"]["text"],
                "duration": leg["duration"]["text"],
                "steps": steps,
              };

              _isRouteReady = true;
            });

            // Fit map to show the entire route
            if (_mapController != null) {
              LatLngBounds bounds = _getLatLngBounds(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                _destinationLocation!,
              );

              _mapController!.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, 100),
              );
            }
          }
        }
      }
    } catch (e) {
      print("Error getting directions: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper to create bounds for camera
  LatLngBounds _getLatLngBounds(LatLng origin, LatLng destination) {
    if (origin.latitude > destination.latitude &&
        origin.longitude > destination.longitude) {
      return LatLngBounds(southwest: destination, northeast: origin);
    } else if (origin.latitude > destination.latitude) {
      return LatLngBounds(
        southwest: LatLng(destination.latitude, origin.longitude),
        northeast: LatLng(origin.latitude, destination.longitude),
      );
    } else if (origin.longitude > destination.longitude) {
      return LatLngBounds(
        southwest: LatLng(origin.latitude, destination.longitude),
        northeast: LatLng(destination.latitude, origin.longitude),
      );
    } else {
      return LatLngBounds(southwest: origin, northeast: destination);
    }
  }

  // Start autonomous navigation
  void _startAutoDrive() {
    if (!_isRouteReady || _routePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid route available')),
      );
      return;
    }

    // Don't start if obstacle detected
    if (obstacleDetected) {
      _showObstacleDialog();
      return;
    }

    setState(() {
      _isAutoDriveActive = true;
      _currentRouteIndex = 0;
    });

    // Send initial speed command
    _sendCommand("speed?value=${_currentSpeed.toInt()}");

    // Show confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Drive Activated'),
        content: const Text(
          'The car will now navigate to the destination automatically. '
          'Press STOP at any time to take manual control.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNavigation();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Stop autonomous navigation
  void _stopAutoDrive() {
    _stopNavigation();

    // Send stop command to vehicle
    _sendCommand("stop");

    setState(() {
      _isAutoDriveActive = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Auto-drive deactivated')),
    );
  }

  // Navigation logic
  void _startNavigation() {
    // Cancel any existing timer
    _navigationTimer?.cancel();

    // Start a new timer for navigation updates
    _navigationTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (_currentRouteIndex >= _routePoints.length - 1) {
        // Reached destination
        _completeNavigation();
        return;
      }

      _navigateToNextPoint();
    });
  }

  void _navigateToNextPoint() {
    if (_currentRouteIndex >= _routePoints.length - 1 || obstacleDetected)
      return;

    // Get current and next point
    LatLng currentPoint = _routePoints[_currentRouteIndex];
    LatLng nextPoint = _routePoints[_currentRouteIndex + 1];

    // Calculate bearing to determine direction
    double bearing = _calculateBearing(currentPoint, nextPoint);

    // Determine command based on bearing
    String command = _getDirectionCommand(bearing);

    // Check if we should signal a turn
    if (_currentRouteIndex + 5 < _routePoints.length) {
      LatLng futurePoint = _routePoints[_currentRouteIndex + 5];
      double futureBearing = _calculateBearing(nextPoint, futurePoint);
      double bearingDifference = _normalizeBearing(futureBearing - bearing);

      // Detect turns
      if (bearingDifference > 30) {
        // Right turn coming up
        _sendCommand("rightIndicator");
      } else if (bearingDifference < -30) {
        // Left turn coming up
        _sendCommand("leftIndicator");
      } else {
        // No turn, clear indicators
        _sendCommand("clearIndicators");
      }
    }

    // Send movement command
    _sendCommand(command);

    // Move to the next point if we're close enough to the current target
    double distance = _calculateDistance(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        nextPoint);

    if (distance < 5) {
      // Within 5 meters of the point
      setState(() {
        _currentRouteIndex++;

        // Update current position for visualization (in real use, this would come from GPS)
        _currentPosition = Position(
          latitude: nextPoint.latitude,
          longitude: nextPoint.longitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: bearing,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        _updateCurrentLocationMarker();
      });

      // Keep camera centered on current position
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(nextPoint),
      );
    }
  }

  void _stopNavigation() {
    _navigationTimer?.cancel();
    _navigationTimer = null;
  }

  void _completeNavigation() {
    _stopNavigation();
    _sendCommand("stop");

    setState(() {
      _isAutoDriveActive = false;
    });

    // Show completion dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Destination Reached'),
        content: const Text('You have arrived at your destination.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Helper methods for navigation
  double _calculateBearing(LatLng start, LatLng end) {
    double startLat = start.latitude * math.pi / 180;
    double startLng = start.longitude * math.pi / 180;
    double endLat = end.latitude * math.pi / 180;
    double endLng = end.longitude * math.pi / 180;

    double y = math.sin(endLng - startLng) * math.cos(endLat);
    double x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(endLng - startLng);

    double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360; // Normalize to 0-360
  }

  double _normalizeBearing(double bearing) {
    if (bearing > 180) return bearing - 360;
    if (bearing < -180) return bearing + 360;
    return bearing;
  }

  String _getDirectionCommand(double bearing) {
    // Convert bearing to cardinal direction command
    if (bearing >= 315 || bearing < 45) {
      return "forward"; // North
    } else if (bearing >= 45 && bearing < 135) {
      return "right"; // East
    } else if (bearing >= 135 && bearing < 225) {
      return "backward"; // South
    } else {
      return "left"; // West
    }
  }

  double _calculateDistance(LatLng start, LatLng end) {
    double lat1 = start.latitude * math.pi / 180;
    double lon1 = start.longitude * math.pi / 180;
    double lat2 = end.latitude * math.pi / 180;
    double lon2 = end.longitude * math.pi / 180;

    // Haversine formula
    double dlon = lon2 - lon1;
    double dlat = lat2 - lat1;
    double a = math.pow(math.sin(dlat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dlon / 2), 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    // Earth radius in meters
    double r = 6371000;
    return r * c;
  }

  // Send command to ESP with obstacle check
  void _sendCommand(String command) async {
    try {
      // Don't send movement commands if obstacle is detected (except "stop" and "backward")
      if (obstacleDetected && command != "stop" && command != "backward") {
        _showObstacleDialog();
        return;
      }

      await http.get(Uri.parse("${widget.espIP}/$command"));
    } catch (e) {
      print("Error sending command: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Stack(
      children: [
        // Google Map
        GoogleMap( 
          initialCameraPosition: _initialCameraPosition,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          zoomGesturesEnabled: true,
          markers: _markers,
          polylines: _polylines,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            setState(() {
              _isMapReady = true;
            });

            if (_currentPosition != null) {
              controller.animateCamera(
                CameraUpdate.newLatLng(
                  LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude),
                ),
              );
              _updateCurrentLocationMarker();
            }
          },
        ),

        // Search bar
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search destination',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
              onChanged: _searchPlaces,
            ),
          ),
        ),

        // Obstacle detection indicator
        if (obstacleDetected)
          Positioned(
            top: 70, // Position below search bar
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.all(10),
                margin: EdgeInsets.symmetric(horizontal: 20),
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
            ),
          ),

        // Search results
        if (_searchResults.isNotEmpty)
          Positioned(
            top: 60,
            left: 10,
            right: 10,
            child: Container(
              constraints: BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final place = _searchResults[index];
                  return ListTile(
                    title: Text(place["structured_formatting"]["main_text"]),
                    subtitle: Text(
                        place["structured_formatting"]["secondary_text"] ?? ""),
                    onTap: () => _selectPlace(place),
                  );
                },
              ),
            ),
          ),

        // Loading indicator
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),

        // Bottom controls
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Route info card (if route is ready)
              if (_isRouteReady)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _destinationAddress,
                              style: TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Distance: ${_routeInfo!["distance"]}'),
                          Text('ETA: ${_routeInfo!["duration"]}'),
                        ],
                      ),
                      SizedBox(height: 8),
                      // Display distance indicator in route info card
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Distance to obstacle: ${obstacleDistance.toStringAsFixed(1)} cm",
                          style: TextStyle(
                              color: obstacleDetected
                                  ? Colors.red
                                  : Colors.black54),
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(_isAutoDriveActive
                                  ? Icons.stop
                                  : Icons.play_arrow),
                              label: Text(_isAutoDriveActive
                                  ? 'STOP AUTO-DRIVE'
                                  : 'START AUTO-DRIVE'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isAutoDriveActive
                                    ? Colors.red
                                    : obstacleDetected
                                        ? Colors.grey
                                        : Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: obstacleDetected && !_isAutoDriveActive
                                  ? null
                                  : _isAutoDriveActive
                                      ? _stopAutoDrive
                                      : _startAutoDrive,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 10),
            ],
          ),
        ),

        // My Location button
        Positioned(
          bottom: _isRouteReady ? 200 : 100,
          right: 20,
          child: FloatingActionButton(
            mini: true,
            onPressed: _getCurrentLocation,
            child: Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
