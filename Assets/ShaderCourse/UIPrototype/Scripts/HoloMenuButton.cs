using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

[DisallowMultipleComponent]
[RequireComponent(typeof(RectTransform))]
[RequireComponent(typeof(Image))]
public class HoloMenuButton : MonoBehaviour, IPointerEnterHandler, IPointerExitHandler, IPointerDownHandler, IPointerUpHandler
{
    [SerializeField] private float scaleUp = 1.035f;
    [SerializeField] private float lerpSpeed = 12f;

    private RectTransform rectTransform;
    private Image targetImage;
    private Material runtimeMaterial;
    private Vector3 baseScale;
    private float hover;
    private float pressed;
    private float selected;

    public void Awake()
    {
        rectTransform = GetComponent<RectTransform>();
        targetImage = GetComponent<Image>();
        baseScale = rectTransform.localScale;

        if (targetImage.material != null)
        {
            runtimeMaterial = new Material(targetImage.material);
            runtimeMaterial.name = targetImage.material.name + " (Runtime)";
            targetImage.material = runtimeMaterial;
            runtimeMaterial.SetFloat("_SweepOffset", Random.value);
        }
    }

    private void Update()
    {
        if (runtimeMaterial == null)
        {
            return;
        }

        Rect rect = rectTransform.rect;
        runtimeMaterial.SetVector("_RectSize", new Vector4(Mathf.Max(rect.width, 1f), Mathf.Max(rect.height, 1f), 0f, 0f));
        runtimeMaterial.SetFloat("_Hover", hover);
        runtimeMaterial.SetFloat("_Pressed", pressed);
        runtimeMaterial.SetFloat("_Selected", selected);

        float targetScale = pressed > 0.5f ? 0.985f : hover > 0.01f || selected > 0.01f ? scaleUp : 1f;
        rectTransform.localScale = Vector3.Lerp(rectTransform.localScale, baseScale * targetScale, Time.deltaTime * lerpSpeed);
    }

    public void SetSelected(bool isSelected)
    {
        selected = isSelected ? 1f : 0f;
    }

    public void OnPointerEnter(PointerEventData eventData)
    {
        hover = 1f;
        MenuSfxSynth.Instance?.PlayHover();
    }

    public void OnPointerExit(PointerEventData eventData)
    {
        hover = 0f;
        pressed = 0f;
    }

    public void OnPointerDown(PointerEventData eventData)
    {
        pressed = 1f;
    }

    public void OnPointerUp(PointerEventData eventData)
    {
        pressed = 0f;
    }
}
