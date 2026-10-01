import Foundation
import CoreBluetooth
import Combine

/// Foreground-only, opt-in advertising. Broadcasts a random server-issued token, never a wallet.
final class BLEBroadcaster: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    static let auraServiceUUID = CBUUID(string:"A7840001-F5C5-4C53-AA82-BF9A2A3F77E4")
    static let auraTokenCharUUID = CBUUID(string:"A7840002-F5C5-4C53-AA82-BF9A2A3F77E4")
    @Published var isAdvertising = false
    @Published var error: String?
    private var manager: CBPeripheralManager!
    private var token: String?
    private var expires = Date.distantPast
    private var expiryTimer: Timer?
    private var installed = false
    override init() { super.init() }
    func advertise(_ presence: Presence) {
        if manager == nil { manager = CBPeripheralManager(delegate:self,queue:.main) }
        token = presence.token; expires = Date(timeIntervalSince1970:presence.expires / 1000)
        expiryTimer?.invalidate()
        expiryTimer = Timer.scheduledTimer(withTimeInterval:max(0.01,expires.timeIntervalSinceNow),repeats:false) { [weak self] _ in self?.stop() }
        startIfAllowed()
    }
    func stop() { token = nil; expires = .distantPast; expiryTimer?.invalidate(); expiryTimer = nil; manager?.stopAdvertising(); manager?.removeAllServices(); installed = false; isAdvertising = false }
    private func startIfAllowed() {
        guard let manager, manager.state == .poweredOn, token != nil, expires > Date() else { return }
        if installed { return }
        let characteristic = CBMutableCharacteristic(type:Self.auraTokenCharUUID,properties:[.read],value:nil,permissions:[.readable])
        let service = CBMutableService(type:Self.auraServiceUUID,primary:true); service.characteristics = [characteristic]
        installed = true; manager.add(service)
    }
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn { error = nil; startIfAllowed() }
        else { installed = false; isAdvertising = false; if peripheral.state == .unauthorized { error = "Allow Bluetooth in Settings to share your presence." } }
    }
    func peripheralManager(_ peripheral: CBPeripheralManager,didAdd service: CBService,error: Error?) {
        guard error == nil else { self.error = error?.localizedDescription; installed = false; return }
        guard token != nil, expires > Date() else { peripheral.removeAllServices(); installed = false; return }
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey:[Self.auraServiceUUID]])
    }
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager,error: Error?) {
        isAdvertising = error == nil && token != nil && expires > Date(); self.error = error?.localizedDescription
        if !isAdvertising { peripheral.stopAdvertising() }
    }
    func peripheralManager(_ peripheral: CBPeripheralManager,didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == Self.auraTokenCharUUID, let token, expires > Date() else { peripheral.respond(to:request,withResult:.readNotPermitted); return }
        let data = Data(token.utf8)
        guard request.offset <= data.count else { peripheral.respond(to:request,withResult:.invalidOffset); return }
        request.value = data.subdata(in:request.offset..<data.count); peripheral.respond(to:request,withResult:.success)
    }
}
