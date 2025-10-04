#if UNITY_ANDROID && !UNITY_EDITOR
using System;
using UnityEngine;

namespace MobileApp.Bluetooth
{
    /// <summary>
    /// Android implementation that bridges to a native plugin.
    /// Requires a Java class exposing minimal API (see README).
    /// </summary>
    internal sealed class AndroidBluetoothService : IBluetoothService
    {
        private const string PluginClassName = "com.example.unitybluetooth.BluetoothBridge";

        private AndroidJavaObject _bridge;
        private bool _isInitialized;

        public bool IsSupported => true;
        public bool IsEnabled { get; private set; }
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

            try
            {
                using AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                AndroidJavaObject activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");

                using AndroidJavaClass bridgeClass = new AndroidJavaClass(PluginClassName);
                _bridge = bridgeClass.CallStatic<AndroidJavaObject>("create", activity, new BluetoothCallbackProxy(this));

                if (_bridge == null)
                {
                    Error?.Invoke($"Bluetooth bridge {PluginClassName} returned null. Ensure native plugin is integrated.");
                    return;
                }

                _isInitialized = true;
                IsEnabled = _bridge.Call<bool>("isEnabled");
                LogMessage?.Invoke("Android Bluetooth bridge initialised.");
            }
            catch (Exception ex)
            {
                Error?.Invoke($"Failed to initialise Android Bluetooth bridge. {ex.Message}");
                Debug.LogException(ex);
            }
        }

        public void StartScan()
        {
            if (!EnsureBridge())
            {
                return;
            }

            _bridge.Call("startScan");
        }

        public void StopScan()
        {
            if (!EnsureBridge())
            {
                return;
            }

            _bridge.Call("stopScan");
        }

        public void Connect(string deviceId)
        {
            if (!EnsureBridge())
            {
                return;
            }

            _bridge.Call("connect", deviceId);
        }

        public void Disconnect()
        {
            if (!EnsureBridge())
            {
                return;
            }

            _bridge.Call("disconnect");
        }

        public void Send(string payload)
        {
            if (!EnsureBridge())
            {
                return;
            }

            _bridge.Call("send", payload);
        }

        private bool EnsureBridge()
        {
            if (_isInitialized && _bridge != null)
            {
                return true;
            }

            Error?.Invoke("Bluetooth bridge not initialised. Call Initialize() first.");
            return false;
        }

        private sealed class BluetoothCallbackProxy : AndroidJavaProxy
        {
            private readonly AndroidBluetoothService _service;

            public BluetoothCallbackProxy(AndroidBluetoothService service)
                : base("com.example.unitybluetooth.BluetoothBridge$Callback")
            {
                _service = service;
            }

            public void onDeviceFound(string deviceId, string name)
            {
                _service.DeviceDiscovered?.Invoke(deviceId, name);
            }

            public void onConnected(string deviceId)
            {
                _service.Connected?.Invoke(deviceId);
            }

            public void onDisconnected(string reason)
            {
                _service.Disconnected?.Invoke(reason);
            }

            public void onMessageReceived(string payload)
            {
                _service.MessageReceived?.Invoke(payload);
            }

            public void onLog(string message)
            {
                _service.LogMessage?.Invoke(message);
            }

            public void onError(string message)
            {
                _service.Error?.Invoke(message);
            }
        }
    }
}
#endif
