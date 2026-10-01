import Foundation
import CoreBluetooth
import Combine

final class BLEScanner: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isScanning = false
    @Published var error: String?
    var onToken: ((String,String,Int)->Void)?
    private var manager: CBCentralManager!
    private var wanted = false
    private var pending: [UUID:CBPeripheral] = [:]
    private var lastRead: [UUID:Date] = [:]
    private var strengths: [UUID:Int] = [:]
    private var timeouts: [UUID:Timer] = [:]
    override init() { super.init() }
    func start() { if manager == nil { manager = CBCentralManager(delegate:self,queue:.main) };wanted = true; startIfAllowed() }
    private func startIfAllowed() {
        guard let manager,wanted, manager.state == .poweredOn else { return }
        manager.scanForPeripherals(withServices:[BLEBroadcaster.auraServiceUUID],options:[CBCentralManagerScanOptionAllowDuplicatesKey:true]);isScanning = true
    }
    func stop() {
        wanted = false; manager?.stopScan(); isScanning = false
        Array(pending.values).forEach { manager.cancelPeripheralConnection($0) }
        timeouts.values.forEach { $0.invalidate() }; timeouts.removeAll();pending.removeAll();lastRead.removeAll();strengths.removeAll()
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { error = nil; startIfAllowed() }
        else { isScanning = false; if central.state == .unauthorized { error = "Bluetooth access is disabled. Enable it in Settings." } }
    }
    func centralManager(_ central: CBCentralManager,didDiscover peripheral: CBPeripheral,advertisementData:[String:Any],rssi RSSI:NSNumber) {
        guard wanted, pending.count < 5, pending[peripheral.identifier] == nil, Date().timeIntervalSince(lastRead[peripheral.identifier] ?? .distantPast) > 6 else { return }
        let id = peripheral.identifier; strengths[id] = RSSI.intValue; pending[id] = peripheral;lastRead[id] = Date();peripheral.delegate = self
        central.connect(peripheral)
        timeouts[id] = Timer.scheduledTimer(withTimeInterval:5,repeats:false) { [weak self,weak peripheral] _ in if let peripheral { self?.finish(peripheral) } }
        if lastRead.count > 200 { lastRead = lastRead.filter { Date().timeIntervalSince($0.value) < 60 } }
    }
    func centralManager(_ central:CBCentralManager,didConnect peripheral:CBPeripheral) { if wanted { peripheral.discoverServices([BLEBroadcaster.auraServiceUUID]) } else { finish(peripheral) } }
    func centralManager(_ central:CBCentralManager,didFailToConnect peripheral:CBPeripheral,error:Error?) { finish(peripheral) }
    func centralManager(_ central:CBCentralManager,didDisconnectPeripheral peripheral:CBPeripheral,error:Error?) { pending.removeValue(forKey:peripheral.identifier);timeouts.removeValue(forKey:peripheral.identifier)?.invalidate() }
    func peripheral(_ peripheral:CBPeripheral,didDiscoverServices error:Error?) {
        guard error == nil, let service = peripheral.services?.first(where:{$0.uuid == BLEBroadcaster.auraServiceUUID}) else { finish(peripheral);return }
        peripheral.discoverCharacteristics([BLEBroadcaster.auraTokenCharUUID],for:service)
    }
    func peripheral(_ peripheral:CBPeripheral,didDiscoverCharacteristicsFor service:CBService,error:Error?) {
        guard error == nil, let characteristic = service.characteristics?.first(where:{$0.uuid == BLEBroadcaster.auraTokenCharUUID}) else { finish(peripheral);return }
        peripheral.readValue(for:characteristic)
    }
    func peripheral(_ peripheral:CBPeripheral,didUpdateValueFor characteristic:CBCharacteristic,error:Error?) {
        defer { finish(peripheral) }
        guard wanted,error == nil, characteristic.uuid == BLEBroadcaster.auraTokenCharUUID,let data = characteristic.value,data.count <= 100,let token = String(data:data,encoding:.utf8) else { return }
        onToken?(peripheral.identifier.uuidString,token,strengths[peripheral.identifier] ?? -100)
    }
    private func finish(_ peripheral:CBPeripheral) { timeouts.removeValue(forKey:peripheral.identifier)?.invalidate();pending.removeValue(forKey:peripheral.identifier);manager.cancelPeripheralConnection(peripheral) }
}
