import '../models/renajud_status.dart';
import 'renajud_provider.dart';

/// Provider de testes — mesma lógica combinada com você no HTML anterior:
/// AAA0000 -> restrição ativa (positivo)
/// BBB1111 -> sem restrição (negativo)
/// Qualquer outra placa -> "não determinado" (deixa o próximo provider decidir).
class MockRenajudProvider implements RenajudProvider {
  @override
  String get name => 'mock';

  static const _positive = 'AAA0000';
  static const _negative = 'BBB1111';

  @override
  Future<RenajudStatus> check(String sanitizedPlate) async {
    // Pequeno delay simulado para exercitar o loading da UI durante testes.
    await Future.delayed(const Duration(milliseconds: 400));

    if (sanitizedPlate == _positive) {
      return RenajudStatus(
        plate: sanitizedPlate,
        hasRestriction: true,
        observation: 'Mock de teste — restrição simulada',
        source: RenajudSource.mock,
        checkedAt: DateTime.now(),
      );
    }

    if (sanitizedPlate == _negative) {
      return RenajudStatus(
        plate: sanitizedPlate,
        hasRestriction: false,
        source: RenajudSource.mock,
        checkedAt: DateTime.now(),
      );
    }

    return RenajudStatus.notFound(sanitizedPlate);
  }
}
