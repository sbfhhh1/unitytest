// ============================================================================
// TextureController.cs - 纹理技术控制脚本
// ============================================================================
//
// 【PPT对应章节】
// - GPU渲染阶段 > 片元Shader > 纹理技术
// - 纹理技术 > 纹理采样、纹理过滤、Mipmap、纹理寻址
// ============================================================================

using UnityEngine;

public class TextureController : MonoBehaviour
{
    [Header("=== 纹理采样 ===")]
    public Texture2D mainTexture;
    public Vector2 uvOffset = Vector2.zero;
    public Vector2 uvScale = Vector2.one;
    
    [Header("=== 纹理过滤 ===")]
    public FilterMode filterMode = FilterMode.Bilinear;
    public int anisotropicLevel = 0;
    
    [Header("=== 纹理寻址 ===")]
    public TextureWrapMode wrapMode = TextureWrapMode.Repeat;
    
    [Header("=== UV动画 ===")]
    public bool enableUVScroll = false;
    public Vector2 scrollSpeed = new Vector2(0.1f, 0f);
    
    [Header("=== 调试选项 ===")]
    public bool showDebugInfo = true;
    
    private Renderer targetRenderer;
    private Material targetMaterial;
    private Vector2 scrollOffset = Vector2.zero;

    void Start()
    {
        targetRenderer = GetComponent<Renderer>();
        if (targetRenderer != null)
        {
            targetMaterial = targetRenderer.material;
            ApplyTextureSettings();
        }
    }
    
    void Update()
    {
        if (enableUVScroll && targetMaterial != null)
        {
            scrollOffset.x += scrollSpeed.x * Time.deltaTime;
            scrollOffset.y += scrollSpeed.y * Time.deltaTime;
            targetMaterial.mainTextureOffset = uvOffset + scrollOffset;
        }
    }
    
    void ApplyTextureSettings()
    {
        if (targetMaterial == null || mainTexture == null) return;
        
        targetMaterial.mainTexture = mainTexture;
        targetMaterial.mainTextureScale = uvScale;
        targetMaterial.mainTextureOffset = uvOffset + (enableUVScroll ? scrollOffset : Vector2.zero);
        
        mainTexture.filterMode = filterMode;
        mainTexture.anisoLevel = anisotropicLevel;
        mainTexture.wrapMode = wrapMode;
    }
    
    public void CycleFilterMode()
    {
        if (filterMode == FilterMode.Point)
            filterMode = FilterMode.Bilinear;
        else if (filterMode == FilterMode.Bilinear)
            filterMode = FilterMode.Trilinear;
        else
            filterMode = FilterMode.Point;
        
        ApplyTextureSettings();
    }
    
    public void CycleWrapMode()
    {
        if (wrapMode == TextureWrapMode.Repeat)
            wrapMode = TextureWrapMode.Clamp;
        else if (wrapMode == TextureWrapMode.Clamp)
            wrapMode = TextureWrapMode.Mirror;
        else
            wrapMode = TextureWrapMode.Repeat;
        
        ApplyTextureSettings();
    }
    
    void OnGUI()
    {
        if (!showDebugInfo) return;
        
        GUILayout.BeginArea(new Rect(10, 10, 250, 200));
        GUILayout.BeginVertical("box");
        
        GUILayout.Label("=== 纹理控制器 ===");
        GUILayout.Space(5);
        
        GUILayout.Label("过滤模式: " + filterMode);
        GUILayout.Label("寻址模式: " + wrapMode);
        
        if (enableUVScroll)
        {
            GUILayout.Label("滚动偏移: " + scrollOffset.x.ToString("F2"));
        }
        
        GUILayout.Space(10);
        GUILayout.Label("快捷键:");
        GUILayout.Label("F - 切换过滤模式");
        GUILayout.Label("W - 切换寻址模式");
        GUILayout.Label("S - 切换滚动动画");
        
        GUILayout.EndVertical();
        GUILayout.EndArea();
    }
    
    void OnDisable()
    {
        if (targetMaterial != null)
        {
            Destroy(targetMaterial);
        }
    }
}