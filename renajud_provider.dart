import '../models/renajud_status.dart';

/// Contrato que qualquer fonte de dados de restrição deve cumprir.
///
/// Isso é o que torna a arquitetura "trocável": a tela de scanner e a
/// tela de teste HTML só conhecem esta interface — nunca sabem se a
/// resposta veio do SQLite local, de uma API paga ou de um mock.
abstract class RenajudProvider {
  /// Consulta uma placa já higienizada (7 caracteres, maiúscula, sem
  /// espaços/hífen) e retorna o status. Nunca deve lançar exceção para
  /// fora — erros de rede/parse devem virar `RenajudStatus.error(plate)`.
  Future<RenajudStatus> check(String sanitizedPlate);

  /// Nome curto do provider, usado em logs/UI de debug.
  String get name;
}
