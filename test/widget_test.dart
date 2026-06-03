import 'package:flutter_test/flutter_test.dart';
import 'package:meo_geosys_mobile/src/app.dart';
import 'package:meo_geosys_mobile/src/state/application_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('login screen renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ApplicationController()),
        ],
        child: const MeoMobileApp(),
      ),
    );

    expect(find.text('MEO GeoSys Mobile'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
