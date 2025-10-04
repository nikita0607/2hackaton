# Bluetooth Demo Setup

These scripts provide a very small Bluetooth abstraction layer with a ready-to-use demo UI.

## Scene configuration
1. Open `Assets/Scenes/SampleScene.unity`.
2. Create an empty GameObject (e.g. `BluetoothController`).
3. Add the `BluetoothManager` component (`Assets/Scripts/Bluetooth/BluetoothManager.cs`).
4. Press Play in the editor. A simulated Bluetooth service is used on non-mobile platforms so you can test the UI flow.

## Runtime behaviour
- `BluetoothManager` requests a platform-specific `IBluetoothService` instance from `BluetoothServiceFactory`.
- On desktop/editor the `SimulatedBluetoothService` immediately exposes a fake device (`SIM-DEVICE-001`) and echoes any message you send.
- On Android and iOS the scripts expect a native plugin to bridge platform Bluetooth APIs. Until you integrate such a plugin the log will report that the bridge could not be initialised.

## Android integration notes
The Android implementation expects a Java class `com.example.unitybluetooth.BluetoothBridge` with the following shape:

```java
public final class BluetoothBridge {
    public interface Callback {
        void onDeviceFound(String id, String name);
        void onConnected(String id);
        void onDisconnected(String reason);
        void onMessageReceived(String payload);
        void onLog(String message);
        void onError(String error);
    }

    public static BluetoothBridge create(Activity activity, Callback callback) { /* ... */ }
    public boolean isEnabled() { /* ... */ }
    public void startScan() { /* ... */ }
    public void stopScan() { /* ... */ }
    public void connect(String deviceId) { /* ... */ }
    public void disconnect() { /* ... */ }
    public void send(String payload) { /* ... */ }
}
```

Hook those methods into Bluetooth Low Energy (recommended) or classic Bluetooth code as needed and package the library inside `Plugins/Android` so Unity includes it in the build.

## iOS integration notes
Create an Objective-C++ plugin that exposes the following C-style functions to Unity:

```objc
bool _IsBluetoothEnabled(void);
void _StartScan(void);
void _StopScan(void);
void _Connect(const char *deviceId);
void _Disconnect(void);
void _Send(const char *payload);
void RegisterCallbacks(
    void (*onDeviceFound)(const char *deviceId, const char *name),
    void (*onConnected)(const char *deviceId),
    void (*onDisconnected)(const char *reason),
    void (*onMessageReceived)(const char *payload),
    void (*onLog)(const char *message),
    void (*onError)(const char *message));
```

Inside your plugin, use CoreBluetooth to perform the actual operations and invoke the callback function pointers as events occur.

## Permissions checklist
- **Android**: request `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`, and location permissions (required for BLE scanning on modern Android). Handle runtime permission prompts in your plugin or via Unity's permission APIs.
- **iOS**: add the `NSBluetoothAlwaysUsageDescription` key to `Info.plist` with a meaningful message.

## Extending the demo
- Replace the simulated editor service with a mock that reflects your backend/device protocol more accurately.
- Persist the last connected device ID and automatically reconnect on app launch if desired.
- Add protocol-specific encoding (e.g. binary packets) inside a small wrapper before calling `IBluetoothService.Send`.
