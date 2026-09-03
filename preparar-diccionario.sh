#!/usr/bin/env bash
#
# preparar-diccionario.sh — arma UN diccionario completo, con todo incluido.
# ============================================================================
#  Junta en un solo archivo (diccionario-completo.txt):
#    - rockyou.txt        (~14 millones de claves reales; ya viene en Kali)
#    - las demas listas .txt de /usr/share/wordlists
#    - el diccionario del laboratorio + variantes generadas
#  Y lo filtra a claves de 8+ caracteres (lo que exige WPA2) y quita repetidas.
#
#  OJO CON LA VELOCIDAD: con millones de claves, el motor Python (wpa_lab.py) es
#  LENTISIMO. Para un diccionario grande usa hashcat, que es el adecuado.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"

azul=$'\e[36m'; verde=$'\e[32m'; amar=$'\e[33m'; rojo=$'\e[31m'; fin=$'\e[0m'
info(){ echo "${azul}==>${fin} $*"; }
ok(){   echo "${verde}[ok]${fin} $*"; }
aviso(){ echo "${amar}[aviso]${fin} $*"; }
error(){ echo "${rojo}[error]${fin} $*" >&2; }

salida="diccionario-completo.txt"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

echo
info "PREPARANDO DICCIONARIO COMPLETO (todo incluido)"
echo

# ---- 1. rockyou ----
ROCK="/usr/share/wordlists/rockyou.txt"
if [ ! -f "$ROCK" ] && [ -f "$ROCK.gz" ]; then
  info "Descomprimiendo rockyou.txt (viene comprimido en Kali)..."
  sudo gunzip -kf "$ROCK.gz" 2>/dev/null || { gunzip -kc "$ROCK.gz" | sudo tee "$ROCK" >/dev/null; }
fi
if [ -f "$ROCK" ]; then
  cat "$ROCK" >> "$tmp"; ok "rockyou: $(wc -l < "$ROCK") claves."
else
  aviso "No encuentro rockyou. Instalalo con:  sudo apt update && sudo apt install -y wordlists"
  aviso "Sigo sin el (usare solo lo demas)."
fi

# ---- 2. otras listas de Kali ----
info "Agregando otras listas de /usr/share/wordlists..."
otras=0
for extra in /usr/share/wordlists/*.txt; do
  [ -f "$extra" ] || continue
  [ "$extra" = "$ROCK" ] && continue
  cat "$extra" >> "$tmp"; otras=$((otras+1))
done
ok "Listas extra agregadas: $otras."

# ---- 3. laboratorio + variantes ----
info "Agregando el diccionario del laboratorio y variantes generadas..."
[ -f diccionario-lab.txt ] && cat diccionario-lab.txt >> "$tmp"
[ -x generar-diccionario.sh ] && ./generar-diccionario.sh casa wifi router admin familia clave >> "$tmp" 2>/dev/null || true
ok "Extras del lab agregados."

# ---- 4. filtrar (WPA2: 8+) + dedup ----
info "Uniendo, filtrando a 8+ caracteres (lo que pide WPA2) y quitando repetidas..."
aviso "En listas grandes esto tarda un poco y usa disco temporal. Paciencia."
awk '{ if (length($0) >= 8) print }' "$tmp" | LC_ALL=C sort -u > "$salida"

n=$(wc -l < "$salida"); peso=$(du -h "$salida" | cut -f1)
echo
ok "LISTO -> $salida  ($n claves unicas, $peso)"
echo
echo "Como usarlo:"
echo "  Rapido (recomendado, con hashcat):"
echo "     hashcat -m 22000 mi-objetivo.hc22000 $salida --force"
echo "  Con el motor Python (solo para listas chicas; en millones es lentisimo):"
echo "     python3 wpa_lab.py crack mi-objetivo.hc22000 $salida"
echo
aviso "Recordatorio honesto: un diccionario mas grande solo ayuda si la clave real es"
aviso "comun o filtrada. Una clave larga y aleatoria NO cae ni con rockyou entero."
