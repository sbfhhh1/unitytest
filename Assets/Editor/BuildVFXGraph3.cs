using UnityEngine;
using UnityEditor;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using System.Reflection;

public static class BuildVFXGraph3
{
    [MenuItem("VFX/Build PillarGrid VFX")]
    static void Execute()
    {
        try { Build(); }
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

    static void Build()
    {
        var graphType = Type.GetType("UnityEditor.VFX.VFXGraph, Unity.VisualEffectGraph.Editor");
        var vfxModelType = Type.GetType("UnityEditor.VFX.VFXModel, Unity.VisualEffectGraph.Editor");
        var vfxCtxType = Type.GetType("UnityEditor.VFX.VFXContext, Unity.VisualEffectGraph.Editor");
        var libType = Type.GetType("UnityEditor.VFX.VFXLibrary, Unity.VisualEffectGraph.Editor");

        var graph = ScriptableObject.CreateInstance(graphType);
        graph.name = "PillarGrid";
        AssetDatabase.CreateAsset(graph, "Assets/VFX/~_tmp_graph.asset");

        var ctxs = libType.GetMethod("GetContexts").Invoke(null, null) as IEnumerable;
        var parms = libType.GetMethod("GetParameters").Invoke(null, null) as IEnumerable;
        var blocks = libType.GetMethod("GetBlocks").Invoke(null, null) as IEnumerable;

        var outputCtx = FindItem(ctxs, "Output Particle|URP Lit|Mesh");
        var spawnCtx = FindItem(ctxs, "Spawn");
        var initCtx = FindItem(ctxs, "Initialize Particle");
        var updateCtx = FindItem(ctxs, "Update Particle");

        object[] contextArray = new object[] { spawnCtx, initCtx, updateCtx, outputCtx };
        foreach (var ctx in contextArray)
            AssetDatabase.AddObjectToAsset((UnityEngine.Object)ctx, graph);

        var addChild = graphType.GetMethod("AddChild", new Type[] { vfxModelType, typeof(int), typeof(bool) });
        foreach (var ctx in contextArray)
            addChild.Invoke(graph, new object[] { ctx, 0, true });

        var linkTo = vfxCtxType.GetMethod("LinkTo", new Type[] { vfxCtxType, typeof(int), typeof(int) });
        linkTo.Invoke(spawnCtx, new object[] { initCtx, 0, 0 });
        linkTo.Invoke(initCtx, new object[] { updateCtx, 0, 0 });
        linkTo.Invoke(updateCtx, new object[] { outputCtx, 0, 0 });

        // Blocks
        var burst = FindItem(blocks, "Single Burst");
        var posSeq = FindItem(blocks, "|Set|_Position Sequential|Three Dimensional");
        var lifetime = FindItem(blocks, "|Set|_Lifetime");
        var scaleMap = FindItem(blocks, "|Set|_Scale from Map|2D");
        var colorMap = FindItem(blocks, "|Set|_Color from Map|2D");

        object[] blockArray = new object[] { burst, posSeq, lifetime, scaleMap, colorMap };
        foreach (var b in blockArray)
            AssetDatabase.AddObjectToAsset((UnityEngine.Object)b, graph);

        addChild.Invoke(spawnCtx, new object[] { burst, 0, true });
        addChild.Invoke(initCtx, new object[] { posSeq, 0, true });
        addChild.Invoke(initCtx, new object[] { lifetime, 0, true });
        addChild.Invoke(updateCtx, new object[] { scaleMap, 0, true });
        addChild.Invoke(updateCtx, new object[] { colorMap, 0, true });

        // --- Create exposed parameters ---
        string[] paramNames = new string[] {
            "AudioTexture", "GridSize", "Spacing", "PillarWidth",
            "Amplitude", "PillarHeight", "ColorA", "ColorB", "ColorC"
        };
        string[] paramTypes = new string[] {
            "Texture 2D", "Uint", "Float", "Float",
            "Float", "Float", "Vector 4", "Vector 4", "Vector 4"
        };

        for (int pi = 0; pi < paramNames.Length; pi++)
        {
            CreateExposedParam(parms, graph, addChild, paramNames[pi], paramTypes[pi]);
        }

        EditorUtility.SetDirty(graph);
        AssetDatabase.SaveAssets();

        Debug.Log("Full graph built. Converting to .vfx...");
        ConvertToVFX();
    }

    static void CreateExposedParam(IEnumerable parms, ScriptableObject graph, MethodInfo addChild, string name, string typeName)
    {
        foreach (var p in parms)
        {
            var pname = p.GetType().GetProperty("name").GetValue(p, null) as string;
            if (pname == typeName)
            {
                var param = p.GetType().GetMethod("CreateInstance").Invoke(p, null);
                AssetDatabase.AddObjectToAsset((UnityEngine.Object)param, graph);

                // Set exposed properties
                var nameField = param.GetType().GetField("m_ExposedName", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                if (nameField != null) nameField.SetValue(param, name);
                var exposedField = param.GetType().GetField("m_Exposed", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                if (exposedField != null) exposedField.SetValue(param, true);

                // Add slots as sub-assets too
                var exprField = param.GetType().GetField("m_ExprSlots", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                if (exprField != null)
                {
                    var slots = exprField.GetValue(param) as Array;
                    if (slots != null)
                    {
                        foreach (var slot in slots)
                        {
                            if (slot != null)
                                AssetDatabase.AddObjectToAsset((UnityEngine.Object)slot, graph);
                        }
                    }
                }

                // Add parameter to graph
                addChild.Invoke(graph, new object[] { param, 0, true });
                Debug.Log("  Added param: " + name);
                return;
            }
        }
        Debug.LogWarning("Parameter type not found: " + typeName);
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
