/// ==========================================================================
/// CONFIGURAÇÃO DO PROVIDER REMOTO — API Placas (backend WDAPI2)
///
/// Documentação oficial: https://apiplacas.com.br/doc.php
///
/// Formato de chamada (confirmado na documentação): o token vai DIRETO na
/// URL, como parte do path — não é um Bearer Token em header como em outras
/// APIs. Exemplo:
///   GET https://wdapi2.com.br/consulta/ABC1234/SEU_TOKEN
///
/// IMPORTANTE (LGPD / segurança):
/// - NUNCA deixe o token de produção hardcoded num app publicado.
///   Prefira buscar isso de um backend seu (que guarda a chave) em vez
///   de embutir a chave dentro do APK.
/// - Este arquivo serve para prototipagem/desenvolvimento local.
///
/// ATENÇÃO — schema de resposta ainda precisa ser confirmado com uma
/// chamada real: a documentação pública da API Placas confirma os campos
/// básicos (marca, modelo, ano, cor, município, UF, chassi mascarado) e
/// menciona um campo "extra" com informações adicionais que "podem não
/// estar disponíveis em todas as consultas" — mas não publica o nome exato
/// do subcampo de restrição/RENAJUD dentro de "extra". Faça uma consulta
/// de teste com uma placa conhecida, veja o JSON bruto retornado e ajuste
/// `restrictionFieldPath` abaixo antes de confiar no resultado em produção.
/// ==========================================================================
class RenajudApiConfig {
  RenajudApiConfig._();

  /// Provider remoto habilitado.
  static const bool remoteEnabled = true;

  /// Host base do WDAPI2 (usado pela API Placas).
  static const String baseHost = "https://wdapi2.com.br/consulta";

  /// Token fornecido pela API Placas.
  /// TODO: mova para variável de ambiente / backend próprio antes de publicar o app.
  static const String apiToken = "8382cdefbfd65ddd976f78f6aac55ff1";

  /// Monta a URL final: https://wdapi2.com.br/consulta/{placa}/{token}
  static Uri buildUrl(String sanitizedPlate) {
    return Uri.parse("$baseHost/$sanitizedPlate/$apiToken");
  }

  /// Headers — a API Placas não exige Authorization em header (token vai na
  /// URL), mas mantemos o Content-Type por padrão de boas práticas HTTP.
  static const Map<String, String> headers = {
    "Content-Type": "application/json",
  };

  /// Caminho (dot-path) dentro do JSON de resposta que indica se HÁ
  /// restrição/RENAJUD ativa.
  ///
  /// ⚠️ PENDENTE DE CONFIRMAÇÃO: ajuste este valor depois de ver uma
  /// resposta real da API. Candidatos prováveis, pela estrutura comum de
  /// APIs desse tipo: "extra.restricoes", "extra.renajud",
  /// "extra.furtoRoubo". Enquanto não confirmado, o provider trata
  /// qualquer erro de path como "não determinado" (nunca como falso
  /// positivo/negativo silencioso).
  static const String restrictionFieldPath = "extra.restricoes";
}

