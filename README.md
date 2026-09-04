# Leitor de Placas em Tempo Real

App Flutter (Android) que lê placas de veículos pela câmera em tempo real
(OCR via Google ML Kit) e cruza cada leitura com uma base local SQLite
populada a partir de uma planilha `.xlsx`.

## Estrutura do projeto

```
lib/
  main.dart
  models/
    plate_record.dart        # Modelo de dados
  services/
    database_service.dart    # SQLite + índice único na coluna "plate"
    excel_import_service.dart# Importação da planilha .xlsx
    plate_ocr_service.dart   # Conversão de frame + ML Kit + extração via regex
    alert_service.dart       # Cooldown de 3s + vibração
  screens/
    home_screen.dart         # Import da planilha, contador, botão de scan
    scanner_screen.dart      # Câmera + OCR em tempo real + alertas
  widgets/
    alert_card.dart          # Card visual do alerta
  utils/
    plate_utils.dart         # Sanitização e regex de placas (antiga/Mercosul)
android/
  app/
    build.gradle             # minSdkVersion 21 (exigido por camera + ML Kit)
    src/main/AndroidManifest.xml
pubspec.yaml
```

## Pré-requisitos para compilar

1. Flutter SDK 3.22+ instalado (`flutter --version`).
2. Android Studio ou apenas o Android SDK/cmdline-tools + um dispositivo/emulador Android 5.0+ (API 21).
3. Um dispositivo físico é fortemente recomendado para testar a câmera (emuladores costumam ter câmera virtual limitada, o que prejudica a leitura de placas reais).

## Como compilar e instalar

A partir da raiz do projeto (onde está o `pubspec.yaml`):

```bash
# 1. Baixe as dependências
flutter pub get

# 2. (opcional) Verifique se está tudo certo com o ambiente
flutter doctor

# 3. Conecte o celular Android via USB com "Depuração USB" ativada
flutter devices

# 4. Instale e rode diretamente no aparelho conectado
flutter run --release

# --- OU, para gerar um APK instalável manualmente ---
flutter build apk --release
# O APK fica em: build/app/outputs/flutter-apk/app-release.apk
# Copie esse arquivo para o celular e instale (habilite "Fontes desconhecidas").
```

Para gerar um **App Bundle** (formato exigido pela Play Store):

```bash
flutter build appbundle --release
```

## Build automático no Codemagic via codemagic.yaml

Este projeto já inclui um `codemagic.yaml` na raiz, então o Codemagic **detecta
e configura o build sozinho** assim que você conecta o repositório — não
precisa montar o workflow manualmente pela interface visual (o passo a passo
"clique em Add application, escolha Android, etc." descrito anteriormente
não é mais necessário).

**Passo a passo:**

1. Suba todo o conteúdo desta pasta — **incluindo o `codemagic.yaml`** — para
   um repositório no GitHub (a raiz do repositório deve ser esta mesma pasta,
   não uma subpasta).
2. Em [codemagic.io](https://codemagic.io), conecte sua conta GitHub e
   selecione esse repositório.
3. O Codemagic vai encontrar o `codemagic.yaml` automaticamente e listar dois
   workflows disponíveis:
   - **`android-release`** — gera o APK de release; dispara sozinho a cada
     push nas branches `main`/`master`, ou manualmente pelo botão "Start new
     build".
   - **`android-debug`** — gera um APK de debug; só roda quando você clica em
     "Start new build" (não dispara automático), útil pra testar rápido.
4. Ao final da build, baixe o `.apk` na aba **Artifacts** da execução.

### Por que o `codemagic.yaml` "regenera" parte da pasta `android/`

O zip não inclui arquivos binários/gerados automaticamente do Gradle
(`gradle-wrapper.jar`, ícones padrão, `MainActivity.kt`) porque eles mudam
conforme a versão do Flutter — versioná-los manualmente arriscaria ficarem
desatualizados. Por isso o workflow roda `flutter create --platforms=android .`
no início de cada build (que preenche automaticamente esses arquivos que
faltam) e, em seguida, **restaura** o `AndroidManifest.xml` e o
`android/app/build.gradle` deste projeto — que são os arquivos que de fato
carregam as customizações importantes (permissões de câmera/internet,
`minSdkVersion 21` etc.). Isso é feito automaticamente; você não precisa
mexer em nada.

Se preferir gerar o APK sem o Codemagic, o `.github/workflows/build-apk.yml`
(GitHub Actions) continua funcionando como alternativa — veja a seção
anterior.

## Assinatura para produção

O `build.gradle` fornecido usa a chave de debug (`signingConfigs.debug`) apenas
para permitir compilar imediatamente. Para publicar ou distribuir oficialmente,
gere sua própria keystore e configure `signingConfigs.release` conforme a
[documentação oficial do Flutter](https://docs.flutter.dev/deployment/android#sign-the-app).

## Formato esperado da planilha .xlsx

| Coluna A (placa) | Coluna B (observação) |
|---|---|
| ABC1234           | Alerta / motivo associado |
| JBL9D33           | Ex.: veículo com pendência de recuperação |

- A primeira linha pode ser um cabeçalho — o app ignora automaticamente
  qualquer linha cuja coluna A não corresponda ao padrão de placa (antigo
  `ABC1234` ou Mercosul `ABC1D23`).
- A higienização remove espaços, hífens e pontuações e converte para
  maiúsculas antes de gravar/consultar no banco.

## Observações técnicas importantes

- **Trava de processamento (`_isProcessing`)**: implementada em
  `scanner_screen.dart`, garante que apenas um frame por vez seja enviado
  ao ML Kit, evitando fila de frames e picos de memória.
- **Cooldown de alerta**: implementado em `alert_service.dart` (3s por
  padrão, configurável no construtor de `AlertService`).
- **Índice no SQLite**: `CREATE UNIQUE INDEX idx_plates_plate ON plates(plate)`
  garante consultas por igualdade extremamente rápidas mesmo com dezenas
  de milhares de registros.
- **Conversão YUV420 → NV21**: necessária porque o plugin `camera` entrega
  frames em planos separados (Y, U, V) no Android, enquanto o ML Kit espera
  o layout NV21. Essa conversão está isolada em `plate_ocr_service.dart`.

## Arquitetura de consulta (providers em camadas)

A partir desta versão, nem o scanner de câmera nem a busca manual consultam
o SQLite diretamente. Toda consulta passa por `lib/core/renajud_service.dart`,
que tenta, em ordem, uma lista de providers que implementam a interface
`RenajudProvider` (`lib/core/providers/renajud_provider.dart`):

```
RenajudService.check(placa)
  1) MockRenajudProvider   -> AAA0000 / BBB1111 (só para testes)
  2) LocalRenajudProvider  -> consulta o SQLite (planilha .xlsx importada)
  3) RemoteRenajudProvider -> API paga externa (desligada por padrão)
```

Isso significa que trocar de fonte de dados — por exemplo, ligar futuramente
uma API comercial de verdade — é só:

1. Preencher `lib/core/config/renajud_api_config.dart` com URL/token reais e
   colocar `remoteEnabled = true`.
2. Nenhuma tela (`scanner_screen.dart`, `search_screen.dart`) precisa mudar.

### Por que não existe um provider "RENAJUD oficial gratuito"

Pesquisa feita antes de desenhar essa arquitetura: o RENAJUD é um sistema do
CNJ/Serpro que liga o Judiciário à base do RENAVAM — acesso direto é restrito
a juízes, tribunais e órgãos conveniados, sem token público. Os DETRANs
estaduais mostram a restrição (que tem origem no RENAJUD) nas consultas
oficiais por placa/RENAVAM, mas apenas via portal web com captcha, sem API
aberta, e os Termos de Uso normalmente proíbem automação. Existiu no passado
um endpoint semi-público do SINESP Cidadão, mas hoje ele é ativamente
bloqueado. O caminho realista para automação é contratar uma API comercial
que já tem convênio/RPA com os DETRANs (ex.: Infosimples, Apify
"brasildados"), pagando por consulta — é para isso que `RemoteRenajudProvider`
já está preparado.

**Minimização de dados (LGPD):** o `RemoteRenajudProvider` extrai *apenas* o
campo booleano de restrição do JSON de resposta e descarta todo o resto
(marca, modelo, proprietário etc.) antes de esse dado tocar qualquer outra
camada do app — nunca persista ou exiba os campos extras que a API devolver.

### Provider remoto configurado: API Placas (WDAPI2)

Após pesquisa, o provider remoto foi ligado (`remoteEnabled = true`) usando a
**API Placas** (`https://apiplacas.com.br/doc.php`, que roda sobre o backend
WDAPI2). O formato confirmado na documentação oficial é:

```
GET https://wdapi2.com.br/consulta/{placa}/{token}
```

O token vai direto na URL (não é um Bearer Token em header). O token
informado já está em `lib/core/config/renajud_api_config.dart`.

**⚠️ Pendência que você precisa resolver antes de confiar no resultado:**
a documentação pública da API Placas confirma os campos básicos do retorno
(marca, modelo, ano, cor, município, UF, chassi mascarado) e cita um campo
`"extra"` com dados adicionais, mas **não publica o nome exato do subcampo
de restrição/RENAJUD** dentro desse `extra`. Fiz uma escolha conservadora:
`restrictionFieldPath = "extra.restricoes"` como palpite inicial, mas o
provider foi escrito para **nunca mascarar isso** — se o campo não existir
no JSON real, ele retorna "indeterminado" (nunca finge que está regularizado)
e imprime no console de debug as chaves reais recebidas, para você me passar
e eu ajustar o path com precisão.

**Como confirmar o schema real:** faça uma consulta de teste com uma placa
conhecida (rode o app em modo debug e veja o `print` no console, ou teste a
URL `https://wdapi2.com.br/consulta/PLACA/8382cdefbfd65ddd976f78f6aac55ff1`
diretamente no navegador/Postman) e me mande o JSON retornado — eu ajusto
`restrictionFieldPath` para o caminho certo.

**Limitação do teste via `renajud_test.html` no navegador:** APIs desse tipo
geralmente não liberam CORS para chamadas via `fetch()` a partir de um
arquivo HTML local/estático — elas são pensadas para uso server-side ou
dentro de um app nativo (como o Flutter, que não sofre essa restrição). Se o
checkbox "Remoto" no HTML de teste der erro de CORS no console do navegador,
isso é esperado; a consulta real deve ser validada rodando o app Flutter em
um dispositivo, não pelo navegador.

## Testando a lógica no navegador antes de rodar no celular

`web_test/renajud_test.html` é um arquivo único (sem dependências de build)
que replica em JavaScript puro a mesma arquitetura em camadas do Dart
(`Mock -> Local -> Remoto`). Basta abrir esse arquivo direto no navegador
(duplo clique) para:

- Ligar/desligar cada provider individualmente (checkboxes no topo).
- Editar a "base local simulada" (textarea no formato `PLACA;observação`,
  igual ao formato da planilha .xlsx) e testar o cruzamento sem precisar
  compilar o app.
- Validar os 3 estados de UI (regularizado / alerta / erro) e a máscara de
  placa antes de portar qualquer ajuste visual para o Flutter.

Use esse HTML como bancada de testes rápida; a versão "de verdade" da lógica
vive em `lib/core/`.

## Uso responsável e conformidade legal

Este é um sistema de reconhecimento automático de placas (ANPR). Antes de
operar em vias públicas, verifique as exigências da LGPD (Lei Geral de
Proteção de Dados) e eventuais licenças/autorizações aplicáveis à sua
atividade (ex.: empresas de recuperação de veículos, segurança patrimonial,
gestão de frotas), já que o processamento de imagens de placas envolve
dados pessoais.
