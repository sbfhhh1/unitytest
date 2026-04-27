// Disabled temporarily because this editor-only builder currently fails compilation
// and blocks unrelated asset/script imports in the project.
#if false
using System;
using System.Collections;
using System.Reflection;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using UnityEngine.VFX;

public static class BuildRedCubeWallVFX
{
    private const string Root = "Assets/VFX/RedCubeWall";
    private const string ScenePath = Root + "/RedCubeWallScene.unity";
    private const string TempGraphPath = Root + "/~RedCubeWallGraph.asset";
    private const string VfxPath = Root + "/RedCubeWall.vfx";
    private const string CubeMeshPath = Root + "/RedCubeWall_CubeMesh.asset";
    private const string CubeMatPath = Root + "/Materials/RedCubeWall_Cubes.mat";
    private const string BackplateMatPath = Root + "/Materials/RedCubeWall_Backplate.mat";
    private const string VolumeProfilePath = Root + "/RedCubeWall_AudioReactiveVolume.asset";
    private const string DefaultAudioPath = "Assets/ShaderCourse/audiopapkin-ambient-soundscapes-007-space-atmosphere-304974.mp3";

    [MenuItem("Tools/VFX/Build Red Cube Wall From Scratch", false, 20)]
    public static void BuildAll()
    {
        EnsureFolders();
        Mesh cubeMesh = CreateCubeMesh();
        Material cubeMaterial = CreateMaterial(CubeMatPath, new Color(0.72f, 0.08f, 0.035f, 1f), 0.56f, 0.05f, true);
        Material backplateMaterial = CreateMaterial(BackplateMatPath, new Color(0.16f, 0.018f, 0.02f, 1f), 0.42f, 0.02f, false);
        VolumeProfile volumeProfile = CreateVolumeProfile();
        AudioClip audioClip = AssetDatabase.LoadAssetAtPath<AudioClip>(DefaultAudioPath);
        VisualEffectAsset vfxAsset = BuildVfxGraph();
        BuildScene(cubeMesh, cubeMaterial, backplateMaterial, volumeProfile, vfxAsset, audioClip);

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        Debug.Log("[RedCubeWall] Built fresh scene and VFX assets at " + Root);
    }

    private static void EnsureFolders()
    {
        EnsureFolder("Assets", "VFX");
        EnsureFolder("Assets/VFX", "RedCubeWall");
        EnsureFolder(Root, "Materials");
        EnsureFolder(Root, "Editor");
        EnsureFolder(Root, "Scripts");
    }

    private static void EnsureFolder(string parent, string child)
    {
        string path = parent + "/" + child;
        if (!AssetDatabase.IsValidFolder(path))
        {
            AssetDatabase.CreateFolder(parent, child);
        }
    }

    private static Mesh CreateCubeMesh()
    {
        Mesh existing = AssetDatabase.LoadAssetAtPath<Mesh>(CubeMeshPath);
        if (existing != null)
        {
            return existing;
        }

        var mesh = new Mesh { name = "RedCubeWall_CubeMesh" };
        Vector3[] vertices =
        {
            new(-0.5f,-0.5f,-0.5f), new(0.5f,-0.5f,-0.5f), new(0.5f,0.5f,-0.5f), new(-0.5f,0.5f,-0.5f),
            new(-0.5f,-0.5f,0.5f), new(0.5f,-0.5f,0.5f), new(0.5f,0.5f,0.5f), new(-0.5f,0.5f,0.5f),
            new(-0.5f,-0.5f,-0.5f), new(-0.5f,0.5f,-0.5f), new(-0.5f,0.5f,0.5f), new(-0.5f,-0.5f,0.5f),
            new(0.5f,-0.5f,-0.5f), new(0.5f,0.5f,-0.5f), new(0.5f,0.5f,0.5f), new(0.5f,-0.5f,0.5f),
            new(-0.5f,0.5f,-0.5f), new(0.5f,0.5f,-0.5f), new(0.5f,0.5f,0.5f), new(-0.5f,0.5f,0.5f),
            new(-0.5f,-0.5f,-0.5f), new(0.5f,-0.5f,-0.5f), new(0.5f,-0.5f,0.5f), new(-0.5f,-0.5f,0.5f)
        };
        int[] triangles =
        {
            0,2,1, 0,3,2, 4,5,6, 4,6,7, 8,10,9, 8,11,10,
            12,13,14, 12,14,15, 16,18,17, 16,19,18, 20,21,22, 20,22,23
        };
        Vector3[] normals =
        {
            Vector3.back,Vector3.back,Vector3.back,Vector3.back,
            Vector3.forward,Vector3.forward,Vector3.forward,Vector3.forward,
            Vector3.left,Vector3.left,Vector3.left,Vector3.left,
            Vector3.right,Vector3.right,Vector3.right,Vector3.right,
            Vector3.up,Vector3.up,Vector3.up,Vector3.up,
            Vector3.down,Vector3.down,Vector3.down,Vector3.down
        };
        mesh.SetVertices(vertices);
        mesh.SetTriangles(triangles, 0);
        mesh.SetNormals(normals);
        mesh.RecalculateBounds();
        AssetDatabase.CreateAsset(mesh, CubeMeshPath);
        return mesh;
    }

    private static Material CreateMaterial(string path, Color color, float smoothness, float metallic, bool emission)
    {
        Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (material == null)
        {
            material = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            AssetDatabase.CreateAsset(material, path);
        }

        material.name = System.IO.Path.GetFileNameWithoutExtension(path);
        material.SetColor("_BaseColor", color);
        material.SetFloat("_Smoothness", smoothness);
        material.SetFloat("_Metallic", metallic);
        if (emission)
        {
            material.EnableKeyword("_EMISSION");
            material.SetColor("_EmissionColor", color * 0.35f);
        }
        else
        {
            material.DisableKeyword("_EMISSION");
            material.SetColor("_EmissionColor", Color.black);
        }
        EditorUtility.SetDirty(material);
        return material;
    }

    private static VolumeProfile CreateVolumeProfile()
    {
        VolumeProfile profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(VolumeProfilePath);
        if (profile == null)
        {
            profile = ScriptableObject.CreateInstance<VolumeProfile>();
            profile.name = "RedCubeWall_AudioReactiveVolume";
            AssetDatabase.CreateAsset(profile, VolumeProfilePath);
        }

        if (!profile.TryGet(out Bloom bloom))
        {
            bloom = profile.Add<Bloom>(true);
        }
        bloom.active = true;
        bloom.intensity.Override(0.78f);
        bloom.threshold.Override(0.72f);
        bloom.scatter.Override(0.58f);
        bloom.tint.Override(new Color(1f, 0.32f, 0.16f, 1f));

        if (!profile.TryGet(out Vignette vignette))
        {
            vignette = profile.Add<Vignette>(true);
        }
        vignette.active = true;
        vignette.intensity.Override(0.28f);
        vignette.smoothness.Override(0.62f);
        vignette.color.Override(new Color(0.1f, 0f, 0.01f, 1f));

        if (!profile.TryGet(out ColorAdjustments color))
        {
            color = profile.Add<ColorAdjustments>(true);
        }
        color.active = true;
        color.postExposure.Override(-0.25f);
        color.contrast.Override(18f);
        color.saturation.Override(16f);
        color.colorFilter.Override(new Color(1f, 0.82f, 0.74f, 1f));

        if (!profile.TryGet(out Tonemapping tonemapping))
        {
            tonemapping = profile.Add<Tonemapping>(true);
        }
        tonemapping.active = true;
        tonemapping.mode.Override(TonemappingMode.ACES);

        EditorUtility.SetDirty(profile);
        return profile;
    }

    private static VisualEffectAsset BuildVfxGraph()
    {
        AssetDatabase.DeleteAsset(TempGraphPath);
        AssetDatabase.DeleteAsset(VfxPath);

        Type graphType = Type.GetType("UnityEditor.VFX.VFXGraph, Unity.VisualEffectGraph.Editor");
        Type modelType = Type.GetType("UnityEditor.VFX.VFXModel, Unity.VisualEffectGraph.Editor");
        Type contextType = Type.GetType("UnityEditor.VFX.VFXContext, Unity.VisualEffectGraph.Editor");
        Type slotType = Type.GetType("UnityEditor.VFX.VFXSlot, Unity.VisualEffectGraph.Editor");
        Type libraryType = Type.GetType("UnityEditor.VFX.VFXLibrary, Unity.VisualEffectGraph.Editor");

        if (graphType == null || modelType == null || contextType == null || slotType == null || libraryType == null)
        {
            Debug.LogWarning("[RedCubeWall] VFX Graph editor API unavailable. Scene will still be built with the same generated cube layout.");
            return null;
        }

        var graph = ScriptableObject.CreateInstance(graphType);
        graph.name = "RedCubeWall";
        AssetDatabase.CreateAsset(graph, TempGraphPath);

        IEnumerable contexts = libraryType.GetMethod("GetContexts")?.Invoke(null, null) as IEnumerable;
        IEnumerable blocks = libraryType.GetMethod("GetBlocks")?.Invoke(null, null) as IEnumerable;
        IEnumerable parameters = libraryType.GetMethod("GetParameters")?.Invoke(null, null) as IEnumerable;
        MethodInfo addChild = graphType.GetMethod("AddChild", new[] { modelType, typeof(int), typeof(bool) });
        MethodInfo linkTo = contextType.GetMethod("LinkTo", new[] { contextType, typeof(int), typeof(int) });
        MethodInfo linkSlot = slotType.GetMethod("Link", new[] { slotType, typeof(bool) });

        object spawn = AddModel(contexts, "Spawn", graph, graph, addChild);
        object init = AddModel(contexts, "Initialize Particle", graph, graph, addChild);
        object update = AddModel(contexts, "Update Particle", graph, graph, addChild);
        object output = AddModel(contexts, "Output Particle|URP Lit|Mesh", graph, graph, addChild);

        linkTo.Invoke(spawn, new[] { init, 0, 0 });
        linkTo.Invoke(init, new[] { update, 0, 0 });
        linkTo.Invoke(update, new[] { output, 0, 0 });

        object burst = AddModel(blocks, "Single Burst", spawn, graph, addChild);
        object position = AddModel(blocks, "|Set|_Position Sequential|Three Dimensional", init, graph, addChild);
        object lifetime = AddModel(blocks, "|Set|_Lifetime", init, graph, addChild);
        object scale = AddModel(blocks, "|Set|_Scale from Map|2D", update, graph, addChild);
        object color = AddModel(blocks, "|Set|_Color from Map|2D", update, graph, addChild);

        SetField(scale, "attribute", "scale");
        SetField(color, "attribute", "color");
        SetEnum(position, "shape", 2);
        SetEnum(position, "mode", 1);

        object columns = CreateParam(parameters, graph, addChild, "Columns", "Uint");
        object rows = CreateParam(parameters, graph, addChild, "Rows", "Uint");
        object spacingX = CreateParam(parameters, graph, addChild, "SpacingX", "Float");
        object spacingY = CreateParam(parameters, graph, addChild, "SpacingY", "Float");
        object breath = CreateParam(parameters, graph, addChild, "BreathAmplitude", "Float");
        object audioLevel = CreateParam(parameters, graph, addChild, "AudioLevel", "Float");
        object gap = CreateParam(parameters, graph, addChild, "Gap", "Float");
        object particleCount = CreateParam(parameters, graph, addChild, "ParticleCount", "Uint");

        LinkParamToInput(particleCount, burst, "Count", linkSlot);
        LinkParamToInput(columns, position, "CountX", linkSlot);
        LinkParamToInput(rows, position, "CountY", linkSlot);
        LinkParamToInput(spacingX, position, "Spacing", linkSlot);
        LinkParamToInput(breath, scale, "valueScale", linkSlot);
        LinkParamToInput(audioLevel, color, "valueScale", linkSlot);
        _ = spacingY;
        _ = lifetime;
        _ = gap;

        EditorUtility.SetDirty(graph);
        AssetDatabase.SaveAssets();
        ConvertTempGraphToVfx();
        AssetDatabase.ImportAsset(VfxPath, ImportAssetOptions.ForceUpdate);
        return AssetDatabase.LoadAssetAtPath<VisualEffectAsset>(VfxPath);
    }

    private static object AddModel(IEnumerable descriptors, string name, object parent, UnityEngine.Object graph, MethodInfo addChild)
    {
        object model = CreateFromLibrary(descriptors, name);
        if (model == null)
        {
            throw new InvalidOperationException("VFX model not found: " + name);
        }

        AssetDatabase.AddObjectToAsset((UnityEngine.Object)model, graph);
        addChild.Invoke(parent, new[] { model, 0, true });
        AddSlotsToAsset(model, graph);
        return model;
    }

    private static object CreateFromLibrary(IEnumerable descriptors, string name)
    {
        foreach (object descriptor in descriptors)
        {
            string descriptorName = descriptor.GetType().GetProperty("name")?.GetValue(descriptor, null) as string;
            if (descriptorName == name)
            {
                return descriptor.GetType().GetMethod("CreateInstance")?.Invoke(descriptor, null);
            }
        }
        return null;
    }

    private static void AddSlotsToAsset(object model, UnityEngine.Object graph)
    {
        AddSlotList(model, "inputSlots", graph);
        AddSlotList(model, "outputSlots", graph);
    }

    private static void AddSlotList(object model, string propertyName, UnityEngine.Object graph)
    {
        IEnumerable slots = model.GetType().GetProperty(propertyName, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)?.GetValue(model, null) as IEnumerable;
        if (slots == null)
        {
            return;
        }

        foreach (object slot in slots)
        {
            if (slot is UnityEngine.Object unityObject)
            {
                AssetDatabase.AddObjectToAsset(unityObject, graph);
            }
        }
    }

    private static object CreateParam(IEnumerable descriptors, UnityEngine.Object graph, MethodInfo addChild, string exposedName, string typeName)
    {
        object param = CreateFromLibrary(descriptors, typeName);
        if (param == null)
        {
            return null;
        }

        AssetDatabase.AddObjectToAsset((UnityEngine.Object)param, graph);
        SetField(param, "m_ExposedName", exposedName);
        SetField(param, "m_Exposed", true);
        AddExprSlotsToAsset(param, graph);
        addChild.Invoke(graph, new[] { param, 0, true });
        return param;
    }

    private static void AddExprSlotsToAsset(object param, UnityEngine.Object graph)
    {
        Array slots = param.GetType().GetField("m_ExprSlots", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)?.GetValue(param) as Array;
        if (slots == null)
        {
            return;
        }

        foreach (object slot in slots)
        {
            if (slot is UnityEngine.Object unityObject)
            {
                AssetDatabase.AddObjectToAsset(unityObject, graph);
            }
        }
    }

    private static void LinkParamToInput(object param, object target, string inputName, MethodInfo linkSlot)
    {
        if (param == null || target == null || linkSlot == null)
        {
            return;
        }

        Array exprSlots = param.GetType().GetField("m_ExprSlots", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)?.GetValue(param) as Array;
        if (exprSlots == null || exprSlots.Length == 0)
        {
            return;
        }

        object outputSlot = exprSlots.GetValue(0);
        IEnumerable inputSlots = target.GetType().GetProperty("inputSlots", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)?.GetValue(target, null) as IEnumerable;
        if (inputSlots == null)
        {
            return;
        }

        foreach (object inputSlot in inputSlots)
        {
            string slotName = inputSlot.GetType().GetProperty("name", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)?.GetValue(inputSlot, null) as string;
            if (slotName == inputName)
            {
                linkSlot.Invoke(outputSlot, new[] { inputSlot, true });
                return;
            }
        }
    }

    private static void SetField(object target, string fieldName, object value)
    {
        FieldInfo field = target?.GetType().GetField(fieldName, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (field != null)
        {
            field.SetValue(target, value);
        }
    }

    private static void SetEnum(object target, string fieldName, int value)
    {
        FieldInfo field = target?.GetType().GetField(fieldName, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (field != null && field.FieldType.IsEnum)
        {
            field.SetValue(target, Enum.ToObject(field.FieldType, value));
        }
    }

    private static void ConvertTempGraphToVfx()
    {
        string sourcePath = System.IO.Path.Combine(Application.dataPath, "VFX/RedCubeWall/~RedCubeWallGraph.asset");
        string targetPath = System.IO.Path.Combine(Application.dataPath, "VFX/RedCubeWall/RedCubeWall.vfx");
        string yaml = System.IO.File.ReadAllText(sourcePath);

        Match graphId = Regex.Match(yaml, @"--- !u!114 &(-?\d+)\nMonoBehaviour:\n  m_ObjectHideFlags: \d+\n  m_CorrespondingSourceObject: \{fileID: 0\}\n  m_PrefabInstance: \{fileID: 0\}\n  m_PrefabAsset: \{fileID: 0\}\n  m_GameObject: \{fileID: 0\}\n  m_Enabled: 1\n  m_EditorHideFlags: 0\n  m_Script: \{fileID: 11500000, guid: 7d4c867f6b72b714dbb5fd1780afe208, type: 3\}");
        string fileId = graphId.Success ? graphId.Groups[1].Value : "11400000";

        yaml = yaml.Replace("m_Name: ~RedCubeWallGraph", "m_Name: RedCubeWall");
        yaml = yaml.Replace("m_ResourceVersion: 0", "m_ResourceVersion: 1");
        yaml = yaml.Replace("m_UIInfos: {fileID: 0}", "m_UIInfos: {fileID: 11400002}");
        yaml += "\n\n--- !u!114 &11400002\nMonoBehaviour:\n  m_ObjectHideFlags: 1\n  m_CorrespondingSourceObject: {fileID: 0}\n  m_PrefabInstance: {fileID: 0}\n  m_PrefabAsset: {fileID: 0}\n  m_GameObject: {fileID: 0}\n  m_Enabled: 1\n  m_EditorHideFlags: 0\n  m_Script: {fileID: 11500000, guid: d01270efd3285ea4a9d6c555cb0a8027, type: 3}\n  m_Name: VFXUI\n  m_EditorClassIdentifier:\n  groupInfos: []\n  stickyNoteInfos: []\n\n--- !u!2058629511 &11400001\nVisualEffectResource:\n  m_ObjectHideFlags: 0\n  m_CorrespondingSourceObject: {fileID: 0}\n  m_PrefabInstance: {fileID: 0}\n  m_PrefabAsset: {fileID: 0}\n  m_GameObject: {fileID: 0}\n  m_Enabled: 1\n  m_EditorHideFlags: 0\n  m_Name: RedCubeWall\n  m_Graph: {fileID: " + fileId + @"}
  m_Infos:
    m_RendererSettings:
      motionVectorGenerationMode: 1
      shadowCastingMode: 1
    m_CullingFlags: 3
    m_UpdateMode: 0
    m_PreWarmDeltaTime: 0.05
    m_PreWarmStepCount: 8
    m_InitialEventName: OnPlay
    m_InstancingMode: 0
    m_InstancingCapacity: 256
";

        System.IO.File.WriteAllText(targetPath, yaml);
        AssetDatabase.DeleteAsset(TempGraphPath);
    }

    private static void BuildScene(Mesh cubeMesh, Material cubeMaterial, Material backplateMaterial, VolumeProfile volumeProfile, VisualEffectAsset vfxAsset, AudioClip audioClip)
    {
        Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        scene.name = "RedCubeWallScene";
        RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
        RenderSettings.ambientLight = new Color(0.045f, 0.006f, 0.008f, 1f);
        RenderSettings.fog = true;
        RenderSettings.fogMode = FogMode.ExponentialSquared;
        RenderSettings.fogColor = new Color(0.11f, 0.008f, 0.012f, 1f);
        RenderSettings.fogDensity = 0.018f;

        var backplate = GameObject.CreatePrimitive(PrimitiveType.Cube);
        backplate.name = "RedCubeWall_Backplate";
        backplate.transform.position = new Vector3(0f, 0f, 0.12f);
        backplate.transform.localScale = new Vector3(10.2f, 5.95f, 0.08f);
        var backplateRenderer = backplate.GetComponent<MeshRenderer>();
        backplateRenderer.sharedMaterial = backplateMaterial;
        backplateRenderer.receiveShadows = true;

        var audioObject = new GameObject("RedCubeWall_Audio");
        var audioSource = audioObject.AddComponent<AudioSource>();
        audioSource.clip = audioClip;
        audioSource.loop = true;
        audioSource.playOnAwake = true;
        audioSource.volume = 0.72f;
        audioSource.spatialBlend = 0f;

        var vfxObject = new GameObject("RedCubeWall_VFX");
        var visualEffect = vfxObject.AddComponent<VisualEffect>();
        if (vfxAsset != null)
        {
            visualEffect.visualEffectAsset = vfxAsset;
        }
        visualEffect.SetUInt("Columns", 16);
        visualEffect.SetUInt("Rows", 9);
        visualEffect.SetUInt("ParticleCount", 144);
        visualEffect.SetFloat("SpacingX", 0.54f);
        visualEffect.SetFloat("SpacingY", 0.54f);
        visualEffect.SetFloat("BreathAmplitude", 0.04f);
        visualEffect.SetFloat("AudioLevel", 0f);
        visualEffect.SetFloat("Gap", 0.08f);
        visualEffect.Reinit();

        var cubesRoot = new GameObject("RedCubeWall_PreviewCubes").transform;
        cubesRoot.position = Vector3.zero;

        var controller = vfxObject.AddComponent<RedCubeWallPreview>();
        controller.Configure(cubesRoot, cubeMesh, cubeMaterial, visualEffect, audioSource);

        var keyLight = new GameObject("Key Light").AddComponent<Light>();
        keyLight.type = LightType.Directional;
        keyLight.intensity = 2.15f;
        keyLight.color = new Color(1f, 0.68f, 0.52f);
        keyLight.transform.rotation = Quaternion.Euler(44f, -36f, 0f);

        var fill = new GameObject("Low Red Fill").AddComponent<Light>();
        fill.type = LightType.Point;
        fill.intensity = 2.6f;
        fill.range = 7.5f;
        fill.color = new Color(1f, 0.06f, 0.36f);
        fill.transform.position = new Vector3(-3.9f, -2.35f, -1.6f);

        var rim = new GameObject("Magenta Rim").AddComponent<Light>();
        rim.type = LightType.Point;
        rim.intensity = 3.4f;
        rim.range = 6.2f;
        rim.color = new Color(1f, 0.08f, 0.64f);
        rim.transform.position = new Vector3(4.2f, 2.65f, -2.7f);

        var volumeObject = new GameObject("RedCubeWall_GlobalVolume");
        var volume = volumeObject.AddComponent<Volume>();
        volume.isGlobal = true;
        volume.priority = 1f;
        volume.profile = volumeProfile;

        var cameraObject = new GameObject("Main Camera");
        var camera = cameraObject.AddComponent<Camera>();
        camera.tag = "MainCamera";
        camera.orthographic = true;
        camera.orthographicSize = 3.2f;
        camera.nearClipPlane = 0.1f;
        camera.farClipPlane = 80f;
        camera.backgroundColor = new Color(0.08f, 0.004f, 0.008f);
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.transform.position = new Vector3(1.0f, 0.38f, -8.4f);
        camera.transform.LookAt(new Vector3(0f, -0.04f, -0.38f), Vector3.up);
        var cameraData = cameraObject.AddComponent<UniversalAdditionalCameraData>();
        cameraData.renderPostProcessing = true;
        cameraData.antialiasing = AntialiasingMode.FastApproximateAntialiasing;
        cameraObject.AddComponent<AudioListener>();

        EditorSceneManager.SaveScene(scene, ScenePath);
    }
}
#endif
