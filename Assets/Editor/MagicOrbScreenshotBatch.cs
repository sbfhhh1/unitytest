using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class MagicOrbScreenshotBatch
{
    public static void CaptureTutorialReplica()
    {
        EditorSceneManager.OpenScene("Assets/VFX/MagicOrb/MagicOrb_TestScene.unity", OpenSceneMode.Single);

        Camera camera = Camera.main;
        if (camera == null)
        {
            Debug.LogError("[MagicOrbScreenshotBatch] Main camera not found.");
            return;
        }

        GameObject root = GameObject.Find("MagicOrb_TutorialReplicaRoot");
        if (root == null)
        {
            Debug.LogError("[MagicOrbScreenshotBatch] Tutorial replica root not found.");
            return;
        }

        root.SetActive(true);
        GameObject legacy = GameObject.Find("MagicOrbRoot");
        if (legacy != null)
        {
            legacy.SetActive(false);
        }

        camera.transform.SetPositionAndRotation(new Vector3(0f, 0f, -4.35f), Quaternion.identity);
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(0.16f, 0.015f, 0.19f, 1f);

        const int width = 1280;
        const int height = 720;
        RenderTexture target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32);
        RenderTexture previous = RenderTexture.active;
        RenderTexture previousCameraTarget = camera.targetTexture;

        camera.targetTexture = target;
        RenderTexture.active = target;
        camera.Render();

        Texture2D image = new Texture2D(width, height, TextureFormat.RGBA32, false);
        image.ReadPixels(new Rect(0, 0, width, height), 0, 0);
        image.Apply();

        camera.targetTexture = previousCameraTarget;
        RenderTexture.active = previous;

        byte[] png = image.EncodeToPNG();
        Object.DestroyImmediate(image);
        Object.DestroyImmediate(target);

        string output = "Assets/Screenshots/MagicOrb_TutorialReplica_Check.png";
        Directory.CreateDirectory(Path.GetDirectoryName(output));
        File.WriteAllBytes(output, png);
        AssetDatabase.ImportAsset(output, ImportAssetOptions.ForceUpdate);
        Debug.Log("[MagicOrbScreenshotBatch] Saved " + output);
    }
}
