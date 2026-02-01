class HistoryNode {
  final String id;
  final String parentId;
  final String label;
  final dynamic imageSource; // File, String(Asset), or Uint8List
  final DateTime timestamp;

  HistoryNode({
    required this.id,
    required this.parentId,
    required this.label,
    required this.imageSource,
    required this.timestamp,
  });
}
