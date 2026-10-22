using UnityEngine;

public class PlayerAnimation : MonoBehaviour
{
    [SerializeField] Animator animator;
    [SerializeField] float dampTime;

    static readonly int velocityX = Animator.StringToHash("velocityX");
    static readonly int velocityZ = Animator.StringToHash("velocityZ");

    const string Handgun = "Handgun";
    const string Rifle = "Rifle";
    const string Shotgun = "Shotgun";
    const string Gatling = "Gatling";

    public void HandleAnimation(Vector2 inputAxis)
    {
        // 入力をプレイヤーの向きで補正
        Vector3 inputDirection = new(inputAxis.x, 0, inputAxis.y);
        Vector3 localDirection = transform.InverseTransformDirection(inputDirection).normalized;

        // さらにdampTimeで値の変動を緩やかに補正
        animator.SetFloat(velocityX, localDirection.x, dampTime, Time.deltaTime);
        animator.SetFloat(velocityZ, localDirection.z, dampTime, Time.deltaTime);
    }
}
