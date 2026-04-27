using UnityEngine;
using UnityEditor;
using UnityEditor.VFX;
using UnityEngine.VFX;
using System;
using System.Reflection;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Linq;

[InitializeOnLoad]
public class RebuildPillarVFX
{
    static RebuildPillarVFX()
    {
        // Register menu item via static constructor
    }

    [MenuItem("VFX/Create PillarGrid VFX")]
    static void CreatePillarVFX()
    {
        string path = EditorUtility.SaveFilePanelInProject("Save PillarGrid VFX", "PillarGrid", "vfx", "Save VFX Graph asset");
        if (string.IsNullOrEmpty(path))
            return;

        try
        {
            var graphType = Type.GetType("UnityEditor.VFX.VFXGraph, Unity.VisualEffectGraph.Editor");
            var graph = ScriptableObject.CreateInstance(graphType) as ScriptableObject;
            if (graph == null)
            {
                Debug.LogError("Failed to create VFXGraph");
                return;
            }

            // Create asset and add graph as sub-asset
            AssetDatabase.CreateAsset(graph, path);

            // Now build the graph
            BuildGraph(graph);

            // Save
            EditorUtility.SetDirty(graph);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            Debug.Log("PillarGrid VFX created at " + path);
        }
        catch (Exception ex)
        {
            Debug.LogError("Create failed: " + ex);
        }
    }

    static object FindDescriptor(string name, bool isBlock)
    {
        var libType = Type.GetType("UnityEditor.VFX.VFXLibrary, Unity.VisualEffectGraph.Editor");
        string methodName = isBlock ? "GetBlocks" : "GetContexts";
        var method = libType.GetMethod(methodName);
        var items = method.Invoke(null, null) as IEnumerable;

        foreach (var item in items)
        {
            var nameProp = item.GetType().GetProperty("name");
            var itemName = nameProp.GetValue(item) as string;
            if (itemName == name)
                return item;
        }
        return null;
    }

    static object CreateFromDescriptor(object desc)
    {
        if (desc == null) return null;
        var createMethod = desc.GetType().GetMethod("CreateInstance");
        if (createMethod != null)
            return createMethod.Invoke(desc, null);
        return null;
    }

    static object AddChildModel(object parent, object child)
    {
        var t = parent.GetType();
        var m = t.GetMethod("AddChild", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance,
            null, new Type[] { typeof(object), typeof(int), typeof(bool) }, null);
        if (m != null)
        {
            m.Invoke(parent, new object[] { child, 0, true });
            return child;
        }
        // Try children list
        var childrenProp = t.GetProperty("children", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (childrenProp != null)
        {
            var children = childrenProp.GetValue(parent);
            children.GetType().GetMethod("Add").Invoke(children, new object[] { child });
            return child;
        }
        return null;
    }

    static void BuildGraph(ScriptableObject graph)
    {
        var graphType = graph.GetType();

        // Create contexts
        var spawnCtx = CreateFromDescriptor(FindDescriptor("Spawn", false));
        if (spawnCtx == null) { Debug.LogError("Spawn ctx null"); return; }
        AddChildModel(graph, spawnCtx);

        var initCtx = CreateFromDescriptor(FindDescriptor("Initialize Particle", false));
        if (initCtx == null) { Debug.LogError("Init ctx null"); return; }
        AddChildModel(graph, initCtx);

        var updateCtx = CreateFromDescriptor(FindDescriptor("Update Particle", false));
        if (updateCtx == null) { Debug.LogError("Update ctx null"); return; }
        AddChildModel(graph, updateCtx);

        var outputCtx = CreateFromDescriptor(FindDescriptor("Output Particle|URP Lit|Mesh", false));
        if (outputCtx == null) { Debug.LogError("Output ctx null"); return; }
        AddChildModel(graph, outputCtx);

        Debug.Log("Contexts created");

        // Link flow
        LinkContexts(spawnCtx, initCtx);
        LinkContexts(initCtx, updateCtx);
        LinkContexts(updateCtx, outputCtx);
        Debug.Log("Flow linked");

        // Add blocks
        var burst = CreateFromDescriptor(FindDescriptor("Single Burst", true));
        if (burst != null) AddChildModel(spawnCtx, burst);

        var pos = CreateFromDescriptor(FindDescriptor("|Set|_Position Sequential|Three Dimensional", true));
        if (pos != null) AddChildModel(initCtx, pos);

        var lifetime = CreateFromDescriptor(FindDescriptor("|Set|_Lifetime", true));
        if (lifetime != null) AddChildModel(initCtx, lifetime);

        var scaleFromMap = CreateFromDescriptor(FindDescriptor("|Set|_Scale from Map|2D", true));
        if (scaleFromMap != null) AddChildModel(updateCtx, scaleFromMap);

        var colorFromMap = CreateFromDescriptor(FindDescriptor("|Set|_Color from Map|2D", true));
        if (colorFromMap != null) AddChildModel(updateCtx, colorFromMap);

        Debug.Log("Blocks added");

        // Add exposed parameters
        AddExposedParameters(graph, graphType);

        Debug.Log("Graph build complete!");
    }

    static void LinkContexts(object fromCtx, object toCtx)
    {
        var ctxType = Type.GetType("UnityEditor.VFX.VFXContext, Unity.VisualEffectGraph.Editor");
        var linkToMethod = ctxType.GetMethod("LinkTo", new Type[] { ctxType });
        if (linkToMethod != null)
            linkToMethod.Invoke(fromCtx, new object[] { toCtx });
        else
        {
            // Try with object parameter
            linkToMethod = ctxType.GetMethod("LinkTo");
            if (linkToMethod != null)
                linkToMethod.Invoke(fromCtx, new object[] { toCtx });
        }
    }

    static void AddExposedParameters(ScriptableObject graph, Type graphType)
    {
        // VFXGraph has a method to add parameters
        var addParamMethod = graphType.GetMethod("AddExposedParameter", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (addParamMethod != null)
        {
            // Add parameters matching the controller
            string[] paramNames = new string[] { "GridSize", "Spacing", "PillarWidth", "Amplitude", "BaseHeight", "AudioTexture", "ColorA", "ColorB", "ColorC" };
            foreach (var name in paramNames)
            {
                try { addParamMethod.Invoke(graph, new object[] { name }); }
                catch { /* ignore if param exists */ }
            }
        }
    }
}
