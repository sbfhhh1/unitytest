using System.Collections.Generic;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.TextCore.LowLevel;
using UnityEngine.UI;

public static class MainMenuPrototypeBuilder
{
    private const string ScenePath = "Assets/Scenes/MainMenuPrototype.unity";
    private const string HoloMaterialPath = "Assets/ShaderCourse/UIPrototype/Materials/HoloButton.mat";
    private const string VolumeProfilePath = "Assets/ShaderCourse/UIPrototype/Materials/MainMenuPrototypeProfile.asset";
    private const string BackdropMaterialPath = "Assets/ShaderCourse/UIPrototype/Materials/MainMenuBackdrop.mat";
    private const string MonitorMaterialPath = "Assets/ShaderCourse/UIPrototype/Materials/MainMenuMonitor.mat";
    private const string CruiserMaterialPath = "Assets/ShaderCourse/UIPrototype/Materials/MainMenuCruiser.mat";
    private const string ChineseFontAssetPath = "Assets/ShaderCourse/UIPrototype/Materials/UIPrototype_CN_TMP.asset";

    [MenuItem("Tools/ShaderCourse/Build Main Menu Prototype")]
    public static void Build()
    {
        EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

        Shader buttonShader = Shader.Find("ShaderCourse/UI/HoloButton");
        if (buttonShader == null)
        {
            Debug.LogError("Missing shader: ShaderCourse/UI/HoloButton");
            return;
        }

        Texture monitorTexture = AssetDatabase.LoadAssetAtPath<Texture>("Assets/ShaderCourse/space-ship-monitor-unity/space-ship-monitor_albedo.png");
        Texture cruiserTexture = AssetDatabase.LoadAssetAtPath<Texture>("Assets/ShaderCourse/space-cruiser-panels1-unity/space-cruiser-panels_albedo.png");
        Texture cityTexture = AssetDatabase.LoadAssetAtPath<Texture>("Assets/ShaderCourse/UIPrototype/Imported/city_reference.jpg");
        Texture globeTexture = AssetDatabase.LoadAssetAtPath<Texture>("Assets/ShaderCourse/UIPrototype/Imported/space_globe_reference.jpg");

        TMP_FontAsset font = GetChineseTmpFont();
        if (font == null)
        {
            Debug.LogError("Missing TMP Chinese font asset.");
            return;
        }

        PopulateFontAsset(font, GetLocalizedTextCorpus());

        Material buttonMaterial = GetOrCreateMaterial(HoloMaterialPath, buttonShader);
        buttonMaterial.SetColor("_BaseColor", new Color(0.04f, 0.10f, 0.18f, 1f));
        buttonMaterial.SetColor("_AccentColor", new Color(0.45f, 0.91f, 1f, 1f));
        buttonMaterial.SetColor("_SecondaryColor", new Color(0.09f, 0.22f, 0.34f, 1f));
        buttonMaterial.SetFloat("_CornerRadius", 0.20f);
        buttonMaterial.SetFloat("_EdgeWidth", 0.022f);
        buttonMaterial.SetFloat("_SweepWidth", 0.26f);
        buttonMaterial.SetFloat("_ScanAngle", 45f);
        buttonMaterial.SetFloat("_NoiseTiling", 28f);

        SetupSceneLighting();
        SetupBackdrop(cityTexture, globeTexture, cruiserTexture);

        GameObject canvasGO = new GameObject("Canvas", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
        Canvas canvas = canvasGO.GetComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        CanvasScaler scaler = canvasGO.GetComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1920f, 1080f);
        scaler.matchWidthOrHeight = 0.5f;

        new GameObject("EventSystem", typeof(EventSystem), typeof(InputSystemUIInputModule));

        GameObject controllerGO = new GameObject("MainMenuController", typeof(MainMenuPrototypeController), typeof(MenuSfxSynth));
        controllerGO.transform.SetParent(canvasGO.transform, false);
        MainMenuPrototypeController controller = controllerGO.GetComponent<MainMenuPrototypeController>();

        BuildUi(canvasGO.transform, controller, buttonMaterial, font, cityTexture != null ? cityTexture : monitorTexture, globeTexture != null ? globeTexture : monitorTexture);

        EditorSceneManager.SaveScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene(), ScenePath);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        Debug.Log("Built main menu prototype scene.");
    }

    private static TMP_FontAsset GetChineseTmpFont()
    {
        TMP_FontAsset existing = AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(ChineseFontAssetPath);
        if (IsUsableFontAsset(existing))
        {
            return existing;
        }

        if (existing != null)
        {
            AssetDatabase.DeleteAsset(ChineseFontAssetPath);
        }

        string[] fontFamilies =
        {
            "Microsoft YaHei",
            "SimHei"
        };

        TMP_FontAsset fontAsset = null;
        foreach (string family in fontFamilies)
        {
            fontAsset = TMP_FontAsset.CreateFontAsset(family, "Regular", 90);
            if (fontAsset != null)
            {
                break;
            }
        }

        if (fontAsset == null)
        {
            return null;
        }

        fontAsset.name = "UIPrototype_CN_TMP";
        fontAsset.isMultiAtlasTexturesEnabled = true;
        AssetDatabase.CreateAsset(fontAsset, ChineseFontAssetPath);
        AssetDatabase.SaveAssets();
        return fontAsset;
    }

    private static bool IsUsableFontAsset(TMP_FontAsset fontAsset)
    {
        return fontAsset != null &&
               fontAsset.atlasTextures != null &&
               fontAsset.atlasTextures.Length > 0 &&
               fontAsset.atlasTextures[0] != null;
    }

    private static void PopulateFontAsset(TMP_FontAsset fontAsset, IEnumerable<string> texts)
    {
        foreach (string text in texts)
        {
            string missing;
            fontAsset.TryAddCharacters(text, out missing);
        }

        fontAsset.TryAddCharacters("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 /:-,.", out _);
        EditorUtility.SetDirty(fontAsset);
        AssetDatabase.SaveAssets();
    }

    private static IEnumerable<string> GetLocalizedTextCorpus()
    {
        return new[]
        {
            "\u661f\u8230\u4e2d\u67a2 / \u6307\u6325\u5927\u5385",
            "\u661f\u8680\u8fb9\u7586",
            "ECLIPSE FRONTIER",
            "\u4ee5\u4e3b\u6d41\u4e8c\u6b21\u5143\u79d1\u5e7b RPG \u7684\u6807\u9898\u9875\u6c14\u8d28\u4e3a\u53c2\u8003\uff0c\u91cd\u6784\u6210\u66f4\u9002\u5408\u8bfe\u7a0b\u5c55\u793a\u7684\u4e2d\u6587\u4e3b\u754c\u9762\u539f\u578b\u3002\u5b83\u5f3a\u8c03\u5c42\u6b21\u3001\u6750\u8d28\u3001\u52a8\u6001\u706f\u6548\u4e0e\u9ad8\u8bc6\u522b\u5ea6\u7684\u4e3b\u6309\u94ae\u5165\u53e3\u3002",
            "\u4f5c\u6218\u5165\u53e3",
            "\u5f53\u524d\u6a21\u5757",
            "\u6218\u672f\u72b6\u6001",
            "\u8230\u961f\u80fd\u91cf",
            "\u4fe1\u53f7\u5b8c\u6574\u5ea6",
            "\u786e\u8ba4\u8d77\u822a",
            "\u8fd4\u56de\u4e3b\u8231",
            "\u542f\u52a8\u4fe1\u53f7\u5df2\u63a5\u6536",
            "\u8230\u6865\u8bf7\u6c42\u5df2\u5c31\u7eea\uff0c\u518d\u6b21\u70b9\u51fb\u53ef\u6a21\u62df\u542f\u52a8\u6d41\u7a0b\u3002",
            "\u539f\u578b\u6d41\u8f6c\uff1a\u6309\u94ae\u5207\u9875\u3001\u72b6\u6001\u53cd\u9988\u3001\u7a0b\u5e8f\u5316 UI \u97f3\u6548\u3001\u52a8\u6001\u9884\u89c8\u8054\u52a8\u3002",
            "\u5f00\u59cb\u8fdc\u5f81",
            "\u7ee7\u7eed\u65c5\u7a0b",
            "\u8230\u8239\u673a\u5e93",
            "\u7cfb\u7edf\u8bbe\u7f6e",
            "\u6863\u6848\u7532\u677f",
            "\u51c6\u5907\u8fdb\u5165\u8fdc\u5f81\u8230\u6865",
            "\u628a\u73a9\u5bb6\u6ce8\u610f\u529b\u96c6\u4e2d\u5230\u552f\u4e00\u7684\u9ad8\u4ef7\u503c\u4e3b\u5165\u53e3\u4e0a\u3002\u8fd9\u4e2a\u7248\u672c\u5f3a\u8c03\u6807\u9898\u3001\u8bf4\u660e\u3001\u4e3b\u6309\u94ae\u4e0e\u9884\u89c8\u533a\u4e4b\u95f4\u7684\u8282\u594f\u5173\u7cfb\uff0c\u8ba9\u9996\u5c4f\u66f4\u50cf\u4e00\u6b3e\u771f\u6b63\u53ef\u4ea4\u4e92\u7684\u5546\u4e1a\u6e38\u620f\u6807\u9898\u9875\u3002",
            "\u65d7\u8230\u822a\u7ebf\u5bf9\u9f50\u5b8c\u6210",
            "\u7ee7\u7eed\u4e0a\u4e00\u6b21\u822a\u7a0b",
            "\u7a81\u51fa\u201c\u56de\u6d41\u201d\u4f53\u9a8c\uff0c\u5feb\u901f\u5448\u73b0\u6700\u8fd1\u8fdb\u5ea6\u3001\u53ef\u7ee7\u7eed\u72b6\u6001\u4e0e\u7cfb\u7edf\u786e\u8ba4\u4fe1\u606f\uff0c\u8ba9\u56de\u5230\u6e38\u620f\u8fd9\u4e00\u6b65\u8db3\u591f\u8f7b\u3001\u8db3\u591f\u5feb\u3002",
            "\u81ea\u52a8\u5b58\u6863\u6d41\u7a33\u5b9a",
            "\u67e5\u770b\u8230\u8239\u673a\u5e93",
            "\u673a\u5e93\u9875\u8d1f\u8d23\u4f20\u8fbe\u4e2d\u5c42\u7cfb\u7edf\u6df1\u5ea6\uff0c\u6697\u793a\u89d2\u8272\u517b\u6210\u3001\u8f7d\u5177\u6539\u9020\u4e0e\u6536\u85cf\u5185\u5bb9\uff0c\u4e3a\u6574\u4e2a\u4e3b\u754c\u9762\u8865\u4e0a\u4e16\u754c\u89c2\u4e0e\u7cfb\u7edf\u5e7f\u5ea6\u3002",
            "\u8230\u4f53\u8bca\u65ad\u53ef\u7528",
            "\u6821\u51c6\u753b\u9762\u4e0e\u63a7\u5236",
            "\u8bbe\u7f6e\u9875\u662f\u53ef\u7528\u6027\u4e0e\u79e9\u5e8f\u611f\u7684\u91cd\u8981\u90e8\u5206\u3002\u5b83\u5728\u8fd9\u4e2a\u539f\u578b\u91cc\u627f\u62c5\u5207\u9875\u3001\u72b6\u6001\u4fdd\u6301\u3001\u8272\u5f69\u5207\u6362\u4e0e\u4fe1\u606f\u5e03\u5c40\u590d\u7528\u7684\u5c55\u793a\u4efb\u52a1\u3002",
            "\u6821\u51c6\u5957\u4ef6\u5728\u7ebf",
            "\u68c0\u89c6\u6863\u6848\u4e0e\u56de\u62a5",
            "\u6863\u6848\u9875\u627f\u62c5\u66f4\u5b89\u9759\u7684\u4fe1\u606f\u8868\u8fbe\u89d2\u8272\uff0c\u8ba9\u754c\u9762\u4ece\u201c\u542f\u52a8\u611f\u201d\u5ef6\u5c55\u5230\u201c\u5185\u5bb9\u611f\u201d\u3002",
            "\u6863\u6848\u8282\u70b9\u5df2\u540c\u6b65"
        };
    }

    private static void SetupSceneLighting()
    {
        GameObject cameraGO = new GameObject("Main Camera", typeof(Camera), typeof(AudioListener), typeof(UniversalAdditionalCameraData));
        Camera camera = cameraGO.GetComponent<Camera>();
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(0.02f, 0.05f, 0.08f, 1f);
        camera.fieldOfView = 42f;
        camera.transform.position = new Vector3(0f, 0f, -12f);
        camera.tag = "MainCamera";

        GameObject lightGO = new GameObject("Directional Light", typeof(Light), typeof(UniversalAdditionalLightData));
        Light light = lightGO.GetComponent<Light>();
        light.type = LightType.Directional;
        light.color = new Color(0.70f, 0.88f, 1f, 1f);
        light.intensity = 1.15f;
        lightGO.transform.rotation = Quaternion.Euler(38f, -26f, 0f);

        GameObject volumeGO = new GameObject("Global Volume", typeof(Volume));
        Volume volume = volumeGO.GetComponent<Volume>();
        volume.isGlobal = true;
        VolumeProfile profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(VolumeProfilePath);
        if (profile == null)
        {
            profile = ScriptableObject.CreateInstance<VolumeProfile>();
            AssetDatabase.CreateAsset(profile, VolumeProfilePath);
        }

        ResetProfile(profile);
        volume.sharedProfile = profile;
    }

    private static void ResetProfile(VolumeProfile profile)
    {
        Bloom bloom;
        if (!profile.TryGet(out bloom))
        {
            bloom = profile.Add<Bloom>(true);
        }
        bloom.active = true;
        bloom.intensity.Override(1.2f);
        bloom.threshold.Override(0.85f);
        bloom.scatter.Override(0.72f);

        Vignette vignette;
        if (!profile.TryGet(out vignette))
        {
            vignette = profile.Add<Vignette>(true);
        }
        vignette.active = true;
        vignette.intensity.Override(0.26f);
        vignette.smoothness.Override(0.70f);

        ColorAdjustments colorAdjustments;
        if (!profile.TryGet(out colorAdjustments))
        {
            colorAdjustments = profile.Add<ColorAdjustments>(true);
        }
        colorAdjustments.active = true;
        colorAdjustments.postExposure.Override(0.12f);
        colorAdjustments.saturation.Override(-8f);

        EditorUtility.SetDirty(profile);
    }

    private static void SetupBackdrop(Texture cityTexture, Texture globeTexture, Texture cruiserTexture)
    {
        GameObject root = new GameObject("Backdrop");

        GameObject bgQuad = GameObject.CreatePrimitive(PrimitiveType.Quad);
        bgQuad.name = "NebulaPlane";
        bgQuad.transform.SetParent(root.transform, false);
        bgQuad.transform.localScale = new Vector3(20f, 11f, 1f);
        bgQuad.transform.localPosition = new Vector3(0f, 0f, 10f);
        bgQuad.GetComponent<MeshRenderer>().sharedMaterial = GetTintedUnlitMaterial(BackdropMaterialPath, new Color(0.04f, 0.09f, 0.14f, 1f), cityTexture);
        Object.DestroyImmediate(bgQuad.GetComponent<Collider>());

        GameObject monitorQuad = GameObject.CreatePrimitive(PrimitiveType.Quad);
        monitorQuad.name = "MonitorPanel";
        monitorQuad.transform.SetParent(root.transform, false);
        monitorQuad.transform.localScale = new Vector3(7.4f, 4.2f, 1f);
        monitorQuad.transform.localPosition = new Vector3(2.8f, 0.2f, 6.2f);
        monitorQuad.transform.localRotation = Quaternion.Euler(0f, -11f, 0f);
        monitorQuad.GetComponent<MeshRenderer>().sharedMaterial = GetTintedUnlitMaterial(MonitorMaterialPath, new Color(0.42f, 0.88f, 1f, 0.22f), globeTexture);
        Object.DestroyImmediate(monitorQuad.GetComponent<Collider>());

        GameObject cruiserQuad = GameObject.CreatePrimitive(PrimitiveType.Quad);
        cruiserQuad.name = "CruiserPanel";
        cruiserQuad.transform.SetParent(root.transform, false);
        cruiserQuad.transform.localScale = new Vector3(9f, 5.5f, 1f);
        cruiserQuad.transform.localPosition = new Vector3(-1.6f, -1.3f, 7.5f);
        cruiserQuad.transform.localRotation = Quaternion.Euler(0f, 10f, 0f);
        cruiserQuad.GetComponent<MeshRenderer>().sharedMaterial = GetTintedUnlitMaterial(CruiserMaterialPath, new Color(0.08f, 0.22f, 0.34f, 0.34f), cruiserTexture);
        Object.DestroyImmediate(cruiserQuad.GetComponent<Collider>());

        GameObject particlesGO = new GameObject("AmbientParticles");
        particlesGO.transform.SetParent(root.transform, false);
        particlesGO.transform.localPosition = new Vector3(0f, 0f, 4f);
        ParticleSystem ps = particlesGO.AddComponent<ParticleSystem>();
        ParticleSystem.MainModule main = ps.main;
        main.loop = true;
        main.startLifetime = 10f;
        main.startSpeed = 0.08f;
        main.startSize = 0.06f;
        main.maxParticles = 160;
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.startColor = new ParticleSystem.MinMaxGradient(new Color(0.50f, 0.92f, 1f, 0.18f));
        ParticleSystem.EmissionModule emission = ps.emission;
        emission.rateOverTime = 14f;
        ParticleSystem.ShapeModule shape = ps.shape;
        shape.shapeType = ParticleSystemShapeType.Box;
        shape.scale = new Vector3(14f, 7f, 2f);
        ParticleSystem.NoiseModule noise = ps.noise;
        noise.enabled = true;
        noise.strength = 0.08f;
        noise.frequency = 0.22f;
        ParticleSystemRenderer renderer = ps.GetComponent<ParticleSystemRenderer>();
        renderer.material = new Material(Shader.Find("Universal Render Pipeline/Particles/Unlit"));
        ps.Play();
    }

    private static void BuildUi(Transform canvasRoot, MainMenuPrototypeController controller, Material buttonMaterial, TMP_FontAsset font, Texture cityTexture, Texture globeTexture)
    {
        string[] menuLabels =
        {
            "\u5f00\u59cb\u8fdc\u5f81",
            "\u7ee7\u7eed\u65c5\u7a0b",
            "\u8230\u8239\u673a\u5e93",
            "\u7cfb\u7edf\u8bbe\u7f6e",
            "\u6863\u6848\u7532\u677f"
        };

        string[] keys = { "launch", "resume", "hangar", "settings", "archive" };

        CreateImage("BackgroundOverlay", canvasRoot, new Color(0.01f, 0.04f, 0.07f, 0.68f), Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero);
        CreateImage("RadialGlow", canvasRoot, new Color(0.18f, 0.62f, 0.78f, 0.18f), new Vector2(0.50f, 0.12f), new Vector2(0.94f, 0.88f), Vector2.zero, Vector2.zero);

        Image leftPanel = CreateImage("LeftPanel", canvasRoot, new Color(0.025f, 0.07f, 0.11f, 0.90f), new Vector2(0f, 0f), new Vector2(0.335f, 1f), new Vector2(0f, 0f), new Vector2(-12f, 0f));
        CreateImage("Divider", leftPanel.transform, new Color(0.40f, 0.84f, 0.98f, 0.55f), new Vector2(1f, 0f), new Vector2(1f, 1f), new Vector2(-2f, 40f), new Vector2(0f, -40f));

        CreateTmpText("BrandKicker", leftPanel.transform, "\u661f\u8230\u4e2d\u67a2 / \u6307\u6325\u5927\u5385", 24, FontStyles.Bold, TextAlignmentOptions.Left, new Color(0.50f, 0.90f, 1f, 0.92f), font, new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(52f, -88f), new Vector2(-40f, -40f), 0.12f, 0.16f);
        CreateTmpText("BrandTitle", leftPanel.transform, "\u661f\u8680\u8fb9\u7586", 68, FontStyles.Bold, TextAlignmentOptions.TopLeft, Color.white, font, new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(48f, -172f), new Vector2(-52f, -96f), 0.15f, 0.20f);
        CreateTmpText("BrandSubTitle", leftPanel.transform, "ECLIPSE FRONTIER", 22, FontStyles.Bold, TextAlignmentOptions.TopLeft, new Color(0.80f, 0.90f, 0.96f, 0.92f), font, new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(54f, -286f), new Vector2(-52f, -182f), 0.08f, 0.12f);
        CreateTmpText("BrandBody", leftPanel.transform, "\u4ee5\u4e3b\u6d41\u4e8c\u6b21\u5143\u79d1\u5e7b RPG \u7684\u6807\u9898\u9875\u6c14\u8d28\u4e3a\u53c2\u8003\uff0c\u91cd\u6784\u6210\u66f4\u9002\u5408\u8bfe\u7a0b\u5c55\u793a\u7684\u4e2d\u6587\u4e3b\u754c\u9762\u539f\u578b\u3002\u5b83\u5f3a\u8c03\u5c42\u6b21\u3001\u6750\u8d28\u3001\u52a8\u6001\u706f\u6548\u4e0e\u9ad8\u8bc6\u522b\u5ea6\u7684\u4e3b\u6309\u94ae\u5165\u53e3\u3002", 24, FontStyles.Normal, TextAlignmentOptions.TopLeft, new Color(0.76f, 0.87f, 0.93f, 0.96f), font, new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(52f, -352f), new Vector2(-54f, -250f), 0.04f, 0.08f);
        CreateTmpText("MenuHeader", leftPanel.transform, "\u4f5c\u6218\u5165\u53e3", 24, FontStyles.Bold, TextAlignmentOptions.Left, new Color(0.63f, 0.85f, 0.95f, 0.72f), font, new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(54f, -454f), new Vector2(-32f, -408f), 0.08f, 0.12f);

        GameObject menuButtonGroup = CreateUiObject("MenuButtonGroup", leftPanel.transform, new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(42f, -494f), new Vector2(-42f, -946f));
        VerticalLayoutGroup menuLayout = menuButtonGroup.AddComponent<VerticalLayoutGroup>();
        menuLayout.childAlignment = TextAnchor.UpperCenter;
        menuLayout.childControlWidth = false;
        menuLayout.childControlHeight = false;
        menuLayout.childForceExpandWidth = false;
        menuLayout.childForceExpandHeight = false;
        menuLayout.spacing = 16f;
        ContentSizeFitter menuFitter = menuButtonGroup.AddComponent<ContentSizeFitter>();
        menuFitter.verticalFit = ContentSizeFitter.FitMode.PreferredSize;

        List<MainMenuPrototypeController.MenuButtonBinding> buttonBindings = new List<MainMenuPrototypeController.MenuButtonBinding>();
        for (int i = 0; i < keys.Length; i++)
        {
            TextMeshProUGUI labelText;
            Button button = CreateButton(keys[i] + "Button", menuButtonGroup.transform, menuLabels[i], buttonMaterial, font, out labelText);
            buttonBindings.Add(new MainMenuPrototypeController.MenuButtonBinding
            {
                button = button,
                feedback = button.GetComponent<HoloMenuButton>(),
                sectionKey = keys[i]
            });
        }

        Image footerStrip = CreateImage("FooterStrip", leftPanel.transform, new Color(0.08f, 0.18f, 0.24f, 0.82f), new Vector2(0f, 0f), new Vector2(1f, 0f), new Vector2(24f, 28f), new Vector2(-24f, 132f));
        TextMeshProUGUI statusText = CreateTmpText("Status", footerStrip.transform, "\u8230\u6865\u8bf7\u6c42\u5df2\u5c31\u7eea\uff0c\u518d\u6b21\u70b9\u51fb\u53ef\u6a21\u62df\u542f\u52a8\u6d41\u7a0b\u3002", 19, FontStyles.Normal, TextAlignmentOptions.Left, new Color(0.86f, 0.95f, 1f, 0.95f), font, Vector2.zero, Vector2.one, new Vector2(22f, 16f), new Vector2(-20f, -18f), 0.04f, 0.08f);

        Image rightPanel = CreateImage("RightPanel", canvasRoot, new Color(0.05f, 0.09f, 0.14f, 0.78f), new Vector2(0.355f, 0.08f), new Vector2(0.965f, 0.92f), Vector2.zero, Vector2.zero);
        CanvasGroup infoPanel = rightPanel.gameObject.AddComponent<CanvasGroup>();
        Image accentBar = CreateImage("AccentBar", rightPanel.transform, new Color(0.45f, 0.91f, 1f, 1f), new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(0f, -8f), Vector2.zero);

        if (cityTexture != null)
        {
            GameObject heroBgGO = CreateUiObject("HeroBackground", rightPanel.transform, new Vector2(0.46f, 0.10f), new Vector2(1f, 0.90f), Vector2.zero, Vector2.zero);
            RawImage heroBg = heroBgGO.AddComponent<RawImage>();
            heroBg.texture = cityTexture;
            heroBg.color = new Color(0.56f, 0.78f, 0.92f, 0.16f);
            heroBg.uvRect = new Rect(0.06f, 0.12f, 0.88f, 0.70f);
        }

        CreateTmpText("SectionKicker", rightPanel.transform, "\u5f53\u524d\u6a21\u5757", 22, FontStyles.Bold, TextAlignmentOptions.Left, new Color(0.56f, 0.84f, 0.95f, 0.86f), font, new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(48f, -52f), new Vector2(-40f, -16f), 0.08f, 0.12f);
        TextMeshProUGUI headline = CreateTmpText("Headline", rightPanel.transform, string.Empty, 50, FontStyles.Bold, TextAlignmentOptions.TopLeft, Color.white, font, new Vector2(0f, 1f), new Vector2(0.50f, 1f), new Vector2(48f, -156f), new Vector2(-10f, -44f), 0.12f, 0.18f);
        TextMeshProUGUI summary = CreateTmpText("Summary", rightPanel.transform, string.Empty, 23, FontStyles.Normal, TextAlignmentOptions.TopLeft, new Color(0.78f, 0.88f, 0.94f, 0.98f), font, new Vector2(0f, 1f), new Vector2(0.48f, 1f), new Vector2(50f, -254f), new Vector2(-18f, -144f), 0.04f, 0.08f);
        TextMeshProUGUI accentLabel = CreateTmpText("AccentLabel", rightPanel.transform, string.Empty, 24, FontStyles.Bold, TextAlignmentOptions.Left, new Color(0.45f, 0.91f, 1f, 1f), font, new Vector2(0f, 1f), new Vector2(0.48f, 1f), new Vector2(50f, -402f), new Vector2(-18f, -350f), 0.08f, 0.12f);

        Image previewFrame = CreateImage("PreviewFrame", rightPanel.transform, new Color(0.03f, 0.07f, 0.11f, 0.90f), new Vector2(0.56f, 0.20f), new Vector2(0.95f, 0.82f), Vector2.zero, Vector2.zero);
        Image previewGlow = CreateImage("PreviewGlow", previewFrame.transform, new Color(0.45f, 0.91f, 1f, 0.42f), new Vector2(0.08f, 0.08f), new Vector2(0.92f, 0.92f), Vector2.zero, Vector2.zero);
        Image orbitRing = CreateImage("OrbitRing", previewFrame.transform, new Color(0.58f, 0.94f, 1f, 0.25f), new Vector2(0.18f, 0.18f), new Vector2(0.82f, 0.82f), Vector2.zero, Vector2.zero);
        orbitRing.rectTransform.localEulerAngles = new Vector3(0f, 0f, 24f);
        CreateImage("PreviewAccent", previewFrame.transform, new Color(0.80f, 0.96f, 1f, 0.12f), new Vector2(0.62f, 0.12f), new Vector2(0.88f, 0.25f), Vector2.zero, Vector2.zero);
        GameObject rawPreviewGO = CreateUiObject("PreviewTexture", previewFrame.transform, new Vector2(0.09f, 0.09f), new Vector2(0.91f, 0.91f), Vector2.zero, Vector2.zero);
        RawImage rawPreview = rawPreviewGO.AddComponent<RawImage>();
        rawPreview.texture = globeTexture;
        rawPreview.color = new Color(0.74f, 0.92f, 1f, 0.42f);
        rawPreview.uvRect = new Rect(0.18f, 0.12f, 0.64f, 0.76f);

        Image statPanel = CreateImage("StatPanel", rightPanel.transform, new Color(0.06f, 0.14f, 0.19f, 0.90f), new Vector2(0f, 0f), new Vector2(0.50f, 0.29f), new Vector2(40f, 182f), new Vector2(-26f, -24f));
        CreateTmpText("StatHeader", statPanel.transform, "\u6218\u672f\u72b6\u6001", 19, FontStyles.Bold, TextAlignmentOptions.Left, new Color(0.54f, 0.86f, 0.97f, 0.82f), font, new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(24f, -42f), new Vector2(-22f, -10f), 0.06f, 0.10f);
        CreateTmpText("EnergyLabel", statPanel.transform, "\u8230\u961f\u80fd\u91cf", 18, FontStyles.Normal, TextAlignmentOptions.Left, new Color(0.88f, 0.94f, 1f, 0.92f), font, new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(24f, -84f), new Vector2(-120f, -56f), 0.02f, 0.06f);
        CreateTmpText("SignalLabel", statPanel.transform, "\u4fe1\u53f7\u5b8c\u6574\u5ea6", 18, FontStyles.Normal, TextAlignmentOptions.Left, new Color(0.88f, 0.94f, 1f, 0.92f), font, new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(24f, -142f), new Vector2(-120f, -114f), 0.02f, 0.06f);

        Slider energySlider = CreateSlider("EnergySlider", statPanel.transform, new Color(0.38f, 0.94f, 1f, 0.95f), new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(24f, -116f), new Vector2(-24f, -94f));
        Slider signalSlider = CreateSlider("SignalSlider", statPanel.transform, new Color(0.83f, 0.93f, 1f, 0.95f), new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(24f, -172f), new Vector2(-24f, -150f));

        GameObject ctaGroup = CreateUiObject("CTAGroup", rightPanel.transform, new Vector2(0f, 0f), new Vector2(1f, 0f), new Vector2(50f, 22f), new Vector2(-50f, 88f));
        HorizontalLayoutGroup ctaLayout = ctaGroup.AddComponent<HorizontalLayoutGroup>();
        ctaLayout.childAlignment = TextAnchor.MiddleCenter;
        ctaLayout.childControlWidth = false;
        ctaLayout.childControlHeight = false;
        ctaLayout.childForceExpandWidth = false;
        ctaLayout.childForceExpandHeight = false;
        ctaLayout.spacing = 28f;
        ContentSizeFitter ctaFitter = ctaGroup.AddComponent<ContentSizeFitter>();
        ctaFitter.horizontalFit = ContentSizeFitter.FitMode.PreferredSize;
        ctaFitter.verticalFit = ContentSizeFitter.FitMode.PreferredSize;

        TextMeshProUGUI ctaLabel;
        Button ctaButton = CreateButton("LaunchCTA", ctaGroup.transform, "\u786e\u8ba4\u8d77\u822a", buttonMaterial, font, out ctaLabel);
        SetBottomButton(ctaButton, 320f);
        ctaButton.onClick.AddListener(controller.TriggerLaunchPulse);

        TextMeshProUGUI backLabel;
        Button backButton = CreateButton("BackCTA", ctaGroup.transform, "\u8fd4\u56de\u4e3b\u8231", buttonMaterial, font, out backLabel);
        SetBottomButton(backButton, 260f);
        backButton.onClick.AddListener(controller.BackToHome);

        TextMeshProUGUI footerTip = CreateTmpText("FooterTip", canvasRoot, string.Empty, 17, FontStyles.Normal, TextAlignmentOptions.BottomRight, new Color(0.70f, 0.85f, 0.93f, 0.86f), font, new Vector2(0.54f, 0f), new Vector2(0.975f, 0.085f), Vector2.zero, Vector2.zero, 0.02f, 0.05f);

        Image overlay = CreateImage("LaunchOverlay", canvasRoot, new Color(0.72f, 0.95f, 1f, 0f), Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero);
        CanvasGroup overlayGroup = overlay.gameObject.AddComponent<CanvasGroup>();
        CreateTmpText("OverlayText", overlay.transform, "\u542f\u52a8\u4fe1\u53f7\u5df2\u63a5\u6536", 74, FontStyles.Bold, TextAlignmentOptions.Center, new Color(0.04f, 0.12f, 0.18f, 0.88f), font, new Vector2(0.2f, 0.4f), new Vector2(0.8f, 0.6f), Vector2.zero, Vector2.zero, 0.18f, 0.22f);

        ApplyControllerBindings(controller, buttonBindings, infoPanel, overlayGroup, accentBar, previewGlow, headline, summary, accentLabel, statusText, footerTip, energySlider, signalSlider, previewFrame.rectTransform, orbitRing.rectTransform);
    }

    private static void ApplyControllerBindings(
        MainMenuPrototypeController controller,
        List<MainMenuPrototypeController.MenuButtonBinding> buttonBindings,
        CanvasGroup infoPanel,
        CanvasGroup overlayGroup,
        Image accentBar,
        Image previewGlow,
        TextMeshProUGUI headline,
        TextMeshProUGUI summary,
        TextMeshProUGUI accentLabel,
        TextMeshProUGUI statusText,
        TextMeshProUGUI footerTip,
        Slider energySlider,
        Slider signalSlider,
        RectTransform previewFrame,
        RectTransform orbitRing)
    {
        SerializedObject serialized = new SerializedObject(controller);
        SetObjectReference(serialized, "infoPanel", infoPanel);
        SetObjectReference(serialized, "launchOverlay", overlayGroup);
        SetObjectReference(serialized, "accentBar", accentBar);
        SetObjectReference(serialized, "previewGlow", previewGlow);
        SetObjectReference(serialized, "headlineText", headline);
        SetObjectReference(serialized, "summaryText", summary);
        SetObjectReference(serialized, "accentLabelText", accentLabel);
        SetObjectReference(serialized, "statusText", statusText);
        SetObjectReference(serialized, "footerTipText", footerTip);
        SetObjectReference(serialized, "energySlider", energySlider);
        SetObjectReference(serialized, "signalSlider", signalSlider);
        SetObjectReference(serialized, "previewFrame", previewFrame);
        SetObjectReference(serialized, "orbitRing", orbitRing);

        MainMenuPrototypeController.MenuSection[] sections =
        {
            CreateSection("launch", "\u51c6\u5907\u8fdb\u5165\u8fdc\u5f81\u8230\u6865", "\u628a\u73a9\u5bb6\u6ce8\u610f\u529b\u96c6\u4e2d\u5230\u552f\u4e00\u7684\u9ad8\u4ef7\u503c\u4e3b\u5165\u53e3\u4e0a\u3002\u8fd9\u4e2a\u7248\u672c\u5f3a\u8c03\u6807\u9898\u3001\u8bf4\u660e\u3001\u4e3b\u6309\u94ae\u4e0e\u9884\u89c8\u533a\u4e4b\u95f4\u7684\u8282\u594f\u5173\u7cfb\uff0c\u8ba9\u9996\u5c4f\u66f4\u50cf\u4e00\u6b3e\u771f\u6b63\u53ef\u4ea4\u4e92\u7684\u5546\u4e1a\u6e38\u620f\u6807\u9898\u9875\u3002", "\u65d7\u8230\u822a\u7ebf\u5bf9\u9f50\u5b8c\u6210", new Color(0.42f, 0.92f, 1f, 1f)),
            CreateSection("resume", "\u7ee7\u7eed\u4e0a\u4e00\u6b21\u822a\u7a0b", "\u7a81\u51fa\u201c\u56de\u6d41\u201d\u4f53\u9a8c\uff0c\u5feb\u901f\u5448\u73b0\u6700\u8fd1\u8fdb\u5ea6\u3001\u53ef\u7ee7\u7eed\u72b6\u6001\u4e0e\u7cfb\u7edf\u786e\u8ba4\u4fe1\u606f\uff0c\u8ba9\u56de\u5230\u6e38\u620f\u8fd9\u4e00\u6b65\u8db3\u591f\u8f7b\u3001\u8db3\u591f\u5feb\u3002", "\u81ea\u52a8\u5b58\u6863\u6d41\u7a33\u5b9a", new Color(0.62f, 0.88f, 1f, 1f)),
            CreateSection("hangar", "\u67e5\u770b\u8230\u8239\u673a\u5e93", "\u673a\u5e93\u9875\u8d1f\u8d23\u4f20\u8fbe\u4e2d\u5c42\u7cfb\u7edf\u6df1\u5ea6\uff0c\u6697\u793a\u89d2\u8272\u517b\u6210\u3001\u8f7d\u5177\u6539\u9020\u4e0e\u6536\u85cf\u5185\u5bb9\uff0c\u4e3a\u6574\u4e2a\u4e3b\u754c\u9762\u8865\u4e0a\u4e16\u754c\u89c2\u4e0e\u7cfb\u7edf\u5e7f\u5ea6\u3002", "\u8230\u4f53\u8bca\u65ad\u53ef\u7528", new Color(0.49f, 1f, 0.84f, 1f)),
            CreateSection("settings", "\u6821\u51c6\u753b\u9762\u4e0e\u63a7\u5236", "\u8bbe\u7f6e\u9875\u662f\u53ef\u7528\u6027\u4e0e\u79e9\u5e8f\u611f\u7684\u91cd\u8981\u90e8\u5206\u3002\u5b83\u5728\u8fd9\u4e2a\u539f\u578b\u91cc\u627f\u62c5\u5207\u9875\u3001\u72b6\u6001\u4fdd\u6301\u3001\u8272\u5f69\u5207\u6362\u4e0e\u4fe1\u606f\u5e03\u5c40\u590d\u7528\u7684\u5c55\u793a\u4efb\u52a1\u3002", "\u6821\u51c6\u5957\u4ef6\u5728\u7ebf", new Color(0.95f, 0.86f, 0.48f, 1f)),
            CreateSection("archive", "\u68c0\u89c6\u6863\u6848\u4e0e\u56de\u62a5", "\u6863\u6848\u9875\u627f\u62c5\u66f4\u5b89\u9759\u7684\u4fe1\u606f\u8868\u8fbe\u89d2\u8272\uff0c\u8ba9\u754c\u9762\u4ece\u201c\u542f\u52a8\u611f\u201d\u5ef6\u5c55\u5230\u201c\u5185\u5bb9\u611f\u201d\u3002", "\u6863\u6848\u8282\u70b9\u5df2\u540c\u6b65", new Color(0.92f, 0.70f, 1f, 1f))
        };

        SerializedProperty sectionsProp = serialized.FindProperty("sections");
        sectionsProp.arraySize = sections.Length;
        for (int i = 0; i < sections.Length; i++)
        {
            SerializedProperty entry = sectionsProp.GetArrayElementAtIndex(i);
            entry.FindPropertyRelative("key").stringValue = sections[i].key;
            entry.FindPropertyRelative("headline").stringValue = sections[i].headline;
            entry.FindPropertyRelative("summary").stringValue = sections[i].summary;
            entry.FindPropertyRelative("accentLabel").stringValue = sections[i].accentLabel;
            entry.FindPropertyRelative("accentColor").colorValue = sections[i].accentColor;
        }

        SerializedProperty buttonsProp = serialized.FindProperty("buttons");
        buttonsProp.arraySize = buttonBindings.Count;
        for (int i = 0; i < buttonBindings.Count; i++)
        {
            SerializedProperty entry = buttonsProp.GetArrayElementAtIndex(i);
            entry.FindPropertyRelative("button").objectReferenceValue = buttonBindings[i].button;
            entry.FindPropertyRelative("feedback").objectReferenceValue = buttonBindings[i].feedback;
            entry.FindPropertyRelative("sectionKey").stringValue = buttonBindings[i].sectionKey;
        }

        serialized.ApplyModifiedPropertiesWithoutUndo();
        EditorUtility.SetDirty(controller.gameObject);
    }

    private static MainMenuPrototypeController.MenuSection CreateSection(string key, string headline, string summary, string accentLabel, Color accentColor)
    {
        return new MainMenuPrototypeController.MenuSection
        {
            key = key,
            headline = headline,
            summary = summary,
            accentLabel = accentLabel,
            accentColor = accentColor
        };
    }

    private static void SetObjectReference(SerializedObject serialized, string propertyName, Object value)
    {
        serialized.FindProperty(propertyName).objectReferenceValue = value;
    }

    private static void SetBottomButton(Button button, float width)
    {
        RectTransform rt = button.GetComponent<RectTransform>();
        rt.anchorMin = new Vector2(0f, 0.5f);
        rt.anchorMax = new Vector2(0f, 0.5f);
        rt.pivot = new Vector2(0f, 0.5f);
        rt.sizeDelta = new Vector2(width, 66f);
    }

    private static Slider CreateSlider(string name, Transform parent, Color fillColor, Vector2 anchorMin, Vector2 anchorMax, Vector2 offsetMin, Vector2 offsetMax)
    {
        GameObject sliderGO = CreateUiObject(name, parent, anchorMin, anchorMax, offsetMin, offsetMax);
        Image background = sliderGO.AddComponent<Image>();
        background.color = new Color(1f, 1f, 1f, 0.1f);
        Slider slider = sliderGO.AddComponent<Slider>();
        slider.minValue = 0f;
        slider.maxValue = 1f;
        slider.direction = Slider.Direction.LeftToRight;

        GameObject fillArea = CreateUiObject("FillArea", sliderGO.transform, Vector2.zero, Vector2.one, new Vector2(4f, 4f), new Vector2(-4f, -4f));
        Image fill = CreateImage("Fill", fillArea.transform, fillColor, Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero);
        slider.fillRect = fill.rectTransform;
        slider.targetGraphic = fill;
        slider.value = 0.5f;
        return slider;
    }

    private static Button CreateButton(string name, Transform parent, string label, Material buttonMaterial, TMP_FontAsset font, out TextMeshProUGUI labelText)
    {
        GameObject buttonGO = CreateUiObject(name, parent, new Vector2(0f, 1f), new Vector2(0f, 1f), Vector2.zero, Vector2.zero);
        RectTransform rect = buttonGO.GetComponent<RectTransform>();
        rect.anchorMin = new Vector2(0f, 1f);
        rect.anchorMax = new Vector2(0f, 1f);
        rect.pivot = new Vector2(0f, 1f);
        rect.sizeDelta = new Vector2(320f, 72f);

        Image image = buttonGO.AddComponent<Image>();
        image.color = Color.white;
        image.material = buttonMaterial;

        Button button = buttonGO.AddComponent<Button>();
        buttonGO.AddComponent<HoloMenuButton>();

        GameObject labelGO = CreateUiObject("Label", buttonGO.transform, Vector2.zero, Vector2.one, new Vector2(26f, 8f), new Vector2(-22f, -8f));
        labelText = labelGO.AddComponent<TextMeshProUGUI>();
        labelText.font = font;
        labelText.text = label;
        labelText.fontSize = 28;
        labelText.fontStyle = FontStyles.Bold;
        labelText.color = new Color(0.93f, 0.98f, 1f, 1f);
        labelText.alignment = TextAlignmentOptions.Center;
        labelText.enableWordWrapping = false;
        labelText.outlineWidth = 0.12f;
        labelText.outlineColor = new Color(0.02f, 0.08f, 0.12f, 0.9f);

        CreateImage("Accent", buttonGO.transform, new Color(0.45f, 0.91f, 1f, 0.85f), new Vector2(1f, 0.5f), new Vector2(1f, 0.5f), new Vector2(-16f, -14f), new Vector2(-8f, 14f));
        return button;
    }

    private static TextMeshProUGUI CreateTmpText(string name, Transform parent, string content, int size, FontStyles style, TextAlignmentOptions alignment, Color color, TMP_FontAsset font, Vector2 anchorMin, Vector2 anchorMax, Vector2 offsetMin, Vector2 offsetMax, float outlineWidth, float glowAlpha)
    {
        GameObject textGO = CreateUiObject(name, parent, anchorMin, anchorMax, offsetMin, offsetMax);
        TextMeshProUGUI text = textGO.AddComponent<TextMeshProUGUI>();
        text.font = font;
        text.text = content;
        text.fontSize = size;
        text.fontStyle = style;
        text.alignment = alignment;
        text.color = color;
        text.enableWordWrapping = true;
        text.outlineWidth = outlineWidth;
        text.outlineColor = new Color(0.02f, 0.08f, 0.12f, glowAlpha);
        return text;
    }

    private static Image CreateImage(string name, Transform parent, Color color, Vector2 anchorMin, Vector2 anchorMax, Vector2 offsetMin, Vector2 offsetMax)
    {
        GameObject imageGO = CreateUiObject(name, parent, anchorMin, anchorMax, offsetMin, offsetMax);
        Image image = imageGO.AddComponent<Image>();
        image.color = color;
        return image;
    }

    private static GameObject CreateUiObject(string name, Transform parent, Vector2 anchorMin, Vector2 anchorMax, Vector2 offsetMin, Vector2 offsetMax)
    {
        GameObject go = new GameObject(name, typeof(RectTransform));
        go.transform.SetParent(parent, false);
        RectTransform rect = go.GetComponent<RectTransform>();
        rect.anchorMin = anchorMin;
        rect.anchorMax = anchorMax;
        rect.offsetMin = offsetMin;
        rect.offsetMax = offsetMax;
        rect.localScale = Vector3.one;
        return go;
    }

    private static Material GetTintedUnlitMaterial(string assetPath, Color color, Texture texture)
    {
        Material material = AssetDatabase.LoadAssetAtPath<Material>(assetPath);
        if (material == null)
        {
            material = new Material(Shader.Find("Universal Render Pipeline/Unlit"));
            AssetDatabase.CreateAsset(material, assetPath);
        }

        material.color = color;
        material.mainTexture = texture;
        EditorUtility.SetDirty(material);
        return material;
    }

    private static Material GetOrCreateMaterial(string assetPath, Shader shader)
    {
        Material material = AssetDatabase.LoadAssetAtPath<Material>(assetPath);
        if (material == null)
        {
            material = new Material(shader);
            AssetDatabase.CreateAsset(material, assetPath);
        }

        material.shader = shader;
        EditorUtility.SetDirty(material);
        return material;
    }
}
