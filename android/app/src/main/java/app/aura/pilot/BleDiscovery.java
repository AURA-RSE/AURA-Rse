package app.aura.pilot;

import android.Manifest;
import android.annotation.SuppressLint;
import android.bluetooth.*;
import android.bluetooth.le.*;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelUuid;
import android.os.SystemClock;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/** Same GATT protocol as iOS; no wallet, name, or device name in advertising. */
@SuppressLint("MissingPermission")
final class BleDiscovery {
    static final UUID SERVICE = UUID.fromString("A7840001-F5C5-4C53-AA82-BF9A2A3F77E4");
    static final UUID TOKEN = UUID.fromString("A7840002-F5C5-4C53-AA82-BF9A2A3F77E4");
    static final String[] PERMISSIONS = {Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_ADVERTISE, Manifest.permission.BLUETOOTH_CONNECT};
    interface Listener { void onToken(String device, String token, int rssi); void onError(String message); void onState(String message); }
    private final Context context;
    private final Listener listener;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ConcurrentHashMap<String, BluetoothGatt> pending = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Long> lastRead = new ConcurrentHashMap<>();
    private BluetoothAdapter adapter;
    private BluetoothLeScanner scanner;
    private BluetoothLeAdvertiser advertiser;
    private volatile BluetoothGattServer server;
    private ScanCallback scanCallback;
    private AdvertiseCallback advertiseCallback;
    private volatile String token;
    private volatile long expires;
    private volatile boolean active;
    private volatile int generation;
    BleDiscovery(Context context, Listener listener) { this.context = context; this.listener = listener; }
    boolean permitted() { for (String permission : PERMISSIONS) if (context.checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) return false; return true; }
    boolean ready() { try { return permitted() && adapter != null && adapter.isEnabled(); } catch (SecurityException e) { return false; } }
    void start(String value, long deadline) {
        try { startRadio(value, deadline); }
        catch (SecurityException error) { fail("Bluetooth permission was revoked."); }
        catch (IllegalStateException error) { fail("Bluetooth became unavailable. Enable it and try again."); }
    }
    private void startRadio(String value, long deadline) {
        stop();
        if (!permitted()) { listener.onError("Nearby Devices permission is required."); return; }
        if (!PresenceRules.validToken(value) || deadline <= System.currentTimeMillis()) { listener.onError("Presence token expired."); return; }
        BluetoothManager manager = context.getSystemService(BluetoothManager.class); adapter = manager == null ? null : manager.getAdapter();
        if (!ready() || !adapter.isMultipleAdvertisementSupported()) { listener.onError("Enable Bluetooth on a phone that supports BLE advertising."); return; }
        token = value; expires = deadline; active = true; int run = ++generation;
        scanner = adapter.getBluetoothLeScanner(); advertiser = adapter.getBluetoothLeAdvertiser();
        if (scanner == null || advertiser == null) { fail("Bluetooth discovery is unavailable."); return; }
        advertiseCallback = new AdvertiseCallback() {
            @Override public void onStartSuccess(AdvertiseSettings settings) { main.post(() -> { if (active && generation == run) listener.onState("Bluetooth discovery and presence are active."); }); }
            @Override public void onStartFailure(int code) { main.post(() -> { if (active && generation == run) fail("Bluetooth advertising failed (" + code + ")."); }); }
        };
        server = manager.openGattServer(context, new BluetoothGattServerCallback() {
            @Override public void onServiceAdded(int status, BluetoothGattService service) {
                main.post(() -> {
                    if (!active || run != generation) return;
                    if (status != BluetoothGatt.GATT_SUCCESS) { fail("Bluetooth service could not be installed."); return; }
                    try {
                        advertiser.startAdvertising(new AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY).setConnectable(true).setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM).build(),
                            new AdvertiseData.Builder().addServiceUuid(new ParcelUuid(SERVICE)).setIncludeDeviceName(false).build(), advertiseCallback);
                    } catch (SecurityException error) { fail("Bluetooth permission was revoked."); }
                });
            }
            @Override public void onCharacteristicReadRequest(BluetoothDevice device, int requestId, int offset, BluetoothGattCharacteristic characteristic) {
                BluetoothGattServer current = server;
                if (current == null || run != generation) return;
                try {
                    String currentToken = token;
                    if (!active || currentToken == null || System.currentTimeMillis() >= expires || !TOKEN.equals(characteristic.getUuid())) {
                        current.sendResponse(device, requestId, BluetoothGatt.GATT_READ_NOT_PERMITTED, offset, null); return;
                    }
                    byte[] data = currentToken.getBytes(StandardCharsets.UTF_8);
                    if (offset < 0 || offset > data.length) { current.sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset, null); return; }
                    current.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, PresenceRules.slice(data, offset));
                } catch (SecurityException ignored) { main.post(() -> { if (active && run == generation) fail("Bluetooth permission was revoked."); }); }
            }
        });
        if (server == null) { fail("Bluetooth GATT server is unavailable."); return; }
        BluetoothGattService service = new BluetoothGattService(SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY);
        service.addCharacteristic(new BluetoothGattCharacteristic(TOKEN, BluetoothGattCharacteristic.PROPERTY_READ, BluetoothGattCharacteristic.PERMISSION_READ));
        if (!server.addService(service)) { fail("Bluetooth service registration failed."); return; }
        scanCallback = new ScanCallback() {
            @Override public void onScanResult(int type, ScanResult result) { main.post(() -> read(result, run)); }
            @Override public void onScanFailed(int code) { main.post(() -> { if (run == generation) fail("Bluetooth scanning failed (" + code + ")."); }); }
        };
        scanner.startScan(List.of(new ScanFilter.Builder().setServiceUuid(new ParcelUuid(SERVICE)).build()), new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), scanCallback);
        scheduleExpiry(run);
    }
    void renew(String value, long deadline) {
        if (!active || !PresenceRules.validToken(value) || deadline <= System.currentTimeMillis()) return;
        token = value; expires = deadline;
    }
    private void scheduleExpiry(int run) {
        main.postDelayed(() -> {
            if (!active || generation != run) return;
            if (System.currentTimeMillis() >= expires || !ready()) { fail("Presence expired or Bluetooth became unavailable. Restart discovery when ready."); return; }
            scheduleExpiry(run);
        }, 1000);
    }
    private void read(ScanResult result, int run) {
        if (!active || generation != run || pending.size() >= 4) return;
        String address;
        try { address = result.getDevice().getAddress(); } catch (SecurityException error) { fail("Bluetooth permission was revoked."); return; }
        long now = SystemClock.elapsedRealtime();
        if (pending.containsKey(address) || now - lastRead.getOrDefault(address, -10000L) < 6000) return;
        lastRead.put(address, now);
        if (lastRead.size() > 500) lastRead.entrySet().removeIf(e -> now - e.getValue() > 60000);
        BluetoothGattCallback callback = new BluetoothGattCallback() {
            @Override public void onConnectionStateChange(BluetoothGatt gatt, int status, int state) {
                if (active && run == generation && status == BluetoothGatt.GATT_SUCCESS && state == BluetoothProfile.STATE_CONNECTED) {
                    try { gatt.discoverServices(); } catch (SecurityException error) { finish(address, gatt); }
                } else if (status != BluetoothGatt.GATT_SUCCESS || state == BluetoothProfile.STATE_DISCONNECTED) finish(address, gatt);
            }
            @Override public void onServicesDiscovered(BluetoothGatt gatt, int status) {
                BluetoothGattService service = gatt.getService(SERVICE);
                BluetoothGattCharacteristic characteristic = service == null ? null : service.getCharacteristic(TOKEN);
                if (!active || run != generation || status != BluetoothGatt.GATT_SUCCESS || characteristic == null) { finish(address, gatt); return; }
                try { if (!gatt.readCharacteristic(characteristic)) finish(address, gatt); } catch (SecurityException error) { finish(address, gatt); }
            }
            private void received(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, byte[] bytes, int status) {
                if (active && generation == run && status == BluetoothGatt.GATT_SUCCESS && TOKEN.equals(characteristic.getUuid()) && bytes != null && bytes.length <= 100) {
                    String value = new String(bytes, StandardCharsets.UTF_8);
                    if (PresenceRules.validToken(value)) main.post(() -> { if (active && generation == run) listener.onToken(address, value, result.getRssi()); });
                }
                finish(address, gatt);
            }
            @Override public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, byte[] value, int status) { received(gatt, characteristic, value, status); }
            @SuppressWarnings("deprecation") @Override public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) { received(gatt, characteristic, characteristic.getValue(), status); }
        };
        try {
            BluetoothGatt gatt = result.getDevice().connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE);
            if (gatt != null) { pending.put(address, gatt); main.postDelayed(() -> { if (pending.get(address) == gatt) finish(address, gatt); }, 5000); }
        } catch (SecurityException error) { fail("Bluetooth permission was revoked."); }
    }
    private void finish(String address, BluetoothGatt gatt) { pending.remove(address, gatt); try { gatt.disconnect(); gatt.close(); } catch (SecurityException ignored) { } }
    private void fail(String message) { stop(); listener.onError(message); }
    void stop() {
        active = false; generation++; token = null; expires = 0;
        try { if (scanner != null && scanCallback != null) scanner.stopScan(scanCallback); } catch (SecurityException ignored) { }
        try { if (advertiser != null && advertiseCallback != null) advertiser.stopAdvertising(advertiseCallback); } catch (SecurityException ignored) { }
        for (var entry : pending.entrySet()) finish(entry.getKey(), entry.getValue());
        pending.clear(); lastRead.clear();
        try { if (server != null) server.close(); } catch (SecurityException ignored) { }
        server = null; scanner = null; advertiser = null; scanCallback = null; advertiseCallback = null;
    }
}
