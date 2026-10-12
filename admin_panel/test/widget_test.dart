// Placeholder: el test por defecto de `flutter create` referenciaba un
// `MyApp` que no existe en este proyecto (nuestro widget raíz es
// `AdminPanelApp`, en lib/main.dart). Probarlo de verdad requiere mockear
// Firebase (Firestore/Auth) ya que `AdminPanelApp` los usa desde
// `initState`; eso se arma cuando haya dashboard real que probar.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, 2);
  });
}
