using System.Collections.Generic;
using System.Text;
using MobileApp.Bluetooth;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Simple MonoBehaviour that wires a Bluetooth service to a basic UI for scanning, connecting and sending text payloads.
/// </summary>
public class BluetoothManager : MonoBehaviour
{
    [Header("UI References")]
    [SerializeField] private TMP_Text statusText;
    [SerializeField] private TMP_Dropdown deviceDropdown;
    [SerializeField] private Button scanButton;
    [SerializeField] private Button connectButton;
    [SerializeField] private Button disconnectButton;
    [SerializeField] private TMP_InputField messageInput;
    [SerializeField] private Button sendButton;
    [SerializeField] private TMP_Text logText;

    private readonly List<string> _deviceIds = new List<string>();
    private readonly StringBuilder _logBuilder = new StringBuilder();

    private IBluetoothService _service;
    private string _connectedDeviceId;

    private void Awake()
    {
        ValidateUiReferences();

        _service = BluetoothServiceFactory.GetOrCreate();
        SubscribeToService(_service);

        if (scanButton != null)
        {
            scanButton.onClick.AddListener(OnScanClicked);
        }

        if (connectButton != null)
        {
            connectButton.onClick.AddListener(OnConnectClicked);
        }

        if (disconnectButton != null)
        {
            disconnectButton.onClick.AddListener(OnDisconnectClicked);
            disconnectButton.interactable = false;
        }

        if (sendButton != null)
        {
            sendButton.onClick.AddListener(OnSendClicked);
            sendButton.interactable = false;
        }

        UpdateStatus("Initialising Bluetooth…");
    }

    private void Start()
    {
        _service.Initialize();
        UpdateStatus("Ready. Use Scan to discover devices.");
    }

    private void OnDestroy()
    {
        if (_service != null)
        {
            UnsubscribeFromService(_service);
            _service.Disconnect();
        }

        if (scanButton != null)
        {
            scanButton.onClick.RemoveListener(OnScanClicked);
        }

        if (connectButton != null)
        {
            connectButton.onClick.RemoveListener(OnConnectClicked);
        }

        if (disconnectButton != null)
        {
            disconnectButton.onClick.RemoveListener(OnDisconnectClicked);
        }

        if (sendButton != null)
        {
            sendButton.onClick.RemoveListener(OnSendClicked);
        }
    }

    private void OnScanClicked()
    {
        AppendLog("Scan requested.");
        ClearDevices();
        _service.StartScan();
        UpdateStatus("Scanning for devices…");
    }

    private void OnConnectClicked()
    {
        if (deviceDropdown == null)
        {
            AppendLog("Device dropdown is not assigned.");
            return;
        }

        if (_deviceIds.Count == 0 || deviceDropdown.value < 0 || deviceDropdown.value >= _deviceIds.Count)
        {
            AppendLog("No device selected.");
            return;
        }

        string deviceId = _deviceIds[deviceDropdown.value];
        _service.Connect(deviceId);
        string deviceName = deviceDropdown.captionText != null ? deviceDropdown.captionText.text : deviceId;
        UpdateStatus($"Connecting to {deviceName}…");
    }

    private void OnDisconnectClicked()
    {
        _service.Disconnect();
        UpdateStatus("Disconnecting…");
    }

    private void OnSendClicked()
    {
        if (messageInput == null)
        {
            AppendLog("Message input is not assigned.");
            return;
        }

        if (string.IsNullOrWhiteSpace(messageInput.text))
        {
            AppendLog("Enter a message before sending.");
            return;
        }

        _service.Send(messageInput.text);
        AppendLog($"→ {messageInput.text}");
        messageInput.text = string.Empty;
    }

    private void SubscribeToService(IBluetoothService service)
    {
        service.DeviceDiscovered += HandleDeviceDiscovered;
        service.Connected += HandleConnected;
        service.Disconnected += HandleDisconnected;
        service.MessageReceived += HandleMessageReceived;
        service.LogMessage += HandleLogMessage;
        service.Error += HandleError;
    }

    private void UnsubscribeFromService(IBluetoothService service)
    {
        service.DeviceDiscovered -= HandleDeviceDiscovered;
        service.Connected -= HandleConnected;
        service.Disconnected -= HandleDisconnected;
        service.MessageReceived -= HandleMessageReceived;
        service.LogMessage -= HandleLogMessage;
        service.Error -= HandleError;
    }

    private void HandleDeviceDiscovered(string deviceId, string name)
    {
        if (_deviceIds.Contains(deviceId))
        {
            return;
        }

        _deviceIds.Add(deviceId);

        if (deviceDropdown != null)
        {
        deviceDropdown.options.Add(new TMP_Dropdown.OptionData(string.IsNullOrWhiteSpace(name) ? deviceId : name));
            deviceDropdown.RefreshShownValue();

            if (_deviceIds.Count == 1)
            {
                deviceDropdown.value = 0;
            }
        }

        AppendLog($"Device discovered: {name} ({deviceId})");
    }

    private void HandleConnected(string deviceId)
    {
        _connectedDeviceId = deviceId;
        string label = deviceDropdown != null && deviceDropdown.captionText != null
            ? deviceDropdown.captionText.text
            : deviceId;
        UpdateStatus($"Connected to {label}.");
        AppendLog($"Connected: {deviceId}");

        if (sendButton != null)
        {
            sendButton.interactable = true;
        }

        if (disconnectButton != null)
        {
            disconnectButton.interactable = true;
        }

        if (connectButton != null)
        {
            connectButton.interactable = false;
        }
    }

    private void HandleDisconnected(string reason)
    {
        AppendLog($"Disconnected: {reason}");
        UpdateStatus("Disconnected.");
        _connectedDeviceId = null;

        if (sendButton != null)
        {
            sendButton.interactable = false;
        }

        if (disconnectButton != null)
        {
            disconnectButton.interactable = false;
        }

        if (connectButton != null)
        {
            connectButton.interactable = true;
        }
    }

    private void HandleMessageReceived(string payload)
    {
        AppendLog($"← {payload}");
    }

    private void HandleLogMessage(string message)
    {
        AppendLog(message);
    }

    private void HandleError(string error)
    {
        AppendLog($"Error: {error}");
        UpdateStatus(error);
    }

    private void AppendLog(string line)
    {
        _logBuilder.AppendLine(line);

        if (_logBuilder.Length > 2000)
        {
            _logBuilder.Remove(0, _logBuilder.Length - 2000);
        }

        if (logText != null)
        {
            logText.text = _logBuilder.ToString();
        }
    }

    private void UpdateStatus(string message)
    {
        if (statusText != null)
        {
            statusText.text = $"Status: {message}";
        }
    }

    private void ClearDevices()
    {
        _deviceIds.Clear();

        if (deviceDropdown == null)
        {
            return;
        }

        deviceDropdown.ClearOptions();
        if (deviceDropdown.captionText != null)
        {
            deviceDropdown.captionText.text = "No devices";
        }
    }

    private void ValidateUiReferences()
    {
        if (statusText == null)
        {
            Debug.LogWarning("BluetoothManager: statusText reference is not assigned.");
        }

        if (deviceDropdown == null)
        {
            Debug.LogWarning("BluetoothManager: deviceDropdown reference is not assigned.");
        }

        if (scanButton == null)
        {
            Debug.LogWarning("BluetoothManager: scanButton reference is not assigned.");
        }

        if (connectButton == null)
        {
            Debug.LogWarning("BluetoothManager: connectButton reference is not assigned.");
        }

        if (disconnectButton == null)
        {
            Debug.LogWarning("BluetoothManager: disconnectButton reference is not assigned.");
        }

        if (messageInput == null)
        {
            Debug.LogWarning("BluetoothManager: messageInput reference is not assigned.");
        }

        if (sendButton == null)
        {
            Debug.LogWarning("BluetoothManager: sendButton reference is not assigned.");
        }

        if (logText == null)
        {
            Debug.LogWarning("BluetoothManager: logText reference is not assigned.");
        }
    }
}
