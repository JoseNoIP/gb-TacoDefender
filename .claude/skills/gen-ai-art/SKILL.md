---
name: gen-ai-art
description: Genera assets visuales de un juego con IA (Pollinations.ai Flux, gratis, sin API key). Backgrounds, sprites con transparencia, íconos. Incluye fallback procedural y pipeline de regeneración.
disable-model-invocation: true
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
---

## /gen-ai-art — Pipeline de Arte con IA para Juegos

Genera arte final para un juego usando **Pollinations.ai (Flux, gratuito, sin registro)** como fuente de imágenes, con **Pillow** para conversión y transparencia, y un script procedural como fallback.

---

### PASO 0 — PREREQUISITOS

```bash
# Crear venv aislado con Pillow (no contamina el Python del sistema)
python3 -m venv /tmp/gb_venv
/tmp/gb_venv/bin/pip install Pillow --quiet

# Verificar
/tmp/gb_venv/bin/python3 -c "from PIL import Image; print('OK')"
```

**Por qué venv:** `pip install Pillow` falla en macOS con PEP 668 ("externally managed environment"). El venv en `/tmp/` evita tocar el sistema.

---

### PASO 1 — ENTENDER LA API DE POLLINATIONS.AI

```
https://image.pollinations.ai/prompt/{PROMPT_ENCODED}?width=W&height=H&nologo=true&model=flux&seed=N
```

**Reglas críticas aprendidas:**
1. **Secuencial, nunca paralelo.** El tier gratuito permite 1 request en cola por IP. Enviar 15 en paralelo devuelve `{"error":"Too Many Requests","message":"Queue full..."}` en formato JSON (no PNG). Siempre descargar uno a la vez.
2. **Devuelve JPEG, no PNG.** Verificar con `data[:2] in (b'\xff\xd8', b'\x89PN')`. Convertir a PNG con Pillow o `sips` (macOS).
3. **Seeds reproducibles.** Mismo prompt + mismo seed = misma imagen. Documentar los seeds usados.
4. **Timeout 120s.** Algunos requests tardan hasta 90s en hora pico. Usar `timeout=120`.
5. **Esperar 2-3s entre requests** para no saturar la cola.

```python
import io, time, urllib.request, urllib.parse
from PIL import Image

def fetch_image(prompt: str, width: int, height: int, seed: int) -> Image.Image | None:
    enc = urllib.parse.quote(prompt)
    url = (f"https://image.pollinations.ai/prompt/{enc}"
           f"?width={width}&height={height}&nologo=true&model=flux&seed={seed}")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "GameProject/1.0"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = resp.read()
        if data[:2] in (b'\xff\xd8', b'\x89PN'):
            return Image.open(io.BytesIO(data)).convert("RGBA")
        else:
            print(f"  API error: {data[:80].decode('utf-8', errors='replace')}")
    except Exception as e:
        print(f"  Fetch error: {e}")
    return None

# Siempre con sleep entre requests
for biome in range(5):
    img = fetch_image(prompt, 390, 844, seed=biome * 100 + 7)
    img.save(f"bg_{biome}.png", "PNG")
    time.sleep(3)
```

---

### PASO 2 — BACKGROUNDS (fondos de pantalla completa)

Para fondos NO se necesita transparencia. El proceso es directo:

```python
# Descargar y guardar directamente como PNG
img = fetch_image(prompt, 390, 844, seed=7)
if img:
    img.save("assets/sprites/backgrounds/bg_0_0.png", "PNG")
```

**Estructura de prompts efectivos para fondos de juego:**
```
{tema} game background portrait {dimensiones implicadas},
{elementos visuales clave}, {paleta de colores}, atmospheric moody,
{intensidad visual} tones, mobile game art
```

Ejemplos probados (Flux, seed documentados):

| Bioma | Prompt base | Seeds usados |
|---|---|---|
| Jungla oscura | `dark tropical jungle night game background portrait, dense dark green foliage palm trees, glowing fireflies, crescent moon, atmospheric moody, dark green tones, mobile game art` | 7, 44, 81 |
| Crepúsculo índigo | `twilight indigo purple night sky cityscape game background portrait, mystical stars nebula glowing, urban silhouette, deep purple tones, atmospheric moody mobile game art` | 107, 144, 181 |
| Volcánico | `volcanic lava landscape game background portrait, glowing lava rivers, molten rock dark red orange embers, volcano peak, dark inferno tones, atmospheric dramatic mobile game art` | 207, 244, 281 |
| Abismo oceánico | `deep ocean abyss underwater game background portrait, bioluminescent jellyfish creatures, dark blue tones, abyssal depth, glowing particles, atmospheric mobile game art` | 307, 344, 381 |
| Luna de sangre | `blood moon red night desert game background portrait, dramatic crimson sky, dark sand dunes silhouette, dead trees, gothic dark red tones, atmospheric moody mobile game art` | 407, 444, 481 |

**Dimensiones recomendadas:**
- Móvil portrait: 390×844 (iPhone 14 canvas)
- Desktop landscape: 1280×720 o 1920×1080

---

### PASO 3 — SPRITES CON TRANSPARENCIA (personajes, items, enemigos)

Los sprites necesitan fondo transparente. Estrategia: pedir `"white background, isolated 2D game asset"` y aplicar **chroma key** para remover el blanco.

```python
def chroma_key(img: Image.Image, bg_color=(255,255,255), tolerance=40) -> Image.Image:
    """Remueve el fondo blanco para crear transparencia."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            dist = ((r-bg_color[0])**2 + (g-bg_color[1])**2 + (b-bg_color[2])**2) ** 0.5
            if dist < tolerance:
                px[x, y] = (r, g, b, 0)
    return img

# Proceso completo para un sprite
img = fetch_image(
    "pixel art green spaceship game sprite, white background, isolated 2D game asset",
    width=512, height=512, seed=1001
)
if img:
    img = chroma_key(img)                         # Remover fondo blanco
    img = img.resize((64, 64), Image.LANCZOS)     # Escalar al tamaño de juego
    img.save("assets/sprites/player.png", "PNG")
```

**Notas sobre chroma key:**
- `tolerance=40`: remueve blanco puro y blanco sucio (anti-aliasing). Valor seguro.
- Si el sprite tiene áreas blancas genuinas (ej: dientes, ojos), aumentar a 30 para ser más conservador.
- El resultado tendrá bordes semi-transparentes (anti-aliasing) que se ven bien en juego.
- Pedir imagen a 512×512 y escalar a tamaño de juego con `LANCZOS` da mejor calidad.

**Prompts efectivos para sprites:**
```
pixel art {descripción del personaje} game sprite,
{color dominante}, {rasgos clave}, white background, isolated 2D game asset
```

**Verificar calidad del sprite resultante:**
```python
from PIL import Image

img = Image.open("assets/sprites/player.png").convert("RGBA")
px = img.load()
w, h = img.size
opaque = sum(1 for y in range(h) for x in range(w) if px[x,y][3] > 100)
print(f"Opaque: {opaque*100//(w*h)}% (buen sprite: 20-50%)")
```

---

### PASO 4 — ÍCONOS DE POWER-UP / UI (procedural mejorado)

Para íconos pequeños (32×32 a 64×64), **la generación procedural en Python** supera a la IA porque:
- La IA a esas dimensiones produce imágenes borrosas/ruidosas.
- Los íconos necesitan comunicar una mecánica específica con claridad.
- Se pueden ajustar colores y formas exactamente.

Ver `tools/gen_assets.py` en el proyecto para el sistema de íconos procedurales con:
- Fondo redondeado con gradiente de color por tipo
- Formas simbólicas específicas por power-up (flechas, relámpagos, escudos, etc.)
- Funciones reutilizables: `_arrow_up()`, `_rounded_rect()`, `_icon_base()`, `_poly()`

**Cuándo usar IA vs procedural para sprites:**
| Tamaño | Enfoque recomendado |
|---|---|
| ≥ 128×128 | IA (Pollinations.ai) + chroma key |
| 64×128 | IA + chroma key, revisar calidad |
| ≤ 64×64 | Procedural en Python (más control, más nítido) |

**Reglas aprendidas generando sprites procedurales de gameplay (torres/enemigos/proyectiles
de un tower defense, personajes de cualquier juego con cuerpo circular + apéndices):**

1. **Generar al DOBLE del tamaño de render en juego**, y aplicar `sprite.scale = Vector2(0.5, 0.5)`
   al `Sprite2D` que lo usa. Se ve más nítido en pantallas retina tras el
   `stretch/mode=canvas_items` del proyecto, sin cambiar el estilo pixel-art (regla CLAUDE.md #61
   sobre el viewport virtual fijo aplica igual acá).
2. **Cualquier apéndice que deba sobresalir de un cuerpo circular/rectangular ya dibujado
   (orejas, alas, patas, antenas) se dibuja DESPUÉS del cuerpo principal, nunca antes.** Si se
   dibuja antes, el círculo/rect del cuerpo (dibujado encima) lo tapa por completo — sin error,
   sin warning, el PNG resultante se ve como una forma lisa sin ningún rasgo. Posicionar el
   apéndice a una distancia del centro tal que una porción quede claramente fuera del radio
   principal (o completamente afuera si hace falta contraste total, como las orejas de un
   ratón). Un helper `_thick_line(g, x1, y1, x2, y2, width, color)` (quad perpendicular a la
   línea, coordenadas SIEMPRE `int()` porque `_poly`/`range()` no aceptan floats) cubre patas,
   antenas, colas y brazos de catapulta con la misma función.
3. **Verificar SIEMPRE con un zoom nearest-neighbor** (`img.resize((w*8, h*8), Image.NEAREST)`
   en Pillow, o pegar varios sprites en una sola hoja de contacto) antes de integrar el sprite
   al juego — a tamaño real (16-40px) un apéndice mal dibujado, clippeado contra el borde del
   canvas, o tapado por otra forma es indistinguible a simple vista de uno bien dibujado.

---

### PASO 5 — GESTIÓN DE ARCHIVOS .IMPORT EN GODOT

Cuando se añade un PNG nuevo que Godot no había importado antes:

1. Godot auto-genera el `.import` cuando abres el editor. Para headless builds o si el asset se referencia en `.tscn` antes de abrir el editor:
2. Crear manualmente el `.import` copiando el formato de uno existente y asignando un UID único.

```ini
# assets/sprites/nuevo_sprite.png.import
[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://abc123xyz4567"   # ← ÚNICO, no reutilizar
path="res://.godot/imported/nuevo_sprite.png-abc123xyz4567.ctex"
metadata={"vram_texture": false}

[deps]
source_file="res://assets/sprites/nuevo_sprite.png"
dest_files=["res://.godot/imported/nuevo_sprite.png-abc123xyz4567.ctex"]

[params]
compress/mode=0
# ... (copiar resto de parámetros de otro .import existente)
```

Generar un UID único:
```python
import random, string
uid = ''.join(random.choice('abcdefghijklmnopqrstuvwxyz0123456789') for _ in range(13))
print(f"uid://e{uid}")
```

El `.ctex` no existe aún pero Godot lo creará al importar. La referencia en `.tscn` debe usar el mismo UID.

---

### PASO 6 — ESTRUCTURA DEL SCRIPT PRINCIPAL

Ver `tools/fetch_ai_assets.py` como referencia completa. Estructura recomendada:

```python
#!/usr/bin/env python3
"""
Uso: /tmp/gb_venv/bin/python3 tools/fetch_ai_assets.py
"""
import io, os, time, urllib.request, urllib.parse
from PIL import Image

# --- Config ---
BACKGROUNDS = [
    {"path": "assets/sprites/backgrounds/bg_0_0.png",
     "prompt": "dark jungle night...", "w": 390, "h": 844, "seed": 7},
    # ...
]
SPRITES = [
    {"path": "assets/sprites/player.png",
     "prompt": "pixel art ship...", "w": 512, "h": 512, "seed": 1001,
     "output_size": (64, 64), "chroma_key": True},
    # ...
]

# --- Functions ---
def fetch_image(...): ...
def chroma_key(...): ...

# --- Main ---
def main():
    print("=== Backgrounds ===")
    for spec in BACKGROUNDS:
        img = fetch_image(spec["prompt"], spec["w"], spec["h"], spec["seed"])
        if img:
            img.save(spec["path"], "PNG")
        time.sleep(3)

    print("=== Sprites ===")
    for spec in SPRITES:
        img = fetch_image(spec["prompt"], spec["w"], spec["h"], spec["seed"])
        if img:
            if spec.get("chroma_key"):
                img = chroma_key(img)
            if "output_size" in spec:
                img = img.resize(spec["output_size"], Image.LANCZOS)
            img.save(spec["path"], "PNG")
        time.sleep(3)
```

---

### PASO 7 — INTEGRAR FONDOS EN LA ESCENA (legibilidad de texto)

Un fondo de pantalla completa generado por IA tiene MUCHO más detalle visual que el
`ColorRect` plano que reemplaza — cualquier texto/botón que no tenga su propio panel
opaco (título, subtítulo, contador, botón "Volver") corre el mismo riesgo de
ilegibilidad que un `PanelContainer` sin estilo propio (regla CLAUDE.md #53), solo que
a nivel de pantalla completa en vez de un modal.

Fix: un velo semi-transparente oscuro (`ColorRect`, alpha ~0.2-0.35) ENCIMA de la
imagen de fondo y DEBAJO del resto de la UI. Conviene un helper compartido
(`src/shared/background_style.gd`, mismo espíritu que `modal_style.gd`) para no repetir
la lógica de carga+velo en cada escena:

```gdscript
static func add_background(parent: Node, texture_path: String, dim_alpha: float = 0.35) -> void:
    var bg: TextureRect = TextureRect.new()
    bg.texture = load(texture_path)
    bg.position = Vector2.ZERO
    bg.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(bg)
    if dim_alpha > 0.0:
        var scrim: ColorRect = ColorRect.new()
        scrim.position = Vector2.ZERO
        scrim.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
        scrim.color = Color(0.0, 0.0, 0.0, dim_alpha)
        scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
        parent.add_child(scrim)
```

Notas:
- Funciona igual como hijo de un `Control` (menú/tienda) o de un `Node2D` (escena de
  gameplay) — es solo `CanvasItem`, no depende de la jerarquía. Respeta igual la regla
  CLAUDE.md #43: agregarlo PRIMERO (nunca dentro de un `CanvasLayer`) para quedar detrás
  del resto por orden de árbol.
- Si el fondo queda casi totalmente tapado por otro elemento opaco de la escena (ej. el
  tablero de un tower defense, que puede cubrir >90% del viewport), bajar `dim_alpha` a
  ~0.15-0.2 — el fondo ahí solo aporta ambientación en los márgenes visibles, no
  legibilidad de texto, así que un velo fuerte solo lo apaga sin necesidad.
- Verificar el resultado con una captura real (`tools/probe_visual.gd`, regla CLAUDE.md
  #49) — un velo con alpha mal calibrado (muy bajo = texto ilegible, muy alto = se pierde
  el arte) no se detecta con ningún test headless.

---

### ERRORES COMUNES Y SOLUCIONES

| Error | Causa | Solución |
|---|---|---|
| Archivo descargado es JSON con `"Too Many Requests"` | Requests paralelos en tier gratis | Descargar secuencialmente + `sleep(3)` |
| `pip install Pillow` falla (PEP 668) | macOS protege el Python del sistema | `python3 -m venv /tmp/venv && /tmp/venv/bin/pip install Pillow` |
| PNG válido pero con fondo blanco visible en juego | `tolerance` muy bajo en chroma_key | Subir `tolerance` a 50-60 |
| Sprite con huecos en áreas blancas del personaje | `tolerance` muy alto | Bajar a 25-30 |
| Fondo procedural sobreescribe descarga AI | `gen_assets.py` corre `main()` accidentalmente | Ejecutar solo las funciones necesarias (no `main()`). Para generar UN solo ícono, escribir un script inline que importe solo la función: `python3 -c "import sys; sys.path.insert(0,'tools'); from gen_assets import _make_cb_icon, save_png; save_png('ruta.png', 64, 64, _make_cb_icon())"` |
| `enemy_elite.tscn` usa sprite de otro personaje | Scene referencia UID incorrecto en `ext_resource` | Crear `.import` manual + actualizar UID en `.tscn` |

---

### CHECKLIST DE FINALIZACIÓN

- [ ] Todos los backgrounds son PNG válidos con dimensiones correctas
- [ ] Todos los sprites tienen alpha (verificar con: `opaque%` entre 20-60%)
- [ ] Ningún `.import` faltante para assets referenciados en `.tscn`
- [ ] UIDs en `.import` coinciden con UIDs en `.tscn`
- [ ] Seeds documentados en el script para reproducibilidad
- [ ] `tools/gen_assets.py` actualizado con mejores funciones procedurales como fallback
- [ ] Documentar en `CLAUDE.md` y `idea-base.md` el pipeline de regeneración

---

### REFERENCIA RÁPIDA — COMANDOS

```bash
# Setup (una sola vez)
python3 -m venv /tmp/gb_venv && /tmp/gb_venv/bin/pip install Pillow

# Descargar todo (backgrounds + sprites, ~30 min)
/tmp/gb_venv/bin/python3 tools/fetch_ai_assets.py

# Re-descargar un subconjunto específico
/tmp/gb_venv/bin/python3 tools/redownload_missing_bgs.py

# Regenerar fallback procedural (íconos, audio, splash)
python3 tools/gen_assets.py

# Verificar backgrounds AI (deben ser > 100KB)
python3 -c "
import os
base = 'assets/sprites/backgrounds'
ai = sum(1 for f in os.listdir(base) if f.endswith('.png') and os.path.getsize(f'{base}/{f}') > 100000)
print(f'{ai}/15 AI backgrounds')
"

# Verificar sprites AI (deben ser > 1000 bytes)
python3 -c "
import os
for f in os.listdir('assets/sprites'):
    if f.endswith('.png') and not f.endswith('.import'):
        s = os.path.getsize(f'assets/sprites/{f}')
        print(f'  {\"AI\" if s > 1000 else \"proc\"} {f}: {s}B')
"
```
