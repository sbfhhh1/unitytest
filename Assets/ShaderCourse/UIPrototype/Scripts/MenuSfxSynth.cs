using UnityEngine;

[DisallowMultipleComponent]
[RequireComponent(typeof(AudioSource))]
public class MenuSfxSynth : MonoBehaviour
{
    [SerializeField] private float masterVolume = 0.55f;
    [SerializeField] private float ambienceVolume = 0.22f;

    private AudioSource uiSource;
    private AudioSource ambienceSource;

    private AudioClip hoverClip;
    private AudioClip clickClip;
    private AudioClip backClip;
    private AudioClip ambienceClip;

    public static MenuSfxSynth Instance { get; private set; }

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }

        Instance = this;

        uiSource = GetComponent<AudioSource>();
        uiSource.playOnAwake = false;
        uiSource.loop = false;
        uiSource.spatialBlend = 0f;
        uiSource.volume = masterVolume;

        ambienceSource = gameObject.AddComponent<AudioSource>();
        ambienceSource.playOnAwake = false;
        ambienceSource.loop = true;
        ambienceSource.spatialBlend = 0f;
        ambienceSource.volume = ambienceVolume;

        hoverClip = CreateUiTone("Hover", 0.11f, 760f, 1040f, 0.35f);
        clickClip = CreateUiTone("Click", 0.18f, 480f, 760f, 0.8f);
        backClip = CreateUiTone("Back", 0.20f, 620f, 360f, 0.55f);
        ambienceClip = CreateAmbience("Ambience", 5.5f);

        ambienceSource.clip = ambienceClip;
        ambienceSource.Play();
    }

    public void PlayHover()
    {
        if (hoverClip != null)
        {
            uiSource.PlayOneShot(hoverClip, 0.65f);
        }
    }

    public void PlayClick()
    {
        if (clickClip != null)
        {
            uiSource.PlayOneShot(clickClip, 0.8f);
        }
    }

    public void PlayBack()
    {
        if (backClip != null)
        {
            uiSource.PlayOneShot(backClip, 0.75f);
        }
    }

    private static AudioClip CreateUiTone(string clipName, float duration, float startFrequency, float endFrequency, float sparkle)
    {
        const int sampleRate = 44100;
        int samples = Mathf.CeilToInt(duration * sampleRate);
        float[] data = new float[samples];

        for (int i = 0; i < samples; i++)
        {
            float t = i / (float)sampleRate;
            float progress = i / (float)(samples - 1);
            float frequency = Mathf.Lerp(startFrequency, endFrequency, progress);
            float envelope = Mathf.Sin(progress * Mathf.PI);
            float main = Mathf.Sin(2f * Mathf.PI * frequency * t);
            float upper = Mathf.Sin(2f * Mathf.PI * frequency * 2.01f * t) * sparkle * 0.25f;
            data[i] = (main * 0.8f + upper) * envelope * 0.18f;
        }

        AudioClip clip = AudioClip.Create(clipName, samples, 1, sampleRate, false);
        clip.SetData(data, 0);
        return clip;
    }

    private static AudioClip CreateAmbience(string clipName, float duration)
    {
        const int sampleRate = 44100;
        int samples = Mathf.CeilToInt(duration * sampleRate);
        float[] data = new float[samples];

        for (int i = 0; i < samples; i++)
        {
            float t = i / (float)sampleRate;
            float progress = i / (float)samples;
            float slowPad = Mathf.Sin(2f * Mathf.PI * 110f * t) * 0.055f;
            float shimmer = Mathf.Sin(2f * Mathf.PI * (220f + Mathf.Sin(t * 0.6f) * 6f) * t) * 0.025f;
            float air = Mathf.PerlinNoise(progress * 8f, 0.5f) * 2f - 1f;
            float envelope = Mathf.SmoothStep(0.5f, 1f, Mathf.Sin(progress * Mathf.PI));
            data[i] = (slowPad + shimmer + air * 0.01f) * envelope;
        }

        AudioClip clip = AudioClip.Create(clipName, samples, 1, sampleRate, false);
        clip.SetData(data, 0);
        return clip;
    }
}
