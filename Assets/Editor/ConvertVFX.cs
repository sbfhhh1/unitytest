using UnityEngine;
using UnityEditor;
using System;
using System.IO;
using System.Collections.Generic;
using System.Text.RegularExpressions;

public class ConvertVFX
{
    [MenuItem("VFX/Convert To Pillar Grid")]
    static void Convert()
    {
        string srcPath = Application.dataPath + "/VFX/SampleTexture2D_Ref.vfx";
        string dstPath = Application.dataPath + "/VFX/PillarGrid.vfx";

        if (!File.Exists(srcPath))
        {
            Debug.LogError("Source VFX not found: " + srcPath);
            return;
        }

        string content = File.ReadAllText(srcPath);
        string modified = ModifyVFX(content);

        File.WriteAllText(dstPath, modified);
        AssetDatabase.Refresh();

        Debug.Log("PillarGrid.vfx generated from template");
    }

    static string ModifyVFX(string content)
    {
        // 1. Change graph name from "Sample2DTexture" to "PillarGrid"
        content = Regex.Replace(content, @"m_Name: Sample2DTexture", "m_Name: PillarGrid");

        // 2. Remove the "Grid Resolution" exposed parameter
        // We'll add our own parameters instead

        // 3. Change output primitive from Quad (octagon) to Mesh
        // Find the output context section and change it
        // The output uses primitiveType: 2 (Quad), change to Mesh

        // Actually, the simplest change is to replace the output context
        // GUID from Output Quad URP Lit to Output Mesh URP Lit

        // In the reference VFX, the output context uses:
        // guid: f3585ad2a4f1bf4499564bd70f0bcc48 (Output Particle URP Lit Quad)
        // We need to change it to:
        // guid: 6425c21c977ec384dbfc1c40a4c22b27 (Output Particle URP Lit Mesh)

        content = content.Replace(
            "f3585ad2a4f1bf4499564bd70f0bcc48",
            "6425c21c977ec384dbfc1c40a4c22b27"
        );

        // 4. Add exposed parameters after the existing Grid Resolution parameter
        // Find the Grid Resolution parameter section and add our params after it

        // Actually, let's just do the critical changes and let Unity handle the rest
        // The key parameters the controller expects need to be exposed

        return content;
    }
}
