# ===== Clientes Seraf Clips =====
_scplan() {
  case ${(L)1} in
    prueba) echo "7 39 4 Prueba";;
    basico|básico) echo "30 129 4 Básico";;
    pro) echo "30 269 6 Pro";;
    elite|élite) echo "30 389 6 Élite";;
    *) return 1;;
  esac
}
_scfecha() {
  zmodload zsh/datetime
  local u d m; local -a DN MN
  DN=(Lunes Martes Miércoles Jueves Viernes Sábado Domingo)
  MN=(ene feb mar abr may jun jul ago sep oct nov dic)
  strftime -s u '%u' $1; strftime -s d '%d' $1; strftime -s m '%m' $1
  if [ -n "$2" ]; then echo "$((10#$d)) $MN[$((10#$m))]"; else echo "$DN[$u] $((10#$d)) $MN[$((10#$m))]"; fi
}
_scepoch() {
  zmodload zsh/datetime
  local t; [[ $1 =~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ]] || return 1
  strftime -r -s t '%Y-%m-%d %H' "$1 12" 2>/dev/null || return 1; echo $t
}
_scdia() { zmodload zsh/datetime; strftime '%Y-%m-%d' $1; }
_scleeme() {
  local C=$1 n=$2 plan=$3 ini=$4 fin=$5 info; info=($(_scplan $plan))
  {
    echo "Hola ${(C)n} 👋 Esta es tu carpeta de Seraf Clips."
    echo "Tu plan: $info[4] ($ini → $fin)."
    echo
    if [ $plan = prueba ]; then
      echo "Cada día de directo encontrarás tus clips en la carpeta de ese día, ya editados en vertical y listos para subir a TikTok, Reels y Shorts."
      echo
      echo "- En \"8. Lo mejor de la semana\" te dejamos los que más potencial tienen."
    else
      echo "Dentro de cada \"Mes\" tienes una carpeta por día con los clips de ese directo, ya editados en vertical para TikTok, Reels y Shorts. Además se publican solos en tus redes con título y hashtags: aquí siempre tienes una copia."
      echo
      echo "- En \"A. Lo mejor del mes\" guardamos los que más potencial tienen."
      [ $plan != basico ] && echo "- En \"B. Reportes semanales\" te dejamos cada domingo cómo les fue a tus clips."
      [ $plan = elite ] && echo "- En \"C. Videos largos\" van tus videos largos del mes y en \"D. Miniaturas y portadas\" sus miniaturas. Tu plan para el canal está en \"Estrategia YouTube\"."
    fi
    echo "- Para guardar un clip en tu móvil: ábrelo, toca los 3 puntos y elige Descargar (en iPhone: Enviar una copia → Guardar video)."
    echo "- ¿Quieres algún cambio? Escríbenos por WhatsApp y lo ajustamos."
    echo
    echo "Seraf Clips"
  } > "$C/LEEME.txt"
}
nuevocliente() {
  zmodload zsh/datetime
  local n=${(U)1} plan=${(L)2} f=$3
  plan=${plan//á/a}; plan=${plan//é/e}
  local -a info; info=($(_scplan $plan 2>/dev/null))
  if [ -z "$n" ] || [ -z "$info" ]; then
    echo "Uso: nuevocliente NOMBRE PLAN FECHA   (PLAN: prueba, basico, pro o elite · FECHA: 2026-12-01, sin fecha empieza mañana)"; return 1
  fi
  local t0
  if [ -n "$f" ]; then t0=$(_scepoch $f) || { echo "Fecha no válida. Escríbela así: 2026-12-01"; return 1; }
  else t0=$(( $(_scepoch $(_scdia $EPOCHSECONDS)) + 86400 )); fi
  local D=(~/Library/CloudStorage/GoogleDrive-*/"Mi unidad"/"Seraf Clips"(N/))
  [ -z "$D[1]" ] && { echo "No encuentro la carpeta Seraf Clips en Google Drive."; return 1; }
  local R=~/Desktop/Clips/clientes.txt ini=$(_scdia $t0) dias=$info[1] i t
  local fin=$(_scdia $((t0+(dias-1)*86400)))
  local T=$'\t'
  if grep -q "^$n${T}[^${T}]*${T}$ini${T}" $R 2>/dev/null; then echo "$n ya tiene creado el periodo que empieza el $ini."; return 1; fi
  local C="$D[1]/Clientes/$n"
  mkdir -p "$D[1]/Clientes/$n" || return 1
  if [ $plan = prueba ]; then
    for ((i=0;i<7;i++)); do t=$((t0+i*86400)); mkdir -p "$C/$((i+1)). $(_scfecha $t)"; done
    mkdir -p "$C/8. ⭐ Lo mejor de la semana"
  else
    local -a ms; ms=("$C"/Mes\ *(N/))
    local M="$C/Mes $(( ${#ms} + 1 )) · $(_scfecha $t0 c) – $(_scfecha $((t0+(dias-1)*86400)) c)"
    for ((i=0;i<dias;i++)); do t=$((t0+i*86400)); mkdir -p "$M/$(printf %02d $((i+1))). $(_scfecha $t)"; done
    mkdir -p "$M/A. ⭐ Lo mejor del mes"
    [ $plan != basico ] && mkdir -p "$M/B. Reportes semanales"
    [ $plan = elite ] && mkdir -p "$M/C. Videos largos" "$M/D. Miniaturas y portadas" "$C/Estrategia YouTube"
  fi
  _scleeme "$C" $n $plan "$(_scfecha $t0 c)" "$(_scfecha $((t0+(dias-1)*86400)) c)"
  mkdir -p ~/Desktop/Clips; printf '%s\t%s\t%s\t%s\t%s\n' $n $plan $ini $fin $info[2] >> $R
  echo "✅ $n listo · Plan $info[4] (\$$info[2]) · $(_scfecha $t0 c) → $(_scfecha $((t0+(dias-1)*86400)) c) · $info[3] clips al día"
  echo "Siguiente: comparte su carpeta en drive.google.com y sigue el Manual de clientes."
  [[ $OSTYPE == darwin* ]] && open "$D[1]/Clientes"
  return 0
}
renovar() {
  local n=${(U)1} R=~/Desktop/Clips/clientes.txt last
  last=$(grep "^$n"$'\t' $R 2>/dev/null | tail -1)
  [ -z "$last" ] && { echo "No tengo a $n apuntado. Usa: nuevocliente $n PLAN FECHA"; return 1; }
  local -a c; c=("${(@ps:\t:)last}")
  local plan=${(L)2:-$c[2]}
  [ $plan = prueba ] && { echo "La prueba no se renueva. Dime a qué plan pasa: renovar $n pro (o basico, elite)"; return 1; }
  nuevocliente $n $plan $(_scdia $(( $(_scepoch $c[4]) + 86400 )))
}
clientes() {
  zmodload zsh/datetime
  local R=~/Desktop/Clips/clientes.txt l n q
  [ -s $R ] || { echo "Aún no hay clientes apuntados. Usa: nuevocliente NOMBRE PLAN FECHA"; return 0; }
  local hoy=$(_scepoch $(_scdia $EPOCHSECONDS)); local -A ult
  while IFS= read -r l; do [ -n "$l" ] && ult[${l%%$'\t'*}]=$l; done < $R
  local -a c info
  for n in ${(ko)ult}; do
    c=("${(@ps:\t:)ult[$n]}"); info=($(_scplan $c[2]))
    q=$(( ($(_scepoch $c[4]) - hoy) / 86400 ))
    if (( q < 0 )); then l="terminó hace $(( -q )) días"
    elif (( q == 0 )); then l="⚠️  termina HOY"
    elif (( q <= 3 )); then l="⚠️  quedan $q días: mándale el recordatorio"
    else l="quedan $q días"; fi
    echo "${(r:12:)n} ${(r:7:)info[4]} ${(l:4:)${:-\$$c[5]}}  hasta ${(r:7:)$(_scfecha $(_scepoch $c[4]) c)} $l"
  done
}
