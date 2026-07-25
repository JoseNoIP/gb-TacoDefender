# Despliegue — Taco Defender

Runbook operativo para publicar builds de este juego. Referencia rápida para no tener
que re-derivar los pasos en cada sesión. Para errores conocidos y el detalle de por qué
cada paso del workflow existe, ver el skill `/android-deploy`
(`.claude/skills/android-deploy/SKILL.md`) — este documento es el checklist de "qué
llenar y en qué orden", no el troubleshooting.

Dos pipelines, dos propósitos distintos:

| Pipeline | Workflow | Qué produce | Cuándo correr |
|---|---|---|---|
| **Google Play** | `.github/workflows/deploy-playstore.yml` | AAB firmado de release | push a `main` (Internal Testing) / tag `v*.*.*` (Production) |
| **Dropbox** | `.github/workflows/test-build-dropbox.yml` | APK debug + link compartido | manual (`workflow_dispatch`) — para mandarle un build a un tester sin pasar por Play Console |

Variables de este juego ya fijadas en los workflows (no hace falta tocarlas):

| Variable | Valor |
|---|---|
| `PACKAGE_NAME` | `com.guacamolebit.tacodefender` |
| `GAME_NAME` | `TacoDefender` |
| `GODOT_VERSION` | `4.7` |
| `EXPORT_PRESET` | `Android` (debe coincidir con `export_presets.cfg`) |

Todo lo que sigue son cosas que **vos** tenés que crear/generar (cuentas, keystore,
tokens) y pegar como GitHub Secret. Yo no tengo acceso a Play Console/Dropbox/tu keychain,
así que estos pasos son 100% manuales de tu lado.

---

## 1. Keystore de Android (una sola vez, para TODA la vida del juego)

**Importante:** si ya publicaste una versión con un keystore, jamás lo cambies ni lo
pierdas — Play Store rechaza actualizaciones firmadas con un keystore distinto al de la
primera subida. Guardalo en un password manager, no solo en tu máquina.

```bash
keytool -genkeypair -v \
  -keystore release.keystore \
  -alias taco-defender-release \
  -keyalg RSA -keysize 2048 -validity 10000
```

Te va a pedir (interactivo):
- **Contraseña del keystore** (2 veces) — esta es `ANDROID_KEYSTORE_PASS`.
- Nombre, organización, ciudad, etc. — cualquier valor sirve, no lo valida Google.
- Al final pregunta "¿la contraseña de la key es la misma que la del keystore?" —
  respondé que sí (simplifica: un solo secret cubre ambas).

Convertilo a base64 para pegarlo como secret (en Mac, esto lo copia directo al portapapeles):

```bash
base64 -i release.keystore | pbcopy
```

Guardá el archivo `release.keystore` en un lugar seguro fuera del repo (nunca lo
commitees) — lo vas a necesitar si algún día necesitás regenerar el secret.

---

## 2. GitHub Secrets a crear

Repo → **Settings → Secrets and variables → Actions → New repository secret**.

### Para `deploy-playstore.yml` (Google Play)

| Secret | Valor | De dónde sale |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | el output de `base64 -i release.keystore` | Paso 1 de arriba |
| `ANDROID_KEYSTORE_ALIAS` | `taco-defender-release` (o el alias que hayas elegido) | El `-alias` que usaste en `keytool` |
| `ANDROID_KEYSTORE_PASS` | la contraseña que elegiste | Paso 1 de arriba |
| `GOOGLE_PLAY_JSON` | el archivo JSON completo (pegar todo el contenido, no base64) | Sección 3 de abajo — cuenta de servicio de Google Cloud |

### Para `test-build-dropbox.yml` (Dropbox)

| Secret | Valor | De dónde sale |
|---|---|---|
| `DROPBOX_APP_KEY` | "App key" de tu app de Dropbox | Sección 4 de abajo |
| `DROPBOX_APP_SECRET` | "App secret" de tu app de Dropbox | Sección 4 de abajo |
| `DROPBOX_REFRESH_TOKEN` | token de larga duración (no expira) | Sección 4 de abajo — flujo OAuth2 de una sola vez |

---

## 3. Google Play Console — cuenta de servicio (una sola vez por cuenta de desarrollador)

1. [Play Console](https://play.google.com/console) → crear la app (si no existe) con
   el package name `com.guacamolebit.tacodefender` — **el nombre del paquete no se
   puede cambiar después**, tiene que coincidir exacto con `PACKAGE_NAME`.
2. Play Console → **Configuración → Acceso a la API** → esto te guía a vincular o crear
   un proyecto de Google Cloud.
3. En [Google Cloud Console](https://console.cloud.google.com/) (el proyecto vinculado
   en el paso anterior) → **IAM y administración → Cuentas de servicio** → crear una
   cuenta de servicio nueva (cualquier nombre, ej. "play-store-ci").
4. Sobre esa cuenta de servicio → pestaña **Claves** → **Agregar clave → Crear clave
   nueva → JSON** → se descarga un archivo `.json`.
5. Volvé a Play Console → **Usuarios y permisos** → **Invitar usuarios** → pegá el
   email de la cuenta de servicio (termina en `.gserviceaccount.com`) → dale permiso de
   **Gestor de versiones** (release manager) sobre esta app como mínimo.
6. El contenido completo de ese archivo `.json` es el secret `GOOGLE_PLAY_JSON`
   (pegalo tal cual, es texto plano JSON — no lo codifiques en base64, la action
   `r0adkll/upload-google-play` espera el JSON crudo).

### Primera subida — SIEMPRE manual

La API de Google Play rechaza la primera subida a una app con error genérico si nunca
existió una versión. Antes de confiar en el CI:

1. Corré el workflow una vez con `workflow_dispatch` y `skip_upload: true` (o esperá a
   que falle el paso de subida, no importa — el AAB ya quedó como artefacto).
2. Descargá el AAB del artefacto (`Actions` → el run → `Artifacts`).
3. Play Console → tu app → **Producción** (o **Pruebas internas**) → **Crear nueva
   versión** → subilo a mano ahí, una sola vez.
4. De ahí en adelante, el CI puede subir automáticamente.

---

## 4. Dropbox — app + refresh token (una sola vez)

Dropbox ya no entrega tokens permanentes desde la consola (expiran en ~4h) — hay que
generar un **refresh token** una sola vez con un intercambio OAuth2 manual.

1. [Dropbox App Console](https://www.dropbox.com/developers/apps) → **Create app**.
2. Elegí **Scoped access** → **App folder** (así la app solo puede tocar su propia
   carpeta dentro de tu Dropbox, no todo tu Dropbox) → ponele un nombre (ej.
   "taco-defender-ci") → **Create app**.
3. Pestaña **Permissions** → activá `files.content.write`, `files.content.read` y
   `sharing.write` → **Submit** (abajo de la página).
4. Pestaña **Settings** → anotá **App key** y **App secret** (`DROPBOX_APP_KEY` /
   `DROPBOX_APP_SECRET`).
5. Pegá esta URL en el navegador (reemplazando `<APP_KEY>`) y aprobá el acceso:
   ```
   https://www.dropbox.com/oauth2/authorize?client_id=<APP_KEY>&token_access_type=offline&response_type=code
   ```
   Te va a mostrar un **código** en pantalla — copialo (dura pocos minutos, usalo ya).
6. Canjeá ese código por el refresh token (correr esto en tu terminal, reemplazando los
   3 valores):
   ```bash
   curl https://api.dropbox.com/oauth2/token \
     -d code=<CÓDIGO_DEL_PASO_5> \
     -d grant_type=authorization_code \
     -d client_id=<APP_KEY> \
     -d client_secret=<APP_SECRET>
   ```
7. La respuesta JSON trae un campo `"refresh_token"` — ese valor (no el `access_token`,
   ese es de corta duración y no se guarda) es `DROPBOX_REFRESH_TOKEN`. Este token NO
   expira solo, dura hasta que lo revoques manualmente desde el App Console.

---

## 5. Checklist para correr por primera vez

- [ ] Keystore generado y guardado a buen recaudo (sección 1)
- [ ] Los 4 secrets de Google Play creados (sección 2)
- [ ] App creada en Play Console con el package name correcto
- [ ] Cuenta de servicio de Google Cloud creada + invitada en Play Console con permiso
      de Gestor de versiones
- [ ] Primera subida manual del AAB ya hecha (sección 3)
- [ ] Los 3 secrets de Dropbox creados (sección 4)
- [ ] Corriste `test-build-dropbox.yml` manualmente una vez y el link de Dropbox
      funciona

Una vez marcado todo esto, `git push` a `main` dispara Play Store (Internal Testing) y
`workflow_dispatch` en el otro workflow manda un build de prueba a Dropbox cuando lo
necesites.

---

## 6. Notas de la versión (release notes) para Play Store

Cada vez que se pide "las notas de la versión", entregarlas en ESTE formato exacto — un
bloque por idioma, delimitado por el código de locale entre `<` `>` como tag de apertura
y cierre. Este formato es para pegar manualmente en el campo de "Notas de la versión" de
cada idioma en Play Console al crear una versión — no es un formato que lea ningún
script todavía (ver nota de automatización al final).

```
<en-US>
Texto en inglés acá.
</en-US>

<es-419>
Texto en español (Latinoamérica) acá.
</es-419>

<pt-BR>
Texto en portugués (Brasil) acá.
</pt-BR>

<fr-FR>
Texto en francés acá.
</fr-FR>
```

### Mapeo idioma del juego -> código de locale de Play Console

| `Constants.SUPPORTED_LOCALES` (in-game) | Código Play Console |
|---|---|
| `es` (default) | `es-419` (español latinoamericano — NO `es-ES`, el juego no usa vocabulario/gramática de España) |
| `en` | `en-US` |
| `pt_BR` | `pt-BR` |
| `fr` | `fr-FR` |

### Redactar las notas

- Tono para el jugador final, NO changelog técnico — nada de nombres de archivo, nombres
  de función, ni jerga de implementación (eso vive en `idea-base.md`/commits, no en la
  tienda).
- 3-6 líneas, una idea por línea. Priorizar lo que el jugador va a notar jugando, no
  cambios internos sin impacto visible.
- Mismo idioma/tono que la traducción in-game de cada locale (revisar
  `assets/translations/translations.txt` de esa versión si hay dudas de vocabulario).

### Automatización futura (no implementada todavía)

La action `r0adkll/upload-google-play` (ya usada en `deploy-playstore.yml`) soporta un
input `whatsNewDirectory` que apunta a una carpeta con un archivo de texto plano por
locale (`whatsnew/en-US`, `whatsnew/es-419`, etc. — sin las etiquetas `<...>`, contenido
crudo). Si en algún momento se quiere que el CI suba las notas automáticamente en vez de
pegarlas a mano en Play Console, ese es el mecanismo — pero requeriría un paso extra en
el workflow que parsee este formato de bloques y genere esos archivos, o mantenerlos
directamente en ese formato de carpeta desde el vamos. Fuera de alcance hasta que se
pida explícitamente.
