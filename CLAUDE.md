# CLAUDE.md — Godot Mobile Game Template

Guía autoritativa de desarrollo para Claude Code. **Lee este archivo completo antes de cualquier tarea.**
Versión del template: ver historial de git. Repo del template: `/Users/norb/Dockers/gb-GameTemplate`.

---

## Stack Tecnológico

| Capa | Tecnología |
|---|---|
| Motor | Godot 4.7 (GDScript con tipado estático) |
| Testing | GUT (Godot Unit Testing) v9.7.1 |
| Lint/Format | gdtoolkit (`gdlint` / `gdformat`) vía pipx |
| Plataforma | iOS 14+ / Android API 24+ |
| CI/CD | GitHub Actions → AAB firmado en Google Play Store (Internal/Production) |
| Arte | Pixel art / Vector toony |
| Control | Touch drag relativo (1 dedo) |

---

## Comandos Esenciales

```bash
# Instalar herramientas de linting (una sola vez)
brew install pipx && pipx install gdtoolkit

# Lint — 0 errores antes de cualquier commit
gdlint src/

# Format check
gdformat --check src/

# Tests headless — SIEMPRE por este script, nunca invocar godot/GUT directo (ver regla
# anti-alucinación correspondiente): protege los user://*.json reales de la contaminación
# que sufre cualquier test que suba un valor persistente sin restaurarlo.
./tools/run_tests.sh

# Export Debug — Android
godot --headless --export-debug "Android" builds/debug/Game.apk

# Export Release — Android
godot --headless --export-release "Android" builds/release/Game.apk
```

---

## Estructura de Carpetas (Feature-First)

```
src/
├── core/                   # Singletons / Autoloads globales
│   ├── Constants.gd        # Constantes tipadas (cargado PRIMERO)
│   ├── EventBus.gd         # Bus de señales (TODA comunicación cross-feature)
│   ├── GameManager.gd      # Máquina de estados de partida
│   └── SaveManager.gd      # Persistencia JSON (user://)
├── features/
│   ├── player/
│   ├── projectiles/
│   ├── enemies/
│   ├── powerups/
│   ├── gems/
│   ├── meta/
│   ├── audio/
│   ├── vfx/
│   └── ui/
├── scenes/                 # Escenas raíz (.tscn)
└── shared/                 # Recursos compartidos
assets/
├── sprites/
├── audio/
└── fonts/
tests/
└── unit/
addons/
└── gut/
builds/
├── debug/
└── release/
tools/
├── gen_assets.py           # Íconos y assets procedurales
└── fetch_ai_assets.py      # Backgrounds y sprites con Pollinations.ai
```

---

## Estándares de Código GDScript

### Nomenclatura
| Elemento | Convención | Ejemplo |
|---|---|---|
| Clases | PascalCase, **antes de extends** | `class_name EnemyTank` |
| Variables / funciones | snake_case | `var max_health: int` |
| Constantes | SCREAMING_SNAKE_CASE | `const BASE_DAMAGE: float = 10.0` |
| Señales | snake_case (pasado) | `signal enemy_destroyed(id: int)` |
| Archivos | snake_case | `enemy_tank.gd` |
| Parámetros privados | prefijo `_` | `var _state: GameState` |

### Tipado estático obligatorio
```gdscript
# CORRECTO
var speed: float = 200.0
func take_damage(amount: int) -> void: pass

# PROHIBIDO
var speed = 200.0
func take_damage(amount): pass
```

### Event-Driven Architecture (regla absoluta)
**TODA comunicación entre features NO relacionadas va por `EventBus.gd`.**

```gdscript
EventBus.enemy_destroyed.emit(id, position, xp_value)
EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
func _exit_tree() -> void:
    EventBus.enemy_destroyed.disconnect(_on_enemy_destroyed)
```

---

## Reglas Anti-Alucinación (CRÍTICO — NO NEGOCIABLE)

1. **PROHIBIDO** inventar nombres de métodos de la API de Godot → verificar en docs o WebSearch.
2. **PROHIBIDO** agregar addons no presentes en `addons/` → verificar con `ls addons/`.
3. **PROHIBIDO** usar `get_node()` con rutas hardcodeadas → usar `@onready var` o señales.
4. **PROHIBIDO** crear `.tscn` referenciando scripts inexistentes.
5. **SIEMPRE** leer un archivo con `Read` antes de editarlo.
6. **SIEMPRE** verificar existencia de archivos con `ls` o `find` antes de referenciarlos.
7. Si una función de Godot parece existir pero no hay certeza → declarar la duda, no inventar.
8. Los valores del GDD son la única fuente de verdad para mecánicas.
9. **`const ARRAY: Array[T]`** — inválido como `const` en GDScript 4. Usar `const POOL: Array = [...]`.
10. **`class_name X` + autoload `X`** → conflicto fatal. Singletons SIN `class_name`.
11. **Autoload de constantes PRIMERO** en `[autoload]` de project.godot.
12. **`change_scene_to_file()` en `_ready()`** → usar `.call_deferred()` siempre.
13. **Herencia por class_name** → usar `extends "res://ruta/A.gd"` (path-based) en headless.
14. **Preload-consts** → deben ser PascalCase (`const EnemyBasicGd := preload(...)`).
15. **`class_name` como tipo en otro script** → usar clase base como tipo + `set(&"prop", val)`.
16. **`for id: Variant in dict.keys()`** → tipo `Variant` no válido en for-loop. Usar índice entero.
17. **`add_child()` desde callback de física** → usar `call_deferred(&"add_child", node)`.

### Reglas Android CI/CD
18. **Godot 4.7 no exporta `.aab` directamente** → exportar `.apk` primero, luego `./gradlew bundleRelease`.
19. **`--install-android-build-template`** extrae `android_source.zip` y escribe `.build_version`.
19b. **`gradle_build/use_gradle_build=true` en `export_presets.cfg` afecta TODOS los exports de Android, no solo el AAB de release** — si está activado (necesario para el pipeline de AAB), un simple `--export-debug` en un workflow de CI también falla con `"Android build template not installed"` a menos que ese mismo job corra `--install-android-build-template` (y tenga Java 17 configurado, ya que el export invoca Gradle). Un workflow de "build APK de prueba" separado del de release necesita los mismos pasos de Java + template que el de deploy, no una versión simplificada.
20. **`shouldSign()` es `false` por defecto** → pasar `-Pperform_signing=true` + keystore props a `bundleRelease`.
20b. **`export_version_code` default=1** → pasar `-Pexport_version_code=N` a `bundleRelease`. Usar `$(( ($(date +%s) - 1704067200) / 60 ))` (minutos desde 2024-01-01).
21. **Package name default es `com.godot.game`** → pasar `-Pexport_package_name=com.tuempresa.tujuego`.
22. **`assetPackInstallTime/src/main/assets` debe existir** → `mkdir -p` antes de Gradle.
23. **Primera subida a Play Store debe ser manual** desde Play Console.
24. **Pre-heat obligatorio** → `godot --headless --editor --quit || true` antes del export.
25. **`bundleRelease` no firma con `-Pperform_signing`** → firmar AAB con `jarsigner` explícitamente tras buildear.

### Reglas Multi-idioma / i18n
26. **`LocalizationManager` NO lleva `class_name`** — es autoload.
27. **No usar archivos `.translation` binarios en CI/CD** → CSV parseado en runtime con `FileAccess.get_csv_line()`.
28. **Saltos de línea en CSV** → usar `[BR]` como placeholder, reemplazar en `_load_csv()`.
29. **`LocalizationManager` carga DESPUÉS de `SaveManager`** en project.godot.
30. **El archivo de traducciones NO puede tener extensión `.csv` en Android** (Godot bug #38957) → usar `.txt` + `include_filter="*.txt"` en export_presets.cfg.
31. **Chino/japonés requieren fuente especial** → no añadir sin fuente compatible.

### Reglas de UI programática
32. **`set_anchors_preset(PRESET_BOTTOM_WIDE)` en Control creado programáticamente** → deja altura 0. Usar `position` + `set_size()` explícitos: `panel.position = Vector2(0, vp.y - h); panel.set_size(Vector2(vp.x, h))`.

### Reglas de Tutorial FTUE
33. **Tutorial en escena separada** (`TutorialGame.tscn`) — nunca como overlay sobre `Game.tscn`.
34. **`set_tutorial_shown(true)` solo al completar** — no al entrar a la escena.
35. **Enrutar desde MainMenu** — `_on_play_pressed()` decide entre Tutorial y Game según `SaveManager.get_tutorial_shown()`.

### Reglas de Assets Visuales
36. **NUNCA correr `gen_assets.py` completo para generar un solo ícono** — sobreescribe todos los assets AI. Importar solo la función necesaria:
    ```bash
    python3 -c "import sys; sys.path.insert(0,'tools'); from gen_assets import _make_XX_icon, save_png; save_png('ruta.png', 64, 64, _make_XX_icon())"
    ```
37. **Siempre consultar `/gen-ai-art` antes de tocar archivos de imagen** — el skill documenta el pipeline, los bugs de Pollinations.ai y el proceso de reimport en Godot.

### Reglas de tipado y estado (aprendidas construyendo Totopo Smash)
38. **`var velocity: Vector2` en un script que `extends CharacterBody2D`** → error de compilación "Member velocity redefined" (`velocity` ya es nativo de `CharacterBody2D`, usado por `move_and_slide()`). Si el script mueve el nodo a mano (ej. rebote con `move_and_collide()` en vez de `move_and_slide()`), NO redeclarar la propiedad — usar directamente el `velocity` heredado. Aplica igual a cualquier propiedad nativa de la clase base (`position`, `rotation`, etc.) — nunca la redeclares con `var`.
39. **`Dictionary[K, V]` tipada + `.set(&"campo", {...nuevo...})` con un diccionario literal** → falla en silencio (el campo queda vacío; ni error ni warning en consola). Pasa igual en producción que en tests que intentan inyectar estado desde fuera. Para reemplazar el contenido: obtener la referencia con `.get(&"campo")` y mutarla in-place (`d.clear(); d[key] = value`) — `Dictionary`/`Array` son tipos por referencia en GDScript, así que la mutación se refleja en el objeto real sin pasar por `.set()`.
40. **`GameManager.pause_game()/resume_game()` que solo cambian el enum de estado NO pausan nada de verdad** — si el juego necesita auto-pausa (`NOTIFICATION_APPLICATION_FOCUS_OUT`) o un botón de pausa, esos métodos DEBEN también tocar `get_tree().paused = true/false`. Si no, los overlays de pausa (que sí necesitan `PROCESS_MODE_ALWAYS` para seguir respondiendo) funcionan, pero el gameplay de fondo nunca se congela. Al navegar a otra escena (menú, reinicio) desde un estado pausado, forzar `get_tree().paused = false` explícitamente antes de `change_scene_to_file` — si no, la escena nueva carga con el árbol pausado y sus controles (si no son `PROCESS_MODE_ALWAYS`) quedan congelados.
41. **Input táctil (`InputEventScreenTouch`/`Drag`) no responde a mouse/trackpad en el editor de escritorio** → Godot no emula touch desde mouse por defecto. Si el control del juego es 100% táctil (control drag de la tabla de Stack), agregar en `project.godot`: `[input_devices]` → `pointing/emulate_touch_from_mouse=true` desde FASE 2 (scaffold). Sin esto, probar en Mac/PC "no hace nada" y no genera ningún error — parece un bug de gameplay pero es config de proyecto faltante.
42. **Definir una physics layer en `Constants` y usarla en `collision_mask` NO crea ningún cuerpo físico en esa capa.** Si el diseño requiere paredes/techo/piso/límites de pantalla como colliders (cualquier juego con rebote, ej. Arkanoid/Brick Breaker), hay que instanciar explícitamente un `StaticBody2D` con `collision_layer` en esa capa (ver FASE 3/4 — no basta con nombrarla en `[layer_names]`). Si no, cualquier proyectil que no golpee otra cosa sale disparado fuera de pantalla para siempre y la máquina de estados que espera su retorno se queda trabada sin ningún error en consola — parece un bug de lógica de turnos pero es un collider faltante. Verificar con `grep -rn "collision_layer = Constants.LAYER_X"` que cada layer referenciada como `collision_mask` tiene al menos un emisor real.
43. **Un fondo (`ColorRect`/`Node2D`) metido dentro de un `CanvasLayer` se dibuja SIEMPRE por encima de los `Node2D` normales de la escena** (bloques, personajes, proyectiles), sin importar el valor de `layer` (ni `layer = 0`). `CanvasLayer` no es "una capa más dentro del mismo canvas" — es un canvas de composición aparte que Godot dibuja por encima de todo el contenido 2D que no está envuelto en ningún `CanvasLayer`. Si necesitas un fondo detrás del gameplay (FASE 9, `Game.tscn`), agrégalo como `Node2D`/`ColorRect` normal (primer hijo, para quedar atrás por orden de árbol) — nunca dentro de un `CanvasLayer`. Reservar `CanvasLayer` solo para HUD/overlays que sí deben quedar siempre encima. Síntoma si se hace mal: el juego "no muestra nada" (pantalla del color de fondo, sin errores), pero la lógica de turnos/física/spawner sigue corriendo perfectamente por debajo — muy fácil de confundir con un bug de lógica cuando es puramente orden de dibujado. Verificar visualmente con capturas de pantalla reales, no solo con boots headless (que nunca renderizan nada).
44. **Un nodo que se autodestruye con `queue_free()` (ej. un power-up/ítem recogido) debe borrarse también de cualquier `Dictionary`/`Array` tipado que lo referencie, en el mismo callback que lo libera.** Si no, la próxima vez que ese diccionario se copie o reasigne (ej. desplazar una grilla, un spawner que reconstruye su lista) se intenta insertar una referencia ya liberada en un `Dictionary[K, V]` tipado, y Godot lo rechaza en tiempo de ejecución con `"previously freed object"` — un crash real, no una falla silenciosa. Al recorrer y reconstruir un diccionario tipado que puede contener nodos, comprobar `is_instance_valid(node)` **antes** de insertar en el nuevo diccionario (`continue` si es inválido), nunca insertar primero y validar después.
45. **`CanvasItem` (la clase base compartida por `Node2D` y `Control`) NO declara `position`/`rotation`/`scale`** — cada rama los declara por separado con su propio sistema de transform. `modulate`/`self_modulate` sí viven en `CanvasItem` y son seguros de usar directo. Esto importa en el patrón "placeholder procedural → sprite real cuando el asset ya existe" (FASE de reemplazo de assets): si una variable de efecto visual puede apuntar a un `ColorRect` (fallback) O a un `Sprite2D` (con textura), tiparla `CanvasItem` y usar `.set(&"scale", valor)` en vez de `variable.scale = valor` (regla #15 aplicada a este caso). `Tween.tween_property(objeto, ^"scale", ...)` sí es seguro con acceso directo sin importar el tipo estático — resuelve la propiedad en runtime vía `NodePath`, no en compilación.
46. **Para SFX cortos generados con Python stdlib (`tools/gen_assets.py`), usar `.wav`, no `.ogg`** — no hay encoder OGG en la stdlib; `wave`/`struct` producen `.wav` sin dependencias, y Godot lo reproduce igual de bien para sonidos cortos. Si el `AudioManager` de un juego nuevo asume `.ogg` sin haber generado ningún asset todavía, verificar contra el patrón `.wav` + diccionario nombre→archivo ya probado, en vez de adivinar la extensión.
47. **`JSON.parse_string()` SIEMPRE devuelve los números como `float`, nunca `int`** — incluso `"col": 3` en un archivo de datos (niveles, config, lo que sea) se convierte en `3.0` al parsear. Un chequeo `valor is int` sobre datos que vinieron de JSON da `false` aunque el archivo tenga un entero limpio, y rechaza datos perfectamente válidos. Al validar/leer datos parseados de JSON, comprobar "es un número entero" con `valor is int or (valor is float and valor == floor(valor))`, nunca `is int` a secas. `int(valor)` para convertir sí funciona igual en ambos casos. Cualquier loader de datos basado en JSON (niveles, configuración remota, etc.) debe usar este patrón desde el principio.
48. **Un nodo hijo instanciado dentro de `_build_scene()` (llamado desde `_ready()` de la escena raíz) NO debe leer el estado de un autoload que esa MISMA escena raíz actualiza recién DESPUÉS de `_build_scene()`** (ej. `GameManager.start_game(...)` llamado después de construir la escena, patrón ya establecido en FASE 9) — su `_ready()` corre antes de que ese estado se actualice, así que lee el valor de la partida ANTERIOR (o el default). Si otros sistemas de la escena ya reaccionan correctamente al evento `game_started` para leer ese mismo estado, cualquier nodo nuevo que necesite el mismo dato debe escuchar esa señal también — nunca leerlo de forma síncrona en su propio `_ready()`.
49. **`get_viewport().get_texture().get_image()` (técnica de captura de pantalla real para verificación visual) devuelve `null` bajo `--headless`** — ese modo usa el `RenderingServer` "dummy" (sin textura real detrás del viewport), y llamar `.get_image()` sobre él tira `ERROR: Parameter "t" is null` seguido de un `SCRIPT ERROR` que aborta la función a mitad de camino (si el script sigue con `await`/`get_tree().quit()` después, esas líneas nunca corren y el proceso de Godot se queda colgado para siempre, sin exit code, sin más output — parece un hang de lógica pero es este bug). Para el patrón "instanciar escena real + esperar frames + guardar PNG del viewport" (verificar bugs visuales que ningún test headless puede atrapar, ver regla #43), correr el proceso probe SIN `--headless` (`godot --path . probe.tscn`, ventana real aunque no se vea en pantalla) — ahí `get_texture()` sí devuelve una textura válida.
50. **Un nodo cuyo padre directo hereda de `Container` (`GridContainer`, `ScrollContainer`, `HBoxContainer`, `VBoxContainer`, `CenterContainer`, etc.) NO respeta un `position`/`set_size()` puesto a mano** — el `Container` reposiciona a TODOS sus hijos en cada `NOTIFICATION_SORT_CHILDREN`, pisando silenciosamente cualquier valor manual (sin error, sin warning; mismo espíritu que la regla #32 pero para `Container`, no para anchors). Síntoma real: una grilla de botones dentro de un `ScrollContainer` con `grid.position` puesto a mano para centrarla terminaba siempre pegada a la izquierda (el offset se ignoraba). Fix: si hace falta centrar contenido de ancho fijo dentro de un `Container`, centrar el propio `Container` (ajustando SU `position`/`set_size` al ancho exacto del contenido) dentro de un `Control` plano que sí respete asignación manual — nunca intentar mover a mano un hijo directo de un `Container`.
51. **Un sistema compartido por varios modos de juego (ej. un `TurnManager` usado por un modo "infinito" Y un modo "niveles") NUNCA debe depender de una señal que solo UN modo emite para una transición de estado que TODOS los modos necesitan.** Bug real: un orquestador de turnos volvía de "resolviendo" a "apuntando" escuchando una señal específica de un modo ("nueva oleada"); el otro modo nunca la emitía (no tenía sentido ahí). Resultado: en ese otro modo, después del primer turno el juego se quedaba trabado para siempre sin ningún error en consola — la UI (pausa, menús) seguía funcionando porque es un sistema separado, pero el loop de juego en sí no respondía más, muy fácil de confundir con un bug de input cuando en realidad es una máquina de estados atascada esperando una señal que nunca llega. Fix: agregar una señal mode-agnostic dedicada a esa transición ("turn_advanced" o similar, sin parámetros específicos de un modo), emitida desde TODOS los modos que comparten el sistema, y hacer que el sistema compartido escuche esa señal en vez de una señal semánticamente específica de un solo modo. Regla general: si un handler cross-feature necesita "algo terminó, continuemos" en un sistema que sirve a N modos, la señal que dispara esa transición debe emitirse desde los N modos — nunca reusar una señal que solo un modo entiende como relevante. Verificar con un test de integración que instancie los sistemas relevantes juntos y ejercite la cadena real de señales (no solo emitir la señal final a mano), porque ese es exactamente el tipo de bug que un test aislado por sistema no atrapa.
52. **`gdlint` rechaza cualquier clase con más de 20 métodos públicos (`max-public-methods`)** — un autoload que acumula getters/setters de features no relacionadas (settings + tutorial + score + progreso + lo que se vaya agregando después) choca con este límite tarde o temprano. Sin buscar un truco para "caber" (prefijar con `_` cosas que sí son públicas, o un método `get(key)`/`set(key,val)` genérico que pierde el tipado): crear un autoload nuevo dedicado a la responsabilidad que se está agregando, con su propio archivo `user://algo.json` si necesita persistencia — mismo patrón exacto que el autoload de guardado principal (`_load()`/`save()`), solo que en un archivo separado. Además de resolver el límite del linter, es la aplicación correcta de "una sola responsabilidad por script" (regla del skill `/feature`).
53. **`PanelContainer` sin un `StyleBox` propio usa el panel semi-transparente por defecto del tema de Godot — NUNCA asumir que un panel "modal"/overlay es opaco solo porque el juego define un color de fondo en otro lado.** Bug real: un panel de configuración/pausa/game-over construido con `PanelContainer.new()` sin estilo propio se veía translúcido sobre lo que hubiera detrás (un fondo de menú con imagen, el tablero de juego durante una pausa), y el texto del modal se mezclaba visualmente con eso, ilegible. Sin error, sin warning — solo "se ve raro" hasta que alguien lo nota jugando de verdad (el editor a veces renderiza el tema default distinto a como se ve en juego real). Fix: `panel.add_theme_stylebox_override(&"panel", stylebox)` con un `StyleBoxFlat` de `bg_color` casi 100% opaco (alpha ~0.95-0.97). Vale la pena un helper compartido (`opaque_panel()` en un script de utilidades) reutilizado por TODOS los overlays tipo modal del proyecto, aplicado sin excepción a cualquier `PanelContainer` nuevo usado como overlay — incluyendo paneles de tutorial/hints sobre el gameplay real, no solo menús.
54. **Al auto-escalar contenido de tamaño variable (una grilla, una figura) para que quepa en un espacio de pantalla fijo, escalar SIEMPRE contra TODAS las dimensiones relevantes al mismo tiempo — nunca solo una y asumir que la otra "ya cabrá".** Bug real: un sistema de layout de figuras de alta resolución calculaba su tamaño de celda solo en función del ANCHO disponible (`ancho_pantalla / columnas`), sin verificar cuántas filas tenía el contenido ni si esa altura cabía en pantalla — un contenido alto terminaba dibujándose más grande de lo que cabía verticalmente y tapaba visualmente otro elemento de UI/gameplay debajo (en este caso, la zona de control del jugador). Sin error, sin warning — el resto del juego seguía funcionando perfectamente por debajo (misma familia que la regla #43, un problema de layout que se confunde con uno de lógica). Fix: el campo que define "cuántas filas ocupa el contenido" debe ser **obligatorio** (no inferido del máximo índice usado — eso impide que el layout sepa de antemano cuánto espacio necesita) y el cálculo de escala debe usar `min(ancho_disponible/columnas, alto_disponible/filas)` — el MENOR de los dos ajustes, para garantizar que ambas dimensiones quepan siempre — y centrar el resultado en ambos ejes dentro del espacio disponible. Regla general: cualquier fórmula de "tamaño de celda = espacio disponible / unidades de contenido" que solo mire un eje es una fuga de layout esperando a pasar en el primer contenido con una proporción distinta a la que se probó primero.
55. **Un autoload que arranca música en loop (`AudioStreamPlayer` con un stream de `loop_mode` habilitado) y nunca la detiene hace que `godot --headless -s addons/gut/gut_cmdln.gd -gexit` termine imprimiendo `WARNING: N ObjectDB instances were leaked at exit` + `ERROR: M resources still in use at exit` (el stream/playback de la música, todavía "en uso" en el instante exacto en que el proceso corta).** Esto NO es un bug ni una regresión — es el comportamiento esperado de CUALQUIER audio en loop dentro de un autoload (correcto para un juego real: la música debe sonar hasta que se cierra la app, nunca detenerse sola). Verificar el exit code real (`echo $?`) y el resumen de tests antes de asumir que algo se rompió — el exit code sigue siendo 0 y los tests siguen en verde; el warning es un diagnóstico de shutdown del motor, no una falla de test. No intentar "arreglarlo" agregando un hook de shutdown que detenga la música artificialmente — sería complejidad sin beneficio real, solo para silenciar un mensaje benigno.
56. **Reemplazar un sprite plano (`ColorRect` de color sólido, ocupa el 100% de su celda) por un sprite de IA con silueta irregular (un personaje, un objeto con forma propia) NO cambia la forma de la colisión — sigue siendo la hitbox rectangular de siempre.** Bug real: sprites de IA generados para bloques de un juego tipo brick-breaker (con transparencia real alrededor de la silueta, 34-57% de píxeles opacos medido) dejaban 40-65% del área de colisión visualmente vacía; el proyectil seguía rebotando en el borde exacto de siempre (correcto — la grilla, no la silueta del arte, define el rebote), pero a los ojos del jugador el rebote pasaba "en el aire", cerca de las esquinas donde el sprite ya había terminado. Sin error, sin warning — la física seguía siendo 100% correcta, solo se veía mal. Fix: un `ColorRect`/`ColorRect`-equivalente de fondo (mismo color que el bloque usaba antes de tener sprite) del mismo tamaño EXACTO que la colisión, agregado ANTES del `Sprite2D` (para quedar detrás) — la celda vuelve a verse sólida donde realmente rebota, sin importar cuánta transparencia tenga el arte encima. Regla general: cualquier sprite con transparencia real que se dibuje sobre una hitbox rectangular necesita un respaldo sólido del tamaño de la hitbox — nunca asumir que "un sprite más lindo" es un cambio puramente visual sin implicación de gameplay.
57. **Cualquier autoload que persista en `user://algo.json` (progreso, oro, desbloqueos) es el MISMO archivo real que usa una partida jugada a mano — GUT no lo aísla entre corridas.** Bug real: varios tests que subían un valor "solo si es mayor" (mejor puntaje, nivel/oleada desbloqueada) o agregaban algo (oro, un personaje/ítem desbloqueado) sin restaurarlo al final dejaban ese cambio escrito PARA SIEMPRE en el guardado real — cada corrida de la suite (decenas a lo largo de una sesión normal de desarrollo) sumaba progreso permanente que el jugador nunca ganó. Los tests seguían en verde — el síntoma ("todo aparece desbloqueado/con más recursos de los que debería") solo aparece jugando de verdad, mucho después, y es fácil confundirlo con un bug de la lógica de desbloqueo cuando en realidad la lógica está bien y es el DATO el que está corrupto. Dos partes del fix: (1) todo test que mute un valor de este tipo debe restaurarlo al final — si la API pública es deliberadamente de una sola vía (no puede bajar el valor), escribir directo al campo interno del autoload vía reflección (`Autoload.get(&"_data")["campo"] = valor_original; Autoload.save()` — el guion bajo no es privacidad real en GDScript) — SOLO aceptable en un test, nunca en producción; (2) además, como red de seguridad contra tests NUEVOS que reintroduzcan el mismo problema, envolver la corrida de la suite en un script que respalde los archivos `user://*.json` relevantes antes y los restaure después pase lo que pase, y usar ESE script como comando canónico de tests en vez de invocar GUT directo. **Esa protección NO cubre un probe manual fuera de GUT** (ej. `godot --path . probe.tscn` para capturar una pantalla real, ver regla #49) — si el probe toca un autoload persistente, hay que respaldar/restaurar el `.json` real a mano (`cp` antes/después) alrededor de esa corrida, igual que haría el script de tests para GUT.
58. **Un SFX de impacto sintetizado con tonos puros (aunque combine fundamental+armónico) se percibe "blando"/sintético hasta que se le agrega un TRANSIENTE al inicio — un burst de ruido de solo ~10ms, ANTES/junto con el cuerpo tonal, es lo que el oído interpreta como el "click" de contacto real (mazo/objeto contra superficie).** Confirmado con investigación (técnica estándar de sound design para percusión: capa de ruido corta al ataque + cuerpo tonal después) tras rondas previas de ajuste de tono que no convencían — el problema no era la frecuencia/duración elegida, sino la falta de ese transiente. Patrón: generar el `click` con la misma utilidad de ruido ya usada para otros SFX (`_noise(dur, amp)`), envolvente propia MUY corta (`_env(click, 0.0005, 0.01)`, unos 10-15ms), mezclado (`_mix()`) con las capas tonales existentes sin tocar el resto del diseño. **Además**: dos SFX con picos de amplitud CASI IDÉNTICOS (medidos en la muestra final generada, no solo en el parámetro `amp` de la función) pueden sonar con volumen PERCIBIDO muy distinto si difieren en frecuencia — un tono puro agudo (~1kHz+, zona de máxima sensibilidad del oído humano, curvas isofónicas) se percibe más fuerte que un tono grave/compuesto a igual pico de amplitud y hasta con varios dB menos de ganancia nominal. Al balancear el volumen relativo de dos SFX, no alcanza con bajar dB por sensación — verificar el pico real de la muestra generada (`wave`/`struct` en Python) y, si uno de los dos es un tono agudo puro, compensar también bajando su `pitch_scale` en reproducción (aleja la frecuencia de la zona sensible), no solo su `volume_db`.
59. **Recorrer `dict.keys()` (una foto tomada al inicio del `for`) y acceder `dict[key]` en cada vuelta CRASHEA en runtime (`"Invalid access to property or key"`, no una falla silenciosa) si el CUERPO del propio bucle puede disparar, síncronamente, la eliminación de una clave que el bucle todavía no visitó.** Bug real: un sistema de daño en área (ej. un power-up que recorre `_blocks.keys()` aplicando daño a cada entidad en una línea/radio) puede matar a una entidad cuya propia muerte dispara OTRA explosión/reacción en cadena (vía señal) que destruye síncronamente a un vecino — si ese vecino comparte la misma área de efecto y el bucle original todavía no había llegado a esa clave, la iteración siguiente intenta acceder a una entrada que ya no existe → crash real. El bug no aparece probando ninguno de los dos sistemas de daño por separado — solo cuando SE COMBINAN en la misma acción. Cualquier sistema de "explosión en cadena" (A mata a B, B explota y mata a C) ya necesita un guard `if dict.has(neighbor): ...` en SU propio handler — pero un sistema de daño en área agregado DESPUÉS, con el mismo patrón "recorrer el dict y aplicar daño", fácilmente lo omite porque no es obvio que mutará el mismo dict que está iterando. Regla general: CUALQUIER `for key in dict.keys(): ... dict[key] ...` donde el cuerpo puede destruir entidades que a su vez pueden encadenar más destrucción vía señales necesita `if not dict.has(key): continue` antes de acceder — no es "por si acaso", es que ya existe (o existirá) un feature real que muta el dict desde dentro del callback. Test de regresión: insertar dos entidades en un orden específico (la que explota ANTES que su vecino en el dict, ya que la iteración respeta el orden de inserción) para forzar que el bucle intente acceder a una clave ya borrada — un test que pruebe cada sistema de daño por separado no lo detecta.
60. **Cuando una entidad tiene una posición LÓGICA (`grid_pos` o similar, usada para decidir qué celda/fila/columna afecta) separada de su posición VISUAL (un `Tween` que anima `position` en pantalla), cualquier código que actualice una TIENE que actualizar la otra — copiar el bucle de movimiento para un tipo de entidad nuevo sin copiar esa línea deja el dato lógico congelado para siempre, aunque se vea moverse perfectamente en pantalla.** Bug real: un sistema de desplazamiento de tablero (`_shift_down()` o equivalente) actualiza la posición lógica de los bloques al moverlos (`node.set(&"grid_pos", new_key)`) junto con el tween visual — pero el bucle equivalente para OTRO tipo de entidad (un power-up/ícono agregado después, mismo patrón de movimiento) solo tenía el tween, nunca el `.set()` del dato lógico. La entidad se veía moverse en pantalla con total normalidad, pero cualquier lógica que decidiera "qué celda afecto" (ej. un power-up de área) seguía usando el valor de spawn para siempre. Sin error, sin warning — indistinguible de un bug de diseño/probabilidad hasta notar que el efecto SIEMPRE ocurre en la misma celda sin importar cuánto haya avanzado la partida. Regla general: al copiar un bucle de "mover N entidades una posición" para un tipo de entidad nuevo, verificar explícitamente que se actualiza CUALQUIER propiedad lógica que otro sistema lea después, no solo la visual — un test que solo verifique "está en la posición visual correcta" no lo atrapa; hace falta verificar el dato lógico (`node.get(&"grid_pos")` o equivalente) después de la operación.
61. **Cuando el usuario pregunte si mover/ajustar una posición o tamaño de UI/gameplay (una línea, un margen, un HUD) puede "romper con la resolución de algunos dispositivos", verificar PRIMERO `project.godot`'s `[display] window/stretch/mode`/`window/stretch/aspect` antes de responder por intuición.** Este template usa `stretch/mode="canvas_items"` + `aspect="keep"` con un viewport lógico FIJO (`window/size/viewport_width`/`viewport_height`, 390×844 por defecto) — TODO el layout de un juego construido desde este template se calcula en ese espacio virtual, nunca en píxeles físicos de pantalla; Godot escala (con letterbox si hace falta) el resultado igual en cualquier dispositivo real. Esto significa que la pregunta correcta NO es "¿en qué dispositivo se ve mal?" sino "¿el nuevo valor sigue cabiendo dentro del propio lienzo virtual junto a los demás elementos?" (mismo tipo de chequeo que la regla #54 de auto-escalado con `min()` en ambos ejes). La respuesta a este tipo de pregunta es MATEMÁTICA (calcular márgenes reales en el espacio virtual: ¿cuánto queda entre el elemento movido y el siguiente?), no empírica — no hace falta un dispositivo físico ni un emulador para responderla, siempre que el proyecto conserve este stretch mode estándar del template.
62. **Sprites procedurales pequeños (torres/enemigos/proyectiles, power-ups, cualquier personaje con cuerpo circular/rectangular + apéndices) generados con el generador de pixel art puro-Python (`gen_assets.py`) deben dibujarse al DOBLE del tamaño de render en juego (con `sprite.scale = Vector2(0.5, 0.5)` en el `Sprite2D` — más nitidez en pantallas retina tras el `stretch/mode=canvas_items`, misma lógica que la regla #61) y cualquier apéndice que deba sobresalir del cuerpo principal (orejas, alas, patas, antenas) DESPUÉS de dibujar el cuerpo, nunca antes.** Bug real: un sprite de "ratón" con orejas dibujadas ANTES del círculo del cuerpo (incluso con buen contraste de color) quedó completamente tapado por el cuerpo dibujado encima — sin error, sin warning, el PNG resultante era un círculo liso sin ningún rasgo, solo detectable con inspección visual directa del archivo. Regla de orden: el apéndice se dibuja DESPUÉS del contorno principal, centrado a una distancia tal que una porción quede claramente fuera del radio/rect principal (o completamente afuera, si hace falta contraste total). Un helper `_thick_line(g, x1, y1, x2, y2, width, color)` (quad perpendicular a la línea; coordenadas SIEMPRE `int()`, porque `_poly()`/`range()` de `gen_assets.py` no aceptan floats) cubre patas, antenas, colas y brazos de catapulta con la misma función. Verificar SIEMPRE con un zoom nearest-neighbor (`Image.resize((w*8, h*8), Image.NEAREST)` en Pillow) antes de integrar — a tamaño real (16-40px) un apéndice tapado, clippeado contra el borde del canvas, o mal proporcionado es indistinguible a simple vista de uno correcto.
63. **Los agentes especializados en `.claude/.agents/` (`game-designer.md`, `game-feel.md`, etc.) vienen del template con checklists escritos para SU juego de referencia (un survivor-shooter: power-ups, XP/level-up, autofire, jefes) — `/new-game` no los readapta automáticamente al juego real que construye.** Bug de proceso real: se invocó (mentalmente, antes de notar el problema) `game-designer` para auditar el balance de un tower defense sin avatar de jugador, sin power-ups ni XP — el checklist del agente preguntaba por `PLAYER_BASE_HEALTH`, `POWERUP_DURATION`, `BOSS_SPAWN_INTERVAL`, ninguno de los cuales existe en ese proyecto. Regla general: antes de invocar cualquier agente de `.claude/.agents/` en un proyecto derivado de este template, leer su checklist y verificar que los conceptos que menciona (power-ups, jefes, XP, autofire, contacto jugador-enemigo) existen realmente en el juego actual (comparar contra `idea-base.md`/`Constants.gd`) — si el género es distinto al survivor-shooter original (tower defense, puzzle, plataformas, etc.), reescribir la sección de checklist específico del agente ANTES de usarlo, no después. Nota aparte: también vale la pena tratar los valores del GDD como punto de partida, no como ley inmutable — si un hallazgo de balance real (ej. una torre que mata de un golpe al enemigo más barato) mejora la experiencia del jugador, vale la pena proponerlo aunque desvíe del documento fuente, dejando la decisión final al humano.
64. **Un helper que spawnea un nodo decorativo (VFX, partículas, cualquier efecto de un solo uso) recibiendo un `parent: Node` arbitrario y una posición GLOBAL debe asignar `global_position` DESPUÉS de `parent.add_child(node)`, nunca `position` antes.** `position` es siempre relativo al parent que efectivamente reciba el nodo (que puede tener su propio offset — ej. un tablero centrado con `position != Vector2.ZERO`, un spawner en cualquier punto), así que asignarle directamente la coordenada global de otro nodo (ej. `enemy.global_position`) coloca el efecto en el lugar equivocado apenas ese parent no esté en el origen — y `global_position` tampoco sirve ANTES de `add_child()`, porque necesita que el nodo ya esté en el árbol para resolver la transform heredada del parent real. Este bug se detectó y corrigió ANTES de shippear (nunca llegó a manifestarse visualmente) simplemente por escribir el comentario que justifica la línea y notar la inconsistencia — señal de que vale la pena, al escribir cualquier helper de spawn genérico, preguntarse explícitamente "¿este `position`/`global_position` es relativo a qué exactamente, y ese parent tiene garantizado estar en el origen?" en vez de asumirlo.

---

## Auto-detección de Skills (OBLIGATORIO)

Antes de implementar, identificar qué skill aplica y **leerlo completo**:

| Tarea | Skill a consultar |
|---|---|
| Cualquier asset visual (sprites, íconos, fondos) | `/gen-ai-art` |
| Strings de UI, nuevos idiomas | `/mobile-i18n` |
| Feature nueva completa | `/feature` |
| Publicación Android / CI/CD | `/android-deploy` |
| Juego nuevo desde GDD | `/new-game` |
| Tutorial / FTUE | Sección FTUE en `/new-game` |
| Commit / cierre de tarea | `/doc` |
| Verificar antes de commit | `/validate` |

**No esperar a que el usuario lo pida.** Si la tarea encaja con un skill, leerlo primero.

---

## Propagación al Template (OBLIGATORIO)

Ruta del template: `/Users/norb/Dockers/gb-GameTemplate`

Cuando se descubra algo genérico (aplica a cualquier juego Godot 4 móvil), propagarlo al template **en la misma sesión**, sin que el usuario lo pida:

| Tipo de aprendizaje | Qué actualizar en el template |
|---|---|
| Nueva regla anti-alucinación o anti-patrón Godot | `CLAUDE.md` (sección Reglas) |
| Nuevo skill o agente | `.claude/skills/<nombre>/SKILL.md` o `.claude/.agents/<nombre>.md` |
| Bug de Godot / Android / CI | Skill correspondiente + `CLAUDE.md` si es regla general |
| Mejora al pipeline de assets | `.claude/skills/gen-ai-art/SKILL.md` + `tools/` |
| Mejora al proceso de i18n | `.claude/skills/mobile-i18n/SKILL.md` |

**Si no tienes la ruta del template en memoria, pregunta antes de asumir.**

---

## Protocolo Obligatorio por Cambio

```
a) PLAN      — Listar qué archivos se modifican, qué tests se agregan
b) IMPL      — Código mínimo y tipado (sin over-engineering)
c) VALIDATE  — gdlint src/ && tests GUT headless → BUILD GREEN
d) SANITY    — Verificar que features existentes no se rompieron
e) DOC       — Actualizar idea-base.md, CLAUDE.md, memoria y template si aplica
```

**Una tarea NO está terminada hasta que (c) y (e) estén completos.**

---

## Secciones a rellenar por juego

> Las siguientes secciones están vacías en el template. Rellenarlas al correr `/new-game`.

### Estado Actual del Juego

**Taco Defender** — tower defense hipercasual (GDD v1.1), build inicial completo vía `/new-game`.
Detalle completo (arquitectura, asunciones, pendientes) en `idea-base.md` — resumen acá:

- **Victoria:** sobrevivir las 10 oleadas. **Derrota:** vida de la taquería (base 3, mejorable
  a 8 con "Barra Blindada") llega a 0.
- **Controles:** tap ícono de torre → tap casilla libre = construir. Tap torre construida =
  panel de rango/mejora/venta. Drag vertical = paneo de cámara (camino de 14 filas).
- Sin avatar de jugador, sin drag-to-move, sin gemas/power-ups temporales — es un TD de
  grilla, no un survivor. Por eso `src/features/` usa `board/`, `towers/`, `projectiles/`,
  `enemies/`, `meta/`, `ui/`, `audio/` en vez de `player/`, `powerups/`, `gems/` (carpetas
  del template removidas por no aplicar a este juego).
- Sin capas de física en absoluto — targeting y AoE usan grupos (`&"enemies"`) + distancia.
- Multi-idioma: es (default), en, pt_BR, fr — ver `/mobile-i18n` e idea-base.md.
- Gates verdes: `gdlint src/ tests/` (0 errores), GUT 106/106 tests (367 asserts),
  `--export-debug "Android"` (BUILD SUCCESSFUL, APK ~91MB).

### Señales clave en EventBus

| Señal | Emisor | Receptores |
|---|---|---|
| `game_started` / `game_over` / `game_won` | GameManager | HUD, Pause/GameOver/VictoryScreen, AudioManager, Game.gd |
| `gold_changed(amount)` | GameManager | HUD |
| `base_health_changed(current, max)` | GameManager | HUD |
| `wave_started(n)` / `wave_intermission_started(n, delay)` | GameManager | HUD, EnemySpawner, AudioManager |
| `wave_cleared(n)` | EnemySpawner | GameManager |
| `start_wave_button_pressed` | HUD | GameManager |
| `enemy_spawned(type)` / `enemy_destroyed(pos, reward)` / `enemy_reached_base(dmg)` | EnemyBase/EnemySpawner | GameManager, AudioManager |
| `build_mode_requested(type)` / `build_mode_cancelled` | HUD / Board | Board |
| `tower_placed` / `tower_selected(info)` / `tower_deselected` | Board | HUD, AudioManager |
| `tower_upgrade_requested(cell)` / `tower_sell_requested(cell)` | HUD | Board |
| `tower_upgraded(cell, level)` / `tower_sold(cell, refund)` | Board | HUD, AudioManager |
| `tips_changed` / `meta_upgrade_purchased` | MetaManager | MainMenu, UpgradeScreen |
| `action_feedback(message)` | Board/UpgradeScreen | HUD (toast) |
| `sound_setting_changed(enabled)` | SettingsScreen | AudioManager |
| `language_changed(locale)` | LocalizationManager | MainMenu, UpgradeScreen (refrescan texto con `tr()`) |

### Referencia Rápida del GDD

Ver `idea-base.md` sección "Valores de Balance" para las tablas completas de enemigos,
torres y las 10 oleadas. Única fuente de verdad en código: `src/core/Constants.gd`
(`ENEMY_*`, `TOWER_CATALOG`, `WAVE_DEFINITIONS`, `META_*`).

### Autoloads registrados en project.godot

| Nombre | Archivo | Rol |
|---|---|---|
| Constants | `src/core/Constants.gd` | Constantes tipadas (GDD) — sin lógica. |
| EventBus | `src/core/EventBus.gd` | Señales cross-feature. |
| GameManager | `src/core/GameManager.gd` | Estado de partida: oro, vida de base, oleada, pausa. |
| SaveManager | `src/core/SaveManager.gd` | `user://save.json` — tutorial_shown, sound_enabled, language. |
| LocalizationManager | `src/core/LocalizationManager.gd` | Parsea `assets/translations/translations.txt`, setea TranslationServer.set_locale(). Carga DESPUÉS de SaveManager. |
| MetaManager | `src/core/MetaManager.gd` | `user://meta.json` — propinas, 5 mejoras permanentes, best_wave, victorias. |
| AudioManager | `src/features/audio/AudioManager.gd` | SFX/música — stub funcional, reacciona a EventBus. |

### Skills y Agentes Disponibles

`/new-game` (este build), `/validate`, `/feature`, `/doc`, `/gen-ai-art`, `/android-deploy`,
`/mobile-i18n` (implementado — es/en/pt_BR/fr, ver idea-base.md sección Arquitectura).
Agentes: `godot-architect`, `godot-qa`, `game-designer` (checklist adaptado a tower
defense — ver el archivo, no el genérico de survivor-shooter del template), `game-feel`
(`.claude/.agents/`).

### Pendientes Documentados

Ver `idea-base.md` sección "Pendientes" (audio real, CI/CD Play Store con secrets,
multi-idioma). Arte real ya resuelto (fondos IA + sprites procedurales — ver
`/gen-ai-art`). Nada de lo restante bloquea build/tests/lint — son mejoras de polish
post-MVP.
