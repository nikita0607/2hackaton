# GPS Demo Setup

This project contains a simple GPS UI for Unity.

## Scene configuration
1. Open `Assets/Scenes/SampleScene.unity` in the Unity editor.
2. Create an empty GameObject (e.g. `GpsManager`).
3. Add the `GpsDisplay` component (`Assets/Scripts/GpsDisplay.cs`) to the object.
4. Press Play. The script will automatically create an on-screen canvas showing the current GPS status and values.

## Mobile build notes
- Android: Ensure the `ACCESS_FINE_LOCATION` permission is enabled in **Project Settings ▸ Player ▸ Publishing Settings** or via a custom manifest. Unity requests the runtime permission automatically.
- iOS: Add a location usage description string in **Project Settings ▸ Player ▸ iOS ▸ Other Settings ▸ Location Usage Description** so the permission prompt has meaningful text.
- Testing in the editor uses desktop location services. When running on a device, make sure GPS/location services are enabled and the app has permission to use them.

## Stopping the service
- The service stops automatically when the object with `GpsDisplay` is disabled or destroyed. You can also stop it manually by disabling the component in code if needed.
