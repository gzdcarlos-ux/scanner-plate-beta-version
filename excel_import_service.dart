import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';

import '../models/plate_record.dart';
import '../utils/plate_utils.dart';
import 'database_service.dart';

/// Resultado de uma importação, para exibir feedback na UI.
class ImportResult {
  final int totalRowsRead;
  final int validPlatesImported;
  final int skippedRows;
  final String? fileName;

  const ImportResult({
    required this.totalRowsRead,
    required this.validPlatesImported,
    required this.skippedRows,
    this.fileName,
  });
}

/// Serviço responsável por abrir o seletor de arquivos, ler o .xlsx
/// selecionado e popular o banco SQLite local.
class ExcelImportService {
  ExcelImportService._();

  /// Abre o seletor de arquivos restrito a .xlsx, faz o parsing e grava
  /// no SQLite. Retorna `null` se o usuário cancelar a seleção.
  ///
  /// Regras:
  /// - Coluna 0 (A) = número da placa.
  /// - Coluna 1 (B) = observação/alerta associado.
  /// - A primeira linha é tratada como cabeçalho e ignorada automaticamente
  ///   se a coluna 0 dessa linha não corresponder a um padrão de placa válido.
  static Future<ImportResult?> pickAndImport() async {
    final pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true, // necessário para funcionar de forma confiável em Android/iOS
    );

    if (pickedFile == null || pickedFile.files.isEmpty) {
      return null; // usuário cancelou
    }

    final file = pickedFile.files.first;
    final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);

    if (bytes == null) {
      throw Exception('Não foi possível ler os bytes do arquivo selecionado.');
    }

    final excelFile = xls.Excel.decodeBytes(bytes);

    int totalRows = 0;
    int skipped = 0;
    final List<PlateRecord> toImport = [];

    // Usa a primeira planilha (sheet) do arquivo.
    if (excelFile.tables.isEmpty) {
      throw Exception('A planilha não contém nenhuma aba/sheet.');
    }
    final sheet = excelFile.tables[excelFile.tables.keys.first]!;

    for (final row in sheet.rows) {
      totalRows++;

      if (row.isEmpty) {
        skipped++;
        continue;
      }

      final rawPlateCell = row.isNotEmpty ? row[0]?.value : null;
      final rawObsCell = row.length > 1 ? row[1]?.value : null;

      final rawPlate = rawPlateCell?.toString() ?? '';
      final rawObservation = rawObsCell?.toString() ?? '';

      final sanitizedPlate = PlateUtils.sanitize(rawPlate);

      // Ignora linha de cabeçalho / linhas sem placa válida.
      if (sanitizedPlate.isEmpty || !PlateUtils.isValidPlate(sanitizedPlate)) {
        skipped++;
        continue;
      }

      toImport.add(
        PlateRecord(
          plate: sanitizedPlate,
          observation: rawObservation.trim(),
        ),
      );
    }

    final imported = await DatabaseService.instance.upsertPlates(toImport);

    return ImportResult(
      totalRowsRead: totalRows,
      validPlatesImported: imported,
      skippedRows: skipped,
      fileName: file.name,
    );
  }
}
