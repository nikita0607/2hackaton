using System;
using UnityEngine;

namespace MobileApp.Bluetooth
{
    /// <summary>
    /// Editor/Standalone friendly simulated service so play mode can be used without a device.
    /// </summary>
    internal sealed class SimulatedBluetoothService : IBluetoothService
    {
        private bool _isInitialized;
        private bool _connected;
        private string _currentDeviceId;

        public bool IsSupported => true;
        public bool IsEnabled => true;
        public bool IsInitialized => _isInitialized;

        public event Action<string, string> DeviceDiscovered;
        public event Action<string> Connected;
        public event Action<string> Disconnected;
        public event Action<string> MessageReceived;
        public event Action<string> LogMessage;
        public event Action<string> Error;

        public void Initialize()
        {
            if (_isInitialized)
            {
                return;
            }

            _isInitialized = true;
            LogMessage?.Invoke("Simulated Bluetooth service initialised.");
        }

        public void StartScan()
        {
            EnsureInitialised();
            LogMessage?.Invoke("Simulated scan started.");
            DeviceDiscovered?.Invoke("SIM-DEVICE-001", "Simulated Peripheral");
        }

        public void StopScan()
        {
            LogMessage?.Invoke("Simulated scan stopped.");
        }

        public void Connect(string deviceId)
        {
            EnsureInitialised();

            if (string.IsNullOrEmpty(deviceId))
            {
                Error?.Invoke("Device ID is empty.");
                return;
            }

            _connected = true;
            _currentDeviceId = deviceId;
            Connected?.Invoke(deviceId);
            LogMessage?.Invoke($"Connected to {deviceId} (simulated).");
        }

        public void Disconnect()
        {
            if (!_connected)
            {
                return;
            }

            _connected = false;
            string deviceId = _currentDeviceId;
            _currentDeviceId = null;
            Disconnected?.Invoke(deviceId ?? "Simulated");
            LogMessage?.Invoke("Disconnected (simulated).");
        }

        public void Send(string payload)
        {
            if (!_connected)
            {
                Error?.Invoke("Not connected to any device.");
                return;
            }

            LogMessage?.Invoke($"Sent: {payload}");
            MessageReceived?.Invoke($"Echo from {_currentDeviceId ?? "Simulated"}: {payload}");
        }

        private void EnsureInitialised()
        {
            if (!_isInitialized)
            {
                LogMessage?.Invoke("Auto initialising simulated service.");
                Initialize();
            }
        }
    }
}
