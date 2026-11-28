import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_providers.dart';

/// Deletes the signed-in player's account on the server (Google Play
/// requires in-app account deletion). The password is confirmed again, so a
/// left-open session cannot delete someone's account. Throws an
/// AppException on failure: AuthException('forbidden') for a wrong password.
class AccountDeletionDatasource {
  final ApiClient _api;

  AccountDeletionDatasource(this._api);

  Future<void> deleteAccount(String password) async {
    await _api.post(ApiEndpoints.profileDelete, body: {'password': password});
  }
}

final accountDeletionDatasourceProvider = Provider<AccountDeletionDatasource>((
  ref,
) {
  return AccountDeletionDatasource(ref.watch(apiClientProvider));
});
