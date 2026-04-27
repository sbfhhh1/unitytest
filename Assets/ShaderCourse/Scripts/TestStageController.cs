// ============================================================================
// TestStageController.cs - 测试阶段控制脚本
// ============================================================================
//
// 【PPT对应章节】
// - 测试阶段 > Alpha测试、深度测试、模板测试
// - 输出合并 > 帧缓冲区
// ============================================================================

using UnityEngine;

public class TestStageController : MonoBehaviour
{
    [Header("=== Alpha测试 ===")]
    public bool enableAlphaTest = false;
    public float alphaThreshold = 0.5f;
    
    [Header("=== 深度测试 ===")]
    public bool depthWrite = true;
    public ZTestMode depthTestMode = ZTestMode.Always;
    
    [Header("=== 混合模式 ===")]
    public bool enableTransparency = false;
    public BlendMode blendMode = BlendMode.Transparent;
    
    [Header("=== 渲染队列 ===")]
    public int renderQueue = 3000;
    
    [Header("=== 调试选项 ===")]
    public bool showDebugInfo = true;
    
    private Renderer[] renderers;

    void Start()
    {
        renderers = GetComponentsInChildren<Renderer>();
        ApplySettings();
    }
    
    void Update()
    {
        ApplySettings();
    }
    
    void ApplySettings()
    {
        foreach (var rend in renderers)
        {
            if (rend == null) continue;
            
            rend.material.renderQueue = renderQueue;
            
            if (enableAlphaTest)
            {
                rend.material.EnableKeyword("ALPHATEST_ON");
                rend.material.SetFloat("_Cutoff", alphaThreshold);
            }
            else
            {
                rend.material.DisableKeyword("ALPHATEST_ON");
            }
            
            if (depthWrite)
                rend.material.SetInt("_ZWrite", 1);
            else
                rend.material.SetInt("_ZWrite", 0);
            
            rend.material.SetInt("_ZTest", (int)depthTestMode);
            
            if (enableTransparency)
            {
                rend.material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                rend.material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                rend.material.SetInt("_ZWrite", 0);
            }
            else
            {
                rend.material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                rend.material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
            }
        }
    }
    
    void OnGUI()
    {
        if (!showDebugInfo) return;
        
        GUILayout.BeginArea(new Rect(10, 10, 280, 220));
        GUILayout.BeginVertical("box");
        
        GUILayout.Label("=== 测试阶段控制器 ===");
        GUILayout.Space(5);
        GUILayout.Label("渲染队列: " + renderQueue);
        GUILayout.Label("Alpha测试: " + (enableAlphaTest ? "启用" : "关闭"));
        GUILayout.Label("深度写入: " + (depthWrite ? "启用" : "关闭"));
        GUILayout.Label("深度测试: " + depthTestMode);
        GUILayout.Label("混合模式: " + (enableTransparency ? blendMode.ToString() : "不透明"));
        
        GUILayout.Space(10);
        GUILayout.Label("提示：调整参数观察效果");
        
        GUILayout.EndVertical();
        GUILayout.EndArea();
    }
    
    public enum ZTestMode
    {
        Never = 0,
        Less = 1,
        Equal = 2,
        LEqual = 3,
        Greater = 4,
        NotEqual = 5,
        GEqual = 6,
        Always = 7
    }
    
    public enum BlendMode
    {
        Transparent,
        Additive,
        SoftAdditive,
        Multiply
    }
}