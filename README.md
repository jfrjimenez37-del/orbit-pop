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
| 134 tests automáticos pasando | Ajuste fino de dificultad con jugadores reales |
| APK debug exportado y firmado | AAB release (requiere SDK completo + keystore propio) |
| Arte, audio y fuente 100% originales generados por script | Política de privacidad / ficha de Play Store |
| Guardado local, récords, estadísticas, 6 skins | Anuncios/compras reales: instalar plugins + IDs (ver abajo) |

## Monetización
Arquitectura: `scripts/autoload/monetization.gd` (fachada + reglas) con proveedores intercambiables
en `scripts/monetization/`:

| Proveedor | Cuándo se usa |
|---|---|
| `ads_admob.gd` / `store_play.gd` | Android con los plugins oficiales instalados |
| `ads_mock.gd` / `store_mock.gd` | PC y builds **debug** sin plugins (anuncio "TEST AD", compras sin cobro) |
| ninguno | build release sin plugins: botones de anuncio ocultos, tienda "STORE OFFLINE" |

Qué incluye (todo configurable en `scripts/monetization/config.gd`):

**Anuncios (nunca durante una partida)**
- CONTINUE recompensado en Game Over (1 por partida, desde 5 puntos; con NO ADS es gratis y sin vídeo).
- x2 MONEDAS recompensado en Game Over; x2 del regalo diario; FREE COINS (+60, máx. 3/día) en la tienda.
- Intersticial obligatorio cada 3 reintentos (al pulsar OTRA/MENÚ, a partir de la 3.ª partida).
- Banner pequeño solo en Tienda y en Ranking/Logros (oculto con NO ADS).
- Pausa: botón arriba a la izquierda durante la partida (también tecla P/Esc). CONTINUAR hace
  una cuenta atrás; MENÚ termina la partida y la cuenta igual (récord, monedas, misiones).

**Monedas (moneda blanda, sin compra obligatoria)**
- Se ganan: puntuación/3 + 1 por burbuja en cada partida, regalo diario y anuncios opcionales.
- Regalo diario con racha de 7 días: 30, 40, 50 (+RUSH), 60, 80, 100 (+SHIELD), 250 (+SHIELD).
  Si se salta un día, vuelve al día 1.
- Se gastan en: 4 skins (COOKIE 300, BUBBLY 500, ROBO 800, DRAKE 1200), estela SPARKLE (200),
  mundo LAGOON (600) y boosts.

**Boosts (ventaja limitada)**: SHIELD (aguanta 1 golpe, 150), BUBBLE RUSH (2x burbujas, 100) y
TELEPORT (botón en partida: salta al lado opuesto de la órbita, 120). Máximo uno de cada por
partida; se activan o compran desde el botón PODERES junto a JUGAR. Solo cuestan monedas, para
que los récords sigan siendo justos (las monedas pueden comprarse con la bolsa de 1500).

**Compras (Google Play)**

| ID | Tipo | Contenido | Precio sugerido |
|---|---|---|---|
| `starter` | único | NO ADS + 500 monedas + 2 SHIELD (oferta emergente tras 8 partidas) | $1.99 |
| `no_ads` | único | sin intersticiales ni banner + CONTINUE gratis | $2.99 |
| `star_pack` | único | skins GOLDIE, NEON, PANDA | $1.99 |
| `trail_pack` | único | estelas RAINBOW, HEARTS, STARS | $0.99 |
| `supporter` | único | todos los packs + NO ADS + 1000 monedas | $3.99 |
| `coins_1500` | consumible | 1500 monedas | $0.99 |

Activar lo real (requiere build Gradle, ver sección AAB):
1. Plugins (Godot ▸ AssetLib o GitHub, carpeta `addons/`) y actívalos en Project Settings ▸ Plugins:
   - AdMob: https://github.com/godot-sdk-integrations/godot-admob
   - Billing: https://github.com/godot-sdk-integrations/godot-google-play-billing (rama master, Godot 4.2+)
   El juego los detecta solo (clases `Admob` y `BillingClient`); sin ellos compila igual.
2. AdMob: crea la app y 3 bloques (intersticial, recompensado, banner) y pega los IDs en `config.gd`.
   En debug se usan los IDs de prueba de Google. Configura el formulario de consentimiento (UMP/GDPR):
   el adaptador lo pide antes de inicializar.
3. Play Console: crea los productos de la tabla (todos únicos salvo `coins_1500`, consumible),
   sube una build a prueba interna y añade testers de licencia.
4. Política de privacidad (obligatoria con anuncios) y formulario "Seguridad de los datos".

**No verificado:** los adaptadores reales siguen la API de los README/código fuente oficiales de
ambos plugins, pero no se pudieron compilar ni probar en dispositivo aquí. Probar en "prueba
interna" de Play antes de publicar.

## Mundos y órbitas (gratis, avanzan al jugar)
| Puntos | Mundo | Órbita |
|---|---|---|
| 0 | 1 CIELO | círculo normal |
| 20 | 2 LAGUNA | círculo más grande |
| 45 | 3 ATARDECER | círculo estrecho (cerca del planeta) |
| 75 | 4 CARAMELO | círculo descentrado: estrecha arriba, ancha abajo |
| 110 | 5 NOCHE | 2 órbitas elípticas que se cruzan en 4 estrellas |
| 150 | 6 PLANETAS GEMELOS | 2 planetas, cada uno con su órbita; se cruzan entre ambos (forma de 8) |
| 195 | 7 SISTEMA BINARIO | 2 planetas distintos (círculo + elipse) en diagonal |
| 240 | 8 TRÍO DE PLANETAS | 3 planetas en triángulo, cada órbita cruza a las otras dos |
| 290 | 9 GRANDES Y PEQUEÑAS | 1 órbita grande y 2 pequeñas (planetas de 3 tamaños) |
| 340 | 10 ÓRBITAS DEFORMES | 3 órbitas descentradas: anchas hacia el planeta vecino, estrechas al otro lado |
| 390+ | 11, 12, … | se repiten 2–10 cada 40 puntos |

Al cambiar de mundo se espera a que el campo quede libre y la órbita se transforma en 1,3 s.
En NOCHE, tocar dentro de la ventana de una estrella de cruce (±0,16 rad) **cambia de órbita**
en vez de invertir. En los mundos de 2 planetas el cambio te pasa a la órbita del otro planeta en
el mismo punto, invirtiendo el sentido de giro para seguir hacia delante (recorrido en 8). Los
obstáculos pertenecen a un planeta pero su geometría afecta a ambas órbitas. Obstáculos nuevos según avanzas: PULSO (onda desde el planeta con un hueco
seguro, mundo 2+), SIERRA (recorre un arco marcado de la órbita, mundo 3+), y patrones que
obligan a cambiar de órbita (mundo 5). Con 2 o más planetas (mundo 6+): RAYO (enlace eléctrico
entre dos planetas que bloquea la zona de paso), COMETA (cruza la pantalla en línea recta, no
hacia un planeta) y, desde el mundo 8, lluvias de cometas y jaulas de rayos. El validador de justicia simula también los cambios de
órbita: un test hace sobrevivir al bot justo 45 s en cada forma de órbita.

## Misiones, logros, ranking, nube, compartir, idiomas
- **Misión diaria:** 10 misiones fijas, una por día en ciclo (día del año local % 10). Premio en
  monedas automático al completarla. Botón de pergamino en el menú.
- **Logros:** 16, funcionan sin conexión (pantalla RANKING ▸ LOGROS) y se sincronizan con Google
  Play Games si está conectado.
- **Ranking:** lista local de tus 10 mejores + tablas de Google Play Games **MUNDIAL** y
  **REGIONAL** (LATAM, BRASIL, EUROPA, N. AMÉRICA, ASIA-PACÍFICO, ÁFRICA/O. MEDIO). La región
  sale del país del idioma del teléfono (sin servidores ni permiso de ubicación).
- **Nube:** Saved Games de Play Games. Al conectar se descarga y fusiona: récords y desbloqueos
  se combinan (nunca bajan); monedas y boosts siguen la copia más reciente. Se sube al terminar
  cada partida.
- **Compartir:** botón en Game Over; comparte una captura con el texto de la puntuación (plugin
  godot-share). Sin plugin, copia el texto al portapapeles.
- **Idiomas:** inglés, español, portugués (Portugal) y portugués (Brasil). Detecta el del
  teléfono; se cambia en AJUSTES. Fuente pixel con Á É Í Ó Ú Ñ Ç Ã Õ Â Ê Ô ¡ ¿.
- **Ajustes:** sonido, música, vibración, idioma, nube (conectar) y privacidad (vuelve a abrir el
  formulario de consentimiento de AdMob, obligatorio en la UE).

### Configurar Google Play Games (pendiente, en Play Console)
1. Instalar el plugin https://github.com/Iakobs/godot-play-game-services (v3.x) en `addons/` y
   activarlo; pide el App ID de Play Games en su configuración del editor.
2. En Play Console ▸ Play Games Services: crear 7 tablas (MUNDIAL + 6 regiones) y 16 logros.
3. Pegar los IDs generados en `scripts/services/play_games_config.gd` (los vacíos se ignoran).
4. Activar "Saved Games" en la configuración de Play Games.
5. Compartir: instalar https://github.com/godot-sdk-integrations/godot-share.

**No verificado en dispositivo:** Play Games, compartir nativo y la nube dependen de los plugins
y de la configuración de Play Console; no pudieron probarse aquí. Toda la lógica (misiones,
logros, fusión de la nube, regiones, idiomas) está cubierta por tests.
