using UnityEngine;

namespace MobileApp.Bluetooth
{
    /// <summary>
    /// Provides a platform specific Bluetooth service.
    /// </summary>
    public static class BluetoothServiceFactory
    {
        private static IBluetoothService _instance;

        public static IBluetoothService GetOrCreate()
        {
            if (_instance != null)
            {
                return _instance;
            }

    #if UNITY_ANDROID && !UNITY_EDITOR
            _instance = new AndroidBluetoothService();
    #elif UNITY_IOS && !UNITY_EDITOR
            _instance = new IosBluetoothService();
    #else
            _instance = new SimulatedBluetoothService();
    #endif

            return _instance;
        }

        public static void SetOverride(IBluetoothService service) => _instance = service;
    }
}
