# Estadísticas del juego (GameAnalytics): configuración

El juego (desde la 1.0.14) envía sus estadísticas a **GameAnalytics** sin plugins de Android:
`scripts/services/analytics.gd` (API REST v2). Sin claves no se envía nada.

## 1. Crear la cuenta y el juego (gratis)
1. Entra a **gameanalytics.com** ▸ *Sign up* con `barriogames.studio@gmail.com`.
2. Crea un **Studio**: `Barrio Games`.
3. Añade un **Game**: nombre `ORBIT POP`, plataforma **Android**. Si te pide la tienda, busca
   `com.barriogames.orbitpop` (o déjalo sin enlazar hasta que el juego sea público).
4. En el juego: **Game settings ▸ Keys** (o *Setup*): copia el **Game key** y el **Secret key**.

## 2. Poner las claves en TU proyecto de Godot (no en GitHub)
1. En tu carpeta del proyecto, copia `scripts/services/analytics_keys.example.gd` como
   `scripts/services/analytics_keys.gd`.
2. Pega las claves:
   ```gdscript
   extends RefCounted
   const GAME_KEY := "tu game key"
   const SECRET_KEY := "tu secret key"
   ```
3. Ese archivo está en `.gitignore`: no se sube al repositorio público. Consérvalo cuando
   copies los archivos nuevos de cada versión (no lo borres).

## 3. Comprobarlo en el teléfono
Ajustes ▸ toca la versión 5 veces (DIAG). Debe aparecer:
`analytics: on, queued N, sent N, dropped 0, last http 200`
- `no keys` = falta el archivo de claves. `last http 401` = claves mal copiadas.
- En GameAnalytics los datos aparecen en **Realtime** en minutos y en los paneles al día siguiente.

## 4. Play Console ▸ Contenido de la app ▸ Seguridad de los datos
Añade a lo que ya declaraste (AdMob, compras):
| Tipo de dato | Recopilado | Compartido | Para qué | Opcional |
|---|---|---|---|---|
| **Actividad en la app ▸ Interacciones con la app** | Sí | No (GameAnalytics trata los datos por nosotros) | Estadísticas | Sí (Ajustes ▸ DATOS) |
| **Identificadores del dispositivo u otros** (ID de jugador aleatorio) | Sí | No | Estadísticas | Sí |
| **Información y rendimiento de la app ▸ Diagnóstico** | Sí | No | Estadísticas | Sí |
Datos cifrados en tránsito: **Sí** (HTTPS). Los usuarios pueden pedir que se eliminen: escribiendo
a `barriogames.studio@gmail.com` (y desactivando DATOS en Ajustes).

## Qué se mide
- Sesiones y su duración, jugadores nuevos y recurrentes (día 1, día 7...).
- **Progresión**: inicio de partida por modo (Normal / Duel / Daily) y mundo, cada mundo superado,
  y fin de partida con puntaje (`Fail:Normal:World07`).
- **Muertes**: `Death:<obstáculo>:World07` con el puntaje (qué obstáculo mata más y dónde).
- Duración de la partida, roces, continuar.
- **Tutorial**: `Tutorial:Tap:Shown/Done`, `Tutorial:Jump:Shown/Done/Skipped`.
- **Economía** (monedas): ganadas en partida, misiones, niveles, duelos; gastadas en skins y
  habilidades.
- **Anuncios**: pantalla completa mostrada, videos con recompensa vistos o cerrados.
- **Compras**: producto e importe; ofertas mostradas; abrir tienda, estilos, habilidades, ranking.
- Duelos (empezar, resultado, compartir, abrir enlace), desafío diario, regalo diario, misiones,
  logros, subir de nivel, petición de valoración, permiso de notificaciones.
