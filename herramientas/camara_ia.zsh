# ===== Cámara con IA de Apple (superres) =====
_par() { local v; v=$(printf '%.0f' $1); echo $(( v - v % 2 )); }
_vertical_ia() {
  local f=$1 C=~/Desktop/Clips; local base=$(basename "$f" .mp4); local n=${base%_*}
  local cfg=$C/.cam_$n; [ -f "$cfg" ] || return 1
  local g; g=$(_layout "$n") || return 1
  local BOT=${${g#*\[top\];\[b\]}%%\[bot\]*}
  [ -n "$BOT" ] || return 1
  local r=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$f" | head -1)
  local W=${r%x*} H=${r#*x} R=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$f" | head -1)
  [[ $R == <->/<-> ]] || R=60
  [[ $W == <-> && $H == <-> ]] || return 1
  local c a b d e A=1.40625 rx ry rw rh cw ch cx cy; read c a b d e < $cfg
  if [ "$c" = manual ]; then
    rx=$(( W*a/100.0 )); ry=$(( H*b/100.0 )); rw=$(( W*d/100.0 )); rh=$(( H*e/100.0 ))
    if (( rw/rh > A )); then ch=$rh; cw=$(( rh*A )); else cw=$rw; ch=$(( rw/A )); fi
    cx=$(( rx + (rw-cw)/2 )); cy=$(( ry + (rh-ch)/2 ))
  else
    cw=$(( W*a/100.0 )); ch=$(( cw/A )); cx=0; cy=0
    [[ $c == *der ]] && cx=$(( W-cw )); [[ $c == abajo* ]] && cy=$(( H-ch ))
  fi
  cw=$(_par $cw); ch=$(_par $ch); cx=$(_par $cx); cy=$(_par $cy)
  (( cx < 0 )) && cx=0; (( cy < 0 )) && cy=0
  (( cx + cw > W )) && cx=$(( W - cw )); (( cy + ch > H )) && cy=$(( H - ch ))
  (( cw >= 64 && ch >= 64 )) || return 1
  local sf; sf=$(~/clipstools/superres --check $cw $ch) || return 1
  local out="${f%.mp4}_vertical.mp4"
  echo "Poniendo en vertical con IA en la cámara: $base ($n)... (la IA tarda unos minutos)"
  ffmpeg -nostdin -loglevel error -i "$f" -an -vf "crop=$cw:$ch:$cx:$cy,fps=30,scale=in_color_matrix=bt709:in_range=tv:out_range=pc,format=bgra" -f rawvideo - \
    | ~/clipstools/superres $cw $ch $sf \
    | ffmpeg -nostdin -loglevel error -y -i "$f" -f rawvideo -pix_fmt bgra -s $((cw*sf))x$((ch*sf)) -framerate 30 -i - \
        -filter_complex "[1:v]scale=1080:768:flags=lanczos:in_range=pc:out_color_matrix=bt709:out_range=tv,format=yuv420p,fps=$R,setsar=1[top];[0:v]${BOT}[bot];[top][bot]vstack=shortest=1,format=yuv420p[v]" \
        -map "[v]" -map "0:a?" -c:v h264_videotoolbox -b:v 20M -maxrate 25M -bufsize 50M -c:a copy "$out"
  local st=("${pipestatus[@]}")
  if [[ ${st[*]} != "0 0 0" ]] || [ ! -s "$out" ]; then rm -f "$out"; return 1; fi
  echo "LISTO VERTICAL (cámara con IA)"
  open -R "$out" 2>/dev/null
  return 0
}
[ -z "$functions[_vertical_base]" ] && functions[_vertical_base]=$functions[vertical]
# vertical normal por defecto; con IA solo cuando lo pide la cola (editaria)
vertical() {
  local f="${1:-$(_ultimo)}"
  if [ -n "$_SERAF_IA" ] && [ -f "$f" ] && [ -x ~/clipstools/superres ] && [ ! -f ~/Desktop/Clips/.sinia ]; then
    _vertical_ia "$f" && return 0
    echo "(La IA no pudo con este clip, uso el método normal)"
  fi
  _vertical_base "$@"
}
compararia() {
  local f="$1"
  [ -f "$f" ] && [[ $f != *_vertical* ]] || { echo "Escribe 'compararia ' (con espacio), arrastra un clip SIN _vertical y pulsa Enter."; return 1; }
  local t=~/Desktop/Clips/.comparar b=$(basename "$f"); rm -rf $t; mkdir -p $t; cp "$f" $t/$b
  echo "1/2 Haciendo la versión normal..."
  _vertical_base $t/$b >/dev/null 2>&1
  mv $t/${b%.mp4}_vertical.mp4 $t/normal.mp4 2>/dev/null || { echo "No pude hacer la versión normal."; return 1; }
  echo "2/2 Haciendo la versión con IA (tarda un poco)..."
  _vertical_ia $t/$b >/dev/null || { echo "La IA no funcionó con este clip. Mándame foto."; return 1; }
  mv $t/${b%.mp4}_vertical.mp4 $t/ia.mp4
  local out=~/Desktop/Clips/comparacion_camara.mp4
  ffmpeg -nostdin -loglevel error -y -i $t/normal.mp4 -i $t/ia.mp4 -filter_complex "[0:v]crop=1080:768:0:0[a];[1:v]crop=1080:768:0:0[b];[a][b]hstack[v]" \
    -map "[v]" -map "0:a?" -c:v h264_videotoolbox -b:v 30M -c:a copy "$out" && rm -rf $t \
    && echo "Listo: comparacion_camara.mp4 · IZQUIERDA normal · DERECHA con IA" && open "$out"
}
# ===== Cola de la IA: editar encuadra y la IA trabaja en segundo plano =====
_aviso() {
  osascript -e "display notification \"$2\" with title \"$1\"" >/dev/null 2>&1
  afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &!
}
_colaarrancar() {
  local L=~/Desktop/Clips/.cola/.lock p
  p=$(cat $L/pid 2>/dev/null)
  [ -n "$p" ] && kill -0 $p 2>/dev/null && return 0
  mkdir -p ~/Desktop/Clips/logs
  nohup caffeinate -i zsh -lic '_colaia' >> ~/Desktop/Clips/logs/cola.log 2>&1 &!
}
_encolar() {
  zmodload zsh/datetime
  local Q=~/Desktop/Clips/.cola; mkdir -p $Q
  printf '%s\n%s\n' "$1" "$2" > $Q/${EPOCHREALTIME/./}.job
  local -a a; a=($Q/*.job(N) $Q/*.haciendo(N))
  echo "En cola con IA ✅ (${#a} en la cola). Te aviso cuando esté listo: sigue con el siguiente clip."
  _colaarrancar
}
_colaia() {
  local Q=~/Desktop/Clips/.cola L=~/Desktop/Clips/.cola/.lock j f s out x p
  local _SERAF_IA=1
  while true; do
    if ! mkdir $L 2>/dev/null; then
      p=$(cat $L/pid 2>/dev/null)
      [ -n "$p" ] && [ "$p" != $$ ] && kill -0 $p 2>/dev/null && return 0
      rm -rf $L; mkdir $L 2>/dev/null || return 0
    fi
    echo $$ > $L/pid
    for x in $Q/*.haciendo(N); do mv "$x" "${x%.haciendo}"; done
    while true; do
      local -a js; js=($Q/*.job(N)); j=$js[1]
      [ -z "$j" ] && break
      mv "$j" "$j.haciendo"
      f=$(sed -n 1p "$j.haciendo"); s=$(sed -n 2p "$j.haciendo")
      echo "$(date '+%H:%M') Haciendo ${f:t}"
      if [ -f "$f" ]; then
        out="${f%.mp4}_vertical.mp4"
        vertical "$f" < /dev/null
        if [ -s "$out" ]; then
          rm -f "$f"
          [ "$s" = sub ] && subtitular "$out" < /dev/null
          local env=""; (( $+functions[_aequipo] )) && env=$(_aequipo "$out") && [ -n "$env" ] && echo "$env"
          _aviso "Clip listo con IA ✅" "${out:t}${env:+ · enviado a Para editar}"
        else
          _aviso "No pude hacer el vertical" "${f:t}"
        fi
      fi
      rm -f "$j.haciendo"
      echo "$(date '+%H:%M') Terminado ${f:t}"
    done
    rm -rf $L
    js=($Q/*.job(N)); (( $#js )) || return 0
  done
}
cola() {
  local Q=~/Desktop/Clips/.cola x f; local -a a b
  a=($Q/*.haciendo(N)); b=($Q/*.job(N))
  (( $#a + $#b )) || { echo "No hay clips en la cola."; return 0; }
  for x in $a; do f=$(sed -n 1p $x); echo "▶ Haciendo ahora: ${f:t}"; done
  for x in $b; do f=$(sed -n 1p $x); echo "⏳ Esperando:     ${f:t}"; done
}
# editar = como siempre (rápido, sin IA) · editaria = cámara con IA, en la cola
editaria() {
  local f="$1"
  [ -f "$f" ] || { echo "Escribe 'editaria ' (con espacio), arrastra el clip y pulsa Enter. Agrega 'sub' al final si lo quieres con subtítulos."; return 1; }
  [[ ${f:t} == *_vertical* ]] && { echo "Este clip ya está en vertical."; return 1; }
  [ -x ~/clipstools/superres ] || { echo "La IA no está instalada, lo hago normal."; editar "$@"; return; }
  local base=$(basename "$f" .mp4); local n=${base%_*}
  echo "$n" > ~/Desktop/Clips/.nombre
  echo "Streamer: $n"
  encuadrar "$f" || return 1
  _encolar "$f" "$2"
}
