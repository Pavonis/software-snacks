# Sotto

An Apple Watch-first cycling head unit, with an iPhone companion app.
The watch is the display and the brain: it runs the HealthKit workout,
connects to your BLE sensors, and shows a ride carousel styled after Apple
Fitness. The phone handles setup, your ride archive, and mirrors live stats
to the Lock Screen / Dynamic Island as a Live Activity.

Design mocks live in the "Sotto Ride Flow" artifact from the design session.

## What works today

- **Watch ride flow**: Start screen with sensor status → in-ride carousel
  (Controls · Metrics · Elevation · Drivetrain · Now Playing) → summary.
  Metrics page shows 3s power with an FTP-based zone bar, speed, cadence,
  heart rate, elapsed time, and distance.
- **HealthKit workout** (`HKWorkoutSession` + live builder): wrist heart
  rate, active calories, cycling distance; the ride saves to Apple Fitness.
- **BLE sensors on the watch**: Cycling Power Service (0x1818) for power +
  crank cadence, Heart Rate Service (0x180D) for chest straps (preferred
  over wrist HR), Battery Service for sensor battery. In the simulator,
  synthetic sensor data is generated so the UI is demoable.
- **GPS**: speed, altitude, grade (60 m rolling window), elevation gain,
  and a thinned route line.
- **Music**: the system `NowPlayingView` as the carousel's last page —
  full Apple Music control without a custom player (custom UI can come
  later if it earns it).
- **Live Activity**: lock screen card + Dynamic Island (expanded, compact,
  minimal), fed from the watch over WatchConnectivity at ~1 Hz.
- **iPhone app**: live ride card, ride archive with MapKit route + stats,
  nearby-sensor scanner, drivetrain configuration (synced to the watch).

## Honest limitations

- **Drivetrain**: SRAM AXS / Shimano Di2 use proprietary BLE protocols, so
  the gear page shows an *estimate* derived from speed + cadence + wheel
  circumference against the configured chainrings/cassette. Real gear and
  derailleur battery need the protocol reverse-engineered or a vendor SDK.
- **Backgrounded BLE on watchOS** is best-effort: with the workout session
  running Sotto stays live, but sub-second sensor latency isn't guaranteed
  when the wrist is down. The Live Activity mirrors at the WatchConnectivity
  rate (roughly every second, less when the phone app isn't foregrounded).
- Drivetrain config is display-only for now (2×12, 48/35, 10–33 defaults);
  the editor screen is on the iterate list.
- Written without access to Xcode — expect a shakedown build before the
  first ride.

## Building

1. Open `Sotto.xcodeproj` in Xcode 15+.
2. Set your development team on all three targets (Sotto, SottoWatch,
   SottoWidgets) and change the `com.example.Sotto` bundle-ID prefix to
   your own (keep the `.watchkitapp` / `.SottoWidgets` suffixes).
3. Run the `Sotto` scheme on an iPhone with a paired Apple Watch; the watch
   app installs alongside it (or run `SottoWatch` directly on a watch or
   simulator).
4. On first launch grant Health, Location, and Bluetooth permissions on the
   watch, and allow Live Activities on the phone.

## Layout

- `SottoWatch/` — watch app: workout + sensors + ride UI
- `Sotto/` — iPhone companion: archive, sensors, config, Live Activity host
- `SottoWidgets/` — widget extension rendering the Live Activity
- `Shared/` — models shared across targets
