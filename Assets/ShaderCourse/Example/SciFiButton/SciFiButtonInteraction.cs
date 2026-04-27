using UnityEngine;
using UnityEngine.UI;

public class SciFiButtonInteraction : MonoBehaviour
{
    [SerializeField] private string hoverPropertyName = "_Hover";
    
    [SerializeField] private float transitionSpeed = 8f;

    [SerializeField] private string ColorPropertyName;
    [SerializeField] private Color[] DashCircleColor;
    private Material targetMaterial;
    private float currentHoverValue = 0f;
    private float targetHoverValue = 0f;
    private int index;

    void Awake()
    {
        if (TryGetComponent<Graphic>(out var uiGraphic))
        {
            uiGraphic.material = new Material(uiGraphic.material);
            targetMaterial = uiGraphic.material;
        }
    }

    void Update()
    {
        if (targetMaterial != null)
        {
            currentHoverValue = Mathf.Lerp(currentHoverValue, targetHoverValue, Time.deltaTime * transitionSpeed);
            targetMaterial.SetFloat(hoverPropertyName, currentHoverValue);
        }
    }

    // 供 Event Trigger 的 Pointer Enter 调用
    public void SetHoverOn() => targetHoverValue = 1f;

    // 供 Event Trigger 的 Pointer Exit 调用
    public void SetHoverOff() => targetHoverValue = 0f;
    public void SetCircleColor()
    {
        index++;
        if(index>= DashCircleColor.Length)
        {
            index = 0;
        }
        targetMaterial.SetColor(ColorPropertyName, DashCircleColor[index]);
    }
   
}