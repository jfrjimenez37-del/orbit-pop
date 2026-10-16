# ORBIT POP

Arcade de un solo toque para Android (Godot 4.3, GDScript). Un bichito gira alrededor de un planeta;
**cada toque invierte el giro**. Esquiva meteoritos, estrellas espinosas y barreras eléctricas,
revienta burbujas y supera tu récord.

## Ejecutar en PC
1. Instala Godot **4.3 stable** (https://godotengine.org/download/archive/4.3-stable/).
2. Abre `project.godot` y pulsa F5. O por consola: `godot --path .`
3. Controles: clic izquierdo, Espacio, Enter o flecha ↑ = invertir giro.

## Pruebas automatizadas
```
godot --headless --path . --import                       # primera vez
godot --headless --path . --script tests/run_tests.gd    # 26 comprobaciones, código 0 = OK
xvfb-run -a godot --path . --script tests/shots.gd -- /tmp/shots 540 960   # capturas
```
Qué verifican: geometría de colisiones vs distancias reales, que el validador de equidad rechaza
patrones imposibles y acepta los posibles, guardado/carga, curva de dificultad, 4 partidas de 150 s
con un bot "justo" (debe sobrevivir siempre ⇒ ningún patrón generado es imposible), reinicios
sucesivos y un bot "humano" (0,35 s de reacción) que estima la duración de partidas.

## Android
**APK de prueba (ya generado en este entorno):** `build/orbit-pop-debug.apk` (firma debug verificada
con `apksigner`, arm64-v8a + armeabi-v7a). Instalar: `adb install -r build/orbit-pop-debug.apk`.

Para regenerarlo en tu PC:
1. Godot ▸ Editor ▸ Manage Export Templates ▸ descargar 4.3.
2. Instala Android Studio (o command-line tools) con *platform-tools* y *build-tools 34*, y JDK 17.
3. Editor Settings ▸ Export ▸ Android: ruta del SDK, del JDK y keystore debug
   (`keytool -genkeypair -keystore debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -validity 10000 -dname "CN=Android Debug,O=Android,C=US"`).
4. `godot --headless --path . --export-debug "Android APK (debug/test)" build/orbit-pop-debug.apk`

**AAB para Google Play (pendiente, preset ya creado: "Android AAB (Google Play)"):**
1. Requiere SDK Android completo (en este entorno `dl.google.com` estaba bloqueado).
2. Godot ▸ Project ▸ Install Android Build Template (crea `android/`).
3. Crea tu keystore de subida (¡guárdalo a salvo!):
   `keytool -genkeypair -keystore orbitpop-upload.keystore -alias orbitpop -keyalg RSA -keysize 2048 -validity 10000`
4. En el preset AAB rellena `keystore/release`, usuario y contraseña (o variables
   `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD`).
5. `godot --headless --path . --export-release "Android AAB (Google Play)" build/orbit-pop.aab`
6. Sube a Play Console con Play App Signing activado. Incrementa `version/code` en cada subida.

## Estructura
```
scenes/main.tscn          escena única (fondo, mundo, UI) -> reinicio instantáneo sin recargar
scripts/main.gd           máquina de estados + bucle (subpasos de 1/120 s)
scripts/game/director.gd  patrones de obstáculos, dificultad progresiva y adaptativa
scripts/game/survival.gd  validador de equidad (bitsets de 128 sectores del anillo)
scripts/game/hazards/     meteor, spiky, barrier (peligros) y bubble (bonus)
scripts/ui/ui.gd          menú, HUD, game over, skins, pausa (construidos en código)
scripts/autoload/         save (ConfigFile local), sfx, monetization (stub vacío)
tools/gen_art.py          genera TODO el pixel art original (python3 + Pillow)
tools/gen_sfx.py          sintetiza efectos y música chiptune (python3)
tests/                    suite headless, bot y capturas
```

## Diseño clave
- **Equidad:** cada patrón candidato se simula con todos los estados alcanzables del jugador
  (ritmo máx. de toque 0,12 s, hitbox inflada). Si no hay salida, se descarta o simplifica.
  Las mismas funciones `danger()` deciden colisiones y validación.
- **Anti-campeo:** los meteoritos apuntan a la posición actual o prevista del jugador y las minas
  aparecen cerca: quedarse temblando en un sitio no es seguro.
- **Puntos:** +1 por peligro superado, +2 por esquiva cercana ("CLOSE!"), +2 por burbuja ("POP!").
- **Dificultad:** velocidad orbital 2,45→3,45 rad/s, meteoritos más rápidos, avisos más cortos y
  patrones nuevos (pinza, minas, barreras, puerta, lluvia, barrera giratoria, jaula, estrella móvil)
  que se desbloquean entre 0 y 48 s. Se desplaza ±segundos según la media de las últimas 5 partidas.
- **Skins:** POPPY (inicial), MINTY (récord 10), BERRY (25), FROSTY (250 puntos totales), EMBER (50), COSMO (80).
- **Móvil:** pausa automática al perder foco, botón Atrás (pausa/menú/salir), vibración al chocar,
  escalado entero pixel-perfect con aspecto "expand" (probado 9:16, 20:9 y 10:16), renderer Compatibility.

## Estado real
| Hecho y verificado | Pendiente |
|---|---|
| Juego completo jugable en PC (headless + capturas renderizadas) | **Prueba en teléfono real** (no había dispositivo) |
| 26 tests automáticos pasando | Ajuste fino de dificultad con jugadores reales |
| APK debug exportado y firmado | AAB release (requiere SDK completo + keystore propio) |
| Arte, audio y fuente 100% originales generados por script | Política de privacidad / ficha de Play Store |
| Guardado local, récords, estadísticas, 6 skins | Anuncios/compras: solo existe el stub `monetization.gd` |

Monetización futura: implementar en `scripts/autoload/monetization.gd` (plugin AdMob/Play Billing);
la UI de Game Over es el único punto de llamada. Nunca se llama durante una partida activa.
