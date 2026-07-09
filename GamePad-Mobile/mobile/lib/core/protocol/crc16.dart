/// CRC16-CCITT with precomputed lookup table (polynomial 0x1021).
class Crc16 {
  Crc16._();

  static const int _polynomial = 0x1021;
  static const int _initialValue = 0xFFFF;

  static final List<int> _table = _buildTable();

  static List<int> _buildTable() {
    final table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int crc = 0;
      int val = i << 8;
      for (int j = 0; j < 8; j++) {
        if (((crc ^ val) & 0x8000) != 0) {
          crc = (crc << 1) ^ _polynomial;
        } else {
          crc <<= 1;
        }
        val <<= 1;
      }
      table[i] = crc & 0xFFFF;
    }
    return table;
  }

  /// Computes CRC16-CCITT over [data].
  static int compute(List<int> data) {
    int crc = _initialValue;
    for (final b in data) {
      final index = ((crc >> 8) ^ b) & 0xFF;
      crc = ((crc << 8) ^ _table[index]) & 0xFFFF;
    }
    return crc;
  }

  /// Appends CRC16 (big-endian) at positions [data.length - 2] and
  /// [data.length - 1]. The CRC is computed over data[0..length-3].
  static void append(List<int> data) {
    if (data.length < 2) {
      throw ArgumentError('Buffer too small for CRC16');
    }
    final crc = compute(data.sublist(0, data.length - 2));
    data[data.length - 2] = (crc >> 8) & 0xFF;
    data[data.length - 1] = crc & 0xFF;
  }

  /// Validates the CRC16 stored at the end of [data].
  static bool validate(List<int> data) {
    if (data.length < 2) return false;
    final stored = (data[data.length - 2] << 8) | data[data.length - 1];
    final computed = compute(data.sublist(0, data.length - 2));
    return stored == computed;
  }
}
