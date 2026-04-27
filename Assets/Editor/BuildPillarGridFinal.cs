using UnityEngine;
using UnityEditor;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using System.Reflection;

public static class BuildPillarGridFinal
{
    static Type graphType, vfxModelType, vfxCtxType, vfxSlotType;
    static MethodInfo addChild, linkSlots;
    static object graph;

    [MenuItem("VFX/Build PillarGrid Final")]
    static void Execute()
    {
        try
        {
            Build();
            Debug.Log("SUCCESS: PillarGrid VFX built and compiled!");
        }
        catch (Exception ex) { Debug.LogError("Build failed: " + ex); }
    }

    static object FindItem(IEnumerable items, string target)
    {
        foreach (var item in items)
        {
            var name = item.GetType().GetProperty("name").GetValue(item, null) as string;
            if (name == target)
                return item.GetType().GetMethod("CreateInstance").Invoke(item, null);
        }
        return null;
    }

    static void SetField(object obj, string field, object value)
    {
        var f = obj.GetType().GetField(field, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (f != null)
            f.SetValue(obj, value);
    }

    static void Build()
    {
        graphType = Type.GetType("UnityEditor.VFX.VFXGraph, Unity.VisualEffectGraph.Editor");
        vfxModelType = Type.GetType("UnityEditor.VFX.VFXModel, Unity.VisualEffectGraph.Editor");
        vfxCtxType = Type.GetType("UnityEditor.VFX.VFXContext, Unity.VisualEffectGraph.Editor");
        vfxSlotType = Type.GetType("UnityEditor.VFX.VFXSlot, Unity.VisualEffectGraph.Editor");
        var libType = Type.GetType("UnityEditor.VFX.VFXLibrary, Unity.VisualEffectGraph.Editor");

        var soGraph = ScriptableObject.CreateInstance(graphType);
        soGraph.name = "PillarGrid";
        graph = soGraph;
        AssetDatabase.CreateAsset(soGraph, "Assets/VFX/~_tmp_graph.asset");

        var ctxs = libType.GetMethod("GetContexts").Invoke(null, null) as IEnumerable;
        var parms = libType.GetMethod("GetParameters").Invoke(null, null) as IEnumerable;
        var blocks = libType.GetMethod("GetBlocks").Invoke(null, null) as IEnumerable;

        addChild = graphType.GetMethod("AddChild", new Type[] { vfxModelType, typeof(int), typeof(bool) });
        linkSlots = vfxSlotType.GetMethod("Link", new Type[] { vfxSlotType, typeof(bool) });

        // Create and add contexts
        var spawnCtx = AddContext(ctxs, "Spawn");
        var initCtx = AddContext(ctxs, "Initialize Particle");
        var updateCtx = AddContext(ctxs, "Update Particle");
        var outputCtx = AddContext(ctxs, "Output Particle|URP Lit|Mesh");

        var linkTo = vfxCtxType.GetMethod("LinkTo", new Type[] { vfxCtxType, typeof(int), typeof(int) });
        linkTo.Invoke(spawnCtx, new object[] { initCtx, 0, 0 });
        linkTo.Invoke(initCtx, new object[] { updateCtx, 0, 0 });
        linkTo.Invoke(updateCtx, new object[] { outputCtx, 0, 0 });

        // Create and add blocks
        var burstBlock = AddBlock(spawnCtx, blocks, "Single Burst");
        var posBlock = AddBlock(initCtx, blocks, "|Set|_Position Sequential|Three Dimensional");
        var lifetimeBlock = AddBlock(initCtx, blocks, "|Set|_Lifetime");
        var scaleBlock = AddBlock(updateCtx, blocks, "|Set|_Scale from Map|2D");
        var colorBlock = AddBlock(updateCtx, blocks, "|Set|_Color from Map|2D");

        // Configure blocks
        // Scale from Map: attribute=scale, SampleMode=IndexRelative
        SetField(scaleBlock, "attribute", "scale");
        SetEnum(scaleBlock, "SampleMode", 0);

        // Color from Map: attribute=color, SampleMode=IndexRelative
        SetField(colorBlock, "attribute", "color");
        SetEnum(colorBlock, "SampleMode", 0);

        // Position Sequential: shape=2 (Grid), mode=1 (Grid)
        SetEnum(posBlock, "shape", 2);
        SetEnum(posBlock, "mode", 1);

        // Create exposed parameters and link them
        var audioTexParam = CreateParam(parms, "AudioTexture", "Texture 2D");
        var gridSizeParam = CreateParam(parms, "GridSize", "Uint");
        var spacingParam = CreateParam(parms, "Spacing", "Float");
        var pillarWidthParam = CreateParam(parms, "PillarWidth", "Float");
        var amplitudeParam = CreateParam(parms, "Amplitude", "Float");
        var baseHeightParam = CreateParam(parms, "PillarHeight", "Float");
        var colorAParam = CreateParam(parms, "ColorA", "Vector 4");
        var colorBParam = CreateParam(parms, "ColorB", "Vector 4");
        var colorCParam = CreateParam(parms, "ColorC", "Vector 4");

        // Create TotalParticles param (used by controller for burst count)
        var totalParticlesParam = CreateParam(parms, "TotalParticles", "Uint");

        // Link parameters to block inputs
        LinkParamToBlockInput(audioTexParam, scaleBlock, "attributeMap");
        LinkParamToBlockInput(audioTexParam, colorBlock, "attributeMap");
        LinkParamToBlockInput(gridSizeParam, posBlock, "CountX");
        LinkParamToBlockInput(gridSizeParam, posBlock, "CountY");
        LinkParamToBlockInput(spacingParam, posBlock, "Spacing");
        LinkParamToBlockInput(pillarWidthParam, outputCtx, "scale");
        LinkParamToBlockInput(baseHeightParam, lifetimeBlock, "Lifetime");
        LinkParamToBlockInput(amplitudeParam, scaleBlock, "valueScale");
        LinkParamToBlockInput(totalParticlesParam, burstBlock, "Count");

        // Dirty all modified objects so links serialize to YAML
        EditorUtility.SetDirty((UnityEngine.Object)graph);
        foreach (var obj in new UnityEngine.Object[] {
            (UnityEngine.Object)burstBlock, (UnityEngine.Object)posBlock,
            (UnityEngine.Object)scaleBlock, (UnityEngine.Object)colorBlock,
            (UnityEngine.Object)audioTexParam, (UnityEngine.Object)gridSizeParam,
            (UnityEngine.Object)totalParticlesParam
        }) EditorUtility.SetDirty(obj);
        AssetDatabase.SaveAssets();

        Debug.Log("Graph built with all params and links. Converting...");
        ConvertToVFX();
    }

    static void AddSlotsToAsset(object obj)
    {
        var inputSlotsProp = obj.GetType().GetProperty("inputSlots", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (inputSlotsProp != null)
        {
            var inputSlots = inputSlotsProp.GetValue(obj, null) as IEnumerable;
            if (inputSlots != null)
                foreach (var slot in inputSlots)
                    if (slot != null)
                        AssetDatabase.AddObjectToAsset((UnityEngine.Object)slot, (UnityEngine.Object)graph);
        }
        var outputSlotsProp = obj.GetType().GetProperty("outputSlots", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (outputSlotsProp != null)
        {
            var outputSlots = outputSlotsProp.GetValue(obj, null) as IEnumerable;
            if (outputSlots != null)
                foreach (var slot in outputSlots)
                    if (slot != null)
                        AssetDatabase.AddObjectToAsset((UnityEngine.Object)slot, (UnityEngine.Object)graph);
        }
    }

    static object AddContext(IEnumerable ctxs, string name)
    {
        var ctx = FindItem(ctxs, name);
        AssetDatabase.AddObjectToAsset((UnityEngine.Object)ctx, (UnityEngine.Object)graph);
        addChild.Invoke(graph, new object[] { ctx, 0, true });
        AddSlotsToAsset(ctx);
        return ctx;
    }

    static object AddBlock(object ctx, IEnumerable blocks, string name)
    {
        var block = FindItem(blocks, name);
        AssetDatabase.AddObjectToAsset((UnityEngine.Object)block, (UnityEngine.Object)graph);
        addChild.Invoke(ctx, new object[] { block, 0, true });
        AddSlotsToAsset(block);
        return block;
    }

    static void SetEnum(object obj, string field, int enumValue)
    {
        var f = obj.GetType().GetField(field, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (f != null)
        {
            var enumUnderlying = Enum.ToObject(f.FieldType, enumValue);
            f.SetValue(obj, enumUnderlying);
        }
    }

    static object CreateParam(IEnumerable parms, string name, string typeName)
    {
        foreach (var p in parms)
        {
            var pname = p.GetType().GetProperty("name").GetValue(p, null) as string;
            if (pname == typeName)
            {
                var param = p.GetType().GetMethod("CreateInstance").Invoke(p, null);
                AssetDatabase.AddObjectToAsset((UnityEngine.Object)param, (UnityEngine.Object)graph);

                var nameField = param.GetType().GetField("m_ExposedName", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                if (nameField != null) nameField.SetValue(param, name);
                var exposedField = param.GetType().GetField("m_Exposed", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                if (exposedField != null) exposedField.SetValue(param, true);

                // Add slot sub-assets
                var exprField = param.GetType().GetField("m_ExprSlots", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                if (exprField != null)
                {
                    var slots = exprField.GetValue(param) as Array;
                    if (slots != null)
                        foreach (var slot in slots)
                            if (slot != null)
                                AssetDatabase.AddObjectToAsset((UnityEngine.Object)slot, (UnityEngine.Object)graph);
                }

                addChild.Invoke(graph, new object[] { param, 0, true });
                return param;
            }
        }
        return null;
    }

    static void LinkParamToBlockInput(object param, object block, string inputName)
    {
        // Get param output slot (first expr slot)
        var exprField = param.GetType().GetField("m_ExprSlots", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (exprField == null) { Debug.LogWarning("No exprField on " + param); return; }
        var exprSlots = exprField.GetValue(param) as Array;
        if (exprSlots == null || exprSlots.Length == 0) { Debug.LogWarning("No expr slots"); return; }
        var paramOutSlot = exprSlots.GetValue(0);

        // Find block input by name
        var inputSlotsProp = block.GetType().GetProperty("inputSlots", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (inputSlotsProp == null) { Debug.LogWarning("No inputSlots on " + block); return; }
        var inputSlots = inputSlotsProp.GetValue(block, null) as IEnumerable;

        foreach (var slot in inputSlots)
        {
            var nameProp = slot.GetType().GetProperty("name", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
            if (nameProp != null)
            {
                var slotName = nameProp.GetValue(slot, null) as string;
                if (slotName == inputName)
                {
                    linkSlots.Invoke(paramOutSlot, new object[] { slot, true });
                    var exposedField = param.GetType().GetField("m_ExposedName", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                    var exposedVal = exposedField != null ? exposedField.GetValue(param) : "?";
                    Debug.Log("  Linked " + inputName + " to " + exposedVal);
                    return;
                }
            }
        }
        Debug.LogWarning("Input slot " + inputName + " not found on " + block.GetType().Name);
    }

    static void ConvertToVFX()
    {
        string assetFullPath = Application.dataPath + "/VFX/~_tmp_graph.asset";
        string vfxPath = Application.dataPath + "/VFX/PillarGrid.vfx";

        string yaml = System.IO.File.ReadAllText(assetFullPath);

        var match = Regex.Match(yaml, @"--- !u!114 &(-?\d+)\nMonoBehaviour:\n  m_ObjectHideFlags: \d+\n  m_CorrespondingSourceObject: {fileID: 0}\n  m_PrefabInstance: {fileID: 0}\n  m_PrefabAsset: {fileID: 0}\n  m_GameObject: {fileID: 0}\n  m_Enabled: 1\n  m_EditorHideFlags: 0\n  m_Script: {fileID: 11500000, guid: 7d4c867f6b72b714dbb5fd1780afe208, type: 3}");
        string graphFid = match.Success ? match.Groups[1].Value : "11400000";

        yaml = yaml.Replace("m_Name: ~_tmp_graph", "m_Name: PillarGrid");
        yaml = yaml.Replace("m_ResourceVersion: 0", "m_ResourceVersion: 1");
        yaml = yaml.Replace("m_UIInfos: {fileID: 0}", "m_UIInfos: {fileID: 11400002}");

        yaml += "\n\n--- !u!114 &11400002\nMonoBehaviour:\n  m_ObjectHideFlags: 1\n  m_CorrespondingSourceObject: {fileID: 0}\n  m_PrefabInstance: {fileID: 0}\n  m_PrefabAsset: {fileID: 0}\n  m_GameObject: {fileID: 0}\n  m_Enabled: 1\n  m_EditorHideFlags: 0\n  m_Script: {fileID: 11500000, guid: d01270efd3285ea4a9d6c555cb0a8027, type: 3}\n  m_Name: VFXUI\n  m_EditorClassIdentifier:\n  groupInfos: []\n  stickyNoteInfos: []\n\n--- !u!2058629511 &11400001\nVisualEffectResource:\n  m_ObjectHideFlags: 0\n  m_CorrespondingSourceObject: {fileID: 0}\n  m_PrefabInstance: {fileID: 0}\n  m_PrefabAsset: {fileID: 0}\n  m_GameObject: {fileID: 0}\n  m_Enabled: 1\n  m_EditorHideFlags: 0\n  m_Name: PillarGrid\n  m_Graph: {fileID: " + graphFid + @"}
  m_Infos:
    m_RendererSettings:
      motionVectorGenerationMode: 1
      shadowCastingMode: 1
    m_CullingFlags: 3
    m_UpdateMode: 0
    m_PreWarmDeltaTime: 0.05
    m_PreWarmStepCount: 0
    m_InitialEventName: OnPlay
    m_InstancingMode: 0
    m_InstancingCapacity: 64
";

        System.IO.File.WriteAllText(vfxPath, yaml);
        AssetDatabase.DeleteAsset("Assets/VFX/~_tmp_graph.asset");
        AssetDatabase.Refresh();
        Debug.Log("VFX written to " + vfxPath);
    }
}
