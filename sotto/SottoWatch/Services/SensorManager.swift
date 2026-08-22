import Foundation
import CoreBluetooth
import Combine

/// Connects to standard BLE cycling sensors from the watch:
/// - Cycling Power Service (0x1818): instantaneous power + crank cadence
/// - Heart Rate Service (0x180D): chest-strap heart rate (preferred over wrist)
/// - Battery Service (0x180F): battery level for connected sensors
///
/// Electronic drivetrains (SRAM AXS, Shimano Di2) use proprietary protocols,
/// so gear position stays estimated/unavailable until that's reverse-engineered
/// or an SDK is adopted — the drivetrain page reflects that honestly.
final class SensorManager: NSObject, ObservableObject {
    static let cyclingPowerService = CBUUID(string: "1818")
    static let heartRateService = CBUUID(string: "180D")
    static let batteryService = CBUUID(string: "180F")
    static let powerMeasurement = CBUUID(string: "2A63")
    static let heartRateMeasurement = CBUUID(string: "2A37")
    static let batteryLevel = CBUUID(string: "2A19")

    @Published var instantPower: Int = 0
    @Published var power3s: Int = 0
    @Published var cadence: Int = 0
    @Published var strapHeartRate: Int = 0
    @Published var powerMeterConnected = false
    @Published var powerMeterName: String?
    @Published var powerMeterBattery: Int?
    @Published var heartRateStrapConnected = false
    @Published var heartRateStrapName: String?

    private var central: CBCentralManager!
    private var powerPeripheral: CBPeripheral?
    private var heartRatePeripheral: CBPeripheral?
    private var recentPower: [Int] = []
    private var lastCrankRevolutions: UInt16?
    private var lastCrankEventTime: UInt16?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        #if targetEnvironment(simulator)
        startSimulator()
        #endif
    }

    func startScanning() {
        guard central.state == .poweredOn, !central.isScanning else { return }
        central.scanForPeripherals(
            withServices: [Self.cyclingPowerService, Self.heartRateService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func recordPower(_ watts: Int) {
        instantPower = watts
        recentPower.append(watts)
        if recentPower.count > 3 { recentPower.removeFirst() }
        power3s = recentPower.reduce(0, +) / recentPower.count
    }

    // MARK: - Characteristic parsing

    private func parsePowerMeasurement(_ data: Data) {
        guard data.count >= 4 else { return }
        let flags = UInt16(data[0]) | (UInt16(data[1]) << 8)
        let watts = Int(Int16(bitPattern: UInt16(data[2]) | (UInt16(data[3]) << 8)))
        recordPower(max(0, watts))

        // Optional fields precede crank data; walk the offsets the flags declare.
        var offset = 4
        if flags & 0x0001 != 0 { offset += 1 } // pedal power balance
        if flags & 0x0004 != 0 { offset += 2 } // accumulated torque
        if flags & 0x0010 != 0 { offset += 6 } // wheel revolution data
        if flags & 0x0020 != 0, data.count >= offset + 4 { // crank revolution data
            let revolutions = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            let eventTime = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
            updateCadence(revolutions: revolutions, eventTime: eventTime)
        }
    }

    private func updateCadence(revolutions: UInt16, eventTime: UInt16) {
        defer {
            lastCrankRevolutions = revolutions
            lastCrankEventTime = eventTime
        }
        guard let lastRevs = lastCrankRevolutions, let lastTime = lastCrankEventTime else { return }
        let revDelta = revolutions &- lastRevs
        let timeDelta = eventTime &- lastTime // 1/1024 s units, rollover-safe
        guard revDelta > 0, timeDelta > 0 else { return }
        let seconds = Double(timeDelta) / 1024.0
        cadence = Int((Double(revDelta) / seconds) * 60.0)
    }

    private func parseHeartRate(_ data: Data) {
        guard data.count >= 2 else { return }
        let flags = data[0]
        if flags & 0x01 == 0 {
            strapHeartRate = Int(data[1])
        } else if data.count >= 3 {
            strapHeartRate = Int(UInt16(data[1]) | (UInt16(data[2]) << 8))
        }
    }

    // MARK: - Simulator support

    #if targetEnvironment(simulator)
    private var simulatorTimer: Timer?

    private func startSimulator() {
        powerMeterConnected = true
        powerMeterName = "Simulated Power"
        powerMeterBattery = 78
        heartRateStrapConnected = true
        heartRateStrapName = "Simulated HR"
        simulatorTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recordPower(200 + Int.random(in: 0...80))
            self.cadence = 85 + Int.random(in: 0...12)
            self.strapHeartRate = 140 + Int.random(in: 0...20)
        }
    }
    #endif
}

extension SensorManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            powerMeterConnected = false
            heartRateStrapConnected = false
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        if services.contains(Self.cyclingPowerService), powerPeripheral == nil {
            powerPeripheral = peripheral
            central.connect(peripheral)
        } else if services.contains(Self.heartRateService), heartRatePeripheral == nil {
            heartRatePeripheral = peripheral
            central.connect(peripheral)
        }
        if powerPeripheral != nil && heartRatePeripheral != nil {
            central.stopScan()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([Self.cyclingPowerService, Self.heartRateService, Self.batteryService])
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        if peripheral == powerPeripheral {
            powerPeripheral = nil
            powerMeterConnected = false
        }
        if peripheral == heartRatePeripheral {
            heartRatePeripheral = nil
            heartRateStrapConnected = false
        }
        startScanning()
    }
}

extension SensorManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case Self.powerMeasurement:
                powerMeterConnected = true
                powerMeterName = peripheral.name ?? "Power Meter"
                peripheral.setNotifyValue(true, for: characteristic)
            case Self.heartRateMeasurement:
                heartRateStrapConnected = true
                heartRateStrapName = peripheral.name ?? "Heart Rate"
                peripheral.setNotifyValue(true, for: characteristic)
            case Self.batteryLevel:
                peripheral.readValue(for: characteristic)
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }
        switch characteristic.uuid {
        case Self.powerMeasurement:
            parsePowerMeasurement(data)
        case Self.heartRateMeasurement:
            parseHeartRate(data)
        case Self.batteryLevel:
            if peripheral == powerPeripheral, let level = data.first {
                powerMeterBattery = Int(level)
            }
        default:
            break
        }
    }
}
