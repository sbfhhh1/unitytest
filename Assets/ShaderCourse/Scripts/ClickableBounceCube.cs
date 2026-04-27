using UnityEngine;

#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

[RequireComponent(typeof(Collider))]
public class ClickableBounceCube : MonoBehaviour
{
    [SerializeField] private float bounceHeight = 1f;
    [SerializeField] private float bounceSpeed = 2.5f;

    private Camera _mainCamera;
    private Vector3 _restPosition;
    private float _elapsedTime;
    private bool _isBouncing;

    private void Awake()
    {
        _mainCamera = Camera.main;
        _restPosition = transform.position;
    }

    private void Update()
    {
        if (WasClickedThisFrame() && IsPointerOverThisCube())
        {
            ToggleBounce();
        }

        if (!_isBouncing)
        {
            return;
        }

        _elapsedTime += Time.deltaTime * bounceSpeed;
        float yOffset = Mathf.Abs(Mathf.Sin(_elapsedTime)) * bounceHeight;
        transform.position = _restPosition + Vector3.up * yOffset;
    }

    private void ToggleBounce()
    {
        _isBouncing = !_isBouncing;

        if (_isBouncing)
        {
            _elapsedTime = 0f;
            return;
        }

        transform.position = _restPosition;
    }

    private bool WasClickedThisFrame()
    {
#if ENABLE_INPUT_SYSTEM
        if (Mouse.current != null)
        {
            return Mouse.current.leftButton.wasPressedThisFrame;
        }
#endif

#if ENABLE_LEGACY_INPUT_MANAGER
        return Input.GetMouseButtonDown(0);
#else
        return false;
#endif
    }

    private bool IsPointerOverThisCube()
    {
        if (_mainCamera == null)
        {
            _mainCamera = Camera.main;
        }

        if (_mainCamera == null)
        {
            return false;
        }

        Ray ray = _mainCamera.ScreenPointToRay(GetPointerPosition());
        return Physics.Raycast(ray, out RaycastHit hit) && hit.transform == transform;
    }

    private Vector3 GetPointerPosition()
    {
#if ENABLE_INPUT_SYSTEM
        if (Mouse.current != null)
        {
            return Mouse.current.position.ReadValue();
        }
#endif

#if ENABLE_LEGACY_INPUT_MANAGER
        return Input.mousePosition;
#else
        return Vector3.zero;
#endif
    }
}
