class CheatKitAutodriveModel extends IScriptable {
  public static func ProfileLimit(mode: Int32) -> Float {
    return mode == 1 ? 120.0 : mode == 2 ? 180.0 : mode == 3 ? 240.0 : mode == 4 ? 300.0 : 0.0;
  }
  public static func Deceleration(mode: Int32) -> Float {
    return mode == 1 ? 3.0 : mode == 2 ? 3.5 : 4.0;
  }
  public static func Reaction(mode: Int32) -> Float {
    return mode == 1 ? 1.2 : mode == 2 ? 1.1 : mode == 3 ? 1.0 : 1.0;
  }
  public static func Buffer(mode: Int32) -> Float {
    return mode == 1 ? 12.0 : mode == 2 ? 16.0 : mode == 3 ? 20.0 : 25.0;
  }
  public static func Lateral(mode: Int32) -> Float {
    return mode == 1 ? 1.8 : mode == 2 ? 2.2 : mode == 3 ? 2.6 : 2.8;
  }
  public static func Ramp(mode: Int32) -> Float {
    return mode == 1 ? 1.0 : mode == 2 ? 1.4 : mode == 3 ? 1.8 : 2.0;
  }
  public static func StoppingDistance(speed: Float, deceleration: Float, reaction: Float, reserve: Float) -> Float {
    speed = MaxF(speed, 0.0);
    return speed * reaction + speed * speed / (2.0 * MaxF(deceleration, 0.5)) + MaxF(reserve, 0.0);
  }
  public static func SpeedForDistance(distance: Float, deceleration: Float, reaction: Float, reserve: Float) -> Float {
    let a = MaxF(deceleration, 0.5);
    let t = MaxF(reaction, 0.0);
    let usable = MaxF(distance - MaxF(reserve, 0.0), 0.0);
    return MaxF(SqrtF(a * a * t * t + 2.0 * a * usable) - a * t, 0.0);
  }
  public static func CurveSpeed(curvature: Float, lateralAcceleration: Float) -> Float {
    return SqrtF(MaxF(lateralAcceleration, 0.1) / MaxF(AbsF(curvature), 0.0001));
  }
  public static func ProbeDistance(index: Int32) -> Float {
    return Cast<Float>(index + 1) * 12.0;
  }
}
