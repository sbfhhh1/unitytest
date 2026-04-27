using System.Collections;
using UnityEngine;

#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

[RequireComponent(typeof(Collider))]
public class ClickableBounceSphere : MonoBehaviour
{
    [SerializeField] private float bounceHeight = 1f;
    [SerializeField] private float bounceDuration = 0.5f;

    private Camera _mainCamera;
    private Vector3 _restPosition;
    private bool _isBouncing;

    private void Awake()
    {
        _mainCamera = Camera.main;
        _restPosition = transform.position;
    }

    private void Update()
    {
        if (!_isBouncing && WasClickedThisFrame() && IsPointerOverThis())
            StartCoroutine(DoBounce());
    }

    private IEnumerator DoBounce()
    {
        _isBouncing = true;
        float elapsed = 0f;

        while (elapsed < bounceDuration)
        {
            elapsed += Time.deltaTime;
            float t = elapsed / bounceDuration;
            float yOffset = Mathf.Sin(t * Mathf.PI) * bounceHeight;
            transform.position = _restPosition + Vector3.up * yOffset;
            yield return null;
        }

        transform.position = _restPosition;
        _isBouncing = false;
    }

    private bool WasClickedThisFrame()
    {
#if ENABLE_INPUT_SYSTEM
        if (Mouse.current != null)
            return Mouse.current.leftButton.wasPressedThisFrame;
#endif
#if ENABLE_LEGACY_INPUT_MANAGER
        return Input.GetMouseButtonDown(0);
#else
        return false;
#endif
    }

    private bool IsPointerOverThis()
    {
        if (_mainCamera == null)
            _mainCamera = Camera.main;
        if (_mainCamera == null)
            return false;

        Ray ray = _mainCamera.ScreenPointToRay(GetPointerPosition());
        return Physics.Raycast(ray, out RaycastHit hit) && hit.transform == transform;
    }

    private Vector3 GetPointerPosition()
    {
#if ENABLE_INPUT_SYSTEM
        if (Mouse.current != null)
            return Mouse.current.position.ReadValue();
#endif
#if ENABLE_LEGACY_INPUT_MANAGER
        return Input.mousePosition;
#else
        return Vector3.zero;
#endif
    }
}
