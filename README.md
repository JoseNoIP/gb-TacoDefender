# Godot Mobile Game Template

Template de producción para juegos móviles con Godot 4.7 + Claude Code.  
Basado en el stack probado de [GuacBlaster Survivor](https://github.com/GuacamoleBit/gb-GuacBlaster-Survivor).

---

## Qué incluye

| Componente | Detalle |
|---|---|
| **Arquitectura** | Feature-first, EventBus, autoloads tipados |
| **Core stubs** | `Constants.gd`, `EventBus.gd`, `GameManager.gd`, `SaveManager.gd` |
| **CI/CD** | GitHub Actions → AAB firmado → Google Play (Internal/Production) |
| **Export presets** | Android + iOS preconfigurados (390×844, GL Compatibility) |
| **Testing** | GUT v9.7.1, script `run_tests.sh` que protege saves del usuario |
| **Lint** | gdtoolkit (`gdlint` / `gdformat`) vía pipx |
| **Skills de Claude Code** | `/new-game`, `/validate`, `/feature`, `/doc`, `/gen-ai-art`, `/android-deploy`, `/mobile-i18n` |
| **Agentes de Claude Code** | `godot-architect`, `godot-qa`, `game-designer`, `game-feel` |
| **Herramientas de arte** | `tools/gen_assets.py` (procedural), `tools/fetch_ai_assets.py` (Pollinations.ai) |

---

## Cómo usar este template

### 1. Crear el repositorio del nuevo juego

En GitHub: **Use this template → Create a new repository**  
O en local:

```bash
git clone https://github.com/GuacamoleBit/gb-GameTemplate gb-MiJuego
cd gb-MiJuego
git remote set-url origin https://github.com/TU_ORG/gb-MiJuego.git
```

### 2. Instalar dependencias

```bash
# gdtoolkit para lint/format
brew install pipx && pipx install gdtoolkit

# Python + Pillow para generación de assets (opcional)
python3 -m venv /tmp/gb_venv && /tmp/gb_venv/bin/pip install Pillow
```

### 3. Describir el juego con `/new-game`

Abre Claude Code en la raíz del repo y ejecuta:

```
/new-game tu-gdd.md
```

El skill guía el proceso completo: define mecánicas core, reemplaza los PLACEHOLDERs en `idea-base.md`, ajusta `Constants.gd`, y construye la primera escena jugable.  
Si no tienes un GDD todavía, puedes pasar el archivo `idea-base.md` con el concepto básico del juego.

### 4. Flujo de desarrollo

Cada feature nueva sigue el protocolo PLAN→IMPL→VALIDATE→SANITY→DOC:

```bash
# En Claude Code:
/feature nombre-de-la-feature

# Antes de cualquier commit:
/validate

# Al cerrar cualquier tarea:
/doc
```

### 5. Deploy a Google Play

Configura los secrets de GitHub y ejecuta:

```
/android-deploy
```

El skill cubre los 10+ errores conocidos de Godot 4.7 → Google Play, incluyendo firmado con `jarsigner`, version code automático y package name.

---

## Estructura de carpetas

```
src/
├── core/           # Constants, EventBus, GameManager, SaveManager
├── features/       # player/, enemies/, projectiles/, ui/, audio/, ...
├── scenes/         # Escenas raíz (.tscn)
└── shared/         # Recursos compartidos (.tres, temas)
assets/
├── sprites/
├── audio/
└── fonts/
tests/unit/         # Tests GUT (test_*.gd)
tools/              # Scripts de generación de assets
.claude/
├── skills/         # Slash commands de Claude Code
└── .agents/        # Agentes especializados
.github/workflows/  # CI/CD Google Play
```

---

## Skills disponibles

| Comando | Cuándo usar |
|---|---|
| `/new-game [gdd.md]` | Arrancar un juego nuevo desde cero — autónomo hasta build funcional |
| `/validate` | Antes de cualquier commit — corre gdlint + GUT |
| `/feature [nombre]` | Implementar una feature nueva con guía completa |
| `/doc` | Cerrar una tarea — sincroniza idea-base.md, CLAUDE.md y memorias |
| `/gen-ai-art` | Generar arte con Pollinations.ai (Flux, gratis) |
| `/android-deploy` | Configurar o depurar el pipeline CI/CD de Google Play |
| `/mobile-i18n` | Agregar soporte multi-idioma (CSV runtime, sin binarios) |

---

## Reglas clave

- **Todo valor numérico va en `Constants.gd`** — nunca hardcodeado en features.
- **Toda comunicación entre features va por `EventBus`** — nunca `get_parent()` ni rutas hardcodeadas.
- **Tipado estático obligatorio** — `var x: float`, `func f(n: int) -> void`.
- **`class_name` + autoload es un conflicto fatal** en Godot 4.7 — los singletons no llevan `class_name`.
- El detalle completo de reglas anti-alucinación y estándares está en `CLAUDE.md`.

---

## Origen

Template extraído de **GuacBlaster Survivor** (GuacamoleBit, 2026).  
Stack validado en producción: Android + Google Play Store + CI/CD con GitHub Actions.
