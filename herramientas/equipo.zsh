# ===== Equipo: clips solos a "Para editar" + resumen del día (hoy / mensaje) =====
_scdrive() { local D=(~/Library/CloudStorage/GoogleDrive-*/"Mi unidad"/"Seraf Clips"(N/)); [ -n "$D[1]" ] && echo "$D[1]"; }
vincular() {
  local c=${(U)1} k=${(L)${2#@}} l=$3 F=~/Desktop/Clips/.vinculos
  if [ -z "$c" ] || [ -z "$k" ]; then
    echo "Uso: vincular CLIENTE CANAL [LINK-DE-SU-CARPETA]   Ej: vincular joanse joanseee https://drive.google.com/..."; return 1
  fi
  mkdir -p ~/Desktop/Clips; touch $F
  grep -v "^$c " $F > $F.tmp; mv $F.tmp $F
  echo "$c $k ${l:--}" >> $F
  echo "✅ $c vinculado: sus clips de '$k' irán solos a '$c - equipo / Para editar'.${l:+ Link guardado para los mensajes.}"
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
  local -a c; c=("${(@ps:\t:)last}"); local hoy=$(_scdia $EPOCHSECONDS)
  ! [[ $c[3] > $hoy ]] && ! [[ $c[4] < $hoy ]]
}
_aequipo() {
  local v=$1 b=${1:t:r}; b=${b%_vertical}; local s=${b%_*} c D
  c=$(_clientede $s) || return 0
  _clienteactivo $c || return 0
  D=$(_scdrive) || return 0
  local dest="$D/Clientes/$c - equipo (no compartir)/Para editar"
  [ -d "$dest" ] || return 0
  cp "$v" "$dest/" || { echo "(No pude copiar ${v:t} a Drive)"; return 1; }
  local x; for x in ${v%.mp4}*.srt(N); do cp "$x" "$dest/"; done
  echo "📤 ${v:t} enviado a $c - equipo / Para editar"
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
_diacarpeta() {
  local n=$1 hn=$2 D=$3; local -a dd
  dd=("$D/Clientes/$n"/*". $hn"(N/) "$D/Clientes/$n"/Mes\ */*". $hn"(N/))
  echo "$dd[1]"
}
hoy() {
  zmodload zsh/datetime
  local R=~/Desktop/Clips/clientes.txt D l n
  [ -s $R ] || { echo "Aún no hay clientes apuntados."; return 0; }
  D=$(_scdrive) || { echo "No encuentro la carpeta Seraf Clips en Google Drive."; return 1; }
  local hoy=$(_scdia $EPOCHSECONDS); local th=$(_scepoch $hoy) hn=$(_scfecha $EPOCHSECONDS)
  local -A ult; while IFS= read -r l; do [ -n "$l" ] && ult[${l%%$'\t'*}]=$l; done < $R
  echo "📅 Hoy: $hn"
  local -a c info vids pe; local q dia dd k est
  for n in ${(ko)ult}; do
    c=("${(@ps:\t:)ult[$n]}"); info=($(_scplan $c[2]))
    if [[ $c[3] > $hoy ]]; then echo "\n• $n ($info[4]): empieza el $(_scfecha $(_scepoch $c[3]) c)"; continue; fi
    q=$(( ($(_scepoch $c[4]) - th) / 86400 ))
    if (( q < 0 )); then echo "\n• $n ($info[4]): su plan terminó el $(_scfecha $(_scepoch $c[4]) c)"; continue; fi
    dia=$(( (th - $(_scepoch $c[3])) / 86400 + 1 ))
    dd=$(_diacarpeta $n "$hn" "$D"); vids=(); [ -n "$dd" ] && vids=("$dd"/*.(mp4|mov|MP4|MOV)(N))
    pe=("$D/Clientes/$n - equipo (no compartir)/Para editar"/*.(mp4|mov|MP4|MOV)(N))
    est="✅"; (( $#vids < info[3] )) && est="⏳"
    echo "\n• $n · $info[4] · día $dia de $info[1]"
    echo "  $est Entregados hoy: $#vids de $info[3]"
    (( $#pe )) && echo "  ✂️  Esperando a tus amigos en 'Para editar': $#pe"
    k=$(_colade $n); (( k )) && echo "  🤖 En la cola de IA: $k"
    if (( q <= 3 )); then
      if (( q == 0 )); then echo "  ⚠️  Su plan termina HOY: mándale el recordatorio de renovación"
      else echo "  ⚠️  Su plan termina en $q días: mándale el recordatorio de renovación"; fi
    fi
    (( $#vids )) && echo "  💬 Mensaje de entrega listo: escribe  mensaje ${(L)n}"
  done
  return 0
}
mensaje() {
  zmodload zsh/datetime
  local n=${(U)1} D last
  [ -n "$n" ] || { echo "Uso: mensaje CLIENTE   (ej: mensaje joanse)"; return 1; }
  last=$(grep "^$n"$'\t' ~/Desktop/Clips/clientes.txt 2>/dev/null | tail -1)
  [ -n "$last" ] || { echo "No tengo a $n apuntado."; return 1; }
  D=$(_scdrive) || { echo "No encuentro la carpeta Seraf Clips en Google Drive."; return 1; }
  local -a c vids; c=("${(@ps:\t:)last}")
  local dd=$(_diacarpeta $n "$(_scfecha $EPOCHSECONDS)" "$D")
  [ -n "$dd" ] && vids=("$dd"/*.(mp4|mov|MP4|MOV)(N))
  (( $#vids )) || { echo "Hoy todavía no hay clips en la carpeta de $n."; return 1; }
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
  if print -rn -- "$m" | pbcopy 2>/dev/null; then echo "📋 Copiado. Pégalo en WhatsApp:"; else echo "Mensaje:"; fi
  echo "────────"; print -r -- "$m"; echo "────────"
}
