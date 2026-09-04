import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/renajud_api_config.dart';
import '../models/renajud_status.dart';
import 'renajud_provider.dart';

/// Consulta a API Placas (backend WDAPI2 — https://apiplacas.com.br/doc.php)
/// e devolve SOMENTE o booleano de restrição.
///
/// Formato confirmado na documentação oficial:
///   GET https://wdapi2.com.br/consulta/{placa}/{token}
/// (token vai na própria URL, não em header Authorization).
///
/// Ponto-chave de conformidade: mesmo que a API retorne marca, modelo,
/// cor, município, chassi (mascarado) etc., este provider extrai apenas
/// o indicador de restrição e descarta o resto ANTES de qualquer
/// persistência ou exibição — o restante do app nunca chega a ver esses
/// outros campos.
class RemoteRenajudProvider implements RenajudProvider {
  @override
  String get name => 'remote_api_placas';

  @override
  Future<RenajudStatus> check(String sanitizedPlate) async {
    if (!RenajudApiConfig.remoteEnabled) {
      return RenajudStatus.notFound(sanitizedPlate);
    }

    try {
      final uri = RenajudApiConfig.buildUrl(sanitizedPlate);

      final response = await http
          .get(uri, headers: RenajudApiConfig.headers)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return RenajudStatus.error(sanitizedPlate);
      }

      final Map<String, dynamic> json = jsonDecode(response.body);

      // Placa não encontrada na base do provider.
      if (json.containsKey('erro') || json.containsKey('message')) {
        return RenajudStatus.notFound(sanitizedPlate);
      }

      final bool? hasRestriction = _extractRestrictionFlag(json);

      if (hasRestriction == null) {
        // Path configurado não bateu com o JSON real — não arrisca dar um
        // falso "sem restrição". Melhor reportar como indeterminado e
        // deixar isso visível nos logs de debug (ver `debugRawResponse`).
        _logSchemaMismatch(json);
        return RenajudStatus.error(sanitizedPlate);
      }

      // A partir daqui, "json" completo é descartado — só o booleano segue adiante.
      return RenajudStatus(
        plate: sanitizedPlate,
        hasRestriction: hasRestriction,
        source: RenajudSource.remote,
        checkedAt: DateTime.now(),
      );
    } catch (_) {
      return RenajudStatus.error(sanitizedPlate);
    }
  }

  /// Navega o JSON pelo dot-path configurado (ex.: "extra.restricoes")
  /// e normaliza o valor encontrado para booleano.
  bool? _extractRestrictionFlag(Map<String, dynamic> json) {
    dynamic current = json;
    for (final key in RenajudApiConfig.restrictionFieldPath.split('.')) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }

    if (current == null) return null;
    if (current is bool) return current;
    if (current is num) return current != 0;
    if (current is List) return current.isNotEmpty; // ex.: lista de restrições ativas
    if (current is Map) return current.isNotEmpty;
    if (current is String) {
      final normalized = current.trim().toUpperCase();
      if (normalized.isEmpty) return false;
      return normalized == 'S' || normalized == 'TRUE' || normalized == 'SIM' || normalized == '1';
    }
    return null;
  }

  /// Ajuda a diagnosticar rapidamente qual é o schema real da API na
  /// primeira consulta de teste — aparece só no console de debug, nunca
  /// é exibido na UI nem persistido em disco.
  void _logSchemaMismatch(Map<String, dynamic> json) {
    // ignore: avoid_print
    print(
      '[RemoteRenajudProvider] restrictionFieldPath '
      '"${RenajudApiConfig.restrictionFieldPath}" não encontrado. '
      'Chaves de nível raiz recebidas: ${json.keys.toList()}. '
      'Ajuste RenajudApiConfig.restrictionFieldPath conforme o JSON real.',
    );
  }
}
