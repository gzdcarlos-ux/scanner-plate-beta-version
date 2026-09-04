import 'config/renajud_api_config.dart';
import 'models/renajud_status.dart';
import 'providers/local_provider.dart';
import 'providers/mock_provider.dart';
import 'providers/remote_provider.dart';
import 'providers/renajud_provider.dart';
import '../utils/plate_utils.dart';

/// Ponto único de entrada usado pela UI (scanner, tela de busca manual etc.)
/// para descobrir o status de restrição de uma placa.
///
/// Ordem de resolução:
///   1) Mock (só ativo em modo de teste — placas AAA0000/BBB1111)
///   2) Base local (SQLite, planilha importada) — instantâneo, offline
///   3) API remota (se `RenajudApiConfig.remoteEnabled == true`)
///
/// A UI nunca chama os providers diretamente — sempre passa por aqui,
/// o que permite trocar/adicionar fontes sem tocar em nenhuma tela.
class RenajudService {
  RenajudService({bool enableMock = true})
      : _providers = [
          if (enableMock) MockRenajudProvider(),
          LocalRenajudProvider(),
          if (RenajudApiConfig.remoteEnabled) RemoteRenajudProvider(),
        ];

  final List<RenajudProvider> _providers;

  Future<RenajudStatus> check(String rawPlateInput) async {
    final plate = PlateUtils.sanitize(rawPlateInput);

    if (!PlateUtils.isValidPlate(plate)) {
      return RenajudStatus.error(plate);
    }

    for (final provider in _providers) {
      final result = await provider.check(plate);

      // Segue para o próximo provider apenas se este não encontrou nada
      // (notFound). Um resultado conhecido (true/false) ou erro já
      // encerra a busca — erro não deve mascarar a resposta de outra
      // fonte silenciosamente sem log; aqui simplificamos parando ali,
      // mas você pode trocar para "continue" se preferir tentar a
      // próxima fonte mesmo após erro de rede.
      if (result.isKnown) {
        return result;
      }
    }

    return RenajudStatus.notFound(plate);
  }
}
