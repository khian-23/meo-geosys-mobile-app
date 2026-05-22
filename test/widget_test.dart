import 'package:flutter_test/flutter_test.dart';
import 'package:meo_geosys_mobile/src/app.dart';

void main() {
  testWidgets('login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MeoMobileApp());

    expect(find.text('MEO GeoSys Mobile'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
