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

public class CreatePillarVFX
{
    // Known GUIDs for VFX model types (from VFXInfoAttribute)
    static Dictionary<string, string> BlockGUIDs = new Dictionary<string, string>
    {
        { "Single Burst", "5e382412bb691334bb79457a6c127924" },
        { "|Set|_Position Sequential|Three Dimensional", "3e3f628d80ffceb489beac74258f9cf7" },
        { "|Set|_Lifetime", "a971fa2e110a0ac42ac1d8dae408704b" },
        { "|Set|_Scale from Map|2D", "cac5e85d3a3aa30488f6fcb5d24b3784" },
        { "|Set|_Color from Map|2D", "a00b24a1ae15fdc4b8b366a4fca09db0" },
    };

    static Dictionary<string, string> ContextGUIDs = new Dictionary<string, string>
    {
        { "Spawn", "73a13919d81fb7444849bae8b5c812a2" },
        { "Initialize Particle", "2dc095764ededfa4bb32fa602511ea4b" },
        { "Update Particle", "4863fa62cfb1f064799c58d3205acc8b" },
        { "Output Particle|URP Lit|Mesh", "6425c21c977ec384dbfc1c40a4c22b27" },
    };

    [MenuItem("VFX/Create Pillar Grid VFX")]
    static void CreateAsset()
    {
        string dir = "Assets/VFX";
        string path = dir + "/PillarGrid.vfx";

        // Use the VFX Graph API to build the graph
        var graphType = Type.GetType("UnityEditor.VFX.VFXGraph, Unity.VisualEffectGraph.Editor");
        if (graphType == null) { Debug.LogError("VFXGraph type not found"); return; }

        // Create graph
        var graph = ScriptableObject.CreateInstance(graphType) as ScriptableObject;
        if (graph == null) { Debug.LogError("Failed to create VFXGraph"); return; }

        // Make it dirty and save as asset
        AssetDatabase.CreateAsset(graph, path);

        Debug.Log("Created base VFX asset at " + path);

        try
        {
            // Build the graph structure
            BuildGraph(graph);

            // Mark dirty and save
            EditorUtility.SetDirty(graph);
            AssetDatabase.SaveAssets();

            // Build and compile the VFX
            var amType = Type.GetType("UnityEditor.VFX.VFXAssetManager, Unity.VisualEffectGraph.Editor");
            var buildMethod = amType.GetMethod("Build", new Type[] { typeof(bool) });
            if (buildMethod != null)
            {
                buildMethod.Invoke(null, new object[] { true });
                Debug.Log("VFX built successfully");
            }

            AssetDatabase.Refresh();
            Debug.Log("PillarGrid VFX created successfully at " + path);
        }
        catch (Exception ex)
        {
            Debug.LogError("Failed to build graph: " + ex);
        }
    }

    static object CreateModelInstance(string typeName, Dictionary<string, string> guidMap)
    {
        var libType = Type.GetType("UnityEditor.VFX.VFXLibrary, Unity.VisualEffectGraph.Editor");
        string methodName = typeName.Contains("|") ? "GetBlocks" : "GetContexts";
        var method = libType.GetMethod(methodName);
        var items = method.Invoke(null, null) as IEnumerable;

        foreach (var item in items)
        {
            var nameProp = item.GetType().GetProperty("name");
            var itemName = nameProp.GetValue(item) as string;
            if (itemName == typeName)
            {
                var createMethod = item.GetType().GetMethod("CreateInstance");
                if (createMethod != null)
                    return createMethod.Invoke(item, null);

                // Try model property + Activator
                var modelProp = item.GetType().GetProperty("model");
                if (modelProp != null)
                {
                    var model = modelProp.GetValue(item);
                    if (model != null)
                        return Activator.CreateInstance(model.GetType());
                }
            }
        }
        return null;
    }

    static void AddToGraph(object parent, object child)
    {
        var parentType = parent.GetType();
        // Try AddChild(VFXModel, int, bool)
        var addChildMethod = parentType.GetMethod("AddChild", new Type[] {
            typeof(object), typeof(int), typeof(bool)
        });
        if (addChildMethod != null)
        {
            addChildMethod.Invoke(parent, new object[] { child, 0, true });
            return;
        }

        // Try children list
        var childrenProp = parentType.GetProperty("children",
            BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (childrenProp != null)
        {
            var children = childrenProp.GetValue(parent);
            var addMethod = children.GetType().GetMethod("Add");
            if (addMethod != null)
            {
                addMethod.Invoke(children, new object[] { child });

                // Notify parent about new child
                var notifyMethod = parentType.GetMethod("OnAddChild",
                    BindingFlags.NonPublic | BindingFlags.Instance);
                if (notifyMethod != null)
                    notifyMethod.Invoke(parent, new object[] { child });
            }
        }
    }

    static void LinkFlow(object fromCtx, object toCtx)
    {
        var ctxType = Type.GetType("UnityEditor.VFX.VFXContext, Unity.VisualEffectGraph.Editor");
        var linkToMethod = ctxType.GetMethod("LinkTo", new Type[] { ctxType });
        if (linkToMethod == null)
            linkToMethod = ctxType.GetMethod("LinkTo");

        if (linkToMethod != null)
            linkToMethod.Invoke(fromCtx, new object[] { toCtx });
    }

    static void BuildGraph(ScriptableObject graph)
    {
        Debug.Log("Building graph...");

        // Spawn context
        var spawnCtx = CreateModelInstance("Spawn", ContextGUIDs);
        if (spawnCtx == null) { Debug.LogError("Failed Spawn"); return; }
        AddToGraph(graph, spawnCtx);

        // Init context
        var initCtx = CreateModelInstance("Initialize Particle", ContextGUIDs);
        if (initCtx == null) { Debug.LogError("Failed Init"); return; }
        AddToGraph(graph, initCtx);

        // Update context
        var updateCtx = CreateModelInstance("Update Particle", ContextGUIDs);
        if (updateCtx == null) { Debug.LogError("Failed Update"); return; }
        AddToGraph(graph, updateCtx);

        // Output mesh context
        var outputCtx = CreateModelInstance("Output Particle|URP Lit|Mesh", ContextGUIDs);
        if (outputCtx == null) { Debug.LogError("Failed Output"); return; }
        AddToGraph(graph, outputCtx);

        // Link flow
        LinkFlow(spawnCtx, initCtx);
        LinkFlow(initCtx, updateCtx);
        LinkFlow(updateCtx, outputCtx);
        Debug.Log("Contexts linked");

        // Blocks
        var burst = CreateModelInstance("Single Burst", BlockGUIDs);
        if (burst != null) AddToGraph(spawnCtx, burst);

        var pos = CreateModelInstance("|Set|_Position Sequential|Three Dimensional", BlockGUIDs);
        if (pos != null) AddToGraph(initCtx, pos);

        var lifetime = CreateModelInstance("|Set|_Lifetime", BlockGUIDs);
        if (lifetime != null) AddToGraph(initCtx, lifetime);

        var scaleMap = CreateModelInstance("|Set|_Scale from Map|2D", BlockGUIDs);
        if (scaleMap != null) AddToGraph(updateCtx, scaleMap);

        var colorMap = CreateModelInstance("|Set|_Color from Map|2D", BlockGUIDs);
        if (colorMap != null) AddToGraph(updateCtx, colorMap);

        Debug.Log("Blocks added");

        // Set Active
        SetActivation(burst, true);
        SetActivation(lifetime, true);
        SetActivation(scaleMap, true);
        SetActivation(colorMap, true);

        Debug.Log("Graph build complete!");
    }

    static void SetActivation(object block, bool active)
    {
        var blockType = block.GetType();
        var prop = blockType.GetProperty("activationSlot",
            BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        if (prop != null)
        {
            var slot = prop.GetValue(block);
            if (slot != null)
            {
                var valueProp = slot.GetType().GetProperty("value");
                if (valueProp != null)
                    valueProp.SetValue(slot, active);
            }
        }
    }
}
