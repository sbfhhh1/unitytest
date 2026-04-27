// ============================================================================
// DepthTestDemo.cs - 深度测试演示脚本
// ============================================================================
//
// 【对应课程】第三课 - 深度测试
//
// 【功能说明】
// 演示深度测试的工作原理
// 可视化深度缓冲区内容
//
// 【核心知识点】
// 1. ZWrite：是否写入深度缓冲区
// 2. ZTest：深度比较条件
// 3. 深度冲突(Z-Fighting)问题
// ============================================================================

using UnityEngine;

[ExecuteInEditMode]
public class DepthTestDemo : MonoBehaviour
{
    public enum DepthTestMode
    {
        Opaque,         // 不透明物体
        Transparent,    // 半透明物体
        AlwaysRender,   // 总是渲染（UI等）
        XRay            // X光效果（只渲染被遮挡部分）
    }
    
    [Header("=== 深度测试模式 ===")]
    public DepthTestMode mode = DepthTestMode.Opaque;
    
    [Header("=== 深度参数 ===")]
    [Tooltip("是否写入深度缓冲区")]
    public bool zWrite = true;
    
    [Tooltip("深度比较函数")]
    public UnityEngine.Rendering.CompareFunction zTest = UnityEngine.Rendering.CompareFunction.LessEqual;
    
    [Header("=== 深度偏移（解决Z-Fighting）===")]
    [Tooltip("深度偏移因子")]
    [Range(-1f, 1f)]
    public float depthBias = 0f;
    
    [Tooltip("深度偏移单位")]
    [Range(-1f, 1f)]
    public float depthSlopeScale = 0f;
    
    [Header("=== 显示选项 ===")]
    public bool showDebugInfo = true;
    
    private Material material;
    private Renderer renderer;
    
    void Start()
    {
        renderer = GetComponent<Renderer>();
        if (renderer != null)
        {
            material = renderer.sharedMaterial;
        }
        ApplyDepthSettings();
    }
    
    void OnValidate()
    {
        ApplyDepthSettings();
    }
    
    void ApplyDepthSettings()
    {
        if (material == null) return;
        
        // 根据模式设置深度参数
        switch (mode)
        {
            case DepthTestMode.Opaque:
                zWrite = true;
                zTest = UnityEngine.Rendering.CompareFunction.LessEqual;
                break;
                
            case DepthTestMode.Transparent:
                zWrite = false;
                zTest = UnityEngine.Rendering.CompareFunction.LessEqual;
                break;
                
            case DepthTestMode.AlwaysRender:
                zWrite = false;
                zTest = UnityEngine.Rendering.CompareFunction.Always;
                break;
                
            case DepthTestMode.XRay:
                zWrite = false;
                zTest = UnityEngine.Rendering.CompareFunction.Greater;
                break;
        }
        
        // 应用设置
        material.SetInt("_ZWrite", zWrite ? 1 : 0);
        material.SetInt("_ZTest", (int)zTest);
        
        // 应用深度偏移
        if (renderer != null)
        {
            material.SetFloat("_DepthBias", depthBias);
            material.SetFloat("_DepthSlopeScale", depthSlopeScale);
        }
    }
    
    void OnGUI()
    {
        if (!showDebugInfo) return;
        
        GUILayout.BeginArea(new Rect(10, 10, 350, 320));
        GUILayout.BeginVertical("box");
        
        GUI.skin.label.fontSize = 14;
        GUI.skin.label.fontStyle = FontStyle.Bold;
        GUILayout.Label("=== 深度测试演示 ===");
        GUI.skin.label.fontSize = 12;
        GUI.skin.label.fontStyle = FontStyle.Normal;
        
        GUILayout.Space(10);
        
        GUILayout.Label("当前模式: " + mode);
        GUILayout.Label("ZWrite: " + (zWrite ? "On" : "Off"));
        GUILayout.Label("ZTest: " + zTest);
        
        GUILayout.Space(10);
        
        GUI.color = Color.green;
        GUILayout.Label("=== 深度测试原理 ===");
        GUI.color = Color.white;
        
        GUILayout.Label("1. 执行时机：模板测试之后");
        GUILayout.Label("2. 深度值越小 = 越靠近摄像机");
        GUILayout.Label("3. 比较片元深度与缓冲区深度");
        GUILayout.Label("4. 通过测试后可写入新深度");
        
        GUILayout.Space(10);
        
        GUI.color = Color.magenta;
        GUILayout.Label("=== 常见问题 ===");
        GUI.color = Color.white;
        
        GUILayout.Label("Z-Fighting（深度冲突）:");
        GUILayout.Label("   两个面重合时闪烁");
        GUILayout.Label("   解决：调整偏移或增加间距");
        
        GUILayout.Space(5);
        
        GUILayout.Label("半透明排序问题:");
        GUILayout.Label("   现象：遮挡不正确");
        GUILayout.Label("   解决：从后往前排序渲染");
        
        GUILayout.EndVertical();
        GUILayout.EndArea();
    }
}

// ============================================================================
// 【课程知识点总结 - 深度测试】
// ============================================================================
//
// 1. 深度缓冲区 (Z Buffer)
//    - 存储每个像素到摄像机的距离
//    - 深度值范围：0（近裁剪面）~ 1（远裁剪面）
//    - 深度值越小 = 越靠近摄像机
//
// 2. ZWrite（深度写入）
//    - On：通过测试后写入深度缓冲区
//    - Off：不写入深度缓冲区
//    - 不透明物体：On
//    - 半透明物体：Off
//
// 3. ZTest（深度比较）
//    - Less：深度 < 缓冲区值 → 通过
//    - Equal：深度 = 缓冲区值 → 通过
//    - LEqual：深度 ≤ 缓冲区值 → 通过（默认）
//    - Greater：深度 > 缓冲区值 → 通过
//    - Always：总是通过
//
// 4. 深度冲突 (Z-Fighting)
//    - 原因：两个面深度值过于接近
//    - 现象：画面闪烁
//    - 解决：
//      - 增加面间距
//      - 使用深度偏移
//      - 调整近/远裁剪面比例
//
// 5. 深度精度优化
//    - 近裁剪面不要设置太小
//    - 远裁剪面不要设置太大
//    - 推荐比例：Far/Near < 10000
//
// ============================================================================