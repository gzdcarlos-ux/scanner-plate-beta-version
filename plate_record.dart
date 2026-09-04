/// Representa um registro de placa carregado da planilha e armazenado no SQLite.
class PlateRecord {
  final int? id;
  final String plate; // Já higienizada: maiúscula, sem espaços/hífen/pontuação.
  final String observation;

  const PlateRecord({
    this.id,
    required this.plate,
    required this.observation,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'plate': plate,
      'observation': observation,
    };
  }

  factory PlateRecord.fromMap(Map<String, dynamic> map) {
    return PlateRecord(
      id: map['id'] as int?,
      plate: map['plate'] as String,
      observation: (map['observation'] as String?) ?? '',
    );
  }

  @override
  String toString() => 'PlateRecord(plate: $plate, observation: $observation)';
}
