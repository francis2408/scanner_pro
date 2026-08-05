/// Hardware camera lens facing direction.
enum CameraFacing {
  /// Back / rear camera lens.
  back,

  /// Front / selfie camera lens.
  front,

  /// External or unknown camera lens.
  unknown,
}

/// Flashlight torch operation mode.
enum TorchState {
  /// Flashlight torch is turned off.
  off,

  /// Flashlight torch is turned on.
  on,

  /// Automatic torch in low ambient light.
  auto,

  /// Flashlight torch hardware unavailable.
  unavailable,
}
