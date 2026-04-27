// ============================================================================
// BlendingDemo.cs - 混合模式演示脚本
// ============================================================================
//
// 【对应课程】第四课 - 输出合并与后处理
//
// 【功能说明】
// 演示不同混合模式的效果
// 实时切换和比较各种混合方式
//
// 【核心知识点】
// 1. 混合公式：Result = Src × SrcFactor + Dst × DstFactor
// 2. SrcFactor/DstFactor的各种组合
// 3. 半透明物体的排序问题
// ============================================================================

using UnityEngine;

[ExecuteInEditMode]
public class BlendingDemo : MonoBehaviour
{
    public enum BlendMode
    {
        Opaque,         // 不透明
        AlphaBlend,     // 标准透明混合
        Additive,       // 叠加（光效）
        Multiply,       // 乘法（阴影）
        Screen,         // 滤色
        Premultiplied   // 预乘Alpha
    }
    
    [Header("=== 混合模式 ===")]
    public BlendMode blendMode = BlendMode.AlphaBlend;
    
    [Header("=== 透明度 ===")]
    [Range(0f, 1f)]
    public float alpha = 0.7f;
    
    [Header("=== 排序设置 ===")]
    [Tooltip("渲染队列值")]
    [Range(2000, 4000)]
    public int renderQueue = 3000;
    
    [Tooltip("是否从后往前排序")]
    public bool sortByDistance = true;
    
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
        ApplyBlendSettings();
    }
    
    void OnValidate()
    {
        ApplyBlendSettings();
    }
    
    void ApplyBlendSettings()
    {
        if (material == null) return;
        
        // 设置渲染队列
        material.renderQueue = renderQueue;
        
        // 设置Alpha
        Color color = material.GetColor("_BaseColor");
        color.a = alpha;
        material.SetColor("_BaseColor", color);
        
        // 根据混合模式设置Blend参数
        switch (blendMode)
        {
            case BlendMode.Opaque:
                // 不透明：禁用混合
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                material.SetInt("_ZWrite", 1);
                break;
                
            case BlendMode.AlphaBlend:
                // 标准透明混合
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                material.SetInt("_ZWrite", 0);
                break;
                
            case BlendMode.Additive:
                // 叠加模式（火焰、光效）
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_ZWrite", 0);
                break;
                
            case BlendMode.Multiply:
                // 乘法模式（阴影）
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.DstColor);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                material.SetInt("_ZWrite", 0);
                break;
                
            case BlendMode.Screen:
                // 滤色模式
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcColor);
                material.SetInt("_ZWrite", 0);
                break;
                
            case BlendMode.Premultiplied:
                // 预乘Alpha
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                material.SetInt("_ZWrite", 0);
                break;
        }
    }
    
    void OnGUI()
    {
        if (!showDebugInfo) return;
        
        GUILayout.BeginArea(new Rect(10, 10, 380, 340));
        GUILayout.BeginVertical("box");
        
        GUI.skin.label.fontSize = 14;
        GUI.skin.label.fontStyle = FontStyle.Bold;
        GUILayout.Label("=== 混合模式演示 ===");
        GUI.skin.label.fontSize = 12;
        GUI.skin.label.fontStyle = FontStyle.Normal;
        
        GUILayout.Space(10);
        
        GUILayout.Label("当前模式: " + blendMode);
        GUILayout.Label("透明度: " + alpha.ToString("F2"));
        GUILayout.Label("渲染队列: " + renderQueue);
        
        GUILayout.Space(10);
        
        GUI.color = Color.cyan;
        GUILayout.Label("=== 混合公式 ===");
        GUI.color = Color.white;
        
        GUILayout.Label("Result = Src × SrcFactor + Dst × DstFactor");
        
        GUILayout.Space(5);
        
        string formula = GetBlendFormula();
        GUILayout.Label(formula);
        
        GUILayout.Space(10);
        
        GUI.color = Color.yellow;
        GUILayout.Label("=== 各模式说明 ===");
        GUI.color = Color.white;
        
        GUILayout.Label("AlphaBlend: 标准透明效果");
        GUILayout.Label("Additive: 叠加亮度（火焰、光效）");
        GUILayout.Label("Multiply: 相乘变暗（阴影）");
        GUILayout.Label("Screen: 滤色变亮（高光）");
        GUILayout.Label("Premultiplied: 预乘Alpha优化");
        
        GUILayout.Space(10);
        
        GUI.color = Color.magenta;
        GUILayout.Label("=== 注意事项 ===");
        GUI.color = Color.white;
        
        GUILayout.Label("半透明物体需关闭ZWrite");
        GUILayout.Label("需从后往前排序渲染");
        
        GUILayout.EndVertical();
        GUILayout.EndArea();
    }
    
    string GetBlendFormula()
    {
        switch (blendMode)
        {
            case BlendMode.Opaque:
                return "Src × 1 + Dst × 0 = Src";
            case BlendMode.AlphaBlend:
                return "Src × SrcA + Dst × (1-SrcA)";
            case BlendMode.Additive:
                return "Src × 1 + Dst × 1";
            case BlendMode.Multiply:
                return "Src × DstColor + Dst × 0";
            case BlendMode.Screen:
                return "Src × 1 + Dst × (1-SrcColor)";
            case BlendMode.Premultiplied:
                return "Src × 1 + Dst × (1-SrcA)";
            default:
                return "";
        }
    }
}

// ============================================================================
// 【课程知识点总结 - 混合模式】
// ============================================================================
//
// 1. 混合公式
//    Result = Src × SrcFactor + Dst × DstFactor
//    - Src：当前片元颜色
//    - Dst：帧缓冲区颜色
//    - SrcFactor：源混合因子
//    - DstFactor：目标混合因子
//
// 2. 常用混合因子
//    - Zero：0
//    - One：1
//    - SrcColor：源颜色RGB
//    - SrcAlpha：源Alpha
//    - DstColor：目标颜色RGB
//    - DstAlpha：目标Alpha
//    - OneMinusSrcAlpha：1 - 源Alpha
//    - OneMinusDstColor：1 - 目标颜色
//
// 3. 常用混合模式
//    - AlphaBlend：透明效果
//      Blend SrcAlpha OneMinusSrcAlpha
//    - Additive：叠加效果
//      Blend One One
//    - Multiply：阴影效果
//      Blend DstColor Zero
//    - Screen：滤色效果
//      Blend One OneMinusSrcColor
//
// 4. 半透明渲染注意
//    - ZWrite Off：不写入深度
//    - 渲染队列 > 2500
//    - 从后往前排序
//    - 可能需要多Pass处理复杂情况
//
// ============================================================================