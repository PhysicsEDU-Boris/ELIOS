import 'package:elio/models/config_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default port is the MaixCAM2 firmware port 8765', () {
    expect(const EspConfig().port, 8765);
    expect(EspConfig.fromMap({}).port, 8765);
  });

  test('a saved config with the old 8080 default moves to 8765', () {
    expect(EspConfig.fromMap({'port': 8080}).port, 8765);
  });

  test('a port the user chose is kept', () {
    expect(EspConfig.fromMap({'port': 9000}).port, 9000);
    expect(EspConfig.fromMap(const EspConfig(port: 9000).toMap()).port, 9000);
  });
}
