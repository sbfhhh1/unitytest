using UnityEngine;
using UnityEditor;
using UnityEditor.VFX;
using System;
using System.Collections;
using System.Reflection;

public static class BuildVFXGraph
{
    [MenuItem("VFX/Build Graph Programmatically")]
    static void Execute()
    {
        try { Build(); }
        catch (Exception ex) { Debug.LogError("Build failed: " + ex); }
    }

    static object CreateFromLibrary(string methodName, string targetName)
    {
        var libType = Type.GetType("UnityEditor.VFX.VFXLibrary, Unity.VisualEffectGraph.Editor");
        var items = libType.GetMethod(methodName).Invoke(null, null) as IEnumerable;
        foreach (var item in items)
        {
            var name = item.GetType().GetProperty("name").GetValue(item, null) as string;
            if (name == targetName)
                return item.GetType().GetMethod("CreateInstance").Invoke(item, null);
        }
        return null;
    }

    static void Build()
    {
        var graphType = Type.GetType("UnityEditor.VFX.VFXGraph, Unity.VisualEffectGraph.Editor");
        var vfxModelType = Type.GetType("UnityEditor.VFX.VFXModel, Unity.VisualEffectGraph.Editor");
        var vfxCtxType = Type.GetType("UnityEditor.VFX.VFXContext, Unity.VisualEffectGraph.Editor");

        var graph = ScriptableObject.CreateInstance(graphType) as ScriptableObject;
        graph.name = "PillarGrid";

        // Create contexts
        var spawnCtx = CreateFromLibrary("GetContexts", "Spawn");
        var initCtx = CreateFromLibrary("GetContexts", "Initialize Particle");
        var updateCtx = CreateFromLibrary("GetContexts", "Update Particle");
        var outputCtx = CreateFromLibrary("GetContexts", "Output Particle|URP Lit|Mesh");

        // Debug.Log("Contexts: " + (spawnCtx!=null) + " " + (initCtx!=null) + " " + (updateCtx!=null) + " " + (outputCtx!=null));

        // Add to graph
        var addChild = graphType.GetMethod("AddChild", new Type[] { vfxModelType, typeof(int), typeof(bool) });
        addChild.Invoke(graph, new object[] { spawnCtx, 0, true });
        addChild.Invoke(graph, new object[] { initCtx, 0, true });
        addChild.Invoke(graph, new object[] { updateCtx, 0, true });
        addChild.Invoke(graph, new object[] { outputCtx, 0, true });

        // Link contexts
        var linkTo = vfxCtxType.GetMethod("LinkTo", new Type[] { vfxCtxType, typeof(int), typeof(int) });
        linkTo.Invoke(spawnCtx, new object[] { initCtx, 0, 0 });
        linkTo.Invoke(initCtx, new object[] { updateCtx, 0, 0 });
        linkTo.Invoke(updateCtx, new object[] { outputCtx, 0, 0 });

        // Create blocks
        var burstBlock = CreateFromLibrary("GetBlocks", "Single Burst");
        var posBlock = CreateFromLibrary("GetBlocks", "|Set|_Position Sequential|Three Dimensional");
        var lifetimeBlock = CreateFromLibrary("GetBlocks", "|Set|_Lifetime");
        var scaleMapBlock = CreateFromLibrary("GetBlocks", "|Set|_Scale from Map|2D");
        var colorMapBlock = CreateFromLibrary("GetBlocks", "|Set|_Color from Map|2D");

        // Add blocks to contexts
        addChild.Invoke(spawnCtx, new object[] { burstBlock, 0, true });
        addChild.Invoke(initCtx, new object[] { posBlock, 0, true });
        addChild.Invoke(initCtx, new object[] { lifetimeBlock, 0, true });
        addChild.Invoke(updateCtx, new object[] { scaleMapBlock, 0, true });
        addChild.Invoke(updateCtx, new object[] { colorMapBlock, 0, true });

        Debug.Log("Graph built successfully. Saving...");

        // Save as asset first
        string path = "Assets/VFX/~_tmp_graph.asset";
        AssetDatabase.CreateAsset(graph, path);
        AssetDatabase.SaveAssets();

        Debug.Log("Saved to " + path);

        // Now convert to .vfx
        ConvertAssetToVFX(path, "Assets/VFX/PillarGrid.vfx");
    }

    static void ConvertAssetToVFX(string assetPath, string vfxPath)
    {
        // Read the .asset YAML
        string yaml = System.IO.File.ReadAllText(assetPath);

        // Remove the .asset file
        AssetDatabase.DeleteAsset(assetPath);

        // Write as .vfx
        System.IO.File.WriteAllText(vfxPath, yaml);
        AssetDatabase.Refresh();
        Debug.Log("VFX file written to " + vfxPath);
    }
}
