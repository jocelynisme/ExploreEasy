import 'package:flutter_test/flutter_test.dart';
import 'package:travel_buddy/budget_estimator.dart';

void main() {
  final estimator = BudgetEstimator();

  final trips = [
    {'budget': 2000, 'numberOfTravelers': 2, 'days': 3}, // ppd ≈ 333
    {'budget': 1500, 'numberOfTravelers': 2, 'days': 3}, // ppd ≈ 250
    {
      'budget': 5000,
      'numberOfTravelers': 4,
      'days': 5,
    }, // ppd = 250 (outlier if overspent)
  ];

  group('11.1 Budget Estimation Tests', () {
    test(
      'TC092 Sufficient similar trips: weighted average budget calculated',
      () {
        final weights = [0.7, 0.3, 0.5];
        final avg = estimator.weightedAverage(trips, weights);
        expect(avg > 250 && avg < 333, true); // between lowest & highest ppd
      },
    );

    test('TC093 Exact match preference: exact matches used with 10% band', () {
      final band = estimator.exactMatchBand(2000);
      expect(band['range_min'], 1800);
      expect(band['range_max'], 2200);
    });

    test('TC094 No similar trips: fallback budget calculation used', () {
      final avg = estimator.weightedAverage([], []);
      expect(avg, 0); // fallback
    });

    test('TC095 Outlier filtering: extreme values excluded', () {
      final filtered = estimator.filterOutliers(trips);
      // Should keep 2000 and 1500, possibly exclude 5000 if far
      expect(filtered.any((t) => t['budget'] == 5000), isFalse);
    });

    test('TC096 User similarity calculation: cosine similarity', () {
      final u = {'Beach': 8.0, 'City': 6.0, 'Nature': 7.0, 'History': 5.0};
      final v = {'Beach': 9.0, 'City': 5.0, 'Nature': 8.0, 'History': 6.0};
      final sim = estimator.cosineSimilarity(u, v);
      expect(sim > 0.8, true); // high similarity
    });
  });
}
