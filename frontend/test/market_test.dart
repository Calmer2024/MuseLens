import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/providers/market_provider.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/core/providers/asset_tree_provider.dart';
import 'package:frontend/data/models/providers/services/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('market provider test', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    
    print('Reading provider...');
    try {
      final query = MarketLensQuery(status: 'active');
      final result = await container.read(marketLensListProvider(query).future);
      print('Result: $result');
    } catch (e, st) {
      print('Error: $e\n$st');
    }
  });
}
