using UnityEngine;
using UnityEditor;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using System.Reflection;

public static class BuildVFXGraph2
{
    [MenuItem("VFX/Build VFX Graph v2")]
    static void Execute()
    {
        try { Build(); }
        catch (Exception ex) { Debug.LogError("Build failed: " + ex); }
    }

    static object FindItem(string methodName, string target)
    {
        var libType = Type.GetType("UnityEditor.VFX.VFXLibrary, Unity.VisualEffectGraph.Editor");
        var items = libType.GetMethod(methodName).Invoke(null, null) as IEnumerable;
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

        var graph = ScriptableObject.CreateInstance(graphType);
        graph.name = "PillarGrid";
        AssetDatabase.CreateAsset(graph, "Assets/VFX/~_tmp_graph.asset");

        // Create and add contexts
        object[] ctxs = new object[] {
            FindItem("GetContexts", "Spawn"),
            FindItem("GetContexts", "Initialize Particle"),
            FindItem("GetContexts", "Update Particle"),
            FindItem("GetContexts", "Output Particle|URP Lit|Mesh")
        };

        foreach (var ctx in ctxs)
            AssetDatabase.AddObjectToAsset((UnityEngine.Object)ctx, graph);

        var addChild = graphType.GetMethod("AddChild", new Type[] { vfxModelType, typeof(int), typeof(bool) });
        foreach (var ctx in ctxs)
            addChild.Invoke(graph, new object[] { ctx, 0, true });

        var linkTo = vfxCtxType.GetMethod("LinkTo", new Type[] { vfxCtxType, typeof(int), typeof(int) });
        linkTo.Invoke(ctxs[0], new object[] { ctxs[1], 0, 0 });
        linkTo.Invoke(ctxs[1], new object[] { ctxs[2], 0, 0 });
        linkTo.Invoke(ctxs[2], new object[] { ctxs[3], 0, 0 });

        // Create and add blocks
        object[] blocks = new object[] {
            FindItem("GetBlocks", "Single Burst"),
            FindItem("GetBlocks", "|Set|_Position Sequential|Three Dimensional"),
            FindItem("GetBlocks", "|Set|_Lifetime"),
            FindItem("GetBlocks", "|Set|_Scale from Map|2D"),
            FindItem("GetBlocks", "|Set|_Color from Map|2D")
        };

        foreach (var b in blocks)
            AssetDatabase.AddObjectToAsset((UnityEngine.Object)b, graph);

        addChild.Invoke(ctxs[0], new object[] { blocks[0], 0, true });
        addChild.Invoke(ctxs[1], new object[] { blocks[1], 0, true });
        addChild.Invoke(ctxs[1], new object[] { blocks[2], 0, true });
        addChild.Invoke(ctxs[2], new object[] { blocks[3], 0, true });
        addChild.Invoke(ctxs[2], new object[] { blocks[4], 0, true });

        EditorUtility.SetDirty(graph);
        AssetDatabase.SaveAssets();

        Debug.Log("Graph built. Converting to .vfx...");
        ConvertToVFX();
    }

    static void ConvertToVFX()
    {
        string assetPath = "Assets/VFX/~_tmp_graph.asset";
        string assetFullPath = Application.dataPath + "/VFX/~_tmp_graph.asset";
        string vfxPath = Application.dataPath + "/VFX/PillarGrid.vfx";

        string yaml = System.IO.File.ReadAllText(assetFullPath);

        // Find the VFXGraph document and its fileID
        var match = Regex.Match(yaml, @"--- !u!114 &(-?\d+)\nMonoBehaviour:\n  m_ObjectHideFlags: \d+\n  m_CorrespondingSourceObject: {fileID: 0}\n  m_PrefabInstance: {fileID: 0}\n  m_PrefabAsset: {fileID: 0}\n  m_GameObject: {fileID: 0}\n  m_Enabled: 1\n  m_EditorHideFlags: 0\n  m_Script: {fileID: 11500000, guid: 7d4c867f6b72b714dbb5fd1780afe208, type: 3}");
        string graphFid = match.Success ? match.Groups[1].Value : "11400000";
        Debug.Log("Graph fileID: " + graphFid);

        // Replace the temp name and resource version
        yaml = yaml.Replace("m_Name: ~_tmp_graph", "m_Name: PillarGrid");
        yaml = yaml.Replace("m_ResourceVersion: 0", "m_ResourceVersion: 1");
        yaml = yaml.Replace("m_UIInfos: {fileID: 0}", "m_UIInfos: {fileID: 11400002}");

        // Add VFXUI and VisualEffectResource documents
        yaml += @"
--- !u!114 &11400002
MonoBehaviour:
  m_ObjectHideFlags: 1
  m_CorrespondingSourceObject: {fileID: 0}
  m_PrefabInstance: {fileID: 0}
  m_PrefabAsset: {fileID: 0}
  m_GameObject: {fileID: 0}
  m_Enabled: 1
  m_EditorHideFlags: 0
  m_Script: {fileID: 11500000, guid: d01270efd3285ea4a9d6c555cb0a8027, type: 3}
  m_Name: VFXUI
  m_EditorClassIdentifier:
  groupInfos: []
  stickyNoteInfos: []

--- !u!2058629511 &11400001
VisualEffectResource:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {fileID: 0}
  m_PrefabInstance: {fileID: 0}
  m_PrefabAsset: {fileID: 0}
  m_GameObject: {fileID: 0}
  m_Enabled: 1
  m_EditorHideFlags: 0
  m_Name: PillarGrid
  m_Graph: {fileID: " + graphFid + @"}
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

        // Also need to set URP sub-output on the output context
        // Find the VFXURPLitMeshOutput document and add m_SubOutputs

        System.IO.File.WriteAllText(vfxPath, yaml);

        // Remove the temp asset
        AssetDatabase.DeleteAsset(assetPath);
        AssetDatabase.Refresh();

        Debug.Log("VFX written to " + vfxPath);
    }
}
