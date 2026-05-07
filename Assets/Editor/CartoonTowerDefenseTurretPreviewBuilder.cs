using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class CartoonTowerDefenseTurretPreviewBuilder
{
    private const string RootName = "Cartoon_TD_Turret_Preview";
    private const string OutputFolder = "Assets/Generated/CartoonTurret";
    private const string FlagPath = OutputFolder + "/RunPreview.flag";
    private const string PrefabPath = OutputFolder + "/CartoonTowerDefenseTurret.prefab";
    private const string ScreenshotPath = OutputFolder + "/CartoonTowerDefenseTurret_preview.png";

    [InitializeOnLoadMethod]
    private static void RunRequestedBuild()
    {
        if (!File.Exists(FlagPath))
        {
            return;
        }

        EditorApplication.delayCall += () =>
        {
            if (!File.Exists(FlagPath))
            {
                return;
            }

            File.Delete(FlagPath);
            BuildInCurrentScene();
        };
    }

    [MenuItem("Tools/Generated Assets/Create Cartoon TD Turret Preview")]
    public static void BuildInCurrentScene()
    {
        EnsureFolder(OutputFolder);

        GameObject existing = GameObject.Find(RootName);
        if (existing != null)
        {
            Object.DestroyImmediate(existing);
        }

        Material teal = CreateMaterial("M_Turret_TealMetal", new Color(0.03f, 0.58f, 0.67f), 0.15f, 0.35f);
        Material orange = CreateMaterial("M_Turret_OrangeArmor", new Color(1.0f, 0.58f, 0.13f), 0.05f, 0.42f);
        Material dark = CreateMaterial("M_Turret_DarkRubber", new Color(0.06f, 0.07f, 0.08f), 0f, 0.25f);
        Material trim = CreateMaterial("M_Turret_CreamTrim", new Color(0.95f, 0.87f, 0.61f), 0f, 0.38f);
        Material glow = CreateMaterial("M_Turret_MuzzleGlow", new Color(0.45f, 0.9f, 1.0f), 0f, 0.75f);

        GameObject root = new GameObject(RootName);
        root.transform.position = FindPreviewPosition();
        root.transform.rotation = Quaternion.Euler(0f, 35f, 0f);

        CreateCylinder("Mobile_LowPoly_Base", root.transform, dark, new Vector3(0f, 0.12f, 0f), new Vector3(1.35f, 0.24f, 1.35f));
        CreateCylinder("Orange_Armor_Ring", root.transform, orange, new Vector3(0f, 0.34f, 0f), new Vector3(1.08f, 0.18f, 1.08f));
        CreateCube("Chunky_Rounded_Body", root.transform, orange, new Vector3(0f, 0.72f, 0f), new Vector3(1.06f, 0.62f, 0.9f));
        CreateCube("Cream_Front_Plate", root.transform, trim, new Vector3(0f, 0.74f, 0.48f), new Vector3(0.72f, 0.36f, 0.08f));

        GameObject barrelPivot = new GameObject("Barrel_Pivot");
        barrelPivot.transform.SetParent(root.transform, false);
        barrelPivot.transform.localPosition = new Vector3(0f, 0.82f, 0.48f);
        barrelPivot.transform.localRotation = Quaternion.Euler(-8f, 0f, 0f);

        GameObject barrel = CreateCylinder("Oversized_Teal_Barrel", barrelPivot.transform, teal, new Vector3(0f, 0f, 0.48f), new Vector3(0.34f, 0.82f, 0.34f));
        barrel.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
        GameObject muzzle = CreateCylinder("Soft_Muzzle_Rim", barrelPivot.transform, dark, new Vector3(0f, 0f, 0.94f), new Vector3(0.48f, 0.16f, 0.48f));
        muzzle.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
        GameObject muzzleCore = CreateCylinder("Blue_Muzzle_Core", barrelPivot.transform, glow, new Vector3(0f, 0f, 1.035f), new Vector3(0.27f, 0.035f, 0.27f));
        muzzleCore.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);

        for (int x = -1; x <= 1; x += 2)
        {
            CreateCylinder("Side_Bolt_" + x, root.transform, trim, new Vector3(0.38f * x, 0.88f, 0.54f), new Vector3(0.13f, 0.045f, 0.13f)).transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
            CreateCylinder("Track_Wheel_" + x, root.transform, dark, new Vector3(0.56f * x, 0.22f, 0.34f), new Vector3(0.22f, 0.08f, 0.22f)).transform.localRotation = Quaternion.Euler(0f, 0f, 90f);
            CreateCylinder("Back_Track_Wheel_" + x, root.transform, dark, new Vector3(0.56f * x, 0.22f, -0.34f), new Vector3(0.22f, 0.08f, 0.22f)).transform.localRotation = Quaternion.Euler(0f, 0f, 90f);
        }

        CreateMobileSpecLabel(root.transform);
        AddPreviewLighting(root.transform.position);
        ConfigurePreviewCamera(root.transform.position);

        PrefabUtility.SaveAsPrefabAssetAndConnect(root, PrefabPath, InteractionMode.AutomatedAction);
        EditorSceneManager.MarkSceneDirty(root.scene);
        Selection.activeGameObject = root;
        CapturePreview(root.transform.position);

        Debug.Log("[CartoonTurret] Created mobile-friendly cartoon tower defense turret preview, prefab, materials, and screenshot in " + OutputFolder);
    }

    private static GameObject CreateCube(string name, Transform parent, Material material, Vector3 localPosition, Vector3 localScale)
    {
        GameObject go = GameObject.CreatePrimitive(PrimitiveType.Cube);
        go.name = name;
        go.transform.SetParent(parent, false);
        go.transform.localPosition = localPosition;
        go.transform.localScale = localScale;
        go.GetComponent<MeshRenderer>().sharedMaterial = material;
        return go;
    }

    private static GameObject CreateCylinder(string name, Transform parent, Material material, Vector3 localPosition, Vector3 localScale)
    {
        GameObject go = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        go.name = name;
        go.transform.SetParent(parent, false);
        go.transform.localPosition = localPosition;
        go.transform.localScale = localScale;
        go.GetComponent<MeshRenderer>().sharedMaterial = material;
        return go;
    }

    private static void CreateMobileSpecLabel(Transform parent)
    {
        GameObject label = new GameObject("Mobile_Game_Params");
        label.transform.SetParent(parent, false);
        label.transform.localPosition = new Vector3(0f, 1.55f, -0.35f);
        TextMesh text = label.AddComponent<TextMesh>();
        text.text = "Mobile TD Turret\nPrefab + 5 shared materials\nSimple colliders, readable silhouette";
        text.anchor = TextAnchor.MiddleCenter;
        text.alignment = TextAlignment.Center;
        text.characterSize = 0.08f;
        text.color = new Color(0.18f, 0.2f, 0.22f);
    }

    private static Material CreateMaterial(string name, Color color, float metallic, float smoothness)
    {
        string path = OutputFolder + "/" + name + ".mat";
        Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (material != null)
        {
            return material;
        }

        Shader shader = Shader.Find("Universal Render Pipeline/Lit");
        if (shader == null)
        {
            shader = Shader.Find("Standard");
        }

        material = new Material(shader) { name = name };
        SetColor(material, color);
        if (material.HasProperty("_Metallic"))
        {
            material.SetFloat("_Metallic", metallic);
        }
        if (material.HasProperty("_Smoothness"))
        {
            material.SetFloat("_Smoothness", smoothness);
        }
        AssetDatabase.CreateAsset(material, path);
        return material;
    }

    private static void SetColor(Material material, Color color)
    {
        if (material.HasProperty("_BaseColor"))
        {
            material.SetColor("_BaseColor", color);
        }
        else if (material.HasProperty("_Color"))
        {
            material.SetColor("_Color", color);
        }
    }

    private static Vector3 FindPreviewPosition()
    {
        Camera camera = Camera.main;
        if (camera == null)
        {
            return Vector3.zero;
        }

        return camera.transform.position + camera.transform.forward * 4f + Vector3.down * 0.35f;
    }

    private static void AddPreviewLighting(Vector3 target)
    {
        if (GameObject.Find("Cartoon_Turret_Key_Light") == null)
        {
            GameObject lightObject = new GameObject("Cartoon_Turret_Key_Light");
            Light light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = new Color(1f, 0.92f, 0.78f);
            light.intensity = 1.65f;
            light.transform.rotation = Quaternion.Euler(45f, -35f, 0f);
        }

        if (GameObject.Find("Cartoon_Turret_Fill_Light") == null)
        {
            GameObject fillObject = new GameObject("Cartoon_Turret_Fill_Light");
            Light fill = fillObject.AddComponent<Light>();
            fill.type = LightType.Point;
            fill.color = new Color(0.55f, 0.8f, 1f);
            fill.intensity = 4f;
            fill.range = 5f;
            fill.transform.position = target + new Vector3(-2f, 2f, -2f);
        }
    }

    private static void ConfigurePreviewCamera(Vector3 target)
    {
        Camera camera = Camera.main;
        if (camera == null)
        {
            GameObject cameraObject = new GameObject("Main Camera");
            cameraObject.tag = "MainCamera";
            camera = cameraObject.AddComponent<Camera>();
        }

        camera.transform.position = target + new Vector3(2.4f, 1.55f, -3.0f);
        camera.transform.LookAt(target + new Vector3(0f, 0.65f, 0f));
        camera.fieldOfView = 36f;
        camera.nearClipPlane = 0.05f;
        camera.farClipPlane = 100f;
        camera.clearFlags = CameraClearFlags.Skybox;
    }

    private static void CapturePreview(Vector3 target)
    {
        Camera camera = Camera.main;
        if (camera == null)
        {
            return;
        }

        RenderTexture previous = camera.targetTexture;
        RenderTexture texture = new RenderTexture(1080, 1080, 24, RenderTextureFormat.ARGB32);
        Texture2D image = new Texture2D(1080, 1080, TextureFormat.RGBA32, false);

        camera.targetTexture = texture;
        camera.transform.position = target + new Vector3(2.4f, 1.55f, -3.0f);
        camera.transform.LookAt(target + new Vector3(0f, 0.65f, 0f));
        camera.Render();

        RenderTexture.active = texture;
        image.ReadPixels(new Rect(0, 0, texture.width, texture.height), 0, 0);
        image.Apply();
        File.WriteAllBytes(ScreenshotPath, image.EncodeToPNG());

        camera.targetTexture = previous;
        RenderTexture.active = null;
        Object.DestroyImmediate(image);
        Object.DestroyImmediate(texture);
        AssetDatabase.ImportAsset(ScreenshotPath);
    }

    private static void EnsureFolder(string path)
    {
        if (AssetDatabase.IsValidFolder(path))
        {
            return;
        }

        string parent = Path.GetDirectoryName(path)?.Replace('\\', '/');
        string name = Path.GetFileName(path);
        if (!string.IsNullOrEmpty(parent))
        {
            EnsureFolder(parent);
        }
        AssetDatabase.CreateFolder(parent, name);
    }
}
