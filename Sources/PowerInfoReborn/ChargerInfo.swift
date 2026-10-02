import AppKit
import IOKit
import IOKit.ps
import IOKit.pwr_mgt

/// One labelled value in the charger info popover (and its copied report).
struct DetailItem: Identifiable, Equatable {
    var label: String
    var value: String
    var symbol: String
    var id: String { label }
}

/// A power profile (USB Power Delivery PDO) the charger offers.
struct PowerProfile: Identifiable, Equatable {
    enum Kind: String { case fixed = "Fixed", variable = "Variable", battery = "Battery", pps = "PPS", avs = "AVS" }

    /// 1-based object position, as used by the PD contract.
    var id: Int
    var kind: Kind
    var minMillivolts: Int
    var maxMillivolts: Int
    var maxMilliamps: Int?
    var maxMilliwatts: Int?

    var voltageText: String {
        minMillivolts == maxMillivolts
            ? Units.volts(maxMillivolts, digits: 0)
            : "\(Units.volts(minMillivolts, digits: 1, unit: false))–\(Units.volts(maxMillivolts, digits: 1))"
    }

    var currentText: String? { maxMilliamps.map { Units.amps($0) } }

    var watts: Int {
        if let maxMilliwatts { return maxMilliwatts / 1000 }
        return maxMillivolts * (maxMilliamps ?? 0) / 1_000_000
    }

    /// Decodes a raw 32-bit USB PD source capability.
    init?(position: Int, pdo raw: Int) {
        let pdo = UInt32(truncatingIfNeeded: raw)
        guard pdo != 0 else { return nil }
        id = position
        switch pdo >> 30 {
        case 0:
            kind = .fixed
            maxMillivolts = Int((pdo >> 10) & 0x3FF) * 50
            minMillivolts = maxMillivolts
            maxMilliamps = Int(pdo & 0x3FF) * 10
        case 1:
            kind = .battery
            maxMillivolts = Int((pdo >> 20) & 0x3FF) * 50
            minMillivolts = Int((pdo >> 10) & 0x3FF) * 50
            maxMilliwatts = Int(pdo & 0x3FF) * 250
        case 2:
            kind = .variable
            maxMillivolts = Int((pdo >> 20) & 0x3FF) * 50
            minMillivolts = Int((pdo >> 10) & 0x3FF) * 50
            maxMilliamps = Int(pdo & 0x3FF) * 10
        default:
            if (pdo >> 28) & 0x3 == 0 {
                kind = .pps
                maxMillivolts = Int((pdo >> 17) & 0xFF) * 100
                minMillivolts = Int((pdo >> 8) & 0xFF) * 100
                maxMilliamps = Int(pdo & 0x7F) * 50
            } else {
                kind = .avs
                maxMillivolts = Int((pdo >> 17) & 0x1FF) * 100
                minMillivolts = Int((pdo >> 8) & 0xFF) * 100
                maxMilliwatts = Int(pdo & 0xFF) * 1000
            }
        }
    }

    /// A profile from the adapter's simpler "UsbHvcMenu" list.
    init(index: Int, millivolts: Int, milliamps: Int) {
        id = index + 1
        kind = .fixed
        minMillivolts = millivolts
        maxMillivolts = millivolts
        maxMilliamps = milliamps
    }
}

/// Everything macOS will tell us about the connected charger, the power
/// flowing through the Mac and the battery. Read from IOKit's power-source
/// APIs and the AppleSmartBattery registry entry; any value can be missing
/// depending on the Mac and the charger.
struct ChargerInfo: Equatable {
    var connected = false

    // Adapter
    var name: String?
    var manufacturer: String?
    var model: String?
    var serial: String?
    var hardwareVersion: String?
    var firmwareVersion: String?
    var adapterID: Int?
    var familyCode: Int?
    var adapterDescription: String?
    var ratedWatts: Int?
    var adapterMillivolts: Int?
    var adapterMilliamps: Int?
    var isWireless: Bool?
    var sourceID: Int?
    var vendorID: Int?
    var productID: Int?
    var profiles: [PowerProfile] = []
    var activeProfile: Int?
    var contractMillivolts: Int?
    var contractMilliamps: Int?
    var capabilities: [String] = []

    // Live power
    var inputMilliwatts: Int?
    var inputMillivolts: Int?
    var inputMilliamps: Int?
    var systemLoadMilliwatts: Int?
    var adapterLossMilliwatts: Int?

    // Charging
    var externalChargeCapable: Bool?
    var chargingMillivolts: Int?
    var chargingMilliamps: Int?
    var notChargingReason: Int?
    var slowChargingReason: Int?
    var thermallyLimitedSeconds: Int?
    var chargeStatus: String?

    // Battery
    var batteryMillivolts: Int?
    var batteryMilliamps: Int?
    var temperatureCentiC: Int?
    var cycleCount: Int?
    var designCycleCount: Int?
    var remainingMah: Int?
    var fullMah: Int?
    var nominalMah: Int?
    var designMah: Int?
    var batteryDevice: String?
    var batterySerial: String?

    var batteryMilliwatts: Int? {
        guard let v = batteryMillivolts, let a = batteryMilliamps else { return nil }
        return v * a / 1000
    }

    var typeText: String? {
        guard let familyCode, familyCode != 0 else { return nil }
        let code = Int(Int32(truncatingIfNeeded: familyCode))
        func is_(_ c: Int) -> Bool { Int(Int32(truncatingIfNeeded: c)) == code }
        if is_(kIOPSFamilyCodeUSBCPD) { return "USB-C Power Delivery" }
        if is_(kIOPSFamilyCodeUSBCTypeC) { return "USB-C" }
        if is_(kIOPSFamilyCodeUSBCBrick) { return "USB-C Apple adapter" }
        if is_(kIOPSFamilyCodeUSBChargingPortDedicated) { return "USB dedicated charging port" }
        if is_(kIOPSFamilyCodeUSBChargingPortDownstream) { return "USB charging downstream port" }
        if is_(kIOPSFamilyCodeUSBChargingPort) { return "USB charging port" }
        if is_(kIOPSFamilyCodeUSBHost) || is_(kIOPSFamilyCodeUSBHostSuspended) { return "USB host port" }
        if is_(kIOPSFamilyCodeUSBDevice) || is_(kIOPSFamilyCodeUSBAdapter) || is_(kIOPSFamilyCodeUSBUnknown) { return "USB" }
        if is_(kIOPSFamilyCodeFirewire) { return "FireWire" }
        if is_(kIOPSFamilyCodeAC) { return "AC power" }
        if is_(kIOPSFamilyCodeUnsupportedRegion) { return "Unsupported in this region" }
        if is_(kIOPSFamilyCodeUnsupported) { return "Unsupported adapter" }
        let external = [kIOPSFamilyCodeExternal, kIOPSFamilyCodeExternal2, kIOPSFamilyCodeExternal3, kIOPSFamilyCodeExternal4,
                        kIOPSFamilyCodeExternal5, kIOPSFamilyCodeExternal6, kIOPSFamilyCodeExternal7, kIOPSFamilyCodeExternal8]
        if external.contains(where: is_) { return "External power adapter" }
        return nil
    }

    var displayName: String {
        if let name { return name }
        if let ratedWatts { return "\(ratedWatts)W Power Adapter" }
        return "Power Adapter"
    }

    // MARK: Sections

    var chargerItems: [DetailItem] {
        guard connected else { return [] }
        var items: [DetailItem] = []
        func add(_ label: String, _ value: String?, _ symbol: String) {
            if let value, !value.isEmpty { items.append(DetailItem(label: label, value: value, symbol: symbol)) }
        }
        add("Name", name, "powerplug")
        add("Manufacturer", manufacturer, "building.2")
        add("Model", model, "shippingbox")
        add("Type", typeText, "cable.connector")
        add("Reported As", adapterDescription.map(Self.prettyDescription), "text.quote")
        add("Rated Power", ratedWatts.map { "\($0) W" }, "bolt")
        if let v = adapterMillivolts, let a = adapterMilliamps {
            add("Negotiated", "\(Units.volts(v)) · \(Units.amps(a))", "bolt.horizontal")
        } else {
            add("Voltage", adapterMillivolts.map { Units.volts($0) }, "bolt.horizontal")
            add("Current Limit", adapterMilliamps.map { Units.amps($0) }, "gauge.with.dots.needle.33percent")
        }
        if let id = activeProfile, let p = profiles.first(where: { $0.id == id }) {
            add("Active Profile", "#\(id) · \(p.voltageText) \(p.kind.rawValue)", "checkmark.circle")
        }
        if let v = contractMillivolts {
            add("Requested Voltage", Units.volts(v), "arrow.down.to.line")
        }
        add("Requested Current", contractMilliamps.map { Units.amps($0) }, "arrow.down.to.line")
        if !profiles.isEmpty {
            add("Max Offered", "\(profiles.map(\.watts).max() ?? 0) W across \(profiles.count) profiles", "chart.bar")
        }
        add("Capabilities", capabilities.isEmpty ? nil : capabilities.joined(separator: ", "), "checklist")
        add("Wireless", isWireless.map { $0 ? "Yes" : "No" }, "wave.3.right")
        add("Serial Number", serial, "barcode")
        add("Hardware Version", hardwareVersion, "cpu")
        add("Firmware Version", firmwareVersion, "memorychip")
        add("Adapter ID", adapterID.flatMap { $0 == 0 ? nil : Self.hex($0) }, "tag")
        add("USB Vendor ID", vendorID.map { Self.hex($0, width: 4) }, "person.crop.square")
        add("USB Product ID", productID.map { Self.hex($0, width: 4) }, "number.square")
        add("Family Code", familyCode.flatMap { $0 == 0 ? nil : Self.hex($0) }, "number")
        add("Source ID", sourceID.map(String.init), "arrow.triangle.branch")
        return items
    }

    func powerItems(_ snapshot: PowerSnapshot) -> [DetailItem] {
        var items: [DetailItem] = []
        func add(_ label: String, _ value: String?, _ symbol: String) {
            if let value, !value.isEmpty { items.append(DetailItem(label: label, value: value, symbol: symbol)) }
        }
        if connected {
            add("Input Power", inputMilliwatts.map { Units.watts($0) }, "bolt.fill")
            add("Input Voltage", inputMillivolts.map { Units.volts($0) }, "bolt.horizontal")
            add("Input Current", inputMilliamps.map { Units.amps($0) }, "gauge.with.dots.needle.50percent")
            if let input = inputMilliwatts, let rated = ratedWatts, rated > 0 {
                add("Charger Load", "\(Int((Double(input) / Double(rated * 10)).rounded()))% of \(rated) W", "chart.pie")
            }
            add("Adapter Loss", adapterLossMilliwatts.flatMap { $0 > 0 ? Units.watts($0) : nil }, "flame")
        }
        add("System Load", systemLoadMilliwatts.map { Units.watts($0) }, "laptopcomputer")
        if let p = batteryMilliwatts {
            let label = p > 0 ? "Into Battery" : p < 0 ? "From Battery" : "Battery Power"
            add(label, Units.watts(abs(p)), p >= 0 ? "battery.100percent.bolt" : "battery.50percent")
        }
        add("Status", snapshot.statusText, "bolt.badge.checkmark")
        if snapshot.hasBattery { add("Time", snapshot.timeText, "clock") }
        if connected {
            add("Charge Capable", externalChargeCapable.map { $0 ? "Yes" : "No" }, "powerplug.portrait")
            add("Charge Voltage", chargingMillivolts.flatMap { $0 > 0 ? Units.volts($0) : nil }, "arrow.up.to.line")
            add("Charge Current", chargingMilliamps.flatMap { $0 > 0 ? Units.amps($0) : nil }, "arrow.up.to.line")
            if !snapshot.isCharging && !snapshot.isFull {
                add("Not Charging Reason", notChargingReason.flatMap { $0 == 0 ? nil : "Code \(Self.hex($0))" }, "pause.circle")
            }
            add("Slow Charging Reason", slowChargingReason.flatMap { $0 == 0 ? nil : "Code \(Self.hex($0))" }, "tortoise")
            add("Thermally Limited", thermallyLimitedSeconds.flatMap { $0 > 0 ? PowerSnapshot.format(minutes: max(1, $0 / 60)) : nil }, "thermometer.high")
            add("Charge Status", chargeStatus.map(Self.chargeStatusText), "exclamationmark.triangle")
        }
        add("Low Power Mode", snapshot.lowPowerMode ? "On" : "Off", "tortoise")
        return items
    }

    func batteryItems(_ snapshot: PowerSnapshot) -> [DetailItem] {
        guard snapshot.hasBattery else { return [] }
        var items: [DetailItem] = []
        func add(_ label: String, _ value: String?, _ symbol: String) {
            if let value, !value.isEmpty { items.append(DetailItem(label: label, value: value, symbol: symbol)) }
        }
        add("Level", "\(snapshot.percent)%", "battery.75percent")
        if let remaining = remainingMah, let full = fullMah {
            add("Charge", "\(remaining) of \(full) mAh", "battery.100percent")
        }
        if let design = designMah, design > 0, let nominal = nominalMah ?? fullMah {
            add("Capacity vs Design", "\(Int((Double(nominal) / Double(design) * 100).rounded()))% (\(nominal) mAh)", "heart")
        }
        add("Design Capacity", designMah.map { "\($0) mAh" }, "ruler")
        if let cycles = cycleCount {
            add("Cycle Count", designCycleCount.map { "\(cycles) of \($0)" } ?? "\(cycles)", "arrow.triangle.2.circlepath")
        }
        add("Voltage", batteryMillivolts.map { Units.volts($0, digits: 3) }, "bolt.horizontal")
        add("Current", batteryMilliamps.map { Units.amps($0) }, "gauge.with.dots.needle.50percent")
        add("Temperature", temperatureCentiC.map { String(format: "%.1f °C", Double($0) / 100) }, "thermometer.medium")
        add("Gas Gauge", batteryDevice, "cpu")
        add("Serial Number", batterySerial, "barcode")
        return items
    }

    /// A plain-text version of everything, for the Copy button.
    func report(_ snapshot: PowerSnapshot) -> String {
        var lines = ["PowerInfo Reborn — Charger Report", Date().formatted(date: .abbreviated, time: .standard), ""]
        func section(_ title: String, _ items: [DetailItem]) {
            guard !items.isEmpty else { return }
            lines.append(title.uppercased())
            lines += items.map { "\($0.label): \($0.value)" }
            lines.append("")
        }
        section("Charger", connected ? chargerItems : [DetailItem(label: "Status", value: "Not connected", symbol: "")])
        if !profiles.isEmpty {
            section("Power Profiles", profiles.map { p in
                let tail = [p.currentText, "\(p.watts) W", p.id == activeProfile ? "active" : nil].compactMap { $0 }
                return DetailItem(label: "#\(p.id) \(p.kind.rawValue)", value: ([p.voltageText] + tail).joined(separator: " · "), symbol: "")
            })
        }
        section("Power", powerItems(snapshot))
        section("Battery", batteryItems(snapshot))
        return lines.joined(separator: "\n")
    }

    // MARK: Reading

    static func read(pluggedIn: Bool) -> ChargerInfo {
        var info = ChargerInfo()
        let battery = registryProperties() ?? [:]

        // The registry copy can be stale or sparse; the power-source API wins.
        var adapter = battery["AdapterDetails"] as? [String: Any] ?? [:]
        if let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] {
            adapter.merge(details) { $1 }
        }

        info.connected = pluggedIn || bool(battery["ExternalConnected"]) == true
        info.externalChargeCapable = bool(battery["ExternalChargeCapable"])

        if info.connected {
            info.name = string(adapter["Name"])
            info.manufacturer = string(adapter["Manufacturer"])
            info.model = string(adapter["Model"])
            info.serial = string(adapter["SerialString"]) ?? string(adapter[kIOPSPowerAdapterSerialNumberKey]).flatMap { $0 == "0" ? nil : $0 }
            info.hardwareVersion = string(adapter["HwVersion"]) ?? string(adapter[kIOPSPowerAdapterRevisionKey])
            info.firmwareVersion = string(adapter["FwVersion"])
            info.adapterID = int(adapter[kIOPSPowerAdapterIDKey])
            info.familyCode = int(adapter[kIOPSPowerAdapterFamilyKey])
            info.adapterDescription = string(adapter["Description"])
            info.ratedWatts = int(adapter[kIOPSPowerAdapterWattsKey]).flatMap { $0 > 0 ? $0 : nil }
            info.adapterMillivolts = (int(adapter["AdapterVoltage"]) ?? int(adapter["Voltage"])).flatMap { $0 > 0 ? $0 : nil }
            info.adapterMilliamps = int(adapter[kIOPSPowerAdapterCurrentKey]).flatMap { $0 > 0 ? $0 : nil }
            info.isWireless = bool(adapter["IsWireless"])
            info.sourceID = int(adapter[kIOPSPowerAdapterSourceKey])
            readPortController(battery, into: &info)
            if info.profiles.isEmpty, let menu = adapter["UsbHvcMenu"] as? [[String: Any]] {
                info.profiles = menu.compactMap { entry in
                    guard let v = int(entry["MaxVoltage"]), let a = int(entry["MaxCurrent"]), v > 0 else { return nil }
                    return PowerProfile(index: int(entry["Index"]) ?? 0, millivolts: v, milliamps: a)
                }
                if let index = int(adapter["UsbHvcHvcIndex"]), !info.profiles.isEmpty { info.activeProfile = index + 1 }
            }
        }

        if let t = battery["PowerTelemetryData"] as? [String: Any] {
            if info.connected {
                info.inputMilliwatts = int(t["SystemPowerIn"]).flatMap { $0 > 0 ? $0 : nil }
                info.inputMillivolts = int(t["SystemVoltageIn"]).flatMap { $0 > 0 ? $0 : nil }
                info.inputMilliamps = int(t["SystemCurrentIn"]).flatMap { $0 > 0 ? $0 : nil }
                info.adapterLossMilliwatts = int(t["AdapterEfficiencyLoss"])
            }
            info.systemLoadMilliwatts = int(t["SystemLoad"]).flatMap { $0 > 0 ? $0 : nil }
        }

        if let c = battery["ChargerData"] as? [String: Any] {
            info.chargingMillivolts = int(c["ChargingVoltage"])
            info.chargingMilliamps = int(c["ChargingCurrent"])
            info.notChargingReason = int(c["NotChargingReason"])
            info.slowChargingReason = int(c["SlowChargingReason"])
            info.thermallyLimitedSeconds = int(c["TimeChargingThermallyLimited"])
        }
        info.chargeStatus = string(battery[kIOPMPSBatteryChargeStatusKey])

        let data = battery["BatteryData"] as? [String: Any] ?? [:]
        info.batteryMillivolts = int(battery["Voltage"]) ?? int(battery["AppleRawBatteryVoltage"])
        info.batteryMilliamps = signed16(int(battery["InstantAmperage"]) ?? int(battery["Amperage"]))
        info.temperatureCentiC = (int(battery["Temperature"]) ?? int(data["Temperature"])).flatMap { $0 > 0 ? $0 : nil }
        info.cycleCount = int(battery["CycleCount"])
        info.designCycleCount = int(battery["DesignCycleCount9C"]).flatMap { $0 > 0 ? $0 : nil }
        info.remainingMah = (int(battery["AppleRawCurrentCapacity"]) ?? int(data["RemainingCapacity"])).flatMap { $0 > 0 ? $0 : nil }
        info.fullMah = (int(battery["AppleRawMaxCapacity"]) ?? int(data["FullChargeCapacity"])).flatMap { $0 > 0 ? $0 : nil }
        info.nominalMah = (int(battery["NominalChargeCapacity"]) ?? int(data["NominalChargeCapacity"])).flatMap { $0 > 0 ? $0 : nil }
        info.designMah = (int(battery["DesignCapacity"]) ?? int(data["DesignCapacity"])).flatMap { $0 > 0 ? $0 : nil }
        info.batteryDevice = string(battery["DeviceName"])
        info.batterySerial = string(battery["Serial"]) ?? string(battery["BatterySerialNumber"])
        return info
    }

    /// Picks the USB-C port that holds the power contract and decodes its
    /// offered profiles and the request the Mac made.
    private static func readPortController(_ battery: [String: Any], into info: inout ChargerInfo) {
        let ports = battery["PortControllerInfo"] as? [[String: Any]] ?? []
        guard let (index, port) = ports.enumerated().first(where: { int($0.element["PortControllerActiveContractRdo"]) ?? 0 != 0 })
        else { return }

        let raw = port["PortControllerPortPDO"] as? [Any] ?? []
        let count = (int(port["PortControllerNPDOs"]) ?? 0) + (int(port["PortControllerNEprPDOs"]) ?? 0)
        info.profiles = raw.prefix(count > 0 ? count : raw.count).enumerated().compactMap { i, pdo in
            int(pdo).flatMap { PowerProfile(position: i + 1, pdo: $0) }
        }

        if let firstPDO = raw.first.flatMap(int).map({ UInt32(truncatingIfNeeded: $0) }), firstPDO >> 30 == 0 {
            let flags: [(Int, String)] = [(29, "Dual-role power"), (28, "USB suspend"), (27, "Unconstrained power"),
                                          (26, "USB data"), (25, "Dual-role data"), (24, "Unchunked messages"), (23, "EPR")]
            info.capabilities = flags.filter { firstPDO & (1 << UInt32($0.0)) != 0 }.map(\.1)
        }

        let rdo = UInt32(truncatingIfNeeded: int(port["PortControllerActiveContractRdo"]) ?? 0)
        let position = Int((rdo >> 28) & 0xF)
        if let profile = info.profiles.first(where: { $0.id == position }) {
            info.activeProfile = position
            switch profile.kind {
            case .pps:
                info.contractMillivolts = Int((rdo >> 9) & 0xFFF) * 20
                info.contractMilliamps = Int(rdo & 0x7F) * 50
            case .avs:
                info.contractMillivolts = Int((rdo >> 9) & 0xFFF) * 25
                info.contractMilliamps = Int(rdo & 0x7F) * 50
            case .fixed, .variable:
                info.contractMilliamps = Int((rdo >> 10) & 0x3FF) * 10
            case .battery:
                break
            }
        }

        // The "Fed" (power-delivery partner) list is indexed like the ports.
        if let fed = (battery["FedDetails"] as? [[String: Any]])?[safe: index] {
            info.vendorID = int(fed["FedVendorID"]).flatMap { $0 > 0 ? $0 : nil }
            info.productID = int(fed["FedProductID"]).flatMap { $0 > 0 ? $0 : nil }
        }
    }

    private static func registryProperties() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return nil }
        return props?.takeRetainedValue() as? [String: Any]
    }

    // MARK: Helpers

    private static func int(_ value: Any?) -> Int? { (value as? NSNumber)?.intValue }

    private static func bool(_ value: Any?) -> Bool? { (value as? NSNumber)?.boolValue }

    private static func string(_ value: Any?) -> String? {
        if let s = value as? String { return s.trimmingCharacters(in: .whitespaces).isEmpty ? nil : s }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    /// Older Macs report negative currents as unsigned 16-bit values.
    private static func signed16(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return (32768..<65536).contains(value) ? value - 65536 : value
    }

    private static func hex(_ value: Int, width: Int = 0) -> String {
        let s = String(UInt32(truncatingIfNeeded: value), radix: 16, uppercase: true)
        return "0x" + String(repeating: "0", count: max(0, width - s.count)) + s
    }

    /// "pd charger" → "PD charger", "usb host" → "USB host".
    private static func prettyDescription(_ s: String) -> String {
        let acronyms: Set = ["pd", "usb", "ac", "hvc", "pps", "qi"]
        let words = s.split(separator: " ").map { acronyms.contains($0.lowercased()) ? $0.uppercased() : String($0) }
        let joined = words.joined(separator: " ")
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }

    private static func chargeStatusText(_ status: String) -> String {
        switch status {
        case kIOPMBatteryChargeStatusTooHot: return "Paused, too hot"
        case kIOPMBatteryChargeStatusTooCold: return "Paused, too cold"
        case kIOPMBatteryChargeStatusTooHotOrCold: return "Paused, temperature"
        case kIOPMBatteryChargeStatusGradient: return "Paused, uneven temperature"
        default: return status
        }
    }
}

enum Units {
    static func watts(_ milliwatts: Int) -> String { String(format: "%.2f W", Double(milliwatts) / 1000) }

    static func volts(_ millivolts: Int, digits: Int = 2, unit: Bool = true) -> String {
        String(format: "%.\(digits)f", Double(millivolts) / 1000) + (unit ? " V" : "")
    }

    static func amps(_ milliamps: Int) -> String { String(format: "%.2f A", Double(milliamps) / 1000) }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Keeps a fresh `ChargerInfo` while the popover is open.
@MainActor
final class ChargerInfoModel: ObservableObject {
    static let shared = ChargerInfoModel()

    @Published private(set) var info = ChargerInfo()
    /// Briefly true after the report is copied, to confirm it on the button.
    @Published private(set) var copied = false
    private var timer: Timer?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let new = ChargerInfo.read(pluggedIn: PowerMonitor.shared.snapshot.isPluggedIn)
        if new != info { info = new }
    }

    func copyReport(_ snapshot: PowerSnapshot) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info.report(snapshot), forType: .string)
        copied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
