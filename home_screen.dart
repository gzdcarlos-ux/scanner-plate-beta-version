import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/database_service.dart';
import '../services/excel_import_service.dart';
import 'scanner_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _plateCount = 0;
  bool _isImporting = false;
  String? _lastImportSummary;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final count = await DatabaseService.instance.countPlates();
    if (mounted) setState(() => _plateCount = count);
  }

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);
    try {
      final result = await ExcelImportService.pickAndImport();
      if (result != null) {
        setState(() {
          _lastImportSummary =
              '"${result.fileName}": ${result.validPlatesImported} placas importadas '
              '(${result.skippedRows} linhas ignoradas de ${result.totalRowsRead} lidas).';
        });
        await _refreshCount();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar planilha: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _handleStartScan() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de câmera é necessária para escanear placas.')),
        );
      }
      return;
    }

    if (_plateCount == 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nenhuma placa cadastrada'),
          content: const Text(
            'Você ainda não importou nenhuma planilha. O scanner funcionará, '
            'mas nenhum alerta será disparado. Deseja continuar mesmo assim?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leitor de Placas')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.storage, size: 40, color: Colors.blueGrey),
                    const SizedBox(height: 8),
                    Text(
                      '$_plateCount',
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                    const Text('placas cadastradas na base local'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isImporting ? null : _handleImport,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_isImporting ? 'Importando...' : 'Importar planilha (.xlsx)'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
            if (_lastImportSummary != null) ...[
              const SizedBox(height: 8),
              Text(
                _lastImportSummary!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _handleStartScan,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Iniciar leitura em tempo real'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('Consultar placa manualmente'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Limpar base local'),
                    content: const Text('Isso apagará todas as placas cadastradas. Deseja continuar?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await DatabaseService.instance.clearAll();
                  await _refreshCount();
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Limpar base local'),
            ),
          ],
        ),
      ),
    );
  }
}
