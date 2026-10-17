import 'package:flutter_test/flutter_test.dart';
import 'package:purebili/api/models.dart';

void main() {
  test('format helpers', () {
    expect(fmtDur(65), '01:05');
    expect(fmtCount(12345), '1.2万');
    expect(bvPattern.hasMatch('BV1xx411c7mD'), true);
  });
}
