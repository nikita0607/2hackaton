using System.Collections;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class GpsDisplay : MonoBehaviour
{
    [Header("UI References")]
    [SerializeField] private Text statusText;
    [SerializeField] private Text latitudeText;
    [SerializeField] private Text longitudeText;
    [SerializeField] private Text altitudeText;
    [SerializeField] private Text accuracyText;

    private bool _locationServiceRunning;

    private void Awake()
    {
        EnsureUi();
        UpdateStatus("Awaiting GPS start…");
    }

    private IEnumerator Start()
    {
        yield return StartCoroutine(StartLocationService());
    }

    private void Update()
    {
        if (!_locationServiceRunning)
        {
            return;
        }

        LocationInfo info = Input.location.lastData;
        latitudeText.text = $"Latitude: {info.latitude:F6}";
        longitudeText.text = $"Longitude: {info.longitude:F6}";
        altitudeText.text = $"Altitude: {info.altitude:F1} m";
        accuracyText.text = $"Accuracy: ±{info.horizontalAccuracy:F1} m | Time: {info.timestamp:F0}s";
    }

    private IEnumerator StartLocationService()
    {
        if (!Input.location.isEnabledByUser)
        {
            UpdateStatus("Location services disabled in system settings.");
            yield break;
        }

        UpdateStatus("Starting location service…");
        Input.location.Start();

        const int timeoutSeconds = 20;
        int elapsed = 0;
        while (Input.location.status == LocationServiceStatus.Initializing && elapsed < timeoutSeconds)
        {
            UpdateStatus($"Initializing GPS… {timeoutSeconds - elapsed}s left");
            elapsed++;
            yield return new WaitForSeconds(1f);
        }

        if (Input.location.status == LocationServiceStatus.Initializing)
        {
            UpdateStatus("GPS initialization timed out.");
            yield break;
        }

        if (Input.location.status == LocationServiceStatus.Failed)
        {
            UpdateStatus("GPS failed to start.");
            yield break;
        }

        _locationServiceRunning = true;
        UpdateStatus("GPS running.");
    }

    private void OnDisable()
    {
        if (_locationServiceRunning)
        {
            Input.location.Stop();
            _locationServiceRunning = false;
        }
    }

    private void EnsureUi()
    {
        if (statusText != null && latitudeText != null && longitudeText != null && altitudeText != null && accuracyText != null)
        {
            return;
        }

        Canvas canvas = FindObjectOfType<Canvas>();
        if (canvas == null)
        {
            canvas = CreateCanvas();
        }

        Font defaultFont = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");

        GameObject panel = new GameObject("GPS Panel", typeof(RectTransform));
        panel.transform.SetParent(canvas.transform, false);
        RectTransform panelTransform = panel.GetComponent<RectTransform>();
        panelTransform.anchorMin = new Vector2(0.5f, 0.5f);
        panelTransform.anchorMax = panelTransform.anchorMin;
        panelTransform.anchoredPosition = new Vector2(0f, 450f);
        panelTransform.sizeDelta = new Vector2(600f, 260f);

        Image panelImage = panel.AddComponent<Image>();
        panelImage.color = new Color(0f, 0f, 0f, 0.5f);

        VerticalLayoutGroup layout = panel.AddComponent<VerticalLayoutGroup>();
        layout.childAlignment = TextAnchor.MiddleCenter;
        layout.spacing = 12f;
        layout.padding = new RectOffset(24, 24, 24, 24);

        statusText = CreateTextElement(panel.transform, "Status", defaultFont, 24);
        latitudeText = CreateTextElement(panel.transform, "Latitude: --", defaultFont, 28);
        longitudeText = CreateTextElement(panel.transform, "Longitude: --", defaultFont, 28);
        altitudeText = CreateTextElement(panel.transform, "Altitude: --", defaultFont, 24);
        accuracyText = CreateTextElement(panel.transform, "Accuracy: --", defaultFont, 20);
    }

    private Canvas CreateCanvas()
    {
        GameObject canvasObject = new GameObject("GpsCanvas");
        canvasObject.layer = LayerMask.NameToLayer("UI");

        Canvas canvas = canvasObject.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.pixelPerfect = true;

        canvasObject.AddComponent<CanvasScaler>();
        canvasObject.AddComponent<GraphicRaycaster>();

        if (FindObjectOfType<EventSystem>() == null)
        {
            new GameObject("EventSystem", typeof(EventSystem), typeof(StandaloneInputModule));
        }
        return canvas;
    }

    private Text CreateTextElement(Transform parent, string initialText, Font font, int fontSize)
    {
        GameObject textObject = new GameObject("Text", typeof(RectTransform));
        textObject.transform.SetParent(parent, false);

        Text uiText = textObject.AddComponent<Text>();
        uiText.text = initialText;
        uiText.font = font;
        uiText.fontSize = fontSize;
        uiText.alignment = TextAnchor.MiddleCenter;
        uiText.color = Color.white;

        LayoutElement layout = textObject.AddComponent<LayoutElement>();
        layout.minHeight = 32f;

        return uiText;
    }

    private void UpdateStatus(string message)
    {
        if (statusText != null)
        {
            statusText.text = $"Status: {message}";
        }
    }
}
