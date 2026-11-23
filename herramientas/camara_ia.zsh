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
  echo "Poniendo en vertical con IA en la cámara: $base ($n)... (tarda 1-3 minutos)"
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
vertical() {
  local f="${1:-$(_ultimo)}"
  if [ -f "$f" ] && [ -x ~/clipstools/superres ] && [ ! -f ~/Desktop/Clips/.sinia ]; then
    _vertical_ia "$f" && return 0
    echo "(La IA no pudo con este clip, uso el método normal)"
  fi
  _vertical_base "$@"
}
