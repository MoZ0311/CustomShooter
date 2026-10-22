using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerController : MonoBehaviour, PlayerInputActions.IPlayerActions
{
    [SerializeField] PlayerAnimation playerAnimation;
    Vector2 inputAxis;

    PlayerInputActions playerInput;
    PlayerInputActions.PlayerActions playerActions;

    void Awake()
    {
        playerInput = new();
        playerActions = playerInput.Player;
        playerActions.AddCallbacks(this);
    }

    void OnEnable()
    {
        playerActions.Enable();
    }

    void OnDisable()
    {
        playerActions.Disable();
    }

    void OnDestroy()
    {
        playerInput.Dispose();
    }

    void Update()
    {
        playerAnimation.HandleAnimation(inputAxis);
    }

    public void OnMove(InputAction.CallbackContext context)
    {
        inputAxis = context.ReadValue<Vector2>();
        Debug.Log(inputAxis);
    }

    public void OnAim(InputAction.CallbackContext context)
    {
    }

    public void OnFire(InputAction.CallbackContext context)
    {
    }
}
