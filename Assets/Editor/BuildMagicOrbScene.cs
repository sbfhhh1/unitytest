using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text.RegularExpressions;
using MagicOrbVfx;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.VFX;

public static class BuildMagicOrbScene
{
    private const string RootFolder = "Assets/VFX/MagicOrb";
    private const string TempGraphPath = RootFolder + "/~MagicOrbGraph.asset";
    private const string VfxPath = RootFolder + "/MagicOrb.vfx";
    private const string ScenePath = RootFolder + "/MagicOrb_TestScene.unity";
    private const string VolumeProfilePath = RootFolder + "/MagicOrb_VolumeProfile.asset";

    private static Type graphType;
    private static Type modelType;
    private static Type contextType;
    private static Type slotType;
    private static Type libraryType;
    private static MethodInfo addChildMethod;
    private static MethodInfo linkContextMethod;
    private static MethodInfo linkSlotMethod;
    private static ScriptableObject graph;

    [MenuItem("VFX/Build Magic Orb Scene")]
    public static void Build()
    {
        EnsureFolders();
        VisualEffectAsset vfxAsset = BuildVfxAsset();
        VolumeProfile volumeProfile = CreateVolumeProfile();
        BuildScene(vfxAsset, volumeProfile);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        Debug.Log($"Magic Orb scene built: {ScenePath}");
    }

    private static void EnsureFolders()
    {
        EnsureFolder("Assets", "VFX");
        EnsureFolder("Assets/VFX", "MagicOrb");
        EnsureFolder(RootFolder, "Scripts");
        EnsureFolder("Assets", "Editor");
    }

    private static void EnsureFolder(string parent, string child)
    {
        string path = parent + "/" + child;
        if (!AssetDatabase.IsValidFolder(path))
            AssetDatabase.CreateFolder(parent, child);
    }

    private static VisualEffectAsset BuildVfxAsset()
    {
        AssetDatabase.DeleteAsset(TempGraphPath);
        AssetDatabase.DeleteAsset(VfxPath);

        graphType = Type.GetType("UnityEditor.VFX.VFXGraph, Unity.VisualEffectGraph.Editor");
        modelType = Type.GetType("UnityEditor.VFX.VFXModel, Unity.VisualEffectGraph.Editor");
        contextType = Type.GetType("UnityEditor.VFX.VFXContext, Unity.VisualEffectGraph.Editor");
        slotType = Type.GetType("UnityEditor.VFX.VFXSlot, Unity.VisualEffectGraph.Editor");
        libraryType = Type.GetType("UnityEditor.VFX.VFXLibrary, Unity.VisualEffectGraph.Editor");
        if (graphType == null || modelType == null || contextType == null || slotType == null || libraryType == null)
            throw new InvalidOperationException("Unity Visual Effect Graph editor API is unavailable.");

        addChildMethod = graphType.GetMethod("AddChild", new[] { modelType, typeof(int), typeof(bool) });
        linkContextMethod = contextType.GetMethod("LinkTo", new[] { contextType, typeof(int), typeof(int) });
        linkSlotMethod = slotType.GetMethod("Link", new[] { slotType, typeof(bool) });

        graph = ScriptableObject.CreateInstance(graphType);
        graph.name = "MagicOrb";
        AssetDatabase.CreateAsset(graph, TempGraphPath);

        IEnumerable contexts = libraryType.GetMethod("GetContexts")?.Invoke(null, null) as IEnumerable;
        IEnumerable blocks = libraryType.GetMethod("GetBlocks")?.Invoke(null, null) as IEnumerable;
        IEnumerable parameters = libraryType.GetMethod("GetParameters")?.Invoke(null, null) as IEnumerable;

        object coreColor = CreateParam(parameters, "CoreColor", "Color");
        object shellColor = CreateParam(parameters, "ShellColor", "Color");
        object arcColor = CreateParam(parameters, "ArcColor", "Color");
        object orbRadius = CreateParam(parameters, "OrbRadius", "Float");
        object coreIntensity = CreateParam(parameters, "CoreIntensity", "Float");
        object shellNoiseAmplitude = CreateParam(parameters, "ShellNoiseAmplitude", "Float");
        object shellNoiseFrequency = CreateParam(parameters, "ShellNoiseFrequency", "Float");
        object arcSpawnRate = CreateParam(parameters, "ArcSpawnRate", "Float");
        object arcLifetime = CreateParam(parameters, "ArcLifetime", "Float");

        BuildCoreSystem(contexts, blocks, coreColor, coreIntensity, orbRadius, shellNoiseAmplitude, shellNoiseFrequency);
        BuildVolumeSystem(contexts, blocks, shellColor, orbRadius, shellNoiseAmplitude, shellNoiseFrequency);
        BuildShellSystem(contexts, blocks, shellColor, orbRadius, shellNoiseAmplitude, shellNoiseFrequency);
        BuildArcSystem(contexts, blocks, arcColor, orbRadius, arcSpawnRate, arcLifetime, shellNoiseAmplitude, shellNoiseFrequency);

        EditorUtility.SetDirty(graph);
        AssetDatabase.SaveAssets();
        ConvertTempGraphToVfx();
        AssetDatabase.ImportAsset(VfxPath, ImportAssetOptions.ForceUpdate);
        return AssetDatabase.LoadAssetAtPath<VisualEffectAsset>(VfxPath);
    }

    private static void BuildCoreSystem(IEnumerable contexts, IEnumerable blocks, object coreColor, object coreIntensity, object orbRadius, object noiseAmplitude, object noiseFrequency)
    {
        object spawn = AddContext(contexts, "Spawn");
        object init = AddContext(contexts, "Initialize Particle");
        object update = AddContext(contexts, "Update Particle");
        object output = AddContext(contexts, "Output Particle|Unlit|Quad");
        LinkContexts(spawn, init, update, output);

        object rate = AddBlock(spawn, blocks, "Constant Spawn Rate");
        SetInputValue(rate, "Rate", 42f);

        object position = AddBlock(init, blocks, "|Set|_Position Shape|Sphere");
        SetEnum(position, "positionMode", 1);
        SetEnum(position, "applyOrientation", 0);
        SetArcSphereRadius(position, orbRadius, 0.2f);

        object lifetime = AddBlock(init, blocks, "|Set|_Lifetime");
        SetField(lifetime, "Random", true);
        SetInputValue(lifetime, "_Lifetime", 0.72f);

        object color = AddBlock(init, blocks, "|Set|_Color");
        LinkParamToInput(coreColor, color, "_Color");

        object size = AddBlock(init, blocks, "|Set|_Size");
        SetField(size, "Random", true);
        LinkParamToInput(coreIntensity, size, "_Size");

        object turbulence = AddBlock(update, blocks, "Turbulence");
        LinkParamToInput(noiseAmplitude, turbulence, "Intensity");
        LinkParamToInput(noiseFrequency, turbulence, "frequency");
        SetInputValue(turbulence, "Drag", 0.08f);
        SetInputValue(turbulence, "octaves", 3);
        SetInputValue(turbulence, "roughness", 0.5f);
        SetInputValue(turbulence, "lacunarity", 2f);

        object drag = AddBlock(update, blocks, "Linear Drag");
        SetInputValue(drag, "dragCoefficient", 1.8f);

        SetOutputDefaults(output);
    }

    private static void BuildVolumeSystem(IEnumerable contexts, IEnumerable blocks, object shellColor, object orbRadius, object noiseAmplitude, object noiseFrequency)
    {
        object spawn = AddContext(contexts, "Spawn");
        object init = AddContext(contexts, "Initialize Particle");
        object update = AddContext(contexts, "Update Particle");
        object output = AddContext(contexts, "Output Particle|Unlit|Quad");
        LinkContexts(spawn, init, update, output);

        object rate = AddBlock(spawn, blocks, "Constant Spawn Rate");
        SetInputValue(rate, "Rate", 320f);

        object position = AddBlock(init, blocks, "|Set|_Position Shape|Sphere");
        SetEnum(position, "positionMode", 1);
        SetEnum(position, "applyOrientation", 0);
        SetArcSphereRadius(position, orbRadius, 0.95f);

        object lifetime = AddBlock(init, blocks, "|Set|_Lifetime");
        SetField(lifetime, "Random", true);
        SetInputValue(lifetime, "_Lifetime", 2.8f);

        object color = AddBlock(init, blocks, "|Set|_Color");
        LinkParamToInput(shellColor, color, "_Color");

        object size = AddBlock(init, blocks, "|Set|_Size");
        SetField(size, "Random", true);
        SetInputValue(size, "_Size", 0.03f);

        object turbulence = AddBlock(update, blocks, "Turbulence");
        LinkParamToInput(noiseAmplitude, turbulence, "Intensity");
        LinkParamToInput(noiseFrequency, turbulence, "frequency");
        SetInputValue(turbulence, "Drag", 0.15f);
        SetInputValue(turbulence, "octaves", 2);
        SetInputValue(turbulence, "roughness", 0.4f);
        SetInputValue(turbulence, "lacunarity", 2f);

        object drag = AddBlock(update, blocks, "Linear Drag");
        SetInputValue(drag, "dragCoefficient", 1.25f);

        SetOutputDefaults(output);
    }

    private static void BuildShellSystem(IEnumerable contexts, IEnumerable blocks, object shellColor, object orbRadius, object noiseAmplitude, object noiseFrequency)
    {
        object spawn = AddContext(contexts, "Spawn");
        object init = AddContext(contexts, "Initialize Particle");
        object update = AddContext(contexts, "Update Particle");
        object output = AddContext(contexts, "Output Particle|Unlit|Quad");
        LinkContexts(spawn, init, update, output);

        object rate = AddBlock(spawn, blocks, "Constant Spawn Rate");
        SetInputValue(rate, "Rate", 72f);

        object position = AddBlock(init, blocks, "|Set|_Position Shape|Sphere");
        SetEnum(position, "positionMode", 0);
        SetEnum(position, "applyOrientation", 1);
        SetArcSphereRadius(position, orbRadius, 1f);

        object lifetime = AddBlock(init, blocks, "|Set|_Lifetime");
        SetField(lifetime, "Random", true);
        SetInputValue(lifetime, "_Lifetime", 1.8f);

        object color = AddBlock(init, blocks, "|Set|_Color");
        LinkParamToInput(shellColor, color, "_Color");

        object size = AddBlock(init, blocks, "|Set|_Size");
        SetField(size, "Random", true);
        SetInputValue(size, "_Size", 0.16f);

        object turbulence = AddBlock(update, blocks, "Turbulence");
        LinkParamToInput(noiseAmplitude, turbulence, "Intensity");
        LinkParamToInput(noiseFrequency, turbulence, "frequency");
        SetInputValue(turbulence, "Drag", 0.25f);
        SetInputValue(turbulence, "octaves", 2);
        SetInputValue(turbulence, "roughness", 0.6f);
        SetInputValue(turbulence, "lacunarity", 2f);

        object drag = AddBlock(update, blocks, "Linear Drag");
        SetInputValue(drag, "dragCoefficient", 2.4f);

        SetOutputDefaults(output);
    }

    private static void BuildArcSystem(IEnumerable contexts, IEnumerable blocks, object arcColor, object orbRadius, object arcSpawnRate, object arcLifetime, object noiseAmplitude, object noiseFrequency)
    {
        object spawn = AddContext(contexts, "Spawn");
        object init = AddContext(contexts, "Initialize Particle");
        object update = AddContext(contexts, "Update Particle");
        object output = AddContext(contexts, "Output Particle|Unlit|Quad");
        LinkContexts(spawn, init, update, output);

        object rate = AddBlock(spawn, blocks, "Constant Spawn Rate");
        LinkParamToInput(arcSpawnRate, rate, "Rate");

        object position = AddBlock(init, blocks, "|Set|_Position Shape|Sphere");
        SetEnum(position, "positionMode", 0);
        SetEnum(position, "applyOrientation", 1);
        SetArcSphereRadius(position, orbRadius, 0.82f);

        object lifetime = AddBlock(init, blocks, "|Set|_Lifetime");
        LinkParamToInput(arcLifetime, lifetime, "_Lifetime");

        object color = AddBlock(init, blocks, "|Set|_Color");
        LinkParamToInput(arcColor, color, "_Color");

        object size = AddBlock(init, blocks, "|Set|_Size");
        SetField(size, "Random", true);
        SetInputValue(size, "_Size", 0.045f);

        object turbulence = AddBlock(update, blocks, "Turbulence");
        LinkParamToInput(noiseAmplitude, turbulence, "Intensity");
        LinkParamToInput(noiseFrequency, turbulence, "frequency");
        SetInputValue(turbulence, "Drag", 0.04f);
        SetInputValue(turbulence, "octaves", 3);
        SetInputValue(turbulence, "roughness", 0.55f);
        SetInputValue(turbulence, "lacunarity", 2f);

        object drag = AddBlock(update, blocks, "Linear Drag");
        SetInputValue(drag, "dragCoefficient", 0.55f);

        SetOutputDefaults(output);
    }

    private static void SetOutputDefaults(object output)
    {
        SetField(output, "cullMode", EnumValue(output, "cullMode", "Off"));
        SetField(output, "blendMode", EnumValue(output, "blendMode", "Additive"));
        SetField(output, "useSoftParticle", false);
        SetField(output, "sort", false);
        SetField(output, "castShadows", false);
    }

    private static object AddContext(IEnumerable descriptors, string name)
    {
        object context = CreateFromLibrary(descriptors, name);
        AssetDatabase.AddObjectToAsset((UnityEngine.Object)context, graph);
        addChildMethod.Invoke(graph, new[] { context, 0, true });
        AddSlotsToAsset(context);
        return context;
    }

    private static object AddBlock(object parentContext, IEnumerable descriptors, string name)
    {
        object block = CreateFromLibrary(descriptors, name);
        AssetDatabase.AddObjectToAsset((UnityEngine.Object)block, graph);
        addChildMethod.Invoke(parentContext, new[] { block, 0, true });
        AddSlotsToAsset(block);
        return block;
    }

    private static object CreateParam(IEnumerable descriptors, string exposedName, string typeName)
    {
        foreach (object descriptor in descriptors)
        {
            string name = descriptor.GetType().GetProperty("name")?.GetValue(descriptor, null) as string;
            if (name != typeName)
                continue;

            object parameter = descriptor.GetType().GetMethod("CreateInstance")?.Invoke(descriptor, null);
            AssetDatabase.AddObjectToAsset((UnityEngine.Object)parameter, graph);
            SetField(parameter, "m_ExposedName", exposedName);
            SetField(parameter, "m_Exposed", true);
            AddSlotsToAsset(parameter);
            addChildMethod.Invoke(graph, new[] { parameter, 0, true });
            return parameter;
        }

        throw new InvalidOperationException("Parameter type not found: " + typeName);
    }

    private static void LinkContexts(object spawn, object init, object update, object output)
    {
        linkContextMethod.Invoke(spawn, new[] { init, 0, 0 });
        linkContextMethod.Invoke(init, new[] { update, 0, 0 });
        linkContextMethod.Invoke(update, new[] { output, 0, 0 });
    }

    private static void LinkParamToInput(object parameter, object block, string inputName)
    {
        Array exprSlots = GetField(parameter, "m_ExprSlots") as Array;
        if (exprSlots == null || exprSlots.Length == 0)
            throw new InvalidOperationException("Parameter has no expression slot.");

        object paramOutSlot = exprSlots.GetValue(0);
        object targetSlot = FindSlot(block, "inputSlots", inputName);
        if (targetSlot == null)
            throw new InvalidOperationException($"Input slot '{inputName}' not found on {block.GetType().Name}.");

        linkSlotMethod.Invoke(paramOutSlot, new[] { targetSlot, true });
    }

    private static void SetArcSphereRadius(object positionBlock, object orbRadiusParameter, float multiplier)
    {
        object arcSphere = FindSlot(positionBlock, "inputSlots", "arcSphere");
        if (arcSphere == null)
            return;

        object radiusSlot = FindSlot(arcSphere, "inputSlots", "sphere_radius");
        if (radiusSlot == null)
            return;

        object constant = CreateInlineOperator("Multiply");
        if (constant == null)
            return;

        object aSlot = FindSlot(constant, "inputSlots", "a");
        object bSlot = FindSlot(constant, "inputSlots", "b");
        object outputSlot = FindSlot(constant, "outputSlots", "o");
        if (aSlot == null || bSlot == null || outputSlot == null)
            return;

        SetSlotValue(bSlot, multiplier);
        LinkParameterOutputToSlot(orbRadiusParameter, aSlot);
        LinkSlots(outputSlot, radiusSlot);
    }

    private static object FindSlot(object owner, string propertyName, string slotName)
    {
        PropertyInfo prop = owner.GetType().GetProperty(propertyName, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        IEnumerable slots = prop?.GetValue(owner, null) as IEnumerable;
        if (slots == null)
            return null;

        foreach (object slot in slots)
        {
            string current = slot.GetType().GetProperty("name", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)?.GetValue(slot, null) as string;
            if (current == slotName)
                return slot;
        }
        return null;
    }

    private static object CreateFromLibrary(IEnumerable descriptors, string targetName)
    {
        foreach (object descriptor in descriptors)
        {
            string name = descriptor.GetType().GetProperty("name")?.GetValue(descriptor, null) as string;
            if (name == targetName)
                return descriptor.GetType().GetMethod("CreateInstance")?.Invoke(descriptor, null);
        }
        throw new InvalidOperationException("VFX descriptor not found: " + targetName);
    }

    private static object CreateInlineOperator(string targetName)
    {
        IEnumerable operators = libraryType.GetMethod("GetOperators")?.Invoke(null, null) as IEnumerable;
        if (operators == null)
            return null;

        foreach (object descriptor in operators)
        {
            string name = descriptor.GetType().GetProperty("name")?.GetValue(descriptor, null) as string;
            if (name != targetName)
                continue;

            object op = descriptor.GetType().GetMethod("CreateInstance")?.Invoke(descriptor, null);
            AssetDatabase.AddObjectToAsset((UnityEngine.Object)op, graph);
            addChildMethod.Invoke(graph, new[] { op, 0, true });
            AddSlotsToAsset(op);
            return op;
        }

        return null;
    }

    private static void AddSlotsToAsset(object owner)
    {
        AddSlotCollection(owner, "inputSlots");
        AddSlotCollection(owner, "outputSlots");

        Array exprSlots = GetField(owner, "m_ExprSlots") as Array;
        if (exprSlots == null)
            return;

        foreach (object slot in exprSlots)
        {
            if (slot != null)
                SafeAddSubAsset((UnityEngine.Object)slot);
        }
    }

    private static void AddSlotCollection(object owner, string propertyName)
    {
        PropertyInfo prop = owner.GetType().GetProperty(propertyName, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        IEnumerable slots = prop?.GetValue(owner, null) as IEnumerable;
        if (slots == null)
            return;

        foreach (object slot in slots)
        {
            if (slot != null)
                SafeAddSubAsset((UnityEngine.Object)slot);
        }
    }

    private static void SafeAddSubAsset(UnityEngine.Object obj)
    {
        if (obj == null)
            return;

        string path = AssetDatabase.GetAssetPath(obj);
        if (!string.IsNullOrEmpty(path))
            return;

        AssetDatabase.AddObjectToAsset(obj, graph);
    }

    private static void SetInputValue(object owner, string inputName, object value)
    {
        object slot = FindSlot(owner, "inputSlots", inputName);
        if (slot == null)
            throw new InvalidOperationException($"Input slot '{inputName}' not found on {owner.GetType().Name}.");

        SetSlotValue(slot, value);
    }

    private static void SetSlotValue(object slot, object value)
    {
        PropertyInfo valueProp = slot.GetType().GetProperty("value", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (valueProp != null)
        {
            valueProp.SetValue(slot, value);
            return;
        }

        object masterData = GetField(slot, "m_MasterData");
        if (masterData == null)
            throw new InvalidOperationException("Unable to assign value to slot.");

        FieldInfo field = masterData.GetType().GetField("m_Value", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        object boxedValue = field?.GetValue(masterData);
        MethodInfo setter = boxedValue?.GetType().GetMethod("Set");
        if (setter == null)
            throw new InvalidOperationException("Unable to locate a setter for slot.");
        setter.Invoke(boxedValue, new[] { value });
    }

    private static void LinkParameterOutputToSlot(object parameter, object targetSlot)
    {
        Array exprSlots = GetField(parameter, "m_ExprSlots") as Array;
        if (exprSlots == null || exprSlots.Length == 0)
            throw new InvalidOperationException("Parameter has no expression slot.");

        LinkSlots(exprSlots.GetValue(0), targetSlot);
    }

    private static void LinkSlots(object sourceSlot, object targetSlot)
    {
        linkSlotMethod.Invoke(sourceSlot, new[] { targetSlot, true });
    }

    private static object EnumValue(object owner, string fieldName, string enumName)
    {
        FieldInfo field = owner.GetType().GetField(fieldName, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        return field == null ? null : Enum.Parse(field.FieldType, enumName);
    }

    private static void SetEnum(object owner, string fieldName, int value)
    {
        FieldInfo field = owner.GetType().GetField(fieldName, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        object enumValue = Enum.ToObject(field.FieldType, value);
        field.SetValue(owner, enumValue);
    }

    private static void SetField(object owner, string fieldName, object value)
    {
        FieldInfo field = owner.GetType().GetField(fieldName, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (field == null)
            return;
        object finalValue = value;
        if (field.FieldType.IsEnum && value != null && value.GetType() != field.FieldType)
        {
            if (value is bool boolValue)
                finalValue = Enum.ToObject(field.FieldType, boolValue ? 1 : 0);
            else if (value is int intValue)
                finalValue = Enum.ToObject(field.FieldType, intValue);
            else
                finalValue = Enum.Parse(field.FieldType, value.ToString());
        }
        field.SetValue(owner, finalValue);
    }

    private static object GetField(object owner, string fieldName)
    {
        return owner.GetType().GetField(fieldName, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)?.GetValue(owner);
    }

    private static void ConvertTempGraphToVfx()
    {
        string yaml = File.ReadAllText(Application.dataPath + "/VFX/MagicOrb/~MagicOrbGraph.asset");
        Match match = Regex.Match(yaml, @"--- !u!114 &(-?\d+)\nMonoBehaviour:\n  m_ObjectHideFlags: \d+\n  m_CorrespondingSourceObject: {fileID: 0}\n  m_PrefabInstance: {fileID: 0}\n  m_PrefabAsset: {fileID: 0}\n  m_GameObject: {fileID: 0}\n  m_Enabled: 1\n  m_EditorHideFlags: 0\n  m_Script: {fileID: 11500000, guid: 7d4c867f6b72b714dbb5fd1780afe208, type: 3}");
        string graphFileId = match.Success ? match.Groups[1].Value : "11400000";

        yaml = yaml.Replace("m_Name: ~MagicOrbGraph", "m_Name: MagicOrb");
        yaml = yaml.Replace("m_ResourceVersion: 0", "m_ResourceVersion: 1");
        yaml = yaml.Replace("m_UIInfos: {fileID: 0}", "m_UIInfos: {fileID: 11400002}");
        yaml += "\n\n--- !u!114 &11400002\nMonoBehaviour:\n  m_ObjectHideFlags: 1\n  m_CorrespondingSourceObject: {fileID: 0}\n  m_PrefabInstance: {fileID: 0}\n  m_PrefabAsset: {fileID: 0}\n  m_GameObject: {fileID: 0}\n  m_Enabled: 1\n  m_EditorHideFlags: 0\n  m_Script: {fileID: 11500000, guid: d01270efd3285ea4a9d6c555cb0a8027, type: 3}\n  m_Name: VFXUI\n  m_EditorClassIdentifier:\n  groupInfos: []\n  stickyNoteInfos: []\n\n--- !u!2058629511 &11400001\nVisualEffectResource:\n  m_ObjectHideFlags: 0\n  m_CorrespondingSourceObject: {fileID: 0}\n  m_PrefabInstance: {fileID: 0}\n  m_PrefabAsset: {fileID: 0}\n  m_GameObject: {fileID: 0}\n  m_Enabled: 1\n  m_EditorHideFlags: 0\n  m_Name: MagicOrb\n  m_Graph: {fileID: " + graphFileId + @"}
  m_Infos:
    m_RendererSettings:
      motionVectorGenerationMode: 0
      shadowCastingMode: 0
    m_CullingFlags: 3
    m_UpdateMode: 0
    m_PreWarmDeltaTime: 0.05
    m_PreWarmStepCount: 0
    m_InitialEventName: OnPlay
    m_InstancingMode: 0
    m_InstancingCapacity: 64
";

        File.WriteAllText(Application.dataPath + "/VFX/MagicOrb/MagicOrb.vfx", yaml);
        AssetDatabase.DeleteAsset(TempGraphPath);
    }

    private static VolumeProfile CreateVolumeProfile()
    {
        VolumeProfile profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(VolumeProfilePath);
        if (profile == null)
        {
            profile = ScriptableObject.CreateInstance<VolumeProfile>();
            AssetDatabase.CreateAsset(profile, VolumeProfilePath);
        }

        if (!profile.TryGet(out Bloom bloom))
            bloom = profile.Add<Bloom>(true);
        bloom.active = true;
        bloom.threshold.Override(0.68f);
        bloom.intensity.Override(1.45f);
        bloom.scatter.Override(0.72f);

        if (!profile.TryGet(out Tonemapping tonemapping))
            tonemapping = profile.Add<Tonemapping>(true);
        tonemapping.active = true;
        tonemapping.mode.Override(TonemappingMode.ACES);

        if (!profile.TryGet(out ColorAdjustments colorAdjustments))
            colorAdjustments = profile.Add<ColorAdjustments>(true);
        colorAdjustments.active = true;
        colorAdjustments.postExposure.Override(0.15f);
        colorAdjustments.contrast.Override(18f);

        EditorUtility.SetDirty(profile);
        return profile;
    }

    private static void BuildScene(VisualEffectAsset vfxAsset, VolumeProfile volumeProfile)
    {
        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        RenderSettings.ambientMode = AmbientMode.Flat;
        RenderSettings.ambientLight = new Color(0.16f, 0.05f, 0.18f, 1f);

        var cameraGo = new GameObject("Main Camera");
        cameraGo.tag = "MainCamera";
        cameraGo.transform.position = new Vector3(0f, 0f, -4.35f);
        var camera = cameraGo.AddComponent<Camera>();
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(0.2f, 0.03f, 0.24f, 1f);
        camera.fieldOfView = 30f;
        cameraGo.AddComponent<AudioListener>();
        var cameraData = cameraGo.AddComponent<UniversalAdditionalCameraData>();
        cameraData.renderPostProcessing = true;

        var volumeGo = new GameObject("Global Volume");
        var volume = volumeGo.AddComponent<Volume>();
        volume.isGlobal = true;
        volume.sharedProfile = volumeProfile;

        var orbRoot = new GameObject("MagicOrbRoot");
        var visualEffect = orbRoot.AddComponent<VisualEffect>();
        visualEffect.visualEffectAsset = vfxAsset;
        visualEffect.resetSeedOnPlay = false;
        visualEffect.startSeed = 7u;
        var rig = orbRoot.AddComponent<MagicOrbRig>();
        rig.visualEffect = visualEffect;
        rig.Apply();

        EditorSceneManager.SaveScene(scene, ScenePath);
    }
}
