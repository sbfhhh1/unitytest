using System.Collections.Generic;
using UnityEngine;
using UnityEngine.VFX;

[ExecuteAlways]
[DisallowMultipleComponent]
public sealed class RedCubeWallPreview : MonoBehaviour
{
    private const int Columns = 16;
    private const int Rows = 9;
    private const int SpectrumSize = 1024;

    [Header("Scene References")]
    [SerializeField] private Transform cubesRoot;
    [SerializeField] private Mesh cubeMesh;
    [SerializeField] private Material cubeMaterial;
    [SerializeField] private VisualEffect visualEffect;
    [SerializeField] private AudioSource audioSource;

    [Header("Grid")]
    [SerializeField, Min(0.05f)] private float cubeSize = 0.46f;
    [SerializeField, Range(0f, 0.35f)] private float gap = 0.08f;
    [SerializeField, Min(0.02f)] private float depthMin = 0.12f;
    [SerializeField, Min(0.2f)] private float depthMax = 2.05f;

    [Header("Audio Response")]
    [SerializeField, Range(0.5f, 80f)] private float audioGain = 34f;
    [SerializeField, Range(4f, 30f)] private float attack = 16f;
    [SerializeField, Range(1f, 12f)] private float release = 4.2f;
    [SerializeField, Range(0.6f, 2.6f)] private float responseCurve = 0.9f;
    [SerializeField, Range(0f, 1f)] private float beatColorBoost = 0.42f;

    [Header("Color")]
    [SerializeField] private Color lowColor = new(0.18f, 0.012f, 0.018f, 1f);
    [SerializeField] private Color midColor = new(0.95f, 0.18f, 0.045f, 1f);
    [SerializeField] private Color highColor = new(1f, 0.42f, 0.28f, 1f);
    [SerializeField] private Color accentColor = new(1f, 0.05f, 0.62f, 1f);
    [SerializeField, Range(0f, 4f)] private float emissionIntensity = 1.6f;

    private readonly List<Transform> _cubes = new();
    private readonly List<MeshRenderer> _renderers = new();
    private readonly List<MaterialPropertyBlock> _blocks = new();
    private readonly float[] _spectrum = new float[SpectrumSize];
    private float[] _levels = new float[Columns * Rows];
    private float[] _velocities = new float[Columns * Rows];
    private float _globalLevel;
    private float _lastGlobalLevel;
    private float _layoutCubeSize;
    private float _layoutGap;
    private bool _pendingRebuild;

    private void Awake()
    {
        CacheChildren();
    }

    private void OnEnable()
    {
        CacheChildren();
        PushVfxParameters();
    }

    private void Start()
    {
        if (Application.isPlaying && audioSource != null && audioSource.clip != null && !audioSource.isPlaying)
        {
            audioSource.Play();
        }
    }

    private void OnValidate()
    {
        depthMax = Mathf.Max(depthMax, depthMin + 0.05f);
        _pendingRebuild = true;
        PushVfxParameters();
    }

    private void Update()
    {
        if (_pendingRebuild || _cubes.Count != Columns * Rows)
        {
            _pendingRebuild = false;
            RebuildPreviewCubes();
        }

        UpdateSpectrum();
        UpdateCubes(Time.deltaTime > 0f ? Time.deltaTime : 1f / 60f);
        PushVfxParameters();
    }

    public void Configure(Transform root, Mesh mesh, Material material, VisualEffect vfx, AudioSource source)
    {
        cubesRoot = root;
        cubeMesh = mesh;
        cubeMaterial = material;
        visualEffect = vfx;
        audioSource = source;
        RebuildPreviewCubes();
    }

    public void RebuildPreviewCubes()
    {
        if (cubesRoot == null || cubeMesh == null || cubeMaterial == null)
        {
            return;
        }

        if (Application.isPlaying && cubesRoot.childCount > 0)
        {
            ApplyLayoutToExistingCubes();
            CacheChildren();
            return;
        }

        for (int i = cubesRoot.childCount - 1; i >= 0; i--)
        {
            Transform child = cubesRoot.GetChild(i);
            if (Application.isPlaying)
            {
                Destroy(child.gameObject);
            }
            else
            {
                DestroyImmediate(child.gameObject);
            }
        }

        float spacing = cubeSize + gap;
        for (int row = 0; row < Rows; row++)
        {
            for (int col = 0; col < Columns; col++)
            {
                int index = row * Columns + col;
                float x = (col - (Columns - 1) * 0.5f) * spacing;
                float y = (row - (Rows - 1) * 0.5f) * spacing;

                var cube = new GameObject("AudioCube_" + index.ToString("000"));
                cube.transform.SetParent(cubesRoot, false);
                cube.transform.localPosition = new Vector3(x, y, -depthMin * 0.5f);
                cube.transform.localScale = new Vector3(cubeSize, cubeSize, depthMin);

                var meshFilter = cube.AddComponent<MeshFilter>();
                meshFilter.sharedMesh = cubeMesh;

                var meshRenderer = cube.AddComponent<MeshRenderer>();
                meshRenderer.sharedMaterial = cubeMaterial;
                meshRenderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
                meshRenderer.receiveShadows = true;
            }
        }

        _layoutCubeSize = cubeSize;
        _layoutGap = gap;
        EnsureLevelArrays();
        CacheChildren();
    }

    private void ApplyLayoutToExistingCubes()
    {
        float spacing = cubeSize + gap;
        int count = Mathf.Min(cubesRoot.childCount, Columns * Rows);
        for (int i = 0; i < count; i++)
        {
            int col = i % Columns;
            int row = i / Columns;
            Transform cube = cubesRoot.GetChild(i);
            float x = (col - (Columns - 1) * 0.5f) * spacing;
            float y = (row - (Rows - 1) * 0.5f) * spacing;
            cube.localPosition = new Vector3(x, y, -depthMin * 0.5f);
            cube.localScale = new Vector3(cubeSize, cubeSize, depthMin);
        }

        _layoutCubeSize = cubeSize;
        _layoutGap = gap;
    }

    private void CacheChildren()
    {
        _cubes.Clear();
        _renderers.Clear();
        _blocks.Clear();

        if (cubesRoot == null)
        {
            return;
        }

        for (int i = 0; i < cubesRoot.childCount; i++)
        {
            Transform child = cubesRoot.GetChild(i);
            _cubes.Add(child);
            _renderers.Add(child.GetComponent<MeshRenderer>());
            _blocks.Add(new MaterialPropertyBlock());
        }

        EnsureLevelArrays();
    }

    private void EnsureLevelArrays()
    {
        int count = Columns * Rows;
        if (_levels.Length != count)
        {
            _levels = new float[count];
            _velocities = new float[count];
        }
    }

    private void UpdateSpectrum()
    {
        if (audioSource != null && audioSource.clip != null && Application.isPlaying)
        {
            audioSource.GetSpectrumData(_spectrum, 0, FFTWindow.BlackmanHarris);
            return;
        }

        float time = (float)Time.realtimeSinceStartup;
        for (int i = 0; i < _spectrum.Length; i++)
        {
            float band = i / (float)_spectrum.Length;
            _spectrum[i] = (Mathf.Sin(time * (1.2f + band * 16f) + i * 0.17f) * 0.5f + 0.5f) * 0.0025f;
        }
    }

    private void UpdateCubes(float deltaTime)
    {
        if (_cubes.Count == 0)
        {
            return;
        }

        int activeCount = Mathf.Min(_cubes.Count, _levels.Length, _velocities.Length, _renderers.Count, _blocks.Count);
        float globalSum = 0f;
        for (int i = 0; i < activeCount; i++)
        {
            int col = i % Columns;
            int row = i / Columns;
            float bandEnergy = SampleColumnEnergy(col, row);
            globalSum += bandEnergy;

            float rowBias = Mathf.Lerp(0.72f, 1.08f, row / Mathf.Max(1f, Rows - 1f));
            float raw = bandEnergy * audioGain * rowBias;
            float target = Mathf.Clamp01(Mathf.Pow(raw * 0.72f, responseCurve));
            float speed = target > _levels[i] ? attack : release;
            _levels[i] = Mathf.SmoothDamp(_levels[i], target, ref _velocities[i], 1f / speed, Mathf.Infinity, deltaTime);
        }

        _lastGlobalLevel = _globalLevel;
        float targetGlobal = Mathf.Clamp01(globalSum * audioGain / Mathf.Max(1, activeCount));
        _globalLevel = Mathf.Lerp(_globalLevel, targetGlobal, 1f - Mathf.Exp(-deltaTime * 5.5f));
        float beat = Mathf.Clamp01(Mathf.Max(0f, _globalLevel - _lastGlobalLevel) * 5f);

        for (int i = 0; i < activeCount; i++)
        {
            int col = i % Columns;
            float columnT = col / Mathf.Max(1f, Columns - 1f);
            float level = Mathf.Clamp01(_levels[i] + beat * 0.22f);
            float depth = Mathf.Lerp(depthMin, depthMax, level);

            Transform cube = _cubes[i];
            cube.localScale = new Vector3(cubeSize, cubeSize, depth);
            cube.localPosition = new Vector3(cube.localPosition.x, cube.localPosition.y, -depth * 0.5f);

            MeshRenderer meshRenderer = _renderers[i];
            if (meshRenderer == null)
            {
                continue;
            }

            Color baseColor = EvaluateAudioColor(level, columnT, beat);
            Color emission = baseColor * (0.15f + emissionIntensity * Mathf.Clamp01(level + beat * beatColorBoost));

            MaterialPropertyBlock block = _blocks[i];
            block.SetColor("_BaseColor", baseColor);
            block.SetColor("_EmissionColor", emission);
            meshRenderer.SetPropertyBlock(block);
        }
    }

    private float SampleColumnEnergy(int col, int row)
    {
        float x = col / Mathf.Max(1f, Columns - 1f);
        float lowBin = Mathf.Lerp(1f, 36f, Mathf.Pow(x, 1.7f));
        float highBin = Mathf.Lerp(10f, SpectrumSize * 0.72f, Mathf.Pow(x, 2.15f));
        int start = Mathf.Clamp(Mathf.RoundToInt(lowBin), 1, SpectrumSize - 2);
        int end = Mathf.Clamp(Mathf.RoundToInt(highBin), start + 1, SpectrumSize - 1);
        int width = Mathf.Clamp(5 + row * 2, 5, 22);
        int center = Mathf.Clamp(Mathf.RoundToInt(Mathf.Lerp(start, end, (row + 0.5f) / Rows)), start, end);

        float sum = 0f;
        int samples = 0;
        for (int i = -width; i <= width; i++)
        {
            int index = Mathf.Clamp(center + i, 1, SpectrumSize - 1);
            float weight = 1f - Mathf.Abs(i) / (float)(width + 1);
            sum += Mathf.Sqrt(_spectrum[index]) * weight;
            samples++;
        }

        float neighbor = 0f;
        if (col > 0)
        {
            neighbor += Mathf.Sqrt(_spectrum[Mathf.Clamp(center - width * 2, 1, SpectrumSize - 1)]);
        }
        if (col < Columns - 1)
        {
            neighbor += Mathf.Sqrt(_spectrum[Mathf.Clamp(center + width * 2, 1, SpectrumSize - 1)]);
        }

        return (sum / Mathf.Max(1, samples)) * 0.82f + neighbor * 0.09f;
    }

    private Color EvaluateAudioColor(float level, float columnT, float beat)
    {
        Color lava = Color.Lerp(lowColor, midColor, Mathf.SmoothStep(0f, 1f, level));
        Color hot = Color.Lerp(lava, highColor, Mathf.Clamp01(level * 1.2f - 0.2f));
        float accentMask = Mathf.SmoothStep(0.62f, 1f, level) * Mathf.SmoothStep(0.35f, 1f, columnT);
        Color accented = Color.Lerp(hot, accentColor, accentMask * 0.42f);
        return Color.Lerp(accented, accentColor, beat * beatColorBoost * 0.28f);
    }

    private void PushVfxParameters()
    {
        if (visualEffect == null)
        {
            return;
        }

        float spacing = cubeSize + gap;
        if (visualEffect.HasUInt("Columns")) visualEffect.SetUInt("Columns", Columns);
        if (visualEffect.HasUInt("Rows")) visualEffect.SetUInt("Rows", Rows);
        if (visualEffect.HasUInt("ParticleCount")) visualEffect.SetUInt("ParticleCount", Columns * Rows);
        if (visualEffect.HasFloat("SpacingX")) visualEffect.SetFloat("SpacingX", spacing);
        if (visualEffect.HasFloat("SpacingY")) visualEffect.SetFloat("SpacingY", spacing);
        if (visualEffect.HasFloat("BreathAmplitude")) visualEffect.SetFloat("BreathAmplitude", Mathf.Lerp(0.02f, 0.18f, _globalLevel));
        if (visualEffect.HasFloat("AudioLevel")) visualEffect.SetFloat("AudioLevel", _globalLevel);
        if (visualEffect.HasFloat("Gap")) visualEffect.SetFloat("Gap", gap);
    }
}
