# Skill: /android-deploy

Configura o repara el pipeline de CI/CD de GitHub Actions para publicar un juego Godot 4.x en Google Play Store como AAB firmado, y opcionalmente un segundo pipeline para mandar builds de prueba (debug APK) a Dropbox sin pasar por Play Console.

Usa este skill cuando:
- Estás configurando el pipeline por primera vez en un nuevo juego
- Un paso del workflow está fallando y quieres el mapa completo de errores conocidos
- Necesitás distribuir un build de prueba a testers rápido (Dropbox) sin tocar Play Store

Al configurar esto en un juego nuevo, generar también un `DEPLOYMENT.md` en la raíz del
proyecto (runbook con las variables YA fijadas del juego — package name, nombre del
juego — y un checklist de qué secrets faltan crear) en vez de que el humano tenga que
releer este skill completo cada vez. Ver `DEPLOYMENT.md` de Taco Defender como ejemplo
de formato.

---

## Arquitectura del pipeline (Godot 4.7+)

```
Checkout → Java 17 → Instalar Godot → Instalar templates
→ Configurar keystore + version_code → Pre-heat cache
→ Export APK (instala template Gradle + popula assets)
→ bundleRelease (produce AAB)
→ jarsigner (firma el AAB explícitamente)
→ Subir artefacto → Upload a Play Store
```

El flujo **dos pasos** es obligatorio en Godot 4.7:
1. `godot --export-release ... game.apk` — Godot exporta APK y popula `android/build/` con los assets del juego.
2. `./gradlew bundleRelease` — Gradle produce el AAB que Play Store requiere.
3. `jarsigner` — firma el AAB explícitamente (Gradle puede producirlo sin firma aunque se pasen los flags `-P`).

Godot 4.7 **rechaza** la extensión `.aab` directamente. El AAB solo se puede producir vía Gradle.

---

## Version code — estándar recomendado

**Usar minutos desde 2024-01-01:**
```bash
echo "version_code=$(( ($(date +%s) - 1704067200) / 60 ))" >> $GITHUB_OUTPUT
```

- ~815,000 hoy (julio 2026), crece ~525,000/año
- Nunca colisiona con versiones subidas manualmente
- Válido por siglos (muy lejos del límite 2,100,000,000 de Play Store)
- El `version_code` es **interno** — usuarios nunca lo ven (ellos ven `version_name`)

**No usar:**
- `github.run_number` — colisiona si subes algo manualmente (empieza en 1)
- Unix epoch (`date +%s`) — válido pero más largo (~1.75B) y expira ~2038

---

## Workflow completo — probado y funcional

```yaml
name: Deploy → Google Play

on:
  push:
    branches: [main]
    tags: ["v*.*.*"]
  workflow_dispatch:
    inputs:
      skip_upload:
        description: "Solo construir AAB (sin subir a Play Store)"
        type: boolean
        default: false

env:
  GODOT_VERSION: "4.7"                        # cambiar según versión del proyecto
  EXPORT_PRESET: "Android"                    # debe coincidir con export_presets.cfg
  PACKAGE_NAME: "com.tuempresa.tujuego"       # ← CAMBIAR

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Determinar track y versión
        id: ctx
        run: |
          if [[ "${{ github.ref }}" == refs/tags/* ]]; then
            echo "track=production" >> $GITHUB_OUTPUT
          else
            echo "track=internal"   >> $GITHUB_OUTPUT
          fi
          # Minutos desde 2024-01-01: compacto, siempre creciente, nunca colisiona
          echo "version_code=$(( ($(date +%s) - 1704067200) / 60 ))" >> $GITHUB_OUTPUT

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17

      - name: Instalar Godot ${{ env.GODOT_VERSION }}
        run: |
          wget -q "https://github.com/godotengine/godot/releases/download/${{ env.GODOT_VERSION }}-stable/Godot_v${{ env.GODOT_VERSION }}-stable_linux.x86_64.zip" -O godot.zip
          unzip -q godot.zip
          mv "Godot_v${{ env.GODOT_VERSION }}-stable_linux.x86_64" /usr/local/bin/godot
          chmod +x /usr/local/bin/godot
          rm godot.zip

      - name: Instalar export templates
        run: |
          wget -q "https://github.com/godotengine/godot/releases/download/${{ env.GODOT_VERSION }}-stable/Godot_v${{ env.GODOT_VERSION }}-stable_export_templates.tpz" -O templates.tpz
          TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${{ env.GODOT_VERSION }}.stable"
          mkdir -p "$TEMPLATES_DIR"
          unzip -q templates.tpz -d templates_tmp
          mv templates_tmp/templates/* "$TEMPLATES_DIR/"
          rm -rf templates_tmp templates.tpz

      - name: Configurar keystore y version code
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > /tmp/game.keystore
          sed -i "s|version/code=[0-9]*|version/code=${{ steps.ctx.outputs.version_code }}|" export_presets.cfg
          sed -i "s|gradle_build/use_gradle_build=false|gradle_build/use_gradle_build=true|" export_presets.cfg
          grep -E "version/code|gradle_build/use" export_presets.cfg

      - name: Pre-heat Godot cache
        run: godot --headless --editor --quit || true

      - name: Exportar APK (instala template + popula android/build/)
        env:
          GODOT_ANDROID_KEYSTORE_RELEASE_PATH: /tmp/game.keystore
          GODOT_ANDROID_KEYSTORE_RELEASE_USER: ${{ secrets.ANDROID_KEYSTORE_ALIAS }}
          GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASS }}
        run: |
          mkdir -p builds/
          godot --headless --verbose \
            --install-android-build-template \
            --export-release "${{ env.EXPORT_PRESET }}" \
            "builds/game.apk"

      - name: Construir AAB con Gradle
        env:
          KEYSTORE_ALIAS: ${{ secrets.ANDROID_KEYSTORE_ALIAS }}
          KEYSTORE_PASS: ${{ secrets.ANDROID_KEYSTORE_PASS }}
        run: |
          mkdir -p android/build/assetPackInstallTime/src/main/assets

          cd android/build
          # PROPIEDADES CRÍTICAS de config.gradle (Godot 4.7):
          #   export_package_name  → applicationId (default: com.godot.game)
          #   export_version_code  → versionCode   (default: 1 — SIEMPRE PASAR)
          #   perform_signing=true → activa signingConfig release (default: false)
          #   release_keystore_*   → datos del keystore
          ./gradlew bundleRelease \
            "-Pexport_package_name=${{ env.PACKAGE_NAME }}" \
            "-Pexport_version_code=${{ steps.ctx.outputs.version_code }}" \
            "-Pperform_signing=true" \
            "-Prelease_keystore_file=/tmp/game.keystore" \
            "-Prelease_keystore_password=$KEYSTORE_PASS" \
            "-Prelease_keystore_alias=$KEYSTORE_ALIAS"

          AAB=$(find . -name "*.aab" -path "*/standardRelease/*" | head -1)
          if [ -z "$AAB" ]; then
            AAB=$(find . -name "*.aab" -not -path "*/intermediates/*" | head -1)
          fi
          cp "$AAB" ../../builds/game.aab

      # Firmar explícitamente: bundleRelease puede ignorar -Pperform_signing
      # en algunas configuraciones de Godot. jarsigner v1 es suficiente para
      # Google Play App Signing (Google re-firma al distribuir).
      - name: Firmar AAB con jarsigner
        env:
          KEYSTORE_ALIAS: ${{ secrets.ANDROID_KEYSTORE_ALIAS }}
          KEYSTORE_PASS: ${{ secrets.ANDROID_KEYSTORE_PASS }}
        run: |
          jarsigner \
            -verbose \
            -sigalg SHA256withRSA \
            -digestalg SHA-256 \
            -keystore /tmp/game.keystore \
            -storepass "$KEYSTORE_PASS" \
            -keypass "$KEYSTORE_PASS" \
            builds/game.aab \
            "$KEYSTORE_ALIAS"
          jarsigner -verify builds/game.aab
          echo "✓ AAB firmado"

      - name: Guardar AAB como artefacto
        uses: actions/upload-artifact@v4
        with:
          name: aab-${{ steps.ctx.outputs.track }}-${{ github.run_number }}
          path: builds/game.aab
          retention-days: 30

      - name: Subir a Google Play — ${{ steps.ctx.outputs.track }}
        if: ${{ github.event_name != 'workflow_dispatch' || inputs.skip_upload == false }}
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_JSON }}
          packageName: ${{ env.PACKAGE_NAME }}
          releaseFiles: builds/game.aab
          track: ${{ steps.ctx.outputs.track }}
          status: completed
```

---

## Generar el keystore de release (una sola vez, para TODA la vida del juego)

**Nunca regenerar ni perder este archivo** una vez publicada la primera versión — Play
Store rechaza cualquier actualización firmada con un keystore distinto al de la subida
original. Guardarlo en un password manager, nunca commitearlo al repo.

```bash
keytool -genkeypair -v \
  -keystore release.keystore \
  -alias <alias-del-juego> \
  -keyalg RSA -keysize 2048 -validity 10000
```

Pide interactivamente: contraseña del keystore (2 veces — es `ANDROID_KEYSTORE_PASS`),
datos de organización (cualquier valor sirve, Google no los valida), y si la contraseña
de la key debe ser igual a la del keystore (responder que sí, simplifica a un solo
secret). Luego, para pegarlo como secret:

```bash
base64 -i release.keystore | pbcopy   # Mac -- lo copia directo al portapapeles
```

## GitHub Secrets requeridos

| Secret | Cómo obtenerlo |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i release.keystore \| pbcopy` (ver arriba) |
| `ANDROID_KEYSTORE_ALIAS` | El alias que se usó al crear el keystore con `keytool` |
| `ANDROID_KEYSTORE_PASS` | La contraseña del keystore (y del key, si son iguales) |
| `GOOGLE_PLAY_JSON` | JSON completo (no base64) de una cuenta de servicio de Google Cloud con acceso a Play Console — ver subsección siguiente |

### Cuenta de servicio de Google Play (para `GOOGLE_PLAY_JSON`)

1. Play Console → la app → **Configuración → Acceso a la API** → vincula/crea un
   proyecto de Google Cloud.
2. Google Cloud Console (ese proyecto) → **IAM y administración → Cuentas de
   servicio** → crear una cuenta nueva.
3. Esa cuenta → pestaña **Claves** → **Agregar clave → Crear clave nueva → JSON** →
   se descarga el archivo.
4. Play Console → **Usuarios y permisos** → invitar el email de la cuenta de servicio
   (termina en `.gserviceaccount.com`) → permiso de **Gestor de versiones** sobre la app.
5. El contenido completo del `.json` descargado es el secret `GOOGLE_PLAY_JSON` (texto
   plano, no lo codifiques en base64 — la action `r0adkll/upload-google-play` espera
   el JSON crudo).

### Primera subida — siempre manual

La API de Google Play rechaza la primera subida con un error genérico si la app nunca
tuvo ninguna versión. Correr el workflow una vez (`workflow_dispatch`), descargar el AAB
del artefacto de CI, y subirlo a mano desde Play Console → Producción/Pruebas internas
→ Crear nueva versión. Después de esa primera vez, el CI sube automáticamente.

---

## export_presets.cfg — requisitos mínimos

```ini
[preset.0]
name="Android"           # debe coincidir con EXPORT_PRESET en el workflow

[preset.0.options]
package/unique_name="com.tuempresa.tujuego"
gradle_build/use_gradle_build=false   # el CI lo activa via sed
version/code=1                        # el CI lo sobreescribe con sed
version/name="1.0"                    # lo que ve el usuario en Play Store
```

---

## Errores conocidos y sus soluciones exactas

### `Trying to build from a gradle built template, but no version info for it exists`
**Causa:** `.build_version` ausente o con contenido incorrecto.
**Solución:** Usar `--install-android-build-template`. Nunca escribir `.build_version` manualmente.

### `Android build template not installed in the project` en un workflow de build de PRUEBA (`--export-debug`)
**Causa:** `gradle_build/use_gradle_build=true` en `export_presets.cfg` (necesario para el pipeline de AAB) hace que Godot pase por Gradle en **cualquier** export de Android, no solo el release. Si tienes un workflow separado para builds de debug/staging (ej. "subir APK de prueba a Dropbox en cada push"), y solo copiaste el paso simple `godot --export-debug`, sin `--install-android-build-template` ni Java 17, falla con este error.
**Solución:** Ese workflow necesita los mismos tres pasos que `deploy-playstore.yml`: `actions/setup-java@v4` (Java 17), `--install-android-build-template` en el comando de export, y opcionalmente el pre-heat (`godot --headless --editor --quit || true`).

### `Android APK requires the *.apk extension`
**Causa:** Godot 4.7 no exporta directo a `.aab`.
**Solución:** Exportar a `.apk`. El AAB se produce con `./gradlew bundleRelease`.

### `All uploaded bundles must be signed. Please sign using jarsigner`
**Causa:** `bundleRelease` puede ignorar `-Pperform_signing=true` según la configuración del template. El AAB sale sin firma de release.
**Solución:** Agregar paso explícito de `jarsigner` después de `bundleRelease`. El mensaje de error de Play Store literalmente dice qué herramienta usar. Ver el template de workflow arriba.

### `Version code X has already been used`
**Causa:** El version code del AAB siempre es `1` porque `config.gradle` usa ese default si no se le pasa `-Pexport_version_code`. El `sed` sobre `export_presets.cfg` le llega a Godot (para el APK) pero NO a Gradle (para el AAB).
**Solución:** Pasar `-Pexport_version_code=${{ steps.ctx.outputs.version_code }}` a `bundleRelease`. **Ambos** el `sed` y el `-P` son necesarios.

### `APK has the wrong package name` / `com.godot.game.fileprovider`
**Causa:** `config.gradle` usa `com.godot.game` como default.
**Solución:** Pasar `-Pexport_package_name=com.tuempresa.tujuego` a `bundleRelease`.

### `assetPackInstrumentedReleasePreBundleTask FAILED`
**Causa:** Falta el directorio `assetPackInstallTime/src/main/assets`.
**Solución:** `mkdir -p android/build/assetPackInstallTime/src/main/assets` antes de Gradle.

### Primera subida falla con error genérico de la API
**Causa:** La API de Google Play rechaza la primera subida si no existe ninguna versión previa.
**Solución:** Descargar el AAB del artefacto de CI y subirlo **manualmente** una vez desde Play Console. Después, el CI funciona automáticamente.

---

## Advertencias de Play Store (ignorables)

Play Store muestra estas advertencias para **todos** los juegos hechos con Godot. No bloquean la publicación:

| Advertencia | Por qué aparece | Acción |
|---|---|---|
| "No hay archivo de desofuscación (R8/Proguard)" | R8/ProGuard es para código Java/Kotlin. Godot usa GDScript/C++, no pasa por ese proceso. | Ignorar permanentemente |
| "Código nativo sin símbolos de depuración" | Godot exporta librerías `.so` del motor en C++. Los símbolos requieren compilar Godot desde fuente. | Ignorar salvo crashes frecuentes en el motor |

---

## Propiedades de config.gradle (Godot 4.7) — referencia completa

| Propiedad | Default | Descripción |
|---|---|---|
| `export_package_name` | `com.godot.game` | applicationId del APK/AAB |
| `export_version_code` | `1` | versionCode — **siempre pasar explícitamente** |
| `export_version_name` | `1.0` | versionName (visible al usuario) |
| `perform_signing` | `false` | Intenta activar signingConfig — no siempre funciona, usar jarsigner además |
| `release_keystore_file` | `.` | Ruta absoluta al .keystore |
| `release_keystore_password` | `""` | Store password |
| `release_keystore_alias` | `""` | Key alias |

---

## Variantes de build en Godot 4.7

`bundleRelease` genera tres variantes. Usar siempre `standardRelease`:
- `standardRelease` — producción normal ✓
- `monoRelease` — con .NET/C#
- `instrumentedRelease` — para tests de instrumentación

El AAB queda en: `android/build/app/build/outputs/bundle/standardRelease/*.aab`

---

## Notas de Play Console

- **Track interno:** push a `main` → Internal Testing (sin revisión de Google).
- **Producción:** tag `v*.*.*` → Production (pasa por revisión de Google).
- El campo que ve el usuario en la tienda es `version/name` (ej. "1.0"), no `version/code`.

---

## Distribución de builds de prueba vía Dropbox (opcional, sin Play Console)

Segundo pipeline independiente del de Play Store — sirve para mandarle un APK debug a
un tester en minutos, sin pasar por revisión ni tracks de Play Console. Mismo cuidado
que la nota de "Android build template not installed" de la sección de errores: aunque
sea un `--export-debug`, si `export_presets.cfg` ya tiene
`gradle_build/use_gradle_build=true` (necesario para el pipeline de AAB), este workflow
necesita los MISMOS pasos de Java 17 + `--install-android-build-template` que el de
release — nunca una versión "simplificada".

### App de Dropbox + refresh token (una sola vez)

Dropbox ya no entrega tokens permanentes desde la consola web (expiran en ~4h) — hace
falta un intercambio OAuth2 manual, una sola vez, para obtener un refresh token que no
expira:

1. [Dropbox App Console](https://www.dropbox.com/developers/apps) → **Create app** →
   **Scoped access** → **App folder** (aísla el acceso a una sola carpeta, no todo el
   Dropbox de la cuenta) → nombre cualquiera → **Create app**.
2. Pestaña **Permissions** → activar `files.content.write`, `files.content.read` y
   `sharing.write` → **Submit**.
3. Pestaña **Settings** → copiar **App key** y **App secret**.
4. Abrir en el navegador (reemplazando `<APP_KEY>`), aprobar el acceso, copiar el
   código que muestra en pantalla (dura pocos minutos, usarlo enseguida):
   ```
   https://www.dropbox.com/oauth2/authorize?client_id=<APP_KEY>&token_access_type=offline&response_type=code
   ```
5. Canjear el código por los tokens:
   ```bash
   curl https://api.dropbox.com/oauth2/token \
     -d code=<CÓDIGO_DEL_PASO_4> \
     -d grant_type=authorization_code \
     -d client_id=<APP_KEY> \
     -d client_secret=<APP_SECRET>
   ```
6. El campo `"refresh_token"` de la respuesta (NO el `access_token`, ese es de corta
   duración y no se guarda) es el secret `DROPBOX_REFRESH_TOKEN` — no expira solo, dura
   hasta que se revoque manualmente desde el App Console.

### GitHub Secrets (Dropbox)

| Secret | Cómo obtenerlo |
|---|---|
| `DROPBOX_APP_KEY` | Paso 3 de arriba |
| `DROPBOX_APP_SECRET` | Paso 3 de arriba |
| `DROPBOX_REFRESH_TOKEN` | Paso 6 de arriba |

### Arquitectura del workflow

```
Checkout → Java 17 → Godot + templates → Pre-heat
→ Export APK debug (--install-android-build-template, igual que release)
→ Canjear refresh_token por un access_token de corta duración (API de Dropbox)
→ Subir el APK (Dropbox Content API, POST /2/files/upload)
→ Crear link compartido (POST /2/sharing/create_shared_link_with_settings)
→ Publicar el link en el resumen del run de GitHub Actions ($GITHUB_STEP_SUMMARY)
```

El access token se pide DENTRO del job (nunca se guarda como secret) porque dura solo
~4 horas — el refresh token es el único secret de larga duración. El nombre de archivo
en Dropbox incluye fecha + número de run (`autorename: true` además como red de
seguridad) para que cada subida tenga su propio link sin colisionar con la anterior.

Ver `.github/workflows/test-build-dropbox.yml` de Taco Defender como implementación de
referencia completa.
