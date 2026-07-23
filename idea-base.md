# Taco Defender — Idea Base

> Definición viva del juego. Actualizar con `/doc` al cerrar cada tarea.

---

## Concepto

**Género:** Tower Defense hipercasual
**Plataforma:** iOS 14+ / Android API 24+
**Control:** Tap (construir/seleccionar torre) + Drag vertical (paneo de cámara sobre el camino)
**Sesión target:** 3–5 minutos (GDD)
**Propuesta de valor:** Defender la barra de una taquería contra 10 oleadas de plagas hambrientas colocando torres de ingredientes (salsa, hielo, guacamole) sobre un camino serpenteante fijo.

---

## Mecánicas Core

- **Victoria:** Sobrevivir las 10 oleadas del GDD (sección 4).
- **Derrota:** La vida de la taquería (base = 3, mejorable con "Barra Blindada") llega a 0. Cada enemigo que llega al final del camino resta `Constants.BASE_DAMAGE_PER_LEAK` (1) de vida — el GDD no especifica el daño por enemigo, se asumió 1 por igual sin importar el tipo (ver "Asunciones documentadas" abajo).
- **Controles:**
  - Tap sobre ícono de torre (barra inferior) → modo construcción → tap sobre casilla libre → coloca la torre (si alcanza el oro).
  - Tap sobre torre construida → panel de selección (daño, rango, nivel, botones Mejorar/Vender).
  - Drag vertical sobre el tablero → paneo de cámara (el camino real, 14 filas, no entra completo en la ventana visible entre el HUD y la barra inferior).

---

## Arquitectura (desviaciones del template genérico)

El template `/new-game` está diseñado sobre el molde de un juego de movimiento/disparo (tipo GuacBlaster Survivor: Player, ProjectileSpawner, PowerUpDropper, GemSpawner, XP/level-up). Taco Defender es un tower defense — no hay avatar de jugador, no hay drag-to-move, no hay recolección de gemas ni power-ups temporales in-run. Adaptaciones documentadas:

- **`src/features/board/`** (nuevo, no está en la lista genérica del skill): grilla + camino + colocación/mejora/venta de torres + TODO el input de mundo (tap/drag). Grid y torres se tratan como una sola feature — colocar una torre depende inherentemente de la celda de grilla; la comunicación INTERNA a esta feature es directa, no por EventBus (ver nota de arquitectura en `EventBus.gd`).
- **`src/features/towers/`** en vez de `player/`: `TowerBase.gd` (sin class_name, subtipos por ruta — regla CLAUDE.md #13) + 3 subtipos delgados que leen `Constants.TOWER_CATALOG` (única fuente de verdad de stats por tipo).
- **`src/features/projectiles/Projectile.gd`**: proyectil sin física (ni Area2D ni CharacterBody2D) — homing hacia una referencia viva, revalida `is_instance_valid()` cada frame (regla CLAUDE.md #44/#59).
- **`src/features/enemies/`**: `EnemyBase.gd` + 3 subtipos (básico/rápido/tank) + `EnemySpawner.gd` (orquesta las 10 oleadas) + `wave_queue.gd` (lógica pura de cola de spawn).
- **Sin capas de física** (`[layer_names]` no existe en project.godot a propósito): targeting de torres y daño en área usan grupos (`&"enemies"`) + distancia, no Area2D/collision_mask. Ver nota extensa en `Constants.gd`.
- **`src/features/meta/upgrade_shop.gd`** + **`src/core/MetaManager.gd`**: mismo patrón que otros proyectos GuacamoleBit (SaveManager ya cubre settings/tutorial; MetaManager, en su propio `user://meta.json`, cubre propinas + las 5 mejoras permanentes — evita acercarse al límite de 20 métodos públicos por clase que exige gdlint, regla CLAUDE.md #52).
- **FTUE ligero** (`HUD.gd::_build_ftue_overlay`): 3 mensajes estáticos con botón "Siguiente"/"Entendido", NO una escena `TutorialGame.tscn` separada — las mecánicas nuevas de este juego (construir/iniciar oleada/mejorar-vender) no encajan con la arquitectura de tutorial del template (pensada para Player/GemSpawner/PowerUpDropper, que no existen acá). `SaveManager.set_tutorial_shown(true)` se llama solo al completar el 3er mensaje, nunca antes.
- **Multi-idioma agregado** (`/mobile-i18n`): es, en, pt_BR, fr. `LocalizationManager.gd` (autoload, después de SaveManager) parsea `assets/translations/translations.txt` (CSV con extensión .txt — bug de Godot #38957) en runtime. `LanguageSelectScreen.tscn` en el primer arranque (`SaveManager.get_language() == ""`), selector de cambio en `SettingsScreen`. Texto estático usa la KEY cruda (auto_translate_mode nativo de Control); texto con valores incrustados usa `tr(&"KEY") % args` + un signal `EventBus.language_changed` para refrescar pantallas vivas (MainMenu/UpgradeScreen) cuando el idioma cambia con ellas abiertas.
- **Sin ilusión de profundidad** (agente `game-feel` §6): un tower defense de grilla top-down 2D no la necesita — el camino es fijo y visible, no hay sensación de "acercarse a cámara" como en un runner.

---

## Asunciones documentadas (GDD ambiguo o incompleto en estos puntos)

1. **Daño de un enemigo que llega a la base:** el GDD no lo especifica. Se asumió 1 vida por enemigo, sin importar el tipo (`Constants.BASE_DAMAGE_PER_LEAK`). Con solo 3-8 vidas totales, dejar pasar unos pocos enemigos es letal — encaja con la dificultad creciente de las oleadas tardías (ej. Oleada 9 "Enjambre" con 35 enemigos).
2. **Orden de spawn dentro de una oleada mixta:** el GDD no dice si los grupos de una oleada se intercalan o van secuenciales. Se implementó secuencial (agota un grupo, luego el siguiente) — determinístico y fácil de testear (`wave_queue.gd::build_spawn_queue()`).
3. **Barra Blindada, nivel 5:** el GDD lista literalmente "3 → 4 → 5 → 6 → 7" (5 valores = base + 4 pasos de +1). Como el sistema de tienda es uniforme (las 5 mejoras usan 5 niveles con el mismo costo por nivel: 100/250/500/1000/2000), se extrapoló el nivel 5 continuando el mismo patrón (+1/nivel) → 8 vidas. Ver `Constants.META_BASE_HP_PER_LEVEL`.
4. **"Clientes Generosos" (+10% propinas):** el GDD no aclara "por nivel" como las otras 4 mejoras, pero la sección dice "cada mejora tiene 5 niveles" de forma general — se asumió también por nivel (nivel 5 = +50% propinas).
5. **Forma del camino:** el GDD no define su trazado exacto, solo que es "fijo". Se diseñó un serpenteo de 6 columnas × 14 filas (7 pasadas horizontales) — largo a propósito para darle un uso real al control de "drag para desplazar cámara" del GDD (con un tablero que entrara completo en pantalla, ese control no tendría ningún propósito).
6. **Targeting "First":** interpretado como "el enemigo con mayor distancia recorrida a lo largo del camino" (`EnemyBase.get_progress()`), equivalente a "más cerca del final" dado que todos los enemigos comparten el mismo camino fijo.

---

## Mejoras Implementadas

- Core: Constants, EventBus, GameManager (máquina de estados: MENU/PLAYING/WAVE_INTERMISSION/PAUSED/GAME_OVER/GAME_WON), SaveManager (tutorial/sonido), MetaManager (propinas + 5 mejoras permanentes), AudioManager (stub funcional, reacciona a EventBus en vez de que cada feature le llame).
- Tablero: grilla 6×14, camino serpenteante fijo, cámara con paneo vertical (drag), tap para construir/seleccionar.
- 3 torres (Salsa Verde, Hielo Horchata, Catapulta Guac) con upgrade in-run hasta nivel 3, venta al 70% de lo invertido.
- 3 enemigos (Básico, Rápido, Tank) con barra de vida visual, ralentización (Hielo Horchata) y daño en área (Catapulta Guac).
- 10 oleadas exactas del GDD, transición manual ("Iniciar Oleada") o auto-start a los 5s.
- Economía: oro por kill, propinas por oleada superada + bono de victoria.
- Metagame: tienda de 5 mejoras permanentes (daño/rango/cooldown/propinas/vida global) en `UpgradeScreen.tscn`.
- UI completa: MainMenu, Game (HUD con barra de compra, panel de selección, FTUE), PauseScreen, GameOverScreen, VictoryScreen, SettingsScreen (sonido on/off), UpgradeScreen.
- Ícono y splash generados proceduralmente (`tools/gen_taco_icon.py`, sin IA — ver `/gen-ai-art`).
- Tests GUT: 100 tests / 348 asserts, cubriendo toda la lógica pura (grid_math, upgrade_shop, wave_queue) y los autoloads/features con estado (GameManager, SaveManager, MetaManager, EnemyBase, TowerBase, Board, EnemySpawner, HUD).
- `tools/run_tests.sh` reforzado: además de respaldar/restaurar `save.json`/`meta.json`, ahora detecta si algún `test_*.gd` falló al PARSEAR (GUT lo excluye del conteo en vez de fallar la corrida — bug real descubierto en esta sesión) y fuerza exit code 1 en ese caso.
- `tools/probe_visual.gd`/`.tscn`: probe NO headless reutilizable para verificar el layout real con capturas PNG (regla CLAUDE.md #49). Uso: `godot --path . tools/probe_visual.tscn` (sin `--headless`); guarda `probe_main_menu.png`, `probe_game_initial.png` y `probe_game_with_towers.png` en `OS.get_user_data_dir()/probe_screenshots/`. Encontró y confirmó el arreglo de un bug real durante este build: el panel de FTUE sin `autowrap_mode` desbordaba el ancho de pantalla (texto y botón cortados) — ver `HUD.gd::_build_ftue_overlay()`.
- Build Android debug verificado localmente: `godot --headless --install-android-build-template --export-debug "Android" builds/debug/TacoDefender.apk` → BUILD SUCCESSFUL (APK ~89MB).

---

## Pendientes

- **Arte real:** RESUELTO. Fondos de pantalla completa (menú, detrás del tablero, tienda de mejoras) generados con Pollinations.ai vía `tools/fetch_taco_backgrounds.py`, integrados con `src/shared/background_style.gd` (velo oscuro para legibilidad de texto — ver `/gen-ai-art` Paso 7). Torres/enemigos generados con IA en estilo "vector cartoon" (`tools/fetch_taco_object_sprites.py`, flood-fill para remover fondo) para igualar la referencia de diseño; proyectiles siguen procedurales (`tools/gen_taco_sprites.py`, muy chicos — 12px — para que sobreviva algo de una imagen de IA). Icono y splash ya estaban resueltos proceduralmente desde el build inicial.
- **UI in-game (HUD/paneles):** RESUELTO. `assets/theme/game_theme.tres` (generado por `tools/build_game_theme.gd`, referenciado en `project.godot` `[gui] theme/custom`) reestiliza TODOS los Button/Label/PanelContainer del juego (antes: tema plano default de Godot). Íconos agregados (`tools/gen_ui_icons.py`, procedural + `src/shared/icon_style.gd` como helper compartido de TextureRect): moneda de oro + corazón de vida en la barra superior, ícono de torre en el panel de selección y en los botones de compra (arte de `fetch_taco_object_sprites.py`), y símbolo de pausa/estrella de victoria/corazón roto de derrota en PauseScreen/VictoryScreen/GameOverScreen. Pendiente: animación de entrada/salida del toast (menor, cosmético).
- **Audio real:** RESUELTO. Los 9 `.wav` generados con `tools/gen_taco_audio.py` (síntesis pura Python, sin PIL/red — reutiliza los helpers de `gen_assets.py`). `AudioManager.gd` ya escuchaba EventBus para los 7 SFX de gameplay; se agregó loop manual de `music_loop.wav` vía `_music_player.finished` (el `.import` de un WAV nuevo no trae loop habilitado por default, y ese archivo está en `.gitignore` — depender de esa metadata habría sido frágil). **Pendiente deliberado:** `button_tap.wav` existe pero NINGÚN botón lo dispara todavía — cablearlo tocaría los ~24 botones repartidos en las 7 pantallas; se decidió no hacerlo en esta pasada para no invadir el alcance de "audio" con cambios masivos de UI. Candidato natural para la próxima vez que se toquen esas pantallas (ej. junto con multi-idioma, que de todos modos las recorre todas). SFX de disparo por torre (muy frecuente) tampoco se implementó — polish opcional.
- **CI/CD Google Play:** `.github/workflows/deploy-playstore.yml` ya tiene el package name real (`com.guacamolebit.tacodefender`), pero requiere secrets de GitHub (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASS`, `GOOGLE_PLAY_JSON`) que esta sesión no puede configurar. Ver `/android-deploy` antes de publicar — incluye la primera subida manual obligatoria a Play Console.
- **Multi-idioma:** RESUELTO (es default + en/pt_BR/fr) — ver sección Arquitectura arriba. Traducciones en `assets/translations/translations.txt` (50 keys) son un primer pase razonable, no revisadas por un hablante nativo de cada idioma — vale la pena una pasada de QA lingüística antes de publicar en mercados pt_BR/fr. De paso se encontró y arregló un bug de layout preexistente (no causado por i18n — los nombres en español ya eran igual de largos): `UpgradeScreen._build_row()` no tenía `autowrap_mode` en el label de nombre, y un nombre de mejora largo empujaba el botón "Comprar" fuera de la pantalla (mismo bug/mismo fix que el panel de FTUE de HUD.gd).
- **Feedback visual de "toast" (`EventBus.action_feedback`):** RESUELTO. Fade+slide de entrada (0.15s) y fade de salida (0.25s) vía `Tween` en `HUD.gd`, con un solo helper (`_play_toast_tween`) que mata cualquier tween en vuelo antes de arrancar uno nuevo (dos toasts seguidos no dejan animaciones peleando por la misma propiedad) y lo mata también en `_exit_tree()` (evita un `Tween` huérfano si la escena cambia a mitad de la animación).
- **Ilusión de profundidad / VFX de impacto:** no implementados (fuera de alcance para este build — el juego es 100% funcional sin ellos). Evaluar con agente `game-feel` si se quiere pulir más.
- **Balance real:** revisado con investigación competitiva (Bloons TD/Kingdom Rush/Plants vs Zombies mobile). Hallazgo: Salsa Verde (15 dmg, $50, cd 1.2s) mata de un golpe a Básico (10 HP) y Rápido (5 HP), y su cooldown es más corto que el intervalo de spawn de la Oleada 1 — una sola torre limpia esa oleada sin recibir daño. Esos valores son literales del GDD, así que NO se tocaron. Hallazgo más grande: no existía NINGÚN escalado de dificultad entre partidas — `MetaManager.get_victories()`/`get_best_wave()` solo se leían para texto en MainMenu, nunca afectaban gameplay, mientras las 5 mejoras permanentes solo buffean al jugador. Con el GDD tratado como propuesta base (no ley), se agregó escalado de dificultad por repetición (`Constants.ENEMY_HP_BONUS_PER_VICTORY`/`ENEMY_REWARD_BONUS_PER_VICTORY`, +15% HP y +15% recompensa de oro por victoria previa, tope de 5 — mismo patrón "5 niveles" que el metagame) en `EnemyBase._ready()`. Con 4+ victorias, Salsa Verde ya no one-shotea a Básico. Tests de `test_enemy_base.gd` derivan el HP/recompensa esperado con la misma fórmula (relativo al `MetaManager` real, mismo patrón que `test_game_manager.gd`). De paso se adaptó `.claude/.agents/game-designer.md` (tenía el checklist del survivor-shooter genérico del template — power-ups/XP/jefes que no existen acá — con un checklist propio de tower defense).

---

## Valores de Balance (GDD v1.1)

### Economía
Oro inicial: $100 · Venta de torres: 70% de lo invertido · Auto-start de oleada: 5s

### Enemigos
| Tipo | HP | Velocidad | Recompensa |
|---|---|---|---|
| Básico (mosca) | 10 | 80 px/s | $5 |
| Rápido (cucaracha) | 5 | 200 px/s | $8 |
| Tank (ratón) | 100 | 30 px/s | $25 |

### Torres
| Torre | Costo | Daño | Rango | Cooldown | Upgrade |
|---|---|---|---|---|---|
| Salsa Verde | $50 | 15 | 150px | 1.2s | +$35: +5 dmg, +15 rango |
| Hielo Horchata | $75 | 8 | 120px | 1.5s | Slow 50%/2s base; +$50: +25% duración/nivel |
| Catapulta Guac | $120 | 25 (AoE R=50px) | 200px | 2.5s | +$80: +10 dmg AoE |

### Oleadas (10 — ver `Constants.WAVE_DEFINITIONS`)
1. 5 Básico (1.5s) · 2. 8 Básico (1.2s) · 3. 5 Básico+3 Rápido (1.0s) · 4. 10 Rápido (0.6s) · 5. 6 Básico+1 Tank (1.0s) · 6. 12 Rápido+2 Tank (0.8s) · 7. 15 Básico+8 Rápido (0.5s) · 8. 4 Tank+10 Rápido (1.0s) · 9. 20 Básico+15 Rápido (0.4s) · 10. 6 Tank+15 Rápido+10 Básico (0.5s)

### Metagame
Propina por oleada: 10 · Bono victoria: 50 · 5 mejoras, 5 niveles c/u, costo 100/250/500/1000/2000 propinas.
