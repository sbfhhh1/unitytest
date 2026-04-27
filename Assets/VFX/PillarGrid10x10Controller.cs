using UnityEngine;

public class PillarGrid10x10Controller : MonoBehaviour
{
    [Header("Grid Layout")]
    [Range(2, 20)]
    public int gridSize = 10;

    [Range(0.1f, 5f)]
    public float spacing = 1.0f;

    [Range(0.01f, 2f)]
    public float cubeWidth = 0.8f;

    [Header("Noise Animation")]
    [Range(0.1f, 3f)]
    public float noiseSpeed = 0.6f;

    [Range(0.1f, 5f)]
    public float noiseScale = 2.0f;

    [Range(0.5f, 10f)]
    public float amplitudeMultiplier = 3.5f;

    [Range(0.01f, 1f)]
    public float minHeight = 0.1f;

    [Header("Visual")]
    public Material cubeMaterial;

    [Range(0.1f, 5f)]
    public float colorIntensity = 2.2f;

    public Gradient heightGradient = new Gradient()
    {
        colorKeys = new GradientColorKey[]
        {
            new GradientColorKey(new Color(0.03f, 0.16f, 0.35f), 0f),
            new GradientColorKey(new Color(0.02f, 0.76f, 0.92f), 0.55f),
            new GradientColorKey(new Color(0.80f, 0.96f, 1.0f), 1f)
        },
        alphaKeys = new GradientAlphaKey[]
        {
            new GradientAlphaKey(1f, 0f),
            new GradientAlphaKey(1f, 1f)
        }
    };

    private Transform[] cubes;
    private MeshRenderer[] renderers;
    private MaterialPropertyBlock propBlock;
    private static readonly int BaseColorId = Shader.PropertyToID("_BaseColor");

    private void Awake()
    {
        int total = gridSize * gridSize;
        cubes = new Transform[total];
        renderers = new MeshRenderer[total];
        propBlock = new MaterialPropertyBlock();

        GameObject template = GameObject.CreatePrimitive(PrimitiveType.Cube);
        template.GetComponent<MeshRenderer>().sharedMaterial = (cubeMaterial != null)
            ? cubeMaterial
            : new Material(Shader.Find("Universal Render Pipeline/Lit"));
        template.SetActive(false);
        template.transform.SetParent(transform, false);

        float offset = -(gridSize - 1) * spacing * 0.5f;
        for (int i = 0; i < total; i++)
        {
            int col = i % gridSize;
            int row = i / gridSize;

            GameObject cube = Instantiate(template, transform);
            cube.name = string.Format("Cube_{0}_{1}", row, col);
            cube.transform.localPosition = new Vector3(offset + col * spacing, 0f, offset + row * spacing);
            cube.transform.localScale = new Vector3(cubeWidth, 0.1f, cubeWidth);
            cube.SetActive(true);

            cubes[i] = cube.transform;
            renderers[i] = cube.GetComponent<MeshRenderer>();
        }

        Destroy(template);
    }

    private void Update()
    {
        float time = Time.time;
        int total = gridSize * gridSize;

        for (int i = 0; i < total; i++)
        {
            int col = i % gridSize;
            int row = i / gridSize;

            float nx = col * noiseScale / gridSize;
            float ny = row * noiseScale / gridSize;
            float noise = Mathf.PerlinNoise(nx + time * noiseSpeed, ny + time * noiseSpeed * 0.7f);

            float height = Mathf.Max(minHeight, noise * amplitudeMultiplier);
            Vector3 s = cubes[i].localScale;
            s.y = height;
            cubes[i].localScale = s;
            cubes[i].localPosition = new Vector3(cubes[i].localPosition.x, height * 0.5f, cubes[i].localPosition.z);

            Color c = heightGradient.Evaluate(noise) * colorIntensity;
            propBlock.SetColor(BaseColorId, c);
            renderers[i].SetPropertyBlock(propBlock);
        }
    }
}
