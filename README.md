# 🤖 Autonomous Unmanned Ground Vehicle (UGV) – Smart Car Controller App

A cross-platform mobile application powered by **Flutter**, this project enables control and automation of a smart delivery robot/UGV using **ESP8266**, **GPS**, and **Computer Vision**. Designed for **warehouse automation**, **logistics**, and **smart delivery**, the system offers manual, path-based, and autonomous driving modes.

---

## 🚀 Features

### 🕹️ Manual Control
- Directional control (Forward, Backward, Left, Right)
- Adjustable speed (0–1023)
- Real-time obstacle detection
- Haptic feedback for button press
- Safety lockout if obstacles are detected

### 🧭 Path Control
- Predefined movement sequences with multiple modes:
  - **Once**, **Loop**, **Bidirectional**
- Supports:
  - Directional commands
  - Hold positions (pause)
  - Reordering, editing, saving paths
- Obstacle-aware execution

### 🗺️ Auto Drive (WIP)
- GPS + Google Maps integration
- Destination-based navigation
- Real-time distance updates
- Future support for traffic-aware routing

### 🧠 Computer Vision
- Camera-enabled object detection
- Identifies people, objects, or delivery zones
- Enables intelligent stopping or rerouting

---

## 🧰 Tech Stack

| Category          | Technology                         |
|------------------|-------------------------------------|
| Mobile App       | Flutter                             |
| Microcontroller  | ESP8266                             |
| Sensors          | Ultrasonic Sensor (Obstacle Detect) |
| GPS Module       | NEO-6M                              |
| Vision           | Raspberry Pi + TensorFlow Lite      |
| Communication    | HTTP (ESP8266 ↔ App)                |
| UI               | Dark Theme, Responsive, Haptic      |

---

## 🌐 Use Cases

- 📦 **Autonomous Delivery & Logistics**
- 🏭 **Warehouse Automation**
- 🚑 **Healthcare & Pandemic Response**
- 🌾 **Smart Agriculture**
- 🛡️ **Security & Surveillance**

---

## 🏁 Getting Started

### 📱 Prerequisites
- Flutter SDK (>= 3.0.0)
- Dart (>= 2.17.0)
- ESP8266 Dev Board + Arduino IDE
- Raspberry Pi (optional for vision tasks)
- Google Maps API Key

### 🔧 Setup Instructions

1. **Clone the Repo**
   ```bash
   git clone https://github.com/your-username/UGV-SmartCarController.git
   cd UGV-SmartCarController
