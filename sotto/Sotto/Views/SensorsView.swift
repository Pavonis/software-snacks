import SwiftUI

struct SensorsView: View {
    @EnvironmentObject private var link: PhoneLink
    @StateObject private var scanner = PhoneSensorScanner()
    @AppStorage("drivetrainConfigData") private var configData: Data = Data()
    @State private var config = DrivetrainConfig()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Sensors pair to your watch automatically when a ride starts. This screen shows what's broadcasting nearby.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Drivetrain Setup") {
                    HStack {
                        Text("Speeds")
                        Spacer()
                        Text("\(config.chainrings.count) × \(config.speedCount)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Chainrings")
                        Spacer()
                        Text(config.chainrings.map(String.init).joined(separator: " / "))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Cassette")
                        Spacer()
                        Text("\(config.cassette.first ?? 0)–\(config.cassette.last ?? 0)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Wheel circumference")
                        Spacer()
                        Text("\(config.wheelCircumferenceMM) mm")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Text("Used for gear estimation and speed-from-cadence fallback. Editable setup screen is on the iterate list.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                Section {
                    if scanner.discovered.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(scanner.scanning ? "Scanning…" : "Bluetooth unavailable")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(scanner.discovered) { sensor in
                            HStack {
                                Image(systemName: sensor.kind == "Power" ? "bolt.fill" : "heart.fill")
                                    .foregroundStyle(sensor.kind == "Power" ? .sottoPurple : .sottoPink)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(sensor.name)
                                        .font(.body.weight(.medium))
                                    Text(sensor.kind)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(sensor.rssi) dBm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Found Nearby")
                        Spacer()
                        if scanner.scanning {
                            Text("Scanning")
                                .font(.caption2)
                                .foregroundStyle(.sottoCyan)
                        }
                    }
                }
            }
            .navigationTitle("Sensors")
            .onAppear {
                if let saved = try? JSONDecoder().decode(DrivetrainConfig.self, from: configData) {
                    config = saved
                }
                link.sendDrivetrainConfig(config)
                scanner.startScanning()
            }
            .onDisappear {
                scanner.stopScanning()
            }
        }
    }
}
