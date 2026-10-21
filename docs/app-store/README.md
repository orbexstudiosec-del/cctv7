# CCTV CANAL 7 en el App Store

Lo que se cargó en App Store Connect para la primera versión de iOS (1.0.1),
para no tener que rearmarlo en la próxima.

## Datos de la app

| | |
|---|---|
| Nombre | CCTV CANAL 7 |
| Bundle ID | `com.orbexstudios.cctvcanal7` |
| Apple ID (App Store Connect) | 6825162932 |
| App iOS en Firebase (`canal7app`) | `1:72308547984:ios:2bbdffe9ebd8c33c041315` |
| Precio | Gratis |
| Copyright | 2026 CCTV CANAL 7 |
| URL de privacidad | https://canal7app.web.app/privacidad.html |
| URL de soporte | https://canal7app.web.app/privacidad.html (tiene la sección de contacto) |

## Compilar y subir (Codemagic)

No hace falta Mac: el workflow `ios-release` de [`codemagic.yaml`](../../codemagic.yaml)
compila el IPA y lo sube a TestFlight.

- Clave de App Store Connect: la integración `nortvision_asc_key` de la cuenta
  (la misma que usan Bex y Nortvision).
- Grupo de variables `cctv7_ios` en la app de Codemagic, con
  `CERTIFICATE_PRIVATE_KEY`: la clave RSA del certificado de distribución.
  **No está en el repo**; respaldarla fuera. Conviene usar esa misma clave en
  las demás apps de iOS de la cuenta: Apple permite solo 3 certificados de
  distribución y con una clave compartida todas usan el mismo.
- El número de build se calcula solo (último de TestFlight + 1). La versión
  (`1.0.1` en `viewer_app/pubspec.yaml`) hay que subirla a mano después de
  cada aprobación, o Apple rechaza el build.

## Ficha de la tienda

**Texto promocional**

> Mira la señal de CCTV CANAL 7 en vivo desde tu celular, gratis y sin registrarte. Noticias y programación del canal al instante.

**Descripción**

```
CCTV CANAL 7 en tu bolsillo. Abre la app y la señal del canal empieza a reproducirse al instante, sin crear cuenta ni iniciar sesión.

EN VIVO
• La transmisión del canal las 24 horas, en pantalla completa.
• Imagen en imagen: sigue viendo el canal mientras usas otras apps.
• Te mostramos qué programa está al aire en este momento.

NOTICIAS
• Las noticias del canal, con las más importantes destacadas.
• Navega por categorías y lee cada nota completa con sus fotos.

PROGRAMACIÓN
• Consulta la grilla del canal para no perderte tus programas favoritos.

Y ADEMÁS
• Modo claro y modo oscuro.
• Acceso directo a las redes sociales del canal.
• Gratis, liviana y sin publicidad dentro de la app.

CCTV CANAL 7: tu canal, donde estés.
```

**Palabras clave**

```
tv,television,en vivo,noticias,canal local,señal,streaming,programacion,ecuador,envivo,tv gratis
```

**Notas para App Review**

```
La app no requiere cuenta. Al abrirla reproduce en vivo la señal de televisión de CCTV CANAL 7 (HLS). El contenido (señal y noticias) lo administra el canal desde su panel. Si el canal estuviera fuera del aire en el momento de la revisión, la app muestra un aviso y las noticias siguen disponibles.
```

## Respuestas de los formularios

- **Encriptación:** "Ninguno de los algoritmos mencionados". Ya está declarado
  en `Info.plist` (`ITSAppUsesNonExemptEncryption = false`), no vuelve a preguntar.
- **Derechos sobre el contenido:** contiene contenido de terceros y se tienen
  los derechos.
- **Privacidad de la app:** se recopilan datos → solo *Datos de uso →
  Interacción con el producto*, finalidad *Analíticas*, no vinculados a la
  identidad, no usados para rastreo (son los contadores anónimos de
  `usage_tracker.dart` para Reportes del panel).

## Capturas

En [`capturas/`](capturas/), sacadas de la app real en el emulador de Android
con la pantalla ajustada al tamaño de Apple y sin la barra de estado:

- iPhone 6,3": `iphone_*.png` (1206 × 2622)
- iPad 13": `ipad_*.png` (2064 × 2752)

Las noticias que se ven son las de demo (`seedDemoContent.js`); rehacerlas
cuando el canal tenga noticias reales.
