# ===== Equipo: clips a "1. crudos", tus amigos los dejan en "2. Editados", entregar al cliente =====
_scdrive() { local D=(~/Library/CloudStorage/GoogleDrive-*/"Mi unidad"/"Seraf Clips"(N/)); [ -n "$D[1]" ] && echo "$D[1]"; }
_carpetaseraf() {
  setopt localoptions extendedglob nullglob
  local D; D=$(_scdrive) || return 1
  local -a m; m=("$D"/(#i)*${1}*(/))
  [ -n "$m[1]" ] && echo "$m[1]"
}
# El "día de directo" termina a las 6 de la mañana: lo entregado de madrugada cuenta para el día anterior
_ahora() { zmodload zsh/datetime; echo $(( ${SERAF_AHORA:-$EPOCHSECONDS} - 21600 )); }
_fechadia() {  # vacío = hoy · ayer · lunes..domingo (el más reciente) -> epoch
  zmodload zsh/datetime; local a=${(L)1} t=$(_ahora) k u n
  a=${a//á/a}; a=${a//é/e}
  case $a in
    ""|hoy) echo $t; return 0;;
    ayer) echo $((t - 86400)); return 0;;
    lunes) n=1;; martes) n=2;; miercoles) n=3;; jueves) n=4;; viernes) n=5;; sabado) n=6;; domingo) n=7;;
    *) return 1;;
  esac
  for k in {0..6}; do strftime -s u '%u' $((t - k*86400)); [ "$u" = "$n" ] && { echo $((t - k*86400)); return 0; }; done
  return 1
}
vincular() {
  local c=${(U)1} k=${(L)${2#@}} l=$3 F=~/Desktop/Clips/.vinculos
  if [ -z "$c" ] || [ -z "$k" ]; then
    echo "Uso: vincular CLIENTE CANAL [LINK-DE-SU-CARPETA]   Ej: vincular joanse joanseee https://drive.google.com/..."; return 1
  fi
  mkdir -p ~/Desktop/Clips; touch $F
  grep -v "^$c " $F > $F.tmp; mv $F.tmp $F
  echo "$c $k ${l:--}" >> $F
  echo "✅ $c vinculado con el canal '$k'.${l:+ Link guardado para los mensajes.}"
}
_canalesde() {
  local F=~/Desktop/Clips/.vinculos c k l; local -a o; o=(${(L)1})
  if [ -f $F ]; then while read c k l; do [ "$c" = "${(U)1}" ] && o+=($k); done < $F; fi
  echo ${(u)o}
}
_clientede() {
  local s=${(L)1} F=~/Desktop/Clips/.vinculos c k l
  if [ -f $F ]; then while read c k l; do [ "$k" = "$s" ] && { echo $c; return 0; }; done < $F; fi
  grep -q "^${(U)s}"$'\t' ~/Desktop/Clips/clientes.txt 2>/dev/null && { echo ${(U)s}; return 0; }
  return 1
}
_clienteactivo() {
  zmodload zsh/datetime
  local last; last=$(grep "^$1"$'\t' ~/Desktop/Clips/clientes.txt 2>/dev/null | tail -1)
  [ -n "$last" ] || return 1
  local -a c; c=("${(@ps:\t:)last}"); local hoy=$(_scdia ${2:-$(_ahora)})
  ! [[ $c[3] > $hoy ]] && ! [[ $c[4] < $hoy ]]
}
# Cada vertical (editar o editaria) va a "1. crudos/STREAMER"
_aequipo() {
  local v=$1 b=${1:t:r}; b=${b%_vertical}; local s=${(U)${b%_*}} cr ed x
  cr=$(_carpetaseraf crudos) || { echo "(No encuentro la carpeta crudos en Drive)"; return 1; }
  ed=$(_carpetaseraf editados)
  mkdir -p "$cr/$s" && cp "$v" "$cr/$s/" || { echo "(No pude copiar ${v:t} a crudos)"; return 1; }
  for x in ${v%.mp4}*.srt(N); do cp "$x" "$cr/$s/"; done
  [ -n "$ed" ] && mkdir -p "$ed/$s"
  echo "📤 ${v:t} enviado a ${cr:t}/$s"
}
[ -z "$functions[_editar_base]" ] && (( $+functions[editar] )) && functions[_editar_base]=$functions[editar]
editar() {
  _editar_base "$@"; local r=$?
  [ $r = 0 ] && [ -f "${1%.mp4}_vertical.mp4" ] && _aequipo "${1%.mp4}_vertical.mp4"
  return $r
}
_colade() {
  local x f b k=0
  for x in ~/Desktop/Clips/.cola/*.(job|haciendo)(N); do
    f=$(sed -n 1p $x); b=${f:t:r}
    [ "$(_clientede ${b%_*})" = "$1" ] && k=$((k+1))
  done
  echo $k
}
_contar() {  # _contar CARPETA-BASE CLIENTE -> clips en BASE/<canal> de ese cliente
  local base=$1 s k=0; local -a f
  [ -n "$base" ] || { echo 0; return; }
  for s in $(_canalesde $2); do f=("$base/${(U)s}"/*.(mp4|mov|MP4|MOV)(N)); k=$((k + $#f)); done
  echo $k
}
_diacarpeta() {
  local n=$1 hn=$2 D=$3; local -a dd
  dd=("$D/Clientes/$n"/*". $hn"(N/) "$D/Clientes/$n"/Mes\ */*". $hn"(N/))
  echo "$dd[1]"
}
hoy() {
  zmodload zsh/datetime
  local R=~/Desktop/Clips/clientes.txt D l n
  D=$(_scdrive) || { echo "No encuentro la carpeta Seraf Clips en Google Drive."; return 1; }
  local cr=$(_carpetaseraf crudos) ed=$(_carpetaseraf editados)
  local ah=$(_ahora); local hoy=$(_scdia $ah); local th=$(_scepoch $hoy) hn=$(_scfecha $ah)
  echo "📅 Hoy: $hn"
  local -A ult; [ -s $R ] && while IFS= read -r l; do [ -n "$l" ] && ult[${l%%$'\t'*}]=$l; done < $R
  local -a c info vids; local q dia dd k e cc est
  for n in ${(ko)ult}; do
    c=("${(@ps:\t:)ult[$n]}"); info=($(_scplan $c[2]))
    if [[ $c[3] > $hoy ]]; then echo "\n• $n ($info[4]): empieza el $(_scfecha $(_scepoch $c[3]) c)"; continue; fi
    q=$(( ($(_scepoch $c[4]) - th) / 86400 ))
    if (( q < 0 )); then echo "\n• $n ($info[4]): su plan terminó el $(_scfecha $(_scepoch $c[4]) c)"; continue; fi
    dia=$(( (th - $(_scepoch $c[3])) / 86400 + 1 ))
    dd=$(_diacarpeta $n "$hn" "$D"); vids=(); [ -n "$dd" ] && vids=("$dd"/*.(mp4|mov|MP4|MOV)(N))
    est="✅"; (( $#vids < info[3] )) && est="⏳"
    echo "\n• $n · $info[4] · día $dia de $info[1]"
    echo "  $est Entregados hoy: $#vids de $info[3]"
    e=$(_contar "$ed" $n); (( e )) && echo "  📦 Editados listos para entregar: $e  →  escribe  entregar ${(L)n}"
    cc=$(_contar "$cr" $n); (( cc )) && echo "  ✂️  En crudos: $cc"
    k=$(_colade $n); (( k )) && echo "  🤖 En la cola de IA: $k"
    if (( q == 0 )); then echo "  ⚠️  Su plan termina HOY: mándale el recordatorio de renovación"
    elif (( q <= 3 )); then echo "  ⚠️  Su plan termina en $q días: mándale el recordatorio de renovación"; fi
  done
  local -a tc te; tc=("$cr"/*/*.(mp4|mov|MP4|MOV)(N)); te=("$ed"/*/*.(mp4|mov|MP4|MOV)(N))
  echo "\nEn total: ${#tc} en ${cr:t} · ${#te} en ${ed:t}"
  return 0
}
mensaje() {
  zmodload zsh/datetime
  local n=${(U)1} D last
  [ -n "$n" ] || { echo "Uso: mensaje CLIENTE [DÍA]   (ej: mensaje joanse  ·  mensaje joanse lunes)"; return 1; }
  local t; t=$(_fechadia "$2") || { echo "No entiendo el día '$2'. Usa: hoy, ayer o lunes..domingo"; return 1; }
  last=$(grep "^$n"$'\t' ~/Desktop/Clips/clientes.txt 2>/dev/null | tail -1)
  [ -n "$last" ] || { echo "No tengo a $n apuntado."; return 1; }
  D=$(_scdrive) || { echo "No encuentro la carpeta Seraf Clips en Google Drive."; return 1; }
  local -a c vids; c=("${(@ps:\t:)last}")
  local dd=$(_diacarpeta $n "$(_scfecha $t)" "$D")
  [ -n "$dd" ] && vids=("$dd"/*.(mp4|mov|MP4|MOV)(N))
  (( $#vids )) || { echo "Todavía no hay clips en la carpeta de $n del $(_scfecha $t)."; return 1; }
  local link=$(awk -v c=$n '$1==c{print $3}' ~/Desktop/Clips/.vinculos 2>/dev/null | tail -1)
  [ -z "$link" ] || [ "$link" = "-" ] && link="[link de su carpeta]"
  local tit="" v t m
  for v in $vids; do t=${v:t:r}; [[ $t == *' '* ]] && tit+="• $t"$'\n'; done
  if [ "$c[2]" = prueba ]; then
    m="${(C)n} ya tienes los clips de hoy en tu carpeta 🔥"$'\n'"$link"$'\n\n'
    [ -n "$tit" ] && m+="Hoy van:"$'\n'"$tit"$'\n'
    m+="Súbelos hoy mismo, mientras el directo está fresco 🙌"
  else
    m="Clips de hoy listos ✅ Te dejamos $#vids en tu carpeta y ya están programados en tus redes 🔥"$'\n'
    [ -n "$tit" ] && m+=$'\n'"$tit"
    m+=$'\n'"$link"
  fi
  if print -rn -- "$m" | pbcopy 2>/dev/null; then echo "📋 Mensaje copiado. Pégalo en WhatsApp:"; else echo "Mensaje:"; fi
  echo "────────"; print -r -- "$m"; echo "────────"
}
# entregar CLIENTE: de "2. Editados/<canal>" a su carpeta de hoy + mensaje copiado
entregar() {
  zmodload zsh/datetime
  local n=${(U)1} D
  [ -n "$n" ] || { echo "Uso: entregar CLIENTE [DÍA]   (ej: entregar joanse  ·  entregar joanse lunes)"; return 1; }
  local t; t=$(_fechadia "$2") || { echo "No entiendo el día '$2'. Usa: hoy, ayer o lunes..domingo"; return 1; }
  grep -q "^$n"$'\t' ~/Desktop/Clips/clientes.txt 2>/dev/null || { echo "No tengo a $n apuntado como cliente."; return 1; }
  _clienteactivo $n $t || { echo "$n no tiene el plan activo el $(_scfecha $t). Su plan: $(grep "^$n"$'\t' ~/Desktop/Clips/clientes.txt | tail -1 | cut -f3,4 | tr '\t' ' ')"; return 1; }
  D=$(_scdrive) || { echo "No encuentro la carpeta Seraf Clips en Google Drive."; return 1; }
  local dd=$(_diacarpeta $n "$(_scfecha $t)" "$D")
  [ -n "$dd" ] || { echo "No encuentro la carpeta del $(_scfecha $t) de $n."; return 1; }
  local ed=$(_carpetaseraf editados) cr=$(_carpetaseraf crudos) s v k=0 old=0
  for s in $(_canalesde $n); do
    for v in "$ed/${(U)s}"/*.(mp4|mov|MP4|MOV)(N); do
      echo "   Entregando ${v:t}..."
      if [ -e "$dd/${v:t}" ] || cp "$v" "$dd/"; then rm -f "$v"; k=$((k+1)); else echo "   (no pude copiar ${v:t})"; fi
    done
    for v in "$cr/${(U)s}"/*(N.m+3); do rm -f "$v" && old=$((old+1)); done
  done
  if (( k )); then echo "📦 $k clips entregados en ${dd:t} ($n)"
  else echo "No hay clips nuevos de $n en '${ed:t}'."; fi
  (( old )) && echo "🧹 Borré $old crudos de $n de hace más de 3 días"
  mensaje $n "$2"
}
# acuerdo CLIENTE: crea su acuerdo de servicio en PDF (Escritorio/Clips/acuerdos)
acuerdo() { python3 ~/clipstools/acuerdo.py "$@"; }
