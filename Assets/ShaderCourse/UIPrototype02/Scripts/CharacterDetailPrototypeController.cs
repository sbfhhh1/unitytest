using System.Collections;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace ShaderCourse.UIPrototype02
{
    [RequireComponent(typeof(AudioSource))]
    public class CharacterDetailPrototypeController : MonoBehaviour
    {
        private static readonly Color ActiveCyan = new Color32(56, 242, 222, 255);
        private static readonly Color ActiveNavFill = new Color32(0, 199, 184, 110);
        private static readonly Color ActiveTabFill = new Color32(18, 64, 62, 92);
        private static readonly Color DimNavFill = new Color32(255, 255, 255, 14);
        private static readonly Color ClearFill = new Color32(0, 0, 0, 0);
        private static readonly Color DimText = new Color32(174, 194, 190, 220);
        private static readonly Color White = new Color32(246, 250, 248, 255);

        private readonly string[] tabLabels =
        {
            "\u5c5e\u6027", "\u6b66\u88c5", "\u9057\u7269", "\u547d\u77f3", "\u5929\u8d4b", "\u6750\u6599"
        };

        private readonly string[][] statLabels =
        {
            new[] { "\u751f\u547d\u4e0a\u9650", "\u653b\u51fb\u529b", "\u9632\u5fa1\u529b", "\u5143\u7d20\u7cbe\u901a", "\u4f53\u529b\u5f3a\u5ea6" },
            new[] { "\u5f13\u672f\u7cbe\u5ea6", "\u66b4\u51fb\u7387", "\u7a7f\u523a\u4f24\u5bb3", "\u62c9\u5f13\u901f\u5ea6", "\u6b66\u5668\u795d\u798f" },
            new[] { "\u9057\u7269\u69fd\u4f4d", "\u7075\u5951\u5f3a\u5ea6", "\u7b26\u6587\u5145\u80fd", "\u795d\u798f\u6548\u7387", "\u56de\u54cd\u6297\u6027" },
            new[] { "\u751f\u547d\u6fc0\u6d8c", "\u8010\u529b\u4e0a\u9650", "\u6062\u590d\u901f\u5ea6", "\u5171\u9e23\u7b49\u7ea7", "\u62a4\u6301\u65f6\u957f" },
            new[] { "\u88ab\u52a8\u8282\u70b9", "\u8fc5\u6377\u7784\u51c6", "\u9677\u9631\u4e13\u7cbe", "\u6f5c\u884c\u52a0\u6210", "\u4f19\u4f34\u94fe\u63a5" },
            new[] { "\u6708\u7eb9\u6811\u8102", "\u7fbd\u7b26", "\u9752\u94dc\u4e1d", "\u7075\u6811\u76ae", "\u8fdc\u53e4\u9aa8\u7247" }
        };

        private readonly int[][] statValues =
        {
            new[] { 23235, 2234, 454, 221, 221 },
            new[] { 94, 37, 418, 129, 7 },
            new[] { 4, 86, 332, 28, 163 },
            new[] { 840, 1620, 114, 42, 18 },
            new[] { 12, 5, 4, 31, 3 },
            new[] { 68, 24, 112, 41, 9 }
        };

        private readonly string[] detailTexts =
        {
            "\u68ee\u6797\u90e8\u65cf\u4e2d\u7684\u4fa6\u730e\u5148\u950b\uff0c\u64c5\u957f\u8fdc\u7a0b\u538b\u5236\u4e0e\u5feb\u901f\u6e38\u730e\u3002",
            "\u53cc\u5f26\u6b66\u88c5\u5f3a\u8c03\u7cbe\u51c6\u3001\u7834\u7532\u4e0e\u9759\u9ed8\u730e\u6740\u3002",
            "\u53e4\u8001\u9057\u7269\u5c01\u5b58\u7740\u524d\u4ee3\u730e\u4eba\u7684\u8bb0\u5fc6\u3002",
            "\u547d\u77f3\u4f1a\u7a33\u5b9a\u4f53\u80fd\uff0c\u5e76\u5ef6\u957f\u8352\u6797\u4e2d\u7684\u7eed\u822a\u3002",
            "\u5929\u8d4b\u8def\u5f84\u5f3a\u5316\u9677\u9631\u3001\u673a\u52a8\u4e0e\u76ee\u6807\u6807\u8bb0\u3002",
            "\u5347\u7ea7\u6750\u6599\u6765\u81ea\u7cbe\u82f1\u72e9\u730e\u548c\u796d\u575b\u4e8b\u4ef6\u3002"
        };

        private RectTransform leftDock;
        private RectTransform centerPanel;
        private RectTransform rightPanel;
        private RectTransform heroFrame;
        private Image levelFill;
        private Text heroNameText;
        private Text levelText;
        private Text flavorText;
        private Text detailText;
        private Text upgradeButtonText;
        private Transform statsContent;
        private GameObject toast;
        private Text toastText;
        private Button[] navButtons;
        private Button[] tabButtons;
        private Button upgradeButton;
        private AudioSource audioSource;
        private AudioClip hoverClip;
        private AudioClip selectClip;
        private AudioClip upgradeClip;
        private int activeIndex;
        private bool isPanelVisible = true;
        private Coroutine toastRoutine;

        private void Awake()
        {
            leftDock = FindRect("LeftDock");
            centerPanel = FindRect("CenterPanel");
            rightPanel = FindRect("RightPanel");
            heroFrame = FindRect("HeroFrame");
            heroNameText = FindText("RightPanel/HeroCard/Header/NameText");
            levelText = FindText("RightPanel/HeroCard/LevelBlock/LevelText");
            flavorText = FindText("CenterPanel/FlavorStrip/FlavorText");
            detailText = FindText("RightPanel/HeroCard/DescriptionText");
            upgradeButtonText = FindText("RightPanel/HeroCard/BottomActions/DetailsButton/Text");
            levelFill = transform.Find("RightPanel/HeroCard/LevelBlock/FillBar").GetComponent<Image>();
            statsContent = transform.Find("RightPanel/HeroCard/StatsBlock/Viewport/Content");
            toast = transform.Find("Toast").gameObject;
            toastText = FindText("Toast/Text");
            navButtons = GatherButtons("LeftDock/NavButtons");
            tabButtons = GatherButtons("CenterPanel/TabColumn");
            upgradeButton = transform.Find("RightPanel/HeroCard/BottomActions/DetailsButton").GetComponent<Button>();
            audioSource = GetComponent<AudioSource>();

            transform.Find("RightPanel/TopBar/CloseButton").GetComponent<Button>().onClick.AddListener(ClosePanel);
            upgradeButton.onClick.AddListener(UpgradeAction);

            for (int i = 0; i < navButtons.Length; i++)
            {
                int index = i;
                navButtons[i].onClick.AddListener(() => SelectTab(index, true));
                AddHoverSfx(navButtons[i]);
            }

            for (int i = 0; i < tabButtons.Length; i++)
            {
                int index = i;
                tabButtons[i].onClick.AddListener(() => SelectTab(index, true));
                AddHoverSfx(tabButtons[i]);
            }

            AddHoverSfx(upgradeButton);
        }

        private void Start()
        {
            LoadAudioClips();
            heroNameText.text = "\u8d1d\u514b\u8bfa";
            toast.SetActive(false);
            SelectTab(0, false);
            StartCoroutine(HeroFloatLoop());
            StartCoroutine(UpgradePulseLoop());
        }

        private void Update()
        {
            if (!isPanelVisible && Input.GetKeyDown(KeyCode.Space))
            {
                ShowPanel();
            }

            if (Input.GetKeyDown(KeyCode.Escape))
            {
                ClosePanel();
            }

            if (Input.GetKeyDown(KeyCode.UpArrow))
            {
                SelectTab((activeIndex + tabLabels.Length - 1) % tabLabels.Length, true);
            }

            if (Input.GetKeyDown(KeyCode.DownArrow))
            {
                SelectTab((activeIndex + 1) % tabLabels.Length, true);
            }
        }

        private void SelectTab(int index, bool showToast)
        {
            activeIndex = Mathf.Clamp(index, 0, tabLabels.Length - 1);

            for (int i = 0; i < navButtons.Length; i++)
            {
                UpdateSelectable(navButtons[i], i == activeIndex, true);
            }

            for (int i = 0; i < tabButtons.Length; i++)
            {
                UpdateSelectable(tabButtons[i], i == activeIndex, false);
            }

            flavorText.text = "\u6e38\u730e\u8005\u7684\u8840\u8109\u4e0e\u8ff7\u96fe\u3001\u94a2\u94c1\u548c\u68ee\u6797\u9884\u5146\u5171\u9e23\u3002";
            detailText.text = detailTexts[activeIndex];
            upgradeButtonText.text = "\u5347\u7ea7";
            levelText.text = activeIndex == 0 ? "\u7b49\u7ea7 83/90" : "\u7b49\u7ea7 12/20";
            levelFill.fillAmount = activeIndex == 0 ? 83f / 90f : 0.62f;

            StopCoroutine(nameof(AnimateStats));
            StartCoroutine(nameof(AnimateStats));

            if (showToast)
            {
                PlayOneShot(selectClip, 0.8f);
                ShowToast(tabLabels[activeIndex] + "\u5df2\u5207\u6362");
            }
        }

        private IEnumerator AnimateStats()
        {
            string[] labels = statLabels[activeIndex];
            int[] values = statValues[activeIndex];

            for (int i = 0; i < statsContent.childCount && i < labels.Length; i++)
            {
                Transform row = statsContent.GetChild(i);
                row.Find("Label").GetComponent<Text>().text = labels[i];
                row.Find("Value").GetComponent<Text>().text = "0";
            }

            for (int rowIndex = 0; rowIndex < statsContent.childCount && rowIndex < values.Length; rowIndex++)
            {
                Text valueText = statsContent.GetChild(rowIndex).Find("Value").GetComponent<Text>();
                int targetValue = values[rowIndex];
                float elapsed = 0f;
                const float Duration = 0.38f;

                while (elapsed < Duration)
                {
                    elapsed += Time.deltaTime;
                    float t = Mathf.Clamp01(elapsed / Duration);
                    float eased = 1f - Mathf.Pow(1f - t, 3f);
                    valueText.text = Mathf.RoundToInt(Mathf.Lerp(0f, targetValue, eased)).ToString("N0");
                    yield return null;
                }

                valueText.text = targetValue.ToString("N0");
                yield return new WaitForSeconds(0.03f);
            }
        }

        private IEnumerator HeroFloatLoop()
        {
            Vector2 basePos = heroFrame.anchoredPosition;
            float time = 0f;

            while (true)
            {
                time += Time.deltaTime;
                heroFrame.anchoredPosition = basePos + Vector2.up * (Mathf.Sin(time * 1.35f) * 8f);
                yield return null;
            }
        }

        private IEnumerator UpgradePulseLoop()
        {
            RectTransform buttonRect = upgradeButton.GetComponent<RectTransform>();
            Image buttonImage = upgradeButton.GetComponent<Image>();
            Vector3 baseScale = Vector3.one;
            float time = 0f;

            while (true)
            {
                time += Time.deltaTime;
                float wave = (Mathf.Sin(time * 2.1f) + 1f) * 0.5f;
                buttonRect.localScale = Vector3.Lerp(baseScale, baseScale * 1.02f, wave);
                buttonImage.color = Color.Lerp(new Color32(0, 160, 148, 230), ActiveCyan, wave * 0.25f);
                yield return null;
            }
        }

        private void UpgradeAction()
        {
            PlayOneShot(upgradeClip, 0.9f);
            ShowToast("\u6253\u5f00\u5347\u7ea7\u9884\u89c8");
        }

        private void ClosePanel()
        {
            if (!isPanelVisible)
            {
                return;
            }

            isPanelVisible = false;
            leftDock.gameObject.SetActive(false);
            centerPanel.gameObject.SetActive(false);
            rightPanel.gameObject.SetActive(false);
            heroFrame.gameObject.SetActive(false);
            ShowToast("\u754c\u9762\u5df2\u9690\u85cf\uff0c\u6309 Space \u91cd\u65b0\u6253\u5f00");
        }

        private void ShowPanel()
        {
            isPanelVisible = true;
            leftDock.gameObject.SetActive(true);
            centerPanel.gameObject.SetActive(true);
            rightPanel.gameObject.SetActive(true);
            heroFrame.gameObject.SetActive(true);
            SelectTab(activeIndex, false);
        }

        private void ShowToast(string message)
        {
            if (toastRoutine != null)
            {
                StopCoroutine(toastRoutine);
            }

            toastRoutine = StartCoroutine(ToastSequence(message));
        }

        private IEnumerator ToastSequence(string message)
        {
            toastText.text = message;
            toast.SetActive(true);
            CanvasGroup canvasGroup = toast.GetComponent<CanvasGroup>();
            canvasGroup.alpha = 1f;
            yield return new WaitForSeconds(1.1f);
            toast.SetActive(false);
        }

        private void UpdateSelectable(Button button, bool active, bool isNavButton)
        {
            Text labelText = button.transform.Find("Text").GetComponent<Text>();
            Image icon = button.transform.Find("Icon") != null ? button.transform.Find("Icon").GetComponent<Image>() : null;
            Image background = button.GetComponent<Image>();
            Outline outline = button.GetComponent<Outline>();

            if (isNavButton)
            {
                labelText.color = new Color32(255, 255, 255, 0);
            }
            else
            {
                int index = System.Array.IndexOf(tabButtons, button);
                labelText.text = "\u2726  " + tabLabels[Mathf.Max(0, index)];
                labelText.color = active ? White : DimText;
            }

            background.color = active ? (isNavButton ? ActiveNavFill : ActiveTabFill) : (isNavButton ? DimNavFill : ClearFill);

            if (icon != null)
            {
                icon.color = active ? White : new Color32(210, 225, 218, 120);
            }

            if (outline != null)
            {
                outline.effectColor = active ? ActiveCyan : new Color32(255, 255, 255, 36);
                outline.effectDistance = active ? new Vector2(2f, 2f) : new Vector2(1f, 1f);
            }

            button.transform.localScale = active ? Vector3.one * 1.02f : Vector3.one;
        }

        private void AddHoverSfx(Button button)
        {
            EventTrigger trigger = button.GetComponent<EventTrigger>();
            if (trigger == null)
            {
                trigger = button.gameObject.AddComponent<EventTrigger>();
            }

            EventTrigger.Entry entry = new EventTrigger.Entry { eventID = EventTriggerType.PointerEnter };
            entry.callback.AddListener(_ => PlayOneShot(hoverClip, 0.55f));
            trigger.triggers.Add(entry);
        }

        private void PlayOneShot(AudioClip clip, float volume)
        {
            if (audioSource != null && clip != null)
            {
                audioSource.PlayOneShot(clip, volume);
            }
        }

        private void LoadAudioClips()
        {
            hoverClip = LoadClip("Assets/ShaderCourse/UIPrototype02/Audio/ui_hover_tick.wav");
            selectClip = LoadClip("Assets/ShaderCourse/UIPrototype02/Audio/ui_select_chime.wav");
            upgradeClip = LoadClip("Assets/ShaderCourse/UIPrototype02/Audio/ui_upgrade_pulse.wav");
        }

        private AudioClip LoadClip(string path)
        {
#if UNITY_EDITOR
            return UnityEditor.AssetDatabase.LoadAssetAtPath<AudioClip>(path);
#else
            return null;
#endif
        }

        private RectTransform FindRect(string path)
        {
            return transform.Find(path).GetComponent<RectTransform>();
        }

        private Text FindText(string path)
        {
            return transform.Find(path).GetComponent<Text>();
        }

        private Button[] GatherButtons(string path)
        {
            Transform parent = transform.Find(path);
            Button[] buttons = new Button[parent.childCount];

            for (int i = 0; i < parent.childCount; i++)
            {
                buttons[i] = parent.GetChild(i).GetComponent<Button>();
            }

            return buttons;
        }
    }
}
