import Foundation
import CoreBluetooth

/// Scans for nearby cycling sensors from the phone. Sensors connect to the
/// WATCH during rides — this scanner exists so the Sensors screen can show
/// what's in range and its signal strength while setting up.
final class PhoneSensorScanner: NSObject, ObservableObject {
    struct Discovered: Identifiable {
        let id: UUID
        var name: String
        var kind: String
        var rssi: Int
    }

    @Published var discovered: [Discovered] = []
    @Published var scanning = false

    private var central: CBCentralManager!

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        guard central.state == .poweredOn else { return }
        discovered = []
        scanning = true
        central.scanForPeripherals(
            withServices: [SensorServices.cyclingPower, SensorServices.heartRate],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        central.stopScan()
        scanning = false
    }

    enum SensorServices {
        static let cyclingPower = CBUUID(string: "1818")
        static let heartRate = CBUUID(string: "180D")
    }
}

extension PhoneSensorScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            scanning = false
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let kind = services.contains(SensorServices.cyclingPower) ? "Power" : "Heart rate"
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "Unknown sensor"

        if let index = discovered.firstIndex(where: { $0.id == peripheral.identifier }) {
            discovered[index].rssi = RSSI.intValue
        } else {
            discovered.append(Discovered(id: peripheral.identifier, name: name,
                                         kind: kind, rssi: RSSI.intValue))
        }
    }
}
