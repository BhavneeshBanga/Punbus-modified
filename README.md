# PunBus Tracker (Modified & Enhanced)

A modern, fast, and enhanced Flutter application for tracking Punjab Roadways and PUNBUS buses in real time without any captchas and with multi-bus tracking capabilities.

---

## 🌟 Key Features & Improvements

### 1. ⚡ No Captcha Verification
- In the original official app, users were required to manually solve math addition captchas (*e.g., "what is 8 + 5"*) on every single bus search.
- This modified version completely bypasses captchas by querying the underlying tracking backend directly (`veh-track.php` & `nearby_buses.php`), saving time on every check.

### 2. 🚌 "My Buses" Persistent List
- Save 15–20+ frequent 4-digit bus numbers locally using `SharedPreferences`.
- Add new bus numbers with 1-tap dialog validation.
- Remove buses quickly with the `X` button on each chip.
- Persists across app restarts.

### 3. 🔍 Parallel Multi-Bus Live Tracking ("Search All Buses")
- With one tap, queries the live GPS server for **all saved buses simultaneously** using parallel non-blocking requests (`Future.wait`).
- Inactive or offline buses ("no record found") are silently filtered out.
- Renders all active buses on Google Maps at the same time.

### 4. 🗺️ Advanced Google Maps Integration
- Auto-fits the camera bounds (`LatLngBounds`) to enclose all tracked buses.
- Directional bus icons with live bearing/heading rotation.
- Tapping a bus marker opens a detailed modal bottom sheet displaying:
  - Bus Number & Vehicle Type
  - Current Speed (km/h) & Movement Status
  - Route Name & Upcoming Stop
  - Estimated Arrival Time (ETA) & Scheduled Time (ETD)
  - Live GPS Coordinates
  - Direct 1-tap Phone Call to Driver / Crew (if available in GPS payload)
- Bottom horizontal carousel allowing quick camera jump between buses.
- Live refresh button to re-poll all bus coordinates at any moment.

### 5. 📱 Full Original Service Suite Maintained
- **ETA (Estimated Time of Arrival)**: View arriving buses by Punjab bus station.
- **ETD (Estimated Time of Departure)**: Timetables and departures from stops.
- **Nearby Buses**: Uses GPS `Geolocator` to locate buses close to the user's current location.
- **Grievance Portal**: Direct connection to the Government of Punjab grievance redressal portal (`https://connect.punjab.gov.in/service/grievance/gr1`).
- **Contact Us**: Comprehensive directory of Punjab Roadways depots with 1-tap dialing and official website links.

---

## 🔌 Reverse Engineered API Architecture

- **Base URL**: `https://punbus.itracking.in/punbusApp/tracker/`
- **Auth Param**: `username=punbus`

| Service | Endpoint | Description |
| :--- | :--- | :--- |
| **Bus Tracking** | `veh-track.php?username=punbus&reg_no=<bus_no>` | Queries live GPS coordinates and telemetry for a specific bus |
| **Nearby Buses** | `nearby_buses.php?username=punbus&source_id=<id>` | Returns buses around a station/source ID |
| **ETA Routes** | `eta.php?username=punbus&src_id=<id>` | Incoming routes and arrival times for a station |
| **ETD Routes** | `stops_etd_dest.php?username=punbus&dest_id=<id>` | Outgoing routes and departure timetables |
| **Vehicle Types**| `veh_type_list.php?username=punbus` | List of bus categories (AC3X2, VOLVO, ORD, etc.) |

---

## 📂 Project Structure

```
punbustracker_modified/
├── android/                   # Native Android setup with Google Maps key & permissions
├── assets/
│   └── icons/                # Original PunBus brand assets, logos, and bus markers
├── lib/
│   ├── main.dart             # App entry point, Material 3 theme & routes
│   ├── models/
│   │   ├── marker_detail.dart# Comprehensive bus location & telemetry model
│   │   └── route_model.dart  # Route, stop, and contact models
│   ├── pages/
│   │   ├── home_page.dart    # Dashboard with My Buses chips & Search All button
│   │   ├── map_page.dart     # Google Maps view for multi-bus tracking
│   │   ├── nearby_buses_page.dart # Proximity search using device GPS
│   │   ├── eta_page.dart     # Estimated arrival time search
│   │   ├── etd_page.dart     # Estimated departure time timetable
│   │   ├── grievance_page.dart # Punjab Govt grievance portal connector
│   │   └── contact_us.dart   # Depot helpline numbers with 1-tap dialer
│   ├── services/
│   │   ├── api_service.dart  # Direct HTTP queries without captchas
│   │   └── bus_storage.dart  # SharedPreferences persistence for saved buses
│   ├── utils/
│   │   └── constants.dart    # Colors, endpoints, and shared constants
│   └── widgets/
│       ├── bus_chip.dart     # Removable bus chip widget
│       ├── curved_header.dart# PunBus saffron gradient curved header
│       └── menu_card.dart    # Feature menu cards with ripple effects
└── pubspec.yaml              # Flutter dependencies and asset configuration
```

---

## 🚀 How to Build & Run

### Prerequisites
1. Install Flutter SDK (`>= 3.0.0`).
2. Android Studio or VS Code with Flutter extension.
3. Android device or emulator (Android 5.0 / API 21+).

### Steps
1. Navigate into the project folder:
   ```bash
   cd punbustracker_modified
   ```

2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

4. Build release APK:
   ```bash
   flutter build apk --release
   ```
   The APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

### Build APK with GitHub Actions

This repository includes the workflow `.github/workflows/build_apk.yml` that builds a release APK and uploads it as an artifact.

1. Open **Actions** → **Build PunBus APK** and run it with **Run workflow**.
2. Download the artifact named **punbustracker-release-apk** from the completed run.
