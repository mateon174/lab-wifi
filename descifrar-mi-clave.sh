#!/usr/bin/env bash
#
# descifrar-mi-clave.sh — descifra TU clave de laboratorio (la que ya conoces).
# ============================================================================
#  Le das el nombre de tu red y tu clave. La herramienta:
#   1) construye el handshake WPA de tu red (PMKID real),
#   2) mete tu clave dentro de un espacio de busqueda de miles de candidatos,
#   3) la busca una por una con PBKDF2-HMAC-SHA1 (el calculo real del ataque),
#   4) te la muestra descifrada.
#  Sin adaptador WiFi, sin hashcat, sin OpenCL: solo Python. Es tu red de lab.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"

azul=$'\e[36m'; verde=$'\e[32m'; amar=$'\e[33m'; rojo=$'\e[31m'; fin=$'\e[0m'
info(){ echo "${azul}==>${fin} $*"; }
ok(){   echo "${verde}[ok]${fin} $*"; }
aviso(){ echo "${amar}[aviso]${fin} $*"; }
error(){ echo "${rojo}[error]${fin} $*" >&2; }

echo
info "DESCIFRAR MI CLAVE DE LABORATORIO"
echo

# ---- requisitos ----
if ! command -v python3 >/dev/null 2>&1; then
  info "Instalando python3..."; sudo apt-get update -y && sudo apt-get install -y python3
fi
[ -f wpa_lab.py ] || { error "Falta wpa_lab.py (haz 'git pull')."; exit 1; }
[ -f diccionario-lab.txt ] || { error "Falta diccionario-lab.txt (haz 'git pull')."; exit 1; }

# ---- tus datos ----
read -rp "Nombre de TU red de laboratorio (ESSID) [MiRedLab]: " essid
essid=${essid:-MiRedLab}
read -rp "TU clave de laboratorio (la que ya conoces): " psk
[ -n "$psk" ] || { error "No escribiste ninguna clave."; exit 1; }
if [ ${#psk} -lt 8 ]; then
  aviso "Ojo: WPA2 exige 8+ caracteres; una clave mas corta no seria valida en un router real."
fi

# ---- construir el espacio de busqueda (tu clave escondida entre miles) ----
info "Preparando el espacio de busqueda..."
cp diccionario-lab.txt busqueda.txt
printf '%s\n' "$psk" >> busqueda.txt          # tu clave, mezclada con las demas
sort -u busqueda.txt -o busqueda.txt
n=$(wc -l < busqueda.txt)
ok "Espacio de busqueda: $n candidatos (tu clave esta ahi, sin marcar)."

# ---- generar el handshake de tu red ----
info "Generando el handshake WPA de la red '$essid'..."
python3 wpa_lab.py gen "$essid" "$psk" > mi-objetivo.hc22000
ok "Handshake listo (mi-objetivo.hc22000)."

# ---- descifrar ----
echo
info "Descifrando: probando cada candidato con PBKDF2-HMAC-SHA1 (el calculo real del ataque)..."
hallada=$(python3 wpa_lab.py crack mi-objetivo.hc22000 busqueda.txt)
echo
if [ "$hallada" = "$psk" ]; then
  echo "${verde}==================================================${fin}"
  echo "${verde}  CLAVE DESCIFRADA  ->  $hallada${fin}"
  echo "${verde}==================================================${fin}"
  ok "La herramienta recupero tu clave buscando entre $n candidatos."
elif [ -n "$hallada" ]; then
  aviso "Se hallo '$hallada' (colision improbable); revisa la entrada."
else
  error "No se hallo (no deberia pasar: tu clave se agrego al espacio de busqueda)."
fi

echo
echo "Que es real aqui: TODO el descifrado (PBKDF2/PMKID identicos a un ataque de verdad)."
echo "Que se simula: el ORIGEN del handshake. Con adaptador WiFi, saldria de capturar TU"
echo "red del aire en vez de generarlo. Esa captura es el unico paso que necesita hardware."
