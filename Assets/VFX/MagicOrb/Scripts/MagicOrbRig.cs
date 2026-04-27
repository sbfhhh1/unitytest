using UnityEngine;
using UnityEngine.VFX;

namespace MagicOrbVfx
{
    [ExecuteAlways]
    public class MagicOrbRig : MonoBehaviour
    {
        [Header("Reference")]
        public VisualEffect visualEffect;

        [Header("Public Controls")]
        public Color CoreColor = new(0.28f, 0.62f, 1f, 1f);
        public Color ShellColor = new(0.92f, 0.18f, 1f, 1f);
        public Color ArcColor = new(1f, 1f, 1f, 1f);

        [Min(0.1f)] public float OrbRadius = 1f;
        [Min(0.1f)] public float CoreIntensity = 1f;
        [Min(0f)] public float ShellNoiseAmplitude = 0.15f;
        [Min(0.01f)] public float ShellNoiseFrequency = 1f;
        [Min(0f)] public float ArcSpawnRate = 30f;
        [Min(0.05f)] public float ArcLifetime = 1f;

        private static readonly int CoreColorId = Shader.PropertyToID("CoreColor");
        private static readonly int ShellColorId = Shader.PropertyToID("ShellColor");
        private static readonly int ArcColorId = Shader.PropertyToID("ArcColor");
        private static readonly int OrbRadiusId = Shader.PropertyToID("OrbRadius");
        private static readonly int CoreIntensityId = Shader.PropertyToID("CoreIntensity");
        private static readonly int ShellNoiseAmplitudeId = Shader.PropertyToID("ShellNoiseAmplitude");
        private static readonly int ShellNoiseFrequencyId = Shader.PropertyToID("ShellNoiseFrequency");
        private static readonly int ArcSpawnRateId = Shader.PropertyToID("ArcSpawnRate");
        private static readonly int ArcLifetimeId = Shader.PropertyToID("ArcLifetime");

        private void Awake()
        {
            Apply();
        }

        private void OnEnable()
        {
            Apply();
        }

        private void OnValidate()
        {
            Apply();
        }

        public void Apply()
        {
            if (visualEffect == null)
                visualEffect = GetComponent<VisualEffect>();

            if (visualEffect == null)
                return;

            visualEffect.SetVector4(CoreColorId, ToHdr(CoreColor, CoreIntensity));
            visualEffect.SetVector4(ShellColorId, ToHdr(ShellColor, CoreIntensity));
            visualEffect.SetVector4(ArcColorId, ToHdr(ArcColor, CoreIntensity * 0.25f));
            visualEffect.SetFloat(OrbRadiusId, OrbRadius);
            visualEffect.SetFloat(CoreIntensityId, CoreIntensity);
            visualEffect.SetFloat(ShellNoiseAmplitudeId, ShellNoiseAmplitude);
            visualEffect.SetFloat(ShellNoiseFrequencyId, ShellNoiseFrequency);
            visualEffect.SetFloat(ArcSpawnRateId, ArcSpawnRate);
            visualEffect.SetFloat(ArcLifetimeId, ArcLifetime);

            if (!Application.isPlaying)
            {
                visualEffect.Reinit();
            }
        }

        private static Vector4 ToHdr(Color color, float intensity)
        {
            Color hdr = color.linear * intensity;
            return new Vector4(hdr.r, hdr.g, hdr.b, 1f);
        }
    }
}
