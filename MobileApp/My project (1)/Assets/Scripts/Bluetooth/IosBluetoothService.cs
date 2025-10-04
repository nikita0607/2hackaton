#if UNITY_IOS && !UNITY_EDITOR
using System;
using System.Runtime.InteropServices;

namespace MobileApp.Bluetooth
{
    /// <summary>
    /// iOS implementation that bridges to Objective-C functions exposed by a native plugin.
    /// </summary>
    internal sealed class IosBluetoothService : IBluetoothService
    {
        public bool IsSupported => true;
        public bool IsEnabled => _IsBluetoothEnabled();
        public bool IsInitialized { get; private set; }

        public event Action<string, string> DeviceDiscovered;
        public event Action<string> Connected;
        public event Action<string> Disconnected;
        public event Action<string> MessageReceived;
        public event Action<string> LogMessage;
        public event Action<string> Error;

        public void Initialize()
        {
            if (IsInitialized)
            {
                return;
            }

            RegisterCallbacks(OnDeviceFound, OnConnected, OnDisconnected, OnMessageReceived, OnLog, OnError);
            IsInitialized = true;
            LogMessage?.Invoke("iOS Bluetooth bridge initialised.");
        }

        public void StartScan()
        {
            if (!EnsureInitialised())
            {
                return;
            }

            _StartScan();
        }

        public void StopScan()
        {
            if (!EnsureInitialised())
            {
                return;
            }

            _StopScan();
        }

        public void Connect(string deviceId)
        {
            if (!EnsureInitialised())
            {
                return;
            }

            _Connect(deviceId);
        }

        public void Disconnect()
        {
            if (!EnsureInitialised())
            {
                return;
            }

            _Disconnect();
        }

        public void Send(string payload)
        {
            if (!EnsureInitialised())
            {
                return;
            }

            _Send(payload);
        }

        private bool EnsureInitialised()
        {
            if (!IsInitialized)
            {
                Error?.Invoke("Bluetooth not initialised. Call Initialize() first.");
                return false;
            }

            return true;
        }

        private delegate void DeviceFoundCallback(string deviceId, string name);
        private delegate void MessageCallback(string message);

        [AOT.MonoPInvokeCallback(typeof(DeviceFoundCallback))]
        private static void OnDeviceFound(string deviceId, string name)
        {
            Instance.DeviceDiscovered?.Invoke(deviceId, name);
        }

        [AOT.MonoPInvokeCallback(typeof(MessageCallback))]
        private static void OnConnected(string deviceId)
        {
            Instance.Connected?.Invoke(deviceId);
        }

        [AOT.MonoPInvokeCallback(typeof(MessageCallback))]
        private static void OnDisconnected(string reason)
        {
            Instance.Disconnected?.Invoke(reason);
        }

        [AOT.MonoPInvokeCallback(typeof(MessageCallback))]
        private static void OnMessageReceived(string payload)
        {
            Instance.MessageReceived?.Invoke(payload);
        }

        [AOT.MonoPInvokeCallback(typeof(MessageCallback))]
        private static void OnLog(string message)
        {
            Instance.LogMessage?.Invoke(message);
        }

        [AOT.MonoPInvokeCallback(typeof(MessageCallback))]
        private static void OnError(string message)
        {
            Instance.Error?.Invoke(message);
        }

        private static IosBluetoothService Instance => BluetoothServiceFactory.GetOrCreate() as IosBluetoothService;

        [DllImport("__Internal")] private static extern bool _IsBluetoothEnabled();
        [DllImport("__Internal")] private static extern void _StartScan();
        [DllImport("__Internal")] private static extern void _StopScan();
        [DllImport("__Internal")] private static extern void _Connect(string deviceId);
        [DllImport("__Internal")] private static extern void _Disconnect();
        [DllImport("__Internal")] private static extern void _Send(string payload);
        [DllImport("__Internal")] private static extern void RegisterCallbacks(
            DeviceFoundCallback onDeviceFound,
            MessageCallback onConnected,
            MessageCallback onDisconnected,
            MessageCallback onMessageReceived,
            MessageCallback onLog,
            MessageCallback onError);
    }
}
#endif
