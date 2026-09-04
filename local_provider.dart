import '../../services/database_service.dart';
import '../models/renajud_status.dart';
import 'renajud_provider.dart';

/// Consulta a base local (SQLite), populada pela importação da planilha
/// .xlsx feita na Home. É sempre a primeira fonte tentada: é instantânea,
/// funciona offline e não depende de nenhum serviço pago de terceiros.
class LocalRenajudProvider implements RenajudProvider {
  @override
  String get name => 'local_sqlite';

  @override
  Future<RenajudStatus> check(String sanitizedPlate) async {
    final record = await DatabaseService.instance.lookupPlate(sanitizedPlate);

    if (record == null) {
      return RenajudStatus.notFound(sanitizedPlate);
    }

    return RenajudStatus(
      plate: sanitizedPlate,
      // Na planilha local, a simples presença do registro já significa
      // restrição (mesma lógica do app de scanner original). Ajuste aqui
      // caso sua planilha passe a ter uma coluna própria de "sim/não".
      hasRestriction: true,
      observation: record.observation,
      source: RenajudSource.local,
      checkedAt: DateTime.now(),
    );
  }
}
