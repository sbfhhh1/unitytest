// ============================================================================
// AlphaTestDemo.cs - Alpha测试演示脚本
// ============================================================================
//
// 【对应课程】第三课 - Alpha测试
//
// 【功能说明】
// 演示Alpha测试的工作原理
// 通过调节阈值观察透明裁剪效果
//
// 【核心知识点】
// 1. clip()函数：低于阈值丢弃像素
// 2. Alpha测试 vs Alpha混合的区别
// 3. 不需要排序的原因
// ============================================================================

using UnityEngine;

[ExecuteInEditMode]
public class AlphaTestDemo : MonoBehaviour
{
    [Header("=== Alpha测试参数 ===")]
    [Tooltip("Alpha测试阈值 - 低于此值的像素被丢弃")]
    [Range(0f, 1f)]
    public float cutoff = 0.5f;
    
    [Header("=== 演示模式 ===")]
    [Tooltip("自动动画 - 阈值自动变化")]
    public bool autoAnimate = false;
    
    [Tooltip("动画速度")]
    public float animSpeed = 0.5f;
    
    [Header("=== 显示选项 ===")]
    public bool showDebugInfo = true;
    
    private MaterialPropertyBlock propBlock;
    private Renderer renderer;
    
    // Shader属性ID
    private static readonly int CutoffID = Shader.PropertyToID("_Cutoff");
    
    void Start()
    {
        renderer = GetComponent<Renderer>();
        propBlock = new MaterialPropertyBlock();
    }
    
    void Update()
    {
        if (autoAnimate)
        {
            // 循环动画：0 → 1 → 0
            float t = Mathf.PingPong(Time.time * animSpeed, 1f);
            cutoff = t;
        }
        
        ApplyCutoff();
    }
    
    void ApplyCutoff()
    {
        if (renderer == null) return;
        
        renderer.GetPropertyBlock(propBlock);
        propBlock.SetFloat(CutoffID, cutoff);
        renderer.SetPropertyBlock(propBlock);
    }
    
    void OnGUI()
    {
        if (!showDebugInfo) return;
        
        GUILayout.BeginArea(new Rect(10, 10, 320, 200));
        GUILayout.BeginVertical("box");
        
        GUI.skin.label.fontSize = 14;
        GUI.skin.label.fontStyle = FontStyle.Bold;
        GUILayout.Label("=== Alpha测试演示 ===");
        GUI.skin.label.fontSize = 12;
        GUI.skin.label.fontStyle = FontStyle.Normal;
        
        GUILayout.Space(10);
        
        GUILayout.Label("当前阈值: " + cutoff.ToString("F2"));
        GUILayout.Label("像素Alpha < " + cutoff.ToString("F2") + " → 被丢弃");
        
        GUILayout.Space(10);
        
        GUI.color = Color.yellow;
        GUILayout.Label("=== 原理说明 ===");
        GUI.color = Color.white;
        
        GUILayout.Label("1. Alpha测试在片元Shader后执行");
        GUILayout.Label("2. 低于阈值的像素被完全丢弃");
        GUILayout.Label("3. 不写入深度缓冲区");
        GUILayout.Label("4. 无需排序，性能优于透明混合");
        
        GUILayout.EndVertical();
        GUILayout.EndArea();
    }
    
    void OnValidate()
    {
        ApplyCutoff();
    }
}

// ============================================================================
// 【课程知识点总结 - Alpha测试】
// ============================================================================
//
// 1. 执行位置
//    - 片元Shader输出后
//    - 模板测试之前
//
// 2. 核心函数
//    - clip(x)：当x < 0时丢弃像素
//    - 等价于：if (x < 0) discard;
//
// 3. 特点
//    - 完全透明或完全不透明（二值化）
//    - 不需要排序
//    - 不写入深度缓冲区
//    - 性能优于Alpha混合
//
// 4. 应用场景
//    - 树叶、草地
//    - 栅栏、铁丝网
//    - 粒子特效
//
// ============================================================================