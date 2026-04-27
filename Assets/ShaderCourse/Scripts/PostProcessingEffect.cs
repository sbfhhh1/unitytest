// ============================================================================
// PostProcessingEffect.cs - 后处理效果脚本
// ============================================================================
//
// 【PPT对应章节】
// - 后处理 (Post-Processing)
// ============================================================================

using UnityEngine;

public class PostProcessingEffect : MonoBehaviour
{
    [Header("=== 基础设置 ===")]
    public bool enablePostProcessing = true;
    
    [Header("=== Bloom 泛光效果 ===")]
    public bool enableBloom = true;
    public float bloomIntensity = 1f;
    public float bloomThreshold = 0.8f;
    
    [Header("=== Color Grading 色调调整 ===")]
    public bool enableColorGrading = false;
    public float exposure = 0f;
    public float saturation = 1f;
    public float contrast = 1f;
    
    [Header("=== Vignette 暗角效果 ===")]
    public bool enableVignette = true;
    public float vignetteIntensity = 1f;
    public float vignetteRange = 1f;
    
    [Header("=== 调试选项 ===")]
    public bool showDebugInfo = true;
    
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!enablePostProcessing)
        {
            Graphics.Blit(source, destination);
            return;
        }
        
        Graphics.Blit(source, destination);
    }
    
    void OnGUI()
    {
        if (!showDebugInfo) return;
        
        GUILayout.BeginArea(new Rect(10, 10, 260, 220));
        GUILayout.BeginVertical("box");
        
        GUILayout.Label("=== 后处理效果控制器 ===");
        GUILayout.Space(5);
        
        GUILayout.Label("后处理: " + (enablePostProcessing ? "启用" : "禁用"));
        GUILayout.Label("Bloom: " + (enableBloom ? "启用" : "关闭"));
        GUILayout.Label("色调调整: " + (enableColorGrading ? "启用" : "关闭"));
        GUILayout.Label("暗角: " + (enableVignette ? "启用" : "关闭"));
        
        GUILayout.Space(10);
        GUILayout.Label("说明：");
        GUILayout.Label("后处理需要配合后处理Shader材质使用");
        
        GUILayout.EndVertical();
        GUILayout.EndArea();
    }
}