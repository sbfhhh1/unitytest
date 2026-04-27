using UnityEngine;
using UnityEngine.VFX;

namespace PillarGrid
{
    /// <summary>
    /// Drives a 15x15 pillar grid VFX with audio spectrum data.
    /// Attach to a GameObject with VisualEffect and AudioSource components.
    /// </summary>
    public class PillarGridController : MonoBehaviour
    {
        [Header("VFX Reference")]
        [Tooltip("The VisualEffect component (auto-detected if on same GameObject).")]
        public VisualEffect visualEffect;

        [Header("Grid Layout")]
        [Tooltip("Number of pillars per side (15 = 15x15 = 225 total).")]
        [Range(4, 40)]
        public int gridSize = 15;

        [Tooltip("Distance between pillar centers.")]
        [Range(0.1f, 5f)]
        public float spacing = 0.9f;

        [Tooltip("Width/depth of each square pillar.")]
        [Range(0.01f, 2f)]
        public float pillarWidth = 0.72f;

        [Tooltip("Base height of pillars without audio influence.")]
        [Range(0.1f, 10f)]
        public float baseHeight = 0.6f;

        [Header("Audio")]
        [Tooltip("AudioSource to analyze. Auto-detected if null.")]
        public AudioSource audioSource;

        [Tooltip("Multiplier applied to audio magnitude for Y displacement.")]
        [Range(0.1f, 20f)]
        public float amplitudeMultiplier = 7.5f;

        [Tooltip("Dampening time for smooth height transitions.")]
        [Range(0f, 2f)]
        public float smoothTime = 0.12f;

        [Tooltip("Number of FFT spectrum samples. Must be power of 2.")]
        [Range(64, 4096)]
        public int spectrumSamples = 512;

        [Tooltip("FFT window function for spectrum analysis.")]
        public FFTWindow fftWindow = FFTWindow.BlackmanHarris;

        [Tooltip("Minimum frequency to consider (Hz). Frequencies below this are ignored.")]
        [Range(10f, 500f)]
        public float frequencyMin = 20f;

        [Tooltip("Maximum frequency to consider (Hz). Frequencies above this are ignored.")]
        [Range(1000f, 22000f)]
        public float frequencyMax = 8000f;

        [Tooltip("Logarithmic frequency scaling. Higher = more low-freq detail.")]
        [Range(0.2f, 3f)]
        public float frequencyCurvePower = 1.8f;

        [Header("Row Variation")]
        [Tooltip("How much row index affects the height falloff (0 = uniform columns).")]
        [Range(0f, 1f)]
        public float rowFalloff = 0.12f;

        [Tooltip("Smooth speed variation per row for wave-like motion.")]
        [Range(0f, 2f)]
        public float rowWaveSpeed = 1.8f;

        [Tooltip("Phase offset per row for wave pattern.")]
        [Range(0f, 6.28f)]
        public float rowPhaseOffset = 0.72f;

        [Header("Color")]
        [Tooltip("Gradient mapped to pillar height (0 = base, 1 = peak).")]
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

        [Tooltip("Multiply color intensity.")]
        [Range(0.1f, 5f)]
        public float colorIntensity = 2.2f;

        [Tooltip("Color influenced by peak frequency magnitude.")]
        [Range(0f, 1f)]
        public float colorAudioInfluence = 0.75f;

        [Header("Advanced")]
        [Tooltip("Audio texture filter mode. Point = sharp per-pillar, Bilinear = blended.")]
        public FilterMode textureFilterMode = FilterMode.Point;

        [Tooltip("Number of frames to skip between texture updates (higher = better performance).")]
        [Range(1, 10)]
        public int textureUpdateInterval = 1;

        [Tooltip("Minimum pillar height (prevents disappearing entirely).")]
        [Range(0f, 2f)]
        public float minPillarHeight = 0.08f;

        // Internal state
        private Texture2D audioTexture;
        private float[] spectrumData;
        private float[] smoothedBands;
        private float[] rowPhases;
        private Color[] texturePixels;
        private int frameCounter;

        // Property IDs
        private static readonly int AudioTextureProp = Shader.PropertyToID("AudioTexture");
        private static readonly int GridSizeProp = Shader.PropertyToID("GridSize");
        private static readonly int SpacingProp = Shader.PropertyToID("Spacing");
        private static readonly int PillarWidthProp = Shader.PropertyToID("PillarWidth");
        private static readonly int PillarHeightProp = Shader.PropertyToID("PillarHeight");
        private static readonly int AmplitudeProp = Shader.PropertyToID("Amplitude");
        private static readonly int ColorAProp = Shader.PropertyToID("ColorA");
        private static readonly int ColorBProp = Shader.PropertyToID("ColorB");
        private static readonly int ColorCProp = Shader.PropertyToID("ColorC");
        private static readonly int TotalParticlesProp = Shader.PropertyToID("TotalParticles");

        private void Awake()
        {
            // Auto-detect components
            if (visualEffect == null)
                visualEffect = GetComponent<VisualEffect>();

            if (audioSource == null)
                audioSource = GetComponent<AudioSource>();

            if (audioSource == null)
                Debug.LogWarning("[PillarGrid] No AudioSource assigned. Pillars will stay at base height.");

            // Allocate arrays
            spectrumData = new float[spectrumSamples];
            smoothedBands = new float[gridSize];
            rowPhases = new float[gridSize];
            texturePixels = new Color[gridSize * gridSize];

            // Create audio texture
            CreateAudioTexture();

            // Initialize row phases
            for (int r = 0; r < gridSize; r++)
            {
                rowPhases[r] = Random.Range(0f, Mathf.PI * 2f);
            }

            // Push initial values to VFX
            if (visualEffect != null)
            {
                visualEffect.SetUInt(GridSizeProp, (uint)gridSize);
                visualEffect.SetFloat(SpacingProp, spacing);
                visualEffect.SetFloat(PillarWidthProp, pillarWidth);
                visualEffect.SetFloat(PillarHeightProp, baseHeight);
                visualEffect.SetFloat(AmplitudeProp, amplitudeMultiplier);
                visualEffect.SetTexture(AudioTextureProp, audioTexture);
                visualEffect.SetUInt(TotalParticlesProp, (uint)(gridSize * gridSize));
                PushColorGradient();
            }
        }

        private void CreateAudioTexture()
        {
            if (audioTexture != null)
                Destroy(audioTexture);

            audioTexture = new Texture2D(gridSize, gridSize, TextureFormat.RFloat, false);
            audioTexture.filterMode = textureFilterMode;
            audioTexture.wrapMode = TextureWrapMode.Clamp;

            // Initialize to black
            var pixels = new Color[gridSize * gridSize];
            for (int i = 0; i < pixels.Length; i++)
                pixels[i] = Color.black;
            audioTexture.SetPixels(pixels);
            audioTexture.Apply();
        }

        private void Start()
        {
            // Log VFX state after 3 seconds to verify setup
            Invoke("LogVfxState", 3f);
        }

        private void LogVfxState()
        {
            if (visualEffect != null)
            {
                Debug.Log($"[PillarGrid] VFX aliveParticleCount={visualEffect.aliveParticleCount} totalParticles={visualEffect.GetUInt("TotalParticles")} time={Time.time}");
                Debug.Log($"[PillarGrid] audio isPlaying={audioSource != null && audioSource.isPlaying}");
            }
        }

        private void Update()
        {
            // Update audio analysis every N frames
            frameCounter++;
            if (frameCounter % textureUpdateInterval != 0)
                return;

            if (audioSource != null && audioSource.isPlaying)
            {
                AnalyzeAudio();
                UpdateTexture();
            }
        }

        private void AnalyzeAudio()
        {
            // Get spectrum data
            audioSource.GetSpectrumData(spectrumData, 0, fftWindow);

            // Map spectrum to frequency bands
            float sampleRate = AudioSettings.outputSampleRate;
            int validSpectrumLength = spectrumData.Length;

            for (int col = 0; col < gridSize; col++)
            {
                float bandMagnitude = 0f;

                // Logarithmic frequency mapping
                float t = (float)col / (gridSize - 1);
                float freqCenter = frequencyMin * Mathf.Pow(frequencyMax / frequencyMin, Mathf.Pow(t, frequencyCurvePower));

                // Find spectrum range for this band
                float halfBandWidth = (frequencyMax - frequencyMin) / (2f * gridSize);
                float freqLow = Mathf.Max(frequencyMin, freqCenter - halfBandWidth);
                float freqHigh = Mathf.Min(frequencyMax, freqCenter + halfBandWidth);

                int indexLow = Mathf.Clamp(Mathf.FloorToInt(freqLow / sampleRate * validSpectrumLength), 0, validSpectrumLength - 1);
                int indexHigh = Mathf.Clamp(Mathf.CeilToInt(freqHigh / sampleRate * validSpectrumLength), 0, validSpectrumLength - 1);

                // Average magnitude in this band
                int count = 0;
                for (int i = indexLow; i <= indexHigh; i++)
                {
                    bandMagnitude += spectrumData[i];
                    count++;
                }
                bandMagnitude = (count > 0) ? bandMagnitude / count : 0f;

                // Scale (spectrum values are typically small, boost them)
                bandMagnitude *= 10f;

                // Smooth
                smoothedBands[col] = Mathf.Lerp(smoothedBands[col], bandMagnitude, Time.deltaTime / (smoothTime + 0.001f));
            }
        }

        private void UpdateTexture()
        {
            float time = Time.time;

            for (int row = 0; row < gridSize; row++)
            {
                // Row-based variation
                float rowFactor = 1f - rowFalloff * (float)row / (gridSize - 1);
                float wavePhase = rowPhaseOffset * row;

                for (int col = 0; col < gridSize; col++)
                {
                    // Get smoothed band value
                    float baseValue = smoothedBands[col];

                    // Apply row variation (wave-like motion per row)
                    float wave = 1f;
                    if (rowWaveSpeed > 0.01f)
                    {
                        wave = 1f + Mathf.Sin(time * rowWaveSpeed + wavePhase) * 0.3f;
                    }

                    float radialX = (col - (gridSize - 1) * 0.5f) / Mathf.Max(1f, gridSize - 1);
                    float radialY = (row - (gridSize - 1) * 0.5f) / Mathf.Max(1f, gridSize - 1);
                    float radial = 1f - Mathf.Clamp01(Mathf.Sqrt(radialX * radialX + radialY * radialY) * 1.1f);
                    float accent = Mathf.Lerp(0.8f, 1.2f, radial);

                    float value = baseValue * rowFactor * wave * accent;
                    value = Mathf.Clamp(value, minPillarHeight, 1f);

                    int pixelIndex = row * gridSize + col;
                    texturePixels[pixelIndex] = new Color(value, 0f, 0f, 1f);
                }
            }

            audioTexture.SetPixels(texturePixels);
            audioTexture.Apply();

            // Push updated properties to VFX each frame
            if (visualEffect != null)
            {
                visualEffect.SetTexture(AudioTextureProp, audioTexture);
            }
        }

        private void OnValidate()
        {
            // Clamp values in editor
            gridSize = Mathf.Max(1, gridSize);
            spectrumSamples = Mathf.ClosestPowerOfTwo(Mathf.Max(64, spectrumSamples));

            // Recreate texture if grid size changed
            if (Application.isPlaying && audioTexture != null && audioTexture.width != gridSize)
            {
                CreateAudioTexture();
                if (visualEffect != null)
                {
                    visualEffect.SetUInt(GridSizeProp, (uint)gridSize);
                    visualEffect.SetTexture(AudioTextureProp, audioTexture);
                    visualEffect.SetUInt(TotalParticlesProp, (uint)(gridSize * gridSize));
                }
            }

            // Push updated params to VFX in editor play mode
            if (Application.isPlaying && visualEffect != null)
            {
                visualEffect.SetFloat(SpacingProp, spacing);
                visualEffect.SetFloat(PillarWidthProp, pillarWidth);
                visualEffect.SetFloat(PillarHeightProp, baseHeight);
                visualEffect.SetFloat(AmplitudeProp, amplitudeMultiplier);
                visualEffect.SetUInt(TotalParticlesProp, (uint)(gridSize * gridSize));
                PushColorGradient();
            }
        }

        private void OnDestroy()
        {
            if (audioTexture != null)
                Destroy(audioTexture);
        }

        /// <summary>
        /// Returns the VFX color for a given height value (0-1 normalized).
        /// </summary>
        public Color EvaluateHeightColor(float normalizedHeight)
        {
            return heightGradient.Evaluate(normalizedHeight) * colorIntensity;
        }

        /// <summary>
        /// Returns the current smoothed audio band values (index 0 = low freq, index gridSize-1 = high).
        /// </summary>
        public float[] GetBandValues()
        {
            return smoothedBands;
        }

        private void PushColorGradient()
        {
            if (visualEffect == null)
                return;

            visualEffect.SetVector4(ColorAProp, heightGradient.Evaluate(0f) * colorIntensity);
            visualEffect.SetVector4(ColorBProp, heightGradient.Evaluate(0.55f) * colorIntensity);
            visualEffect.SetVector4(ColorCProp, heightGradient.Evaluate(1f) * colorIntensity);
        }
    }
}
