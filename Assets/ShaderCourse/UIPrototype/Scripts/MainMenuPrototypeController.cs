using System;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

[DisallowMultipleComponent]
public class MainMenuPrototypeController : MonoBehaviour
{
    [Serializable]
    public class MenuSection
    {
        public string key;
        public string headline;
        [TextArea(2, 5)] public string summary;
        public string accentLabel;
        public Color accentColor = Color.cyan;
    }

    [Serializable]
    public class MenuButtonBinding
    {
        public Button button;
        public HoloMenuButton feedback;
        public string sectionKey;
    }

    [Header("Sections")]
    [SerializeField] private List<MenuSection> sections = new();
    [SerializeField] private List<MenuButtonBinding> buttons = new();

    [Header("Panels")]
    [SerializeField] private CanvasGroup infoPanel;
    [SerializeField] private CanvasGroup launchOverlay;
    [SerializeField] private Image accentBar;
    [SerializeField] private Image previewGlow;
    [SerializeField] private TextMeshProUGUI headlineText;
    [SerializeField] private TextMeshProUGUI summaryText;
    [SerializeField] private TextMeshProUGUI accentLabelText;
    [SerializeField] private TextMeshProUGUI statusText;
    [SerializeField] private TextMeshProUGUI footerTipText;
    [SerializeField] private Slider energySlider;
    [SerializeField] private Slider signalSlider;

    [Header("Motion")]
    [SerializeField] private RectTransform previewFrame;
    [SerializeField] private RectTransform orbitRing;
    [SerializeField] private float previewFloatAmplitude = 8f;
    [SerializeField] private float previewFloatSpeed = 1.2f;

    private readonly Dictionary<string, MenuSection> lookup = new();
    private string currentKey;
    private Vector2 previewBasePos;
    private Vector3 ringBaseRotation;
    private float overlayAlphaVelocity;
    private float infoAlphaVelocity;

    private void Awake()
    {
        foreach (MenuSection section in sections)
        {
            if (!string.IsNullOrEmpty(section.key))
            {
                lookup[section.key] = section;
            }
        }

        foreach (MenuButtonBinding binding in buttons)
        {
            if (binding.button == null)
            {
                continue;
            }

            string capturedKey = binding.sectionKey;
            binding.button.onClick.AddListener(() => OpenSection(capturedKey));
        }

        if (previewFrame != null)
        {
            previewBasePos = previewFrame.anchoredPosition;
        }

        if (orbitRing != null)
        {
            ringBaseRotation = orbitRing.localEulerAngles;
        }

        if (launchOverlay != null)
        {
            launchOverlay.alpha = 0f;
            launchOverlay.gameObject.SetActive(false);
        }

        if (infoPanel != null)
        {
            infoPanel.alpha = 1f;
        }
    }

    private void Start()
    {
        if (buttons.Count > 0)
        {
            OpenSection(buttons[0].sectionKey);
        }

        if (footerTipText != null)
        {
            footerTipText.text = "\u539f\u578b\u6d41\u8f6c\uff1a\u6309\u94ae\u5207\u9875\u3001\u72b6\u6001\u53cd\u9988\u3001\u7a0b\u5e8f\u5316 UI \u97f3\u6548\u3001\u52a8\u6001\u9884\u89c8\u8054\u52a8\u3002";
        }
    }

    private void Update()
    {
        float t = Time.unscaledTime;

        if (previewFrame != null)
        {
            previewFrame.anchoredPosition = previewBasePos + new Vector2(0f, Mathf.Sin(t * previewFloatSpeed) * previewFloatAmplitude);
        }

        if (orbitRing != null)
        {
            orbitRing.localEulerAngles = ringBaseRotation + new Vector3(0f, 0f, t * -12f);
        }

        if (launchOverlay != null && launchOverlay.gameObject.activeSelf)
        {
            launchOverlay.alpha = Mathf.SmoothDamp(launchOverlay.alpha, 1f, ref overlayAlphaVelocity, 0.15f);
        }

        if (infoPanel != null)
        {
            infoPanel.alpha = Mathf.SmoothDamp(infoPanel.alpha, 1f, ref infoAlphaVelocity, 0.12f);
        }
    }

    public void OpenSection(string key)
    {
        if (string.IsNullOrEmpty(key) || !lookup.TryGetValue(key, out MenuSection section))
        {
            return;
        }

        currentKey = key;
        headlineText.text = section.headline;
        summaryText.text = section.summary;
        accentLabelText.text = section.accentLabel;
        accentLabelText.color = section.accentColor;

        if (accentBar != null)
        {
            accentBar.color = section.accentColor;
        }

        if (previewGlow != null)
        {
            Color glow = section.accentColor;
            glow.a = 0.6f;
            previewGlow.color = glow;
        }

        if (energySlider != null)
        {
            energySlider.value = Mathf.Abs(Mathf.Sin(key.GetHashCode() * 0.0134f)) * 0.55f + 0.35f;
        }

        if (signalSlider != null)
        {
            signalSlider.value = Mathf.Abs(Mathf.Cos(key.GetHashCode() * 0.021f)) * 0.45f + 0.4f;
        }

        if (statusText != null)
        {
            statusText.text = key == "launch"
                ? "\u8230\u6865\u8bf7\u6c42\u5df2\u5c31\u7eea\uff0c\u518d\u6b21\u70b9\u51fb\u53ef\u6a21\u62df\u542f\u52a8\u6d41\u7a0b\u3002"
                : $"\u5f53\u524d\u805a\u7126\uff1a{section.accentLabel}";
        }

        foreach (MenuButtonBinding binding in buttons)
        {
            if (binding.feedback != null)
            {
                binding.feedback.SetSelected(binding.sectionKey == key);
            }
        }

        MenuSfxSynth.Instance?.PlayClick();
    }

    public void TriggerLaunchPulse()
    {
        if (currentKey != "launch" || launchOverlay == null)
        {
            OpenSection("launch");
            return;
        }

        StopAllCoroutines();
        StartCoroutine(LaunchPulseRoutine());
    }

    public void OpenSettings()
    {
        OpenSection("settings");
    }

    public void BackToHome()
    {
        MenuSfxSynth.Instance?.PlayBack();
        OpenSection("launch");
    }

    private System.Collections.IEnumerator LaunchPulseRoutine()
    {
        launchOverlay.gameObject.SetActive(true);
        launchOverlay.alpha = 0f;
        MenuSfxSynth.Instance?.PlayClick();
        statusText.text = "\u6b63\u5728\u540c\u6b65\u822a\u7ebf\u3001\u8fde\u63a5\u6307\u6325\u4e2d\u67a2\u5e76\u6a21\u62df\u8d77\u822a\u63e1\u624b...";

        float elapsed = 0f;
        while (elapsed < 1.4f)
        {
            elapsed += Time.unscaledDeltaTime;
            float normalized = elapsed / 1.4f;
            launchOverlay.alpha = Mathf.Sin(normalized * Mathf.PI);
            yield return null;
        }

        launchOverlay.alpha = 0f;
        launchOverlay.gameObject.SetActive(false);
        statusText.text = "\u542f\u52a8\u63e1\u624b\u5b8c\u6210\uff0c\u4e3b\u754c\u9762\u539f\u578b\u9a8c\u8bc1\u901a\u8fc7\u3002";
    }
}
