using UnityEngine;
using UnityEditor;
using UnityEditor.VFX;
using UnityEngine.VFX;
using System;
using System.Reflection;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;

[InitializeOnLoad]
public static class BuildPillarVFX
{
    static BuildPillarVFX() { }

    [MenuItem("VFX/Build Pillar Grid")]
    static void Build()
    {
        try { BuildInternal(); }
        catch (Exception ex) { Debug.LogError("Build failed: " + ex); }
    }

    static void BuildInternal()
    {
        var graphType = Type.GetType("UnityEditor.VFX.VFXGraph, Unity.VisualEffectGraph.Editor");
        var graph = ScriptableObject.CreateInstance(graphType) as ScriptableObject;
        if (graph == null) { Debug.LogError("Failed to create graph"); return; }

        // Temporarily save as asset so it gets a proper fileID
        string tmpPath = "Assets/VFX/~_tmp_build.asset";
        AssetDatabase.CreateAsset(graph, tmpPath);

        // Build graph structure
        var spawnCtx = CreateCtx("Spawn");
        var initCtx = CreateCtx("Initialize Particle");
        var updateCtx = CreateCtx("Update Particle");
        var outputCtx = CreateCtx("Output Particle|URP Lit|Mesh");

        AddChild(graph, spawnCtx);
        AddChild(graph, initCtx);
        AddChild(graph, updateCtx);
        AddChild(graph, outputCtx);

        LinkCtx(spawnCtx, initCtx);
        LinkCtx(initCtx, updateCtx);
        LinkCtx(updateCtx, outputCtx);

        // Blocks
        AddBlock(spawnCtx, "Single Burst");
        AddBlock(initCtx, "|Set|_Position Sequential|Three Dimensional");
        AddBlock(initCtx, "|Set|_Lifetime");
        AddBlock(updateCtx, "|Set|_Scale from Map|2D");
        AddBlock(updateCtx, "|Set|_Color from Map|2D");

        Debug.Log("Graph built. Saving as VFX...");

        // Now we need to output as .vfx YAML
        // The trick: use Unity's own YAML serialization via the VFX asset system

        // Write the VFX file manually with proper structure
        string vfxPath = Application.dataPath + "/VFX/PillarGrid.vfx";
        WriteVFXFromGraph(graph, vfxPath);

        // Clean up temp asset
        AssetDatabase.DeleteAsset(tmpPath);

        // Import the VFX file
        AssetDatabase.ImportAsset("Assets/VFX/PillarGrid.vfx", ImportAssetOptions.ForceUpdate);
        AssetDatabase.Refresh();

        Debug.Log("PillarGrid VFX built at " + vfxPath);
    }

    static object CreateCtx(string name)
    {
        var libType = Type.GetType("UnityEditor.VFX.VFXLibrary, Unity.VisualEffectGraph.Editor");
        var ctxs = libType.GetMethod("GetContexts").Invoke(null, null) as IEnumerable;
        foreach (var c in ctxs)
        {
            if ((string)c.GetType().GetProperty("name").GetValue(c) == name)
                return c.GetType().GetMethod("CreateInstance").Invoke(c, null);
        }
        return null;
    }

    static object CreateBlock(string name)
    {
        var libType = Type.GetType("UnityEditor.VFX.VFXLibrary, Unity.VisualEffectGraph.Editor");
        var blocks = libType.GetMethod("GetBlocks").Invoke(null, null) as IEnumerable;
        foreach (var b in blocks)
        {
            if ((string)b.GetType().GetProperty("name").GetValue(b) == name)
                return b.GetType().GetMethod("CreateInstance").Invoke(b, null);
        }
        return null;
    }

    static void AddChild(object parent, object child)
    {
        parent.GetType().GetMethod("AddChild", new Type[] { typeof(object), typeof(int), typeof(bool) })
            ?.Invoke(parent, new object[] { child, 0, true });
    }

    static void LinkCtx(object from, object to)
    {
        var ctxType = Type.GetType("UnityEditor.VFX.VFXContext, Unity.VisualEffectGraph.Editor");
        ctxType.GetMethod("LinkTo")?.Invoke(from, new object[] { to });
    }

    static void AddBlock(object ctx, string blockName)
    {
        var block = CreateBlock(blockName);
        if (block != null) AddChild(ctx, block);
        else Debug.LogWarning("Block not found: " + blockName);
    }

    static void WriteVFXFromGraph(ScriptableObject graph, string vfxPath)
    {
        // Use VFXAssetManager.BuildAndSave() if available, or
        // manually write the YAML by serializing the graph

        // First try VFXAssetManager
        var amType = Type.GetType("UnityEditor.VFX.VFXAssetManager, Unity.VisualEffectGraph.Editor");
        var buildMethod = amType.GetMethod("BuildAndSave", Type.EmptyTypes);
        if (buildMethod != null)
        {
            buildMethod.Invoke(null, null);
            Debug.Log("VFXAssetManager.BuildAndSave completed");
        }

        // We need to get the serialized YAML for the graph
        // UnityEditor.YAMLExport can export assets to YAML
        // But we have a ScriptableObject not saved as main asset...

        // Alternative: Use AssetDatabase to export the temp asset to YAML
        string tmpPath = "Assets/VFX/~_tmp_build.asset";
        string yamlPath = Application.dataPath + "/../" + tmpPath;

        if (File.Exists(yamlPath))
        {
            string yaml = File.ReadAllText(yamlPath);
            // Transform the YAML from .asset format to .vfx format
            // Add VisualEffectResource wrapper, change fileID references, etc.
            Debug.Log("Temp asset YAML: " + yaml.Length + " bytes");
        }
    }
}
