/// Utilitários para higienização e reconhecimento de placas de veículos brasileiras.
class PlateUtils {
  PlateUtils._();

  // Padrão antigo: ABC1234
  static final RegExp _oldPattern = RegExp(r'^[A-Z]{3}[0-9]{4}$');

  // Padrão Mercosul: ABC1D23
  static final RegExp _mercosulPattern = RegExp(r'^[A-Z]{3}[0-9][A-Z][0-9]{2}$');

  /// Regex combinada usada para varrer texto livre (ex.: saída do OCR) em busca
  /// de qualquer trecho de 7 caracteres que já esteja no formato de placa,
  /// sem espaços. Útil quando o bloco de texto reconhecido já vem "colado".
  static final RegExp _combinedFinder = RegExp(
    r'([A-Z]{3}[0-9]{4})|([A-Z]{3}[0-9][A-Z][0-9]{2})',
  );

  /// Remove espaços, hífens e qualquer pontuação, e converte para maiúsculas.
  /// Ex.: " abc-1234 " -> "ABC1234"
  static String sanitize(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Retorna true se a string (já higienizada) corresponde a um dos dois
  /// formatos de placa brasileira.
  static bool isValidPlate(String sanitized) {
    return _oldPattern.hasMatch(sanitized) ||
        _mercosulPattern.hasMatch(sanitized);
  }

  /// Varre um texto livre (pode conter múltiplas linhas/palavras) e retorna
  /// todas as placas válidas encontradas, já higienizadas e sem duplicatas.
  ///
  /// Estratégia:
  /// 1. Tenta casar diretamente cada "palavra" (após remover espaços internos).
  /// 2. Como fallback, remove TODOS os espaços do texto inteiro e roda uma
  ///    busca por janela deslizante de 7 caracteres, pois o ML Kit às vezes
  ///    quebra a placa em blocos diferentes (ex.: "ABC" e "1234" separados).
  static Set<String> extractPlates(String fullText) {
    final Set<String> found = {};

    // 1) Tenta por linha/token isolado.
    final tokens = fullText.split(RegExp(r'\s+'));
    for (final token in tokens) {
      final clean = sanitize(token);
      if (clean.length == 7 && isValidPlate(clean)) {
        found.add(clean);
      }
    }

    // 2) Fallback: concatena tudo sem espaços e varre com regex + janela.
    final glued = sanitize(fullText.replaceAll('\n', ' '));
    for (final match in _combinedFinder.allMatches(glued)) {
      final value = match.group(0);
      if (value != null) {
        found.add(value);
      }
    }

    return found;
  }
}
