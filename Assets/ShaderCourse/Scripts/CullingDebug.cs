// ============================================================================
// CullingDebug.cs - 剔除调试脚本
// ============================================================================
//
// 【PPT对应章节】
// - CPU应用程序阶段 > 剔除 (Culling)
//
// 【功能说明】
// 可视化显示Unity的剔除系统工作原理
// ============================================================================

using UnityEngine;
using System.Collections.Generic;

public class CullingDebug : MonoBehaviour
{
    [Header("=== 显示设置 ===")]
    public bool showDebug = true;
    public Rect debugRect = new Rect(10, 10, 280, 280);
    
    [Header("=== 剔除设置 ===")]
    public bool frustumCulling = true;
    public bool occlusionCulling = false;
    public LayerMask layerMask = ~0;
    
    private int totalObjects = 0;
    private int visibleObjects = 0;
    private int culledObjects = 0;
    
    private List<GameObject> objectList = new List<GameObject>();
    
    void Start()
    {
        RefreshObjectList();
    }
    
    void Update()
    {
        UpdateCullingStats();
    }
    
    void RefreshObjectList()
    {
        objectList.Clear();
        Renderer[] renderers = FindObjectsOfType<Renderer>();
        foreach (var rend in renderers)
        {
            if (rend != null && rend.gameObject != null)
            {
                objectList.Add(rend.gameObject);
            }
        }
    }
    
    void UpdateCullingStats()
    {
        Camera cam = GetComponent<Camera>();
        if (cam == null) return;
        
        totalObjects = objectList.Count;
        visibleObjects = 0;
        culledObjects = 0;
        
        for (int i = objectList.Count - 1; i >= 0; i--)
        {
            GameObject obj = objectList[i];
            if (obj == null)
            {
                objectList.RemoveAt(i);
                continue;
            }
            
            int layer = obj.layer;
            if ((layerMask & (1 << layer)) == 0)
            {
                culledObjects++;
                continue;
            }
            
            Renderer renderer = obj.GetComponent<Renderer>();
            if (renderer == null)
            {
                culledObjects++;
                continue;
            }
            
            if (renderer.isVisible && cam.enabled)
            {
                visibleObjects++;
            }
            else
            {
                culledObjects++;
            }
        }
    }
    
    void OnGUI()
    {
        if (!showDebug) return;
        
        GUILayout.BeginArea(debugRect);
        GUILayout.BeginVertical("box");
        
        GUI.skin.label.fontSize = 14;
        GUI.skin.label.fontStyle = FontStyle.Bold;
        GUILayout.Label("剔除调试面板");
        GUI.skin.label.fontSize = 11;
        GUI.skin.label.fontStyle = FontStyle.Normal;
        
        GUILayout.Space(10);
        
        GUI.color = Color.yellow;
        GUILayout.Label("=== 统计信息 ===");
        GUI.color = Color.white;
        
        GUILayout.Label("总物体数: " + totalObjects);
        GUILayout.Label("可见物体: " + visibleObjects);
        
        GUI.color = Color.red;
        GUILayout.Label("已剔除: " + culledObjects);
        GUI.color = Color.white;
        
        if (totalObjects > 0)
        {
            float cullRate = (float)culledObjects / totalObjects * 100f;
            GUILayout.Label("剔除率: " + cullRate.ToString("F1") + "%");
        }
        
        GUILayout.Space(10);
        
        GUI.color = Color.cyan;
        GUILayout.Label("=== 剔除类型 ===");
        GUI.color = Color.white;
        
        GUILayout.Label("1. 视锥体剔除 (Frustum)");
        GUILayout.Label("2. 层级剔除 (Layer)");
        GUILayout.Label("3. 遮挡剔除 (Occlusion)");
        
        GUILayout.EndVertical();
        GUILayout.EndArea();
    }
    
    void OnDrawGizmos()
    {
        Camera cam = GetComponent<Camera>();
        if (cam == null) return;
        
        Gizmos.color = Color.yellow;
        
        float near = cam.nearClipPlane;
        float far = cam.farClipPlane;
        float fov = cam.fieldOfView;
        float aspect = cam.aspect;
        
        float tanFov = Mathf.Tan(fov * 0.5f * Mathf.Deg2Rad);
        
        Vector3 nearCenter = cam.transform.position + cam.transform.forward * near;
        Vector3 farCenter = cam.transform.position + cam.transform.forward * far;
        
        float nearHeight = near * tanFov;
        float nearWidth = nearHeight * aspect;
        float farHeight = far * tanFov;
        float farWidth = farHeight * aspect;
        
        Vector3 p1 = nearCenter - cam.transform.right * nearWidth - cam.transform.up * nearHeight;
        Vector3 p2 = nearCenter + cam.transform.right * nearWidth - cam.transform.up * nearHeight;
        Vector3 p3 = nearCenter + cam.transform.right * nearWidth + cam.transform.up * nearHeight;
        Vector3 p4 = nearCenter - cam.transform.right * nearWidth + cam.transform.up * nearHeight;
        
        Vector3 p5 = farCenter - cam.transform.right * farWidth - cam.transform.up * farHeight;
        Vector3 p6 = farCenter + cam.transform.right * farWidth - cam.transform.up * farHeight;
        Vector3 p7 = farCenter + cam.transform.right * farWidth + cam.transform.up * farHeight;
        Vector3 p8 = farCenter - cam.transform.right * farWidth + cam.transform.up * farHeight;
        
        Gizmos.DrawLine(p1, p2);
        Gizmos.DrawLine(p2, p3);
        Gizmos.DrawLine(p3, p4);
        Gizmos.DrawLine(p4, p1);
        
        Gizmos.DrawLine(p5, p6);
        Gizmos.DrawLine(p6, p7);
        Gizmos.DrawLine(p7, p8);
        Gizmos.DrawLine(p8, p5);
        
        Gizmos.DrawLine(p1, p5);
        Gizmos.DrawLine(p2, p6);
        Gizmos.DrawLine(p3, p7);
        Gizmos.DrawLine(p4, p8);
    }
}