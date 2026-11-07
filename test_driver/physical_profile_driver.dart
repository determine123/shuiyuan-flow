import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      if (data == null) throw StateError('未收到 Profile 响应数据');
      final root = Directory(
        Platform.environment['SHUIYUAN_PROFILE_OUTPUT'] ??
            'artifacts/physical-profile',
      );
      await root.create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await File('${root.path}/response.json')
          .writeAsString(encoder.convert(data));
      if (data['ux_metrics'] != null) {
        await File('${root.path}/metrics.json')
            .writeAsString(encoder.convert(data['ux_metrics']));
      }
      if (data['browsing_timeline'] != null) {
        await File('${root.path}/timeline.json')
            .writeAsString(encoder.convert(data['browsing_timeline']));
      }
    },
  );
}
