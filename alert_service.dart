import 'package:vibration/vibration.dart';

/// Controla o cooldown por placa (evita disparar o mesmo alerta
/// repetidamente enquanto a mesma placa continua no campo de visão da
/// câmera por vários frames seguidos) e o disparo de vibração.
class AlertService {
  AlertService({this.cooldown = const Duration(seconds: 3)});

  final Duration cooldown;
  final Map<String, DateTime> _lastAlertAt = {};

  /// Retorna `true` se a placa pode disparar um novo alerta agora
  /// (ou seja, não está em cooldown), registrando o timestamp atual.
  bool shouldAlert(String plate) {
    final now = DateTime.now();
    final last = _lastAlertAt[plate];

    if (last != null && now.difference(last) < cooldown) {
      return false;
    }

    _lastAlertAt[plate] = now;
    return true;
  }

  /// Dispara vibração tátil de alerta (padrão curto-longo-curto).
  Future<void> vibrate() async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) return;

    final hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;
    if (hasAmplitudeControl) {
      await Vibration.vibrate(pattern: [0, 150, 100, 150, 100, 300]);
    } else {
      await Vibration.vibrate(duration: 400);
    }
  }

  void reset() => _lastAlertAt.clear();
}
