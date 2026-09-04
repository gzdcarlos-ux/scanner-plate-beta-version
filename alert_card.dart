import 'package:flutter/material.dart';

import '../core/models/renajud_status.dart';

/// Card destacado exibido sobre a pré-visualização da câmera quando uma
/// placa reconhecida corresponde a um registro com restrição ativa.
class AlertCard extends StatelessWidget {
  final RenajudStatus record;
  final VoidCallback onDismiss;

  const AlertCard({
    super.key,
    required this.record,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.red.shade700,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.plate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.observation.isNotEmpty
                        ? record.observation
                        : 'Placa cadastrada — sem observação adicional.',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
