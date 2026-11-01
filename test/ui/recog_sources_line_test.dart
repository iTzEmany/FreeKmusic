import 'package:codecore/l10n/app_localizations_it.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/ui/screens/activity/activity_log_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Registro line of a job says how many songs each source recognised', () {
    const done = EnrichJobResult(done: 3, total: 3, sources: {'acoustid': 2, 'text': 1});
    expect(done.logDetail, {'sources': {'acoustid': 2, 'text': 1}});
    expect(const EnrichJobResult(failed: true, updated: 1, notFound: 2, sources: {'ytm': 1}).logDetail,
        {'updated': 1, 'notFound': 2, 'sources': {'ytm': 1}});
    expect(const EnrichJobResult().logDetail, isNull); // as before
    expect(recogSourcesLine(AppLocalizationsIt(), done.logDetail), 'Riconosciuti: testo 1, AcoustID 2');
    expect(recogSourcesLine(AppLocalizationsIt(), const {'stopped': true}), isNull);
  });
}
