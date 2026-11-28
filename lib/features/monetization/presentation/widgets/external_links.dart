import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/network_providers.dart';

/// Google Play's subscription centre for one subscription of this app.
Uri playSubscriptionsUri(String productId) => Uri.https(
  'play.google.com',
  '/store/account/subscriptions',
  {'sku': productId, 'package': 'com.skillverse.skillverse_app'},
);

/// The privacy policy served by the backend (the same URL goes in Play Console).
Uri privacyPolicyUri(WidgetRef ref) =>
    Uri.parse('${ref.read(apiConfigProvider).rootUrl}/privacy');

/// Opens a link outside the app, or says it could not.
Future<void> openExternalLink(BuildContext context, Uri uri) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Could not open $uri')));
  }
}
