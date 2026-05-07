using System;
using System.IO;
using System.Reflection;
using OpenClaw.BlenderGeometryNodes;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class OpenClawBlenderGNPackageSceneSetup
{
    private const string ScenePath = "Assets/Samples/OpenClaw Blender Geometry Nodes Runtime/0.1.0/Runtime Scene/Blender_GeometryNodes_Runtime.unity";
    private const string MaterialPath = "Assets/Samples/OpenClaw Blender Geometry Nodes Runtime/0.1.0/Runtime Scene/Materials/Blender_GN_Runtime_Armor.mat";
    private const string BlendRelativePath = "output/blender/scifi_hex_sphere_with_nodes.blend";
    private const string ObjectName = "Outer_Shell_Hex_Armor_GN";
    private const string ModifierName = "Geometry Nodes - Dual Mesh Hex Armor";

    [MenuItem("Tools/OpenClaw/Blender Geometry Nodes/Replace Current Scene With Package Runtime")]
    public static void ReplaceCurrentSceneWithPackageRuntime()
    {
        ReplaceScene(false);
    }

    public static void ReplaceAndDebugSceneBatch()
    {
        ReplaceScene(true);
    }

    private static void ReplaceScene(bool runDebugRefresh)
    {
        EnsureFolder("Assets/Samples");
        EnsureFolder("Assets/Samples/OpenClaw Blender Geometry Nodes Runtime");
        EnsureFolder("Assets/Samples/OpenClaw Blender Geometry Nodes Runtime/0.1.0");
        EnsureFolder("Assets/Samples/OpenClaw Blender Geometry Nodes Runtime/0.1.0/Runtime Scene");
        EnsureFolder("Assets/Samples/OpenClaw Blender Geometry Nodes Runtime/0.1.0/Runtime Scene/Materials");
        EnsureBlenderSidecarInstalled();

        Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        scene.name = "Blender_GeometryNodes_Runtime";

        Material material = CreateMaterial(MaterialPath);
        BlenderGeometryNodesRuntime runner = CreateRunner(material);
        BlenderGeometryNodesUnityMotion motion = runner.GetComponent<BlenderGeometryNodesUnityMotion>();
        CreateRuntimeUi(runner, motion);
        CreateLighting();
        CreateCamera();

        if (runDebugRefresh)
            DebugRefresh(runner);

        EditorSceneManager.SaveScene(scene, ScenePath);
        AssetDatabase.Refresh();
        Selection.activeObject = runner;
        Debug.Log($"[OpenClawGN] Replaced scene with package runtime: {ScenePath}");
    }

    private static BlenderGeometryNodesRuntime CreateRunner(Material material)
    {
        var go = new GameObject("Blender_GeometryNodes_Runtime_Runner");
        go.AddComponent<MeshFilter>();
        MeshRenderer renderer = go.AddComponent<MeshRenderer>();
        renderer.sharedMaterial = material;

        BlenderGeometryNodesRuntime runner = go.AddComponent<BlenderGeometryNodesRuntime>();
        go.AddComponent<BlenderGeometryNodesUnityMotion>();

        var serialized = new SerializedObject(runner);
        serialized.FindProperty("blenderPath").stringValue = FindBlenderPath();
        serialized.FindProperty("blendFile").stringValue = Path.GetFullPath(BlendRelativePath);
        serialized.FindProperty("objectName").stringValue = ObjectName;
        serialized.FindProperty("modifierName").stringValue = ModifierName;
        serialized.FindProperty("blenderScriptPath").stringValue = "BlenderGeometryNodesRuntime/unity_gn_eval.py";
        serialized.FindProperty("blenderTimeoutSeconds").intValue = 45;
        serialized.FindProperty("fallbackMaterial").objectReferenceValue = material;
        serialized.FindProperty("refreshMode").enumValueIndex = (int)BlenderGeometryNodesRuntime.RefreshMode.Manual;
        serialized.FindProperty("fixedRefreshInterval").floatValue = 0.45f;
        serialized.FindProperty("refreshOnEnable").boolValue = false;
        serialized.ApplyModifiedPropertiesWithoutUndo();

        return runner;
    }

    private static void CreateRuntimeUi(BlenderGeometryNodesRuntime runner, BlenderGeometryNodesUnityMotion motion)
    {
        var ui = new GameObject("Blender_GN_Runtime_UI");
        BlenderGeometryNodesRuntimePanel panel = ui.AddComponent<BlenderGeometryNodesRuntimePanel>();
        var serialized = new SerializedObject(panel);
        serialized.FindProperty("target").objectReferenceValue = runner;
        serialized.FindProperty("unityMotion").objectReferenceValue = motion;
        serialized.FindProperty("liveUnityMotion").boolValue = true;
        serialized.FindProperty("liveBlenderRebuild").boolValue = true;
        serialized.FindProperty("rebuildDebounceSeconds").floatValue = 0.45f;
        serialized.FindProperty("blenderFrameRate").floatValue = 24f;
        serialized.ApplyModifiedPropertiesWithoutUndo();
    }

    private static void DebugRefresh(BlenderGeometryNodesRuntime runner)
    {
        runner.RefreshNow();
        MethodInfo pump = typeof(BlenderGeometryNodesRuntime).GetMethod(
            "PumpCompletedRefresh",
            BindingFlags.Instance | BindingFlags.NonPublic);

        double start = EditorApplication.timeSinceStartup;
        while (runner.IsRunning && EditorApplication.timeSinceStartup - start < runner.BlenderTimeoutSeconds + 10)
        {
            pump?.Invoke(runner, null);
            System.Threading.Thread.Sleep(50);
        }

        pump?.Invoke(runner, null);

        if (runner.IsRunning)
            throw new TimeoutException("Blender Geometry Nodes debug refresh did not finish.");
        if (runner.LastVertexCount <= 0 || runner.LastTriangleCount <= 0)
            throw new InvalidOperationException("Blender Geometry Nodes debug refresh did not produce a mesh. Status: " + runner.LastStatus);

        Debug.Log($"[OpenClawGN] Debug refresh succeeded: {runner.LastVertexCount} verts / {runner.LastTriangleCount} tris in {runner.LastEvaluationSeconds:0.00}s");
    }

    private static void EnsureBlenderSidecarInstalled()
    {
        EnsureFolder("Assets/StreamingAssets");
        EnsureFolder("Assets/StreamingAssets/BlenderGeometryNodesRuntime");

        string packageScript = "Packages/com.openclaw.blender-geometry-nodes-runtime/Blender~/unity_gn_eval.py";
        string targetScript = "Assets/StreamingAssets/BlenderGeometryNodesRuntime/unity_gn_eval.py";
        File.Copy(packageScript, targetScript, true);
        AssetDatabase.ImportAsset(targetScript);
    }

    private static void CreateLighting()
    {
        var light = new GameObject("Area_Key_Light");
        Light area = light.AddComponent<Light>();
        area.type = LightType.Rectangle;
        area.intensity = 450f;
        area.color = new Color(0.62f, 0.82f, 1f);
        area.transform.position = new Vector3(-2.5f, 2.5f, -3f);
        area.transform.rotation = Quaternion.Euler(42f, -35f, 0f);
    }

    private static void CreateCamera()
    {
        var cameraObject = new GameObject("Camera");
        Camera camera = cameraObject.AddComponent<Camera>();
        cameraObject.tag = "MainCamera";
        camera.transform.position = new Vector3(0f, 0.3f, -4.8f);
        camera.transform.rotation = Quaternion.Euler(4f, 0f, 0f);
        camera.fieldOfView = 35f;
    }

    private static Material CreateMaterial(string path)
    {
        Material existing = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (existing != null)
            return existing;

        Shader shader = Shader.Find("Universal Render Pipeline/Lit");
        if (shader == null)
            shader = Shader.Find("Standard");

        var material = new Material(shader)
        {
            name = Path.GetFileNameWithoutExtension(path)
        };
        material.SetColor("_BaseColor", new Color(0.05f, 0.075f, 0.085f, 1f));
        if (material.HasProperty("_Metallic"))
            material.SetFloat("_Metallic", 0.9f);
        if (material.HasProperty("_Smoothness"))
            material.SetFloat("_Smoothness", 0.65f);
        AssetDatabase.CreateAsset(material, path);
        return material;
    }

    private static string FindBlenderPath()
    {
        string[] candidates =
        {
            @"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
            @"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe",
            @"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe",
            @"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe"
        };

        foreach (string candidate in candidates)
        {
            if (File.Exists(candidate))
                return candidate;
        }

        return string.Empty;
    }

    private static void EnsureFolder(string path)
    {
        if (AssetDatabase.IsValidFolder(path))
            return;

        string parent = Path.GetDirectoryName(path)?.Replace('\\', '/');
        string name = Path.GetFileName(path);
        if (!string.IsNullOrEmpty(parent))
            EnsureFolder(parent);
        AssetDatabase.CreateFolder(parent, name);
    }
}
