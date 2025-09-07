// lib/budget_estimator.dart
import 'dart:math' as math;

class BudgetEstimator {
  /// Calculate per-person-per-day budget
  double _ppd(int budget, int travelers, int days) {
    if (travelers <= 0 || days <= 0) return 0;
    return budget / travelers / days;
  }

  /// Weighted average of budgets with similarity weights
  double weightedAverage(
    List<Map<String, dynamic>> trips,
    List<double> weights,
  ) {
    if (trips.isEmpty || weights.isEmpty || trips.length != weights.length)
      return 0;
    double sum = 0;
    double wSum = 0;
    for (int i = 0; i < trips.length; i++) {
      final t = trips[i];
      final w = weights[i];
      final ppd = _ppd(t['budget'], t['numberOfTravelers'], t['days']);
      sum += ppd * w;
      wSum += w;
    }
    return wSum > 0 ? sum / wSum : 0;
  }

  /// Apply 10% band around exact matches
  Map<String, dynamic> exactMatchBand(int budget) {
    return {
      'range_min': (budget * 0.9).round(),
      'range_max': (budget * 1.1).round(),
    };
  }

  /// Remove outliers using Median Absolute Deviation (MAD)
  List<Map<String, dynamic>> filterOutliers(
    List<Map<String, dynamic>> trips, {
    double madThreshold = 3.5,
  }) {
    if (trips.length <= 2) return trips; // too few to robustly filter

    final budgets = trips.map((t) => t['budget'] as num).toList()..sort();

    // helper median function
    num _median(List<num> xs) {
      if (xs.isEmpty) return 0;
      final n = xs.length;
      final mid = n ~/ 2;
      return n.isOdd ? xs[mid] : (xs[mid - 1] + xs[mid]) / 2;
    }

    final med = _median(budgets);

    // MAD
    final absDevs = budgets.map((b) => (b - med).abs()).toList()..sort();
    final mad = _median(absDevs);
    if (mad == 0) return trips; // nothing to filter

    // Modified z-score (Iglewicz & Hoaglin)
    bool isOutlier(num b) {
      final mz = 0.6745 * (b - med).abs() / mad;
      return mz > madThreshold;
    }

    return trips.where((t) => !isOutlier(t['budget'] as num)).toList();
  }

  /// Cosine similarity between two preference vectors
  double cosineSimilarity(Map<String, double> u, Map<String, double> v) {
    double dot = 0, normU = 0, normV = 0;
    for (final key in u.keys) {
      final x = u[key] ?? 0;
      final y = v[key] ?? 0;
      dot += x * y;
      normU += x * x;
      normV += y * y;
    }
    if (normU == 0 || normV == 0) return 0;
    return dot / (math.sqrt(normU) * math.sqrt(normV));
  }
}
