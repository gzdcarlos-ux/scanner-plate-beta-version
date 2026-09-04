import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models/renajud_status.dart';
import '../core/renajud_service.dart';
import '../utils/plate_utils.dart';

/// Formatter que aplica, em tempo real, a máscara de placa brasileira
/// (antiga ABC-1234 / Mercosul ABC1D23), convertendo para maiúsculas.
class _PlateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (digits.length > 7) digits = digits.substring(0, 7);

    String formatted = digits;
    if (digits.length > 4) {
      final fifthChar = digits[4];
      final isMercosul = RegExp(r'[A-Z]').hasMatch(fifthChar);
      if (!isMercosul) {
        // Formato antigo -> insere hífen: ABC-1234
        formatted = '${digits.substring(0, 3)}-${digits.substring(3)}';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

enum _UiState { idle, loading, success, alert, error }

/// Tela de consulta manual: usuário digita a placa e recebe SOMENTE o
/// status booleano de restrição — mesma filosofia de UX do protótipo
/// HTML, agora consumindo o RenajudService (local + mock + remoto).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _renajudService = RenajudService();

  _UiState _state = _UiState.idle;
  RenajudStatus? _lastResult;
  String _lastQueriedDisplay = '';

  Future<void> _handleSearch() async {
    final sanitized = PlateUtils.sanitize(_controller.text);

    if (!PlateUtils.isValidPlate(sanitized)) {
      setState(() {
        _state = _UiState.error;
        _lastQueriedDisplay = _controller.text;
      });
      return;
    }

    setState(() {
      _state = _UiState.loading;
      _lastQueriedDisplay = _controller.text;
    });

    final result = await _renajudService.check(sanitized);

    if (!mounted) return;

    setState(() {
      _lastResult = result;
      if (!result.isKnown) {
        _state = _UiState.error;
      } else {
        _state = result.isRestricted ? _UiState.alert : _UiState.success;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _state == _UiState.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Consulta manual de placa')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PLACA DO VEÍCULO',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    inputFormatters: [_PlateInputFormatter()],
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ABC-1234',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleSearch,
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Buscar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Teste: AAA0000 (positivo) / BBB1111 (negativo)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_state == _UiState.idle || _state == _UiState.loading) {
      return const SizedBox.shrink();
    }

    late final Color bg;
    late final Color border;
    late final Color fg;
    late final IconData icon;
    late final String title;
    late final String desc;

    switch (_state) {
      case _UiState.success:
        bg = Colors.green.shade50;
        border = Colors.green.shade300;
        fg = Colors.green.shade800;
        icon = Icons.check_circle_outline;
        title = 'Veículo Regularizado';
        desc = 'Sem restrição de busca ativa encontrada para esta placa.';
        break;
      case _UiState.alert:
        bg = Colors.red.shade50;
        border = Colors.red.shade300;
        fg = Colors.red.shade800;
        icon = Icons.warning_amber_rounded;
        title = 'ALERTA: Restrição encontrada';
        desc = _lastResult?.observation?.isNotEmpty == true
            ? _lastResult!.observation!
            : 'Este veículo possui restrição judicial / ordem de busca e apreensão ativa.';
        break;
      case _UiState.error:
      default:
        bg = Colors.orange.shade50;
        border = Colors.orange.shade300;
        fg = Colors.orange.shade900;
        icon = Icons.error_outline;
        title = 'Não foi possível concluir a consulta';
        desc = 'Verifique se a placa está completa e correta, ou tente novamente em instantes.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lastQueriedDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg.withOpacity(0.7),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: fg)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 13.5, color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
