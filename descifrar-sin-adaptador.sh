#!/usr/bin/env bash
#
# descifrar-sin-adaptador.sh — DESCIFRAR una clave WPA sin adaptador WiFi.
# ============================================================================
#  El descifrado es REAL (mismo PBKDF2/PMKID que un ataque de verdad). Lo unico
#  que no hacemos es capturar del aire (eso si necesita adaptador): en su lugar
#  generamos el handshake de una red de laboratorio y lo rompemos. Sirve para
#  aprender y demostrar el crackeo de punta a punta con lo que tienes hoy.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"

azul=$'\e[36m'; verde=$'\e[32m'; amar=$'\e[33m'; rojo=$'\e[31m'; fin=$'\e[0m'
info(){ echo "${azul}==>${fin} $*"; }
ok(){   echo "${verde}[ok]${fin} $*"; }
aviso(){ echo "${amar}[aviso]${fin} $*"; }
error(){ echo "${rojo}[error]${fin} $*" >&2; }

echo
info "DESCIFRAR WPA SIN ADAPTADOR — handshake de laboratorio + crackeo real"
echo

# ---- 0. python3 ----
if ! command -v python3 >/dev/null 2>&1; then
  info "Instalando python3..."
  sudo apt-get update -y && sudo apt-get install -y python3
fi
[ -f wpa_lab.py ] || { error "Falta wpa_lab.py (haz 'git pull')."; exit 1; }
[ -f diccionario-lab.txt ] || { error "Falta diccionario-lab.txt (haz 'git pull')."; exit 1; }

# ---- 1. datos de la red de laboratorio ----
read -rp "Nombre de la red de laboratorio (ESSID) [MiRedLab]: " essid
essid=${essid:-MiRedLab}

echo
aviso "La clave 'objetivo' es la que simula tener el router. Dos opciones:"
aviso "  - Enter: elijo una AL AZAR del diccionario y NO te la muestro (crackeo a ciegas real)."
aviso "  - O escribe una tu mismo (para que caiga, usa uno del diccionario, p.ej. password1)."
read -rp "Clave objetivo [Enter = al azar]: " psk
secreto=0
if [ -z "$psk" ]; then
  psk=$(shuf -n1 diccionario-lab.txt)
  secreto=1
fi

# ---- 2. generar el handshake ----
info "Generando el handshake WPA de la red '$essid'..."
python3 wpa_lab.py gen "$essid" "$psk" > objetivo.hc22000
ok "Handshake guardado en objetivo.hc22000"
[ "$secreto" = 1 ] && aviso "Clave elegida al azar y OCULTA: el cracker debe descubrirla solo."

# ---- 3. descifrar ----
echo
info "Descifrando contra diccionario-lab.txt (PBKDF2-HMAC-SHA1, igual que el ataque real)..."
hallada=$(python3 wpa_lab.py crack objetivo.hc22000 diccionario-lab.txt)
echo
if [ -n "$hallada" ]; then
  echo "${verde}==================================================${fin}"
  echo "${verde}  CLAVE DESCIFRADA  ->  $hallada${fin}"
  echo "${verde}==================================================${fin}"
  [ "$secreto" = 1 ] && ok "El cracker la descubrio sin conocerla. Eso es un ataque de diccionario WPA."
else
  aviso "La clave NO estaba en el diccionario (clave fuerte)."
  aviso "Ese es el otro resultado valioso: una clave larga y aleatoria no cae. Es la defensa."
fi

echo
echo "Equivalente con la herramienta real (si algun dia instalas hashcat con GPU):"
echo "   hashcat -m 22000 objetivo.hc22000 diccionario-lab.txt --force"
echo "Y con adaptador, 'objetivo.hc22000' saldria de TU captura real en vez de generarse."
