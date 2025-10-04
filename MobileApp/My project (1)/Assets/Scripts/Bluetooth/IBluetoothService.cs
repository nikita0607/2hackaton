using System;

namespace MobileApp.Bluetooth
{
    /// <summary>
    /// Abstraction for Bluetooth LE/classic operations used by the demo.
    /// </summary>
    public interface IBluetoothService
    {
        bool IsSupported { get; }
        bool IsEnabled { get; }
        bool IsInitialized { get; }

        event Action<string, string> DeviceDiscovered; // deviceId, name
        event Action<string> Connected; // deviceId
        event Action<string> Disconnected; // reason
        event Action<string> MessageReceived; // payload
        event Action<string> LogMessage;
        event Action<string> Error;

        void Initialize();
        void StartScan();
        void StopScan();
        void Connect(string deviceId);
        void Disconnect();
        void Send(string payload);
    }
}
