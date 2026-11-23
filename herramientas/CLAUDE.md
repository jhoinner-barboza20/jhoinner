# Seraf Clips · Guía para Claude en el Mac de Jhoiy

Lee esto antes de hacer nada. Resume todo lo que se construyó con Jhoiy hasta el 23 de noviembre de 2026.
Este archivo es global (`~/.claude/CLAUDE.md`): vale para cualquier tarea en el Mac, no solo para los clips.
Si algo de aquí choca con lo que ves en el Mac, manda lo que ves en el Mac y actualiza este archivo.

## Con quién trabajas
- **Jhoiy** dirige **Seraf Clips**, una agencia de clips para streamers de GTA 6 ("tu equipo detrás del stream").
  Vive en Colombia; vende sobre todo a España, Latinoamérica y EE. UU.
- No es programador. Háblale **en español**, en frases cortas, **paso a paso y numerado**, sin jerga.
  Dile exactamente qué pegar, dónde y qué debe ver después. Si hace falta, pide **foto o captura**.
- Equipo: Jhoiy + **2 amigos que editan en CapCut desde el móvil**.
- Mac: MacBook Pro M1 Pro, 32 GB, **macOS 26**. Navegador: **Brave**. Shell: zsh.
- Prioridades de Jhoiy: **calidad máxima**, **pocos pasos**, no llenar el disco, y que todo quede ordenado.

## Reglas para ti
1. **Antes de borrar o sobrescribir algo, pregunta.** Nunca borres clips de `listos/`, de Drive ni grabaciones sin permiso.
2. **No toques una grabación en curso**: `~/Desktop/Clips/<streamer>_grabacion.*` mientras el proceso de grabación siga vivo.
3. **Prueba antes de entregar.** Si cambias una herramienta, compílala o ejecútala tú y comprueba el resultado.
4. **Nada de enviar mensajes ni publicar** a clientes o redes sin que Jhoiy lo pida.
5. Puedes trabajar en cualquier carpeta del Mac. Para proyectos nuevos (apps, webs), crea su propia carpeta en `~/Proyectos/`.
6. Las funciones de zsh nuevas o cambiadas van en archivos de `~/clipstools/*.zsh`, que se cargan desde `~/.zshrc`.
   No pegues bloques sueltos al final de `.zshrc`: ya tiene muchas versiones antiguas, y **la última definición gana**.
7. Las tareas pesadas (IA, descargas largas) van **en segundo plano**, para que Jhoiy pueda seguir trabajando.
8. Cuando termines un cambio importante, **añade una línea al Historial** del final de este archivo.
9. Herramientas interactivas: `editar`, `editaria` y `encuadrar` abren ventanas o piden datos. Ábrelas para que Jhoiy
   dibuje o confirme, y espera. Para procesar sin preguntar usa las funciones internas que se explican abajo.

## Mapa de carpetas
| Dónde | Qué hay |
|---|---|
| `~/Desktop/Clips/` | Carpeta principal de trabajo de los clips. |
| `~/Desktop/Clips/listos/<STREAMER>/` | Clips cortados (`<streamer>_HHMMSS.mp4`) y verticales (`..._vertical.mp4`). Carpeta en MAYÚSCULAS. |
| `~/Desktop/Clips/<streamer>_grabacion.*` | Grabaciones en vivo en curso. |
| `~/Desktop/Clips/.cam_<streamer>` | Encuadre de la cámara: `manual IZQ ARRIBA ANCHO ALTO` (en %) o `abajo-izq 28`. |
| `~/Desktop/Clips/.juego_<streamer>` | Zona del juego `IZQ ARRIBA ANCHO ALTO` (%). Si no existe, se usa el centro. |
| `~/Desktop/Clips/.desfase_<streamer>` | Segundos de retraso del audio para ese streamer. |
| `~/Desktop/Clips/.link_<streamer>`, `.inicio_<streamer>`, `.nombre`, `.marca`, `.vodmarca` | Estado de grabaciones y marcas. |
| `~/Desktop/Clips/clientes.txt` | Clientes: `NOMBRE<TAB>plan<TAB>inicio<TAB>fin<TAB>precio` (una línea por periodo; la última manda). |
| `~/Desktop/Clips/.vinculos` | `CLIENTE canal link-de-su-carpeta` (canal = nombre en Kick/Twitch/YouTube). |
| `~/Desktop/Clips/.cola/`, `logs/cola.log` | Cola de la IA de cámara. |
| `~/Desktop/Clips/candidatos/` | Informes de `buscaclips`. `vods/`: VODs completos. `acuerdos/`: PDFs del comando `acuerdo`. |
| `~/clipstools/` | Herramientas: Swift compiladas, scripts `.py`, archivos `.zsh`, modelo de whisper en `modelos/`. |
| Google Drive: `~/Library/CloudStorage/GoogleDrive-*/Mi unidad/Seraf Clips/` | `1. crudos/<STREAMER>`, `2. Editados/<STREAMER>`, `3. enviados`, `Clientes/<CLIENTE>/...`, `ACUERDOS/Acuerdo de <Nombre>/`. |
| Repo GitHub `jhoinner-barboza20/jhoinner`, rama `claude/stoic-bell-83qiq8` | Copia de las herramientas (`herramientas/`), logo (`canal/logo/`), imagen de planes (`canal/`). **Es público**: no subas datos de clientes. |

## Teclas (app Atajos / Shortcuts, con "Ejecutar script de shell")
| Tecla | Script | Qué hace |
|---|---|---|
| ⌃⌥G | `zsh -lic grabaraqui` | Graba el directo de la **pestaña activa de Brave** (Kick, Twitch o YouTube; TikTok no se puede). |
| ⌃⌥M | `zsh -lic marca` | Marca el inicio del clip (20 s antes). En un VOD marca el minuto del video. |
| ⌃⌥C | `zsh -lic clipaqui` | Corta el clip: desde la marca, o los últimos 90 s. En un VOD corta ese trozo del VOD. |
| ⌃⌥S | `zsh -lic pararaqui` | Deja de grabar esa pestaña (no borra los clips). |
- Indicadores: `~/clipstools/rec` (pastilla roja REC de la pestaña activa) y `~/clipstools/cronometro`, que **solo aparece mientras hay una marca**.
- Los VODs con teclas necesitan en Brave: Visualización → Opciones para desarrolladores → **Permitir JavaScript para eventos de Apple** (ya activado).

## Comandos de Terminal (funciones de zsh)
**Grabar y cortar**
- `grabar LINK` · `estado` · `terminar [nombre]` · `borrar [nombre]` (sin nombre = todas).
- `ya [segundos]` · `cortar HH:MM:SS HH:MM:SS` · `desfase N` (audio adelantado) · `ordenar` · `abrir [nombre]`.
- `clipvod LINK-o-ARCHIVO INICIO [FIN|SEGUNDOS]` · `bajarvod LINK` (VOD completo, ~3 GB por hora).
- `buscaclips LINK-o-ARCHIVO [N] [cortar]`: busca los mejores momentos de un VOD (volumen, chat y transcripción). Si Jhoiy
  te pide elegir, lee el `.txt` más reciente de `candidatos/` y propón minuto, por qué funciona y un título con gancho.

**Vertical (1080×1920: cámara arriba 1080×768, juego abajo 1080×1152)**
- `editar CLIP [sub]`: encuadra (ventana `~/clipstools/selector`), hace el vertical **sin IA** (rápido), borra el original
  y lo copia a `1. crudos/<STREAMER>`.
- `editaria CLIP [sub]`: igual, pero la cámara pasa por la **IA de escalado de Apple** (`~/clipstools/superres`) en una
  **cola en segundo plano** (~10 min por clip de 90 s). `cola` muestra el estado. Es lo que se usa para clientes.
- `vertical CLIP`: solo el vertical, sin IA. Para IA sin ventanas: `_encolar "CLIP" [sub]`.
- `encuadrar CLIP`: vuelve a dibujar cámara y juego. `compararia CLIP`: video normal vs IA lado a lado.
- Subtítulos: `sub` al final de editar o editaria, o `subs CLIP_vertical.mp4`. Amarillos, abajo, con whisper-cli
  (modelo `ggml-large-v3-turbo-q5_0.bin`) y `~/clipstools/subpng`. Deja `_sinsub.mp4` y `.srt` para CapCut.
  Tamaño y margen: `subestilo TAM MARGEN` (por defecto 56 380).

**Clientes y entregas**
- `nuevocliente NOMBRE prueba|basico|pro|elite AAAA-MM-DD`: crea su carpeta de días en Drive y lo apunta.
- `renovar NOMBRE [plan]` · `clientes` (avisa a quién toca renovar) · `vincular CLIENTE CANAL LINK`.
- `hoy`: resumen del día por cliente. `entregar CLIENTE [lunes|ayer]`: pasa sus clips de `2. Editados/<CANAL>` a la
  carpeta de su día (el día acaba a las 6:00), borra sus crudos de más de 3 días y copia el mensaje de WhatsApp.
  `mensaje CLIENTE` solo copia el mensaje.
- `acuerdo CLIENTE`: PDF del acuerdo de servicio con los datos de `clientes.txt` (usa `~/clipstools/htmlpdf`).
  También existe la app **Seraf Acuerdos** (en Aplicaciones), con formulario y vista previa; guarda en Drive `ACUERDOS/`.

## Flujo diario con un cliente
1. Al prender el streamer: abrir su canal en Brave → ⌃⌥G.
2. Momentos buenos: ⌃⌥M al empezar (opcional) → ⌃⌥C al acabar.
3. Los mejores (4 al día en Prueba y Básico, 6 en Pro y Élite) → `editaria CLIP` (+ `sub` en Pro y Élite) → llegan a `1. crudos`.
4. Los amigos editan en CapCut y dejan el resultado en `2. Editados/<CANAL>`, con título en el nombre del archivo.
5. `hoy` → `entregar CLIENTE` → pegar el mensaje en WhatsApp. En planes mensuales: programar en Metricool.

## Si Jhoiy arrastra clips al chat sin decir nada
Para cada clip: saca el streamer del nombre (todo antes del último `_`).
- Si **no** existe `.cam_<streamer>`: ejecuta `zsh -ic 'encuadrar "<clip>"'`, que abre la ventana para que Jhoiy dibuje, y espera.
- Luego, si es de un cliente o pide calidad, usa `zsh -ic '_encolar "<clip>"'` (IA en cola). Si tiene prisa, `zsh -ic 'vertical "<clip>"'`.
- Responde en una línea por clip.

## Detalles técnicos importantes
- Grabación: `yt-dlp --force-ipv4 -f "301/96/300/95/b/bv*+ba" --hls-use-mpegts --no-part` en segundo plano.
- Corte: ffmpeg con `h264_videotoolbox` a 25 Mbps. Vertical: 20 Mbps, escalado `lanczos`, audio copiado. Usa siempre `ffmpeg -nostdin`.
- El ffmpeg de Homebrew **no tiene libass**: los subtítulos se queman como PNG superpuestos.
- IA de cámara: `VTSuperResolutionScalerConfiguration` (macOS 26). La cámara se recorta, va a 30 fps por `superres`
  (fotogramas BGRA por tubería) y se escala ×4. La cola tiene bloqueo, `caffeinate` y avisos con sonido.
- Apps de Atajos **no pueden escribir en la carpeta de Google Drive**; la Terminal sí.
- zsh: usa `${var}` antes de `:` o `[`, pon entre comillas lo que lleve `?`, y usa `(N)` en los comodines que pueden no encontrar nada.
- `pkill -f` con patrones como `_grabacion` puede matar otras cosas: sé preciso.
- Para modificar una función sin reescribirla se usa `functions[nombre]=${functions[nombre]//viejo/nuevo}`. Para envolverla:
  `[ -z "$functions[_x_base]" ] && functions[_x_base]=$functions[x]`.
- Compilar Swift: `swiftc -O archivo.swift -o salida`. Con `@main`, añade `-parse-as-library`. Para APIs de macOS 26: `-target arm64-apple-macos26.0`.
- Python: usa `python3` del sistema (3.9+), sin librerías externas.

## Negocio
- Planes (USD): **Prueba $39** (7 días, 4 clips por día de directo, entrega en Drive; si sigue, se descuenta del primer mes) ·
  **Básico $129/mes** (4 al día, publicación automática) · **Pro $269/mes** (6 al día, clipeo en vivo, edición dinámica,
  reporte, WhatsApp) · **Élite $389/mes** (todo Pro + edición premium, portadas, 4 videos largos al mes, miniaturas,
  estrategia de YouTube, videollamada mensual, prioridad). Todos: "Alta resolución: tu cámara nítida, sin pixelar".
- Algunos clientes tienen precios antiguos: el precio real de cada uno está en `clientes.txt`.
- Cobro por adelantado: PayPal (Latinoamérica) o Wise (EUR/USD). Para publicar en las redes de clientes mensuales hace falta Metricool de pago.
- Marca: morado **#8003F5**, naranja **#FE5104**, blanco **#F4F4F4**. Lema: "Tú solo transmites. Nosotros hacemos el resto."
  Logo vectorial en el repo, en `canal/logo/` (SVG y PNG). Portafolio en TikTok: @seraf_clips.
- Mensajes a streamers: humanos, cortos, en tono de "bro", con un clip de muestra y **siempre una pregunta al final**.
- Ideas pendientes: plantillas de CapCut por cliente, pedir testimonio al terminar cada prueba, facturas de PayPal,
  y subir precios cuando haya varios clientes (el Pro y el Élite dan mucho trabajo para tres personas).
- Páginas de apoyo en claude.ai (privadas de Jhoiy): Manual de clientes https://claude.ai/artifact/LG6QucLN4XYPeJTkAAFymB

## Historial
- 2026-11-23: traspaso desde la sesión en la nube. Sistema completo de grabación y clips, IA de cámara en cola, buscador
  de clips en VODs, flujo crudos → Editados → entregar, clientes, acuerdos (comando y app), cronómetro solo al marcar.
