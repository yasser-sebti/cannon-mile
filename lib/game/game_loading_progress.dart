class GameLoadingProgress {
  const GameLoadingProgress({
    required this.completed,
    required this.total,
    required this.label,
  });

  final int completed;
  final int total;
  final String label;

  double get fraction => total <= 0 ? 0 : (completed / total).clamp(0.0, 1.0);
}
