using UnityEngine;

public class PipelineVisualizer : MonoBehaviour
{
    public bool showPipeline = true;
    public Rect displayRect = new Rect(10, 10, 280, 380);
    
    public bool enableCulling = true;
    public bool enableSorting = true;
    public bool enableVertexShader = true;
    public bool enableRasterization = true;
    public bool enableFragmentShader = true;
    public bool enableTests = true;
    
    private int drawCalls = 0;
    private int triangles = 0;
    private int vertices = 0;
    private float lastUpdateTime = 0f;
    
    void Update()
    {
        if (Time.time - lastUpdateTime > 1f)
        {
            UpdateStatistics();
            lastUpdateTime = Time.time;
        }
    }
    
    void UpdateStatistics()
    {
        Renderer[] renderers = FindObjectsOfType<Renderer>();
        triangles = 0;
        vertices = 0;
        drawCalls = renderers.Length;
        
        foreach (Renderer rend in renderers)
        {
            if (rend is MeshRenderer)
            {
                MeshRenderer mr = (MeshRenderer)rend;
                MeshFilter mf = mr.GetComponent<MeshFilter>();
                if (mf != null && mf.sharedMesh != null)
                {
                    triangles += mf.sharedMesh.triangles.Length / 3;
                    vertices += mf.sharedMesh.vertexCount;
                }
            }
        }
    }
    
    void OnGUI()
    {
        if (!showPipeline) return;
        
        GUILayout.BeginArea(displayRect);
        GUILayout.BeginVertical("box");
        
        GUILayout.Label("=== Pipeline Flow ===");
        GUILayout.Space(10);
        
        GUILayout.BeginVertical("box");
        GUILayout.Label("CPU Stage");
        GUILayout.Label("  Culling: " + (enableCulling ? "ON" : "OFF"));
        GUILayout.Label("  Sort: " + (enableSorting ? "ON" : "OFF"));
        GUILayout.Label("  Data Pack");
        GUILayout.EndVertical();
        
        GUILayout.Label("     |");
        GUILayout.Label("     v");
        
        GUILayout.BeginVertical("box");
        GUILayout.Label("GPU Stage");
        GUILayout.Label("  VertexShader: " + (enableVertexShader ? "ON" : "OFF"));
        GUILayout.Label("  Rasterization: " + (enableRasterization ? "ON" : "OFF"));
        GUILayout.Label("  FragmentShader: " + (enableFragmentShader ? "ON" : "OFF"));
        GUILayout.EndVertical();
        
        GUILayout.Label("     |");
        GUILayout.Label("     v");
        
        GUILayout.BeginVertical("box");
        GUILayout.Label("Test Stage");
        GUILayout.Label("  AlphaTest: " + (enableTests ? "ON" : "OFF"));
        GUILayout.Label("  StencilTest: " + (enableTests ? "ON" : "OFF"));
        GUILayout.Label("  DepthTest: " + (enableTests ? "ON" : "OFF"));
        GUILayout.EndVertical();
        
        GUILayout.Label("     |");
        GUILayout.Label("     v");
        
        GUILayout.BeginVertical("box");
        GUILayout.Label("Output Merge");
        GUILayout.Label("  Blending");
        GUILayout.Label("  FrameBuffer");
        GUILayout.EndVertical();
        
        GUILayout.Space(10);
        GUILayout.Label("=== Stats ===");
        GUILayout.Label("Draw Calls: " + drawCalls);
        GUILayout.Label("Triangles: " + triangles);
        GUILayout.Label("Vertices: " + vertices);
        
        GUILayout.EndVertical();
        GUILayout.EndArea();
    }
}