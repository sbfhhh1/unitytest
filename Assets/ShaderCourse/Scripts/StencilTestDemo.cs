// ============================================================================
// StencilTestDemo.cs - 模板测试演示脚本
// ============================================================================
//
// 【对应课程】第三课 - 模板测试
//
// 【功能说明】
// 演示模板测试的工作原理
// 实现传送门、遮罩等常见效果
//
// 【核心知识点】
// 1. 模板缓冲区：每像素一个整数值
// 2. 比较函数：Always/Never/Equal/NotEqual等
// 3. 操作：Keep/Replace/Zero/Incr/Decr
// ============================================================================

using UnityEngine;

[ExecuteInEditMode]
public class StencilTestDemo : MonoBehaviour
{
    public enum StencilMode
    {
        None,           // 不使用模板测试
        Portal,         // 传送门效果
        Mask,           // 遮罩效果
        Outline         // 描边效果
    }
    
    [Header("=== 模板测试模式 ===")]
    public StencilMode mode = StencilMode.None;
    
    [Header("=== 模板参数 ===")]
    [Tooltip("参考值 - 用于比较")]
    [Range(0, 255)]
    public int referenceValue = 1;
    
    [Tooltip("比较函数")]
    public UnityEngine.Rendering.CompareFunction comparison = UnityEngine.Rendering.CompareFunction.Equal;
    
    [Tooltip("通过测试后的操作")]
    public UnityEngine.Rendering.StencilOp passOperation = UnityEngine.Rendering.StencilOp.Keep;
    
    [Tooltip("测试失败后的操作")]
    public UnityEngine.Rendering.StencilOp failOperation = UnityEngine.Rendering.StencilOp.Keep;
    
    [Header("=== 显示选项 ===")]
    public bool showDebugInfo = true;
    
    private Material material;
    
    void Start()
    {
        Renderer renderer = GetComponent<Renderer>();
        if (renderer != null)
        {
            material = renderer.sharedMaterial;
        }
        ApplyStencilSettings();
    }
    
    void OnValidate()
    {
        ApplyStencilSettings();
    }
    
    void ApplyStencilSettings()
    {
        if (material == null) return;
        
        // 根据模式设置模板参数
        switch (mode)
        {
            case StencilMode.Portal:
                // 传送门：先写入模板，再只在模板区域渲染
                material.SetInt("_StencilRef", referenceValue);
                material.SetInt("_StencilComp", (int)UnityEngine.Rendering.CompareFunction.Always);
                material.SetInt("_StencilPass", (int)UnityEngine.Rendering.StencilOp.Replace);
                break;
                
            case StencilMode.Mask:
                // 遮罩：只在有模板值的区域渲染
                material.SetInt("_StencilRef", referenceValue);
                material.SetInt("_StencilComp", (int)UnityEngine.Rendering.CompareFunction.Equal);
                material.SetInt("_StencilPass", (int)UnityEngine.Rendering.StencilOp.Keep);
                break;
                
            case StencilMode.Outline:
                // 描边：渲染放大的模型，排除内部
                material.SetInt("_StencilRef", referenceValue);
                material.SetInt("_StencilComp", (int)UnityEngine.Rendering.CompareFunction.NotEqual);
                material.SetInt("_StencilPass", (int)UnityEngine.Rendering.StencilOp.Keep);
                break;
                
            default:
                // 禁用模板测试
                material.SetInt("_StencilComp", (int)UnityEngine.Rendering.CompareFunction.Always);
                break;
        }
    }
    
    void OnGUI()
    {
        if (!showDebugInfo) return;
        
        GUILayout.BeginArea(new Rect(10, 10, 350, 280));
        GUILayout.BeginVertical("box");
        
        GUI.skin.label.fontSize = 14;
        GUI.skin.label.fontStyle = FontStyle.Bold;
        GUILayout.Label("=== 模板测试演示 ===");
        GUI.skin.label.fontSize = 12;
        GUI.skin.label.fontStyle = FontStyle.Normal;
        
        GUILayout.Space(10);
        
        GUILayout.Label("当前模式: " + mode);
        GUILayout.Label("参考值: " + referenceValue);
        GUILayout.Label("比较函数: " + comparison);
        GUILayout.Label("通过操作: " + passOperation);
        
        GUILayout.Space(10);
        
        GUI.color = Color.cyan;
        GUILayout.Label("=== 模板测试原理 ===");
        GUI.color = Color.white;
        
        GUILayout.Label("1. 执行时机：Alpha测试之后");
        GUILayout.Label("2. 模板缓冲区：每像素一个整数");
        GUILayout.Label("3. 比较模板值与参考值");
        GUILayout.Label("4. 根据结果决定是否渲染");
        GUILayout.Label("5. 可更新模板值");
        
        GUILayout.Space(10);
        
        GUI.color = Color.yellow;
        GUILayout.Label("=== 应用场景 ===");
        GUI.color = Color.white;
        
        GUILayout.Label("传送门、遮罩、描边、阴影体积");
        
        GUILayout.EndVertical();
        GUILayout.EndArea();
    }
}

// ============================================================================
// 【课程知识点总结 - 模板测试】
// ============================================================================
//
// 1. 模板缓冲区
//    - 每个像素一个整数值（通常8位，0-255）
//    - 初始值为0
//    - 用于标记特定区域
//
// 2. 比较函数
//    - Never：从不通过
//    - Less：< 参考值
//    - Equal：= 参考值
//    - LEqual：≤ 参考值
//    - Greater：> 参考值
//    - NotEqual：≠ 参考值
//    - GEqual：≥ 参考值
//    - Always：总是通过
//
// 3. 操作类型
//    - Keep：保持原值
//    - Zero：设为0
//    - Replace：替换为参考值
//    - IncrSat：加1（饱和）
//    - DecrSat：减1（饱和）
//    - Invert：按位取反
//
// 4. 应用场景
//    - 传送门效果
//    - 卡通描边
//    - UI遮罩
//    - 阴影体积
//
// ============================================================================