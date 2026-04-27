using UnityEngine;
using UnityEditor;
using UnityEngine.VFX;

/// <summary>
/// Provides menu items to help configure the PillarGrid VFX Graph
/// and print setup instructions.
/// </summary>
public static class PillarGridVFXBuilder
{
    private const string AssetPath = "Assets/VFX/PillarGrid.vfx";

    [MenuItem("Tools/VFX/PillarGrid Setup Instructions", false, 100)]
    public static void PrintSetupInstructions()
    {
        var vfxAsset = AssetDatabase.LoadAssetAtPath<VisualEffectAsset>(AssetPath);
        string status = (vfxAsset != null) ? "FOUND" : "NOT FOUND";

        Debug.Log($"[PillarGrid] === Setup Guide ===\n" +
            $"VFX Asset: {status}\n\n" +
            $"1. Open {AssetPath} in the VFX Graph window (double-click)\n" +
            $"2. Open the Blackboard panel and add these exposed properties:\n" +
            $"   - AudioTexture (Texture2D)\n" +
            $"   - GridSize (UInt, default 20)\n" +
            $"   - Spacing (Float, default 0.5)\n" +
            $"   - PillarWidth (Float, default 0.2)\n" +
            $"   - PillarHeight (Float, default 1.0)\n" +
            $"   - Amplitude (Float, default 3.0)\n" +
            $"   - SmoothTime (Float, default 0.15)\n\n" +
            $"3. In the Initialize context, add a Set Position block:\n" +
            $"   - Use expression mode to compute grid position from particle index:\n" +
            $"   - X = (index % GridSize - (GridSize-1)/2) * Spacing\n" +
            $"   - Z = (index / GridSize - (GridSize-1)/2) * Spacing\n" +
            $"   - Y = PillarHeight * 0.5\n\n" +
            $"4. In the Update context:\n" +
            $"   - Add Sample Texture2D operator with AudioTexture\n" +
            $"   - Use grid UV = ((index%GridSize+0.5)/GridSize, (index/GridSize+0.5)/GridSize)\n" +
            $"   - Set Y position += sampled value * Amplitude\n\n" +
            $"5. In the Output context, set primitive type to Cube\n\n" +
            $"6. Bind the VFX asset to the existing PillarGrid object in your current scene\n\n" +
            $"The C# controller (PillarGridController) handles audio analysis and\n" +
            $"updates the AudioTexture each frame.");
    }
}
