#!/usr/bin/env bash
#
# practicar-crackeo.sh — practica el CRACKEO WPA sin adaptador WiFi.
# ============================================================================
#  El ataque WPA tiene dos mitades: CAPTURAR (necesita adaptador con modo
#  monitor) y CRACKEAR (puro computo, sin radio). Este script practica la
#  segunda: crackea un handshake WPA REAL -el de ejemplo que trae hashcat-
#  con el mismo modo 22000 que usarias con tu propia captura. Sin hardware.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"

azul=$'\e[36m'; verde=$'\e[32m'; amar=$'\e[33m'; rojo=$'\e[31m'; fin=$'\e[0m'
info(){ echo "${azul}==>${fin} $*"; }
ok(){   echo "${verde}[ok]${fin} $*"; }
aviso(){ echo "${amar}[aviso]${fin} $*"; }
error(){ echo "${rojo}[error]${fin} $*" >&2; }

echo
info "PRACTICA DE CRACKEO WPA (sin adaptador WiFi)"
echo

# ---- 1. hashcat + OpenCL de CPU (pocl) para que corra en una VM sin GPU ----
info "1/4 · Asegurando hashcat y el backend de CPU (pocl)..."
if ! command -v hashcat >/dev/null 2>&1; then
  sudo apt-get update -y && sudo apt-get install -y hashcat pocl-opencl-icd
else
  sudo apt-get install -y pocl-opencl-icd 2>/dev/null || true
fi
command -v hashcat >/dev/null 2>&1 || { error "hashcat no se instalo. Revisa el internet de Kali."; exit 1; }
ok "hashcat listo."

# ---- 2. tomar el handshake WPA de ejemplo de hashcat (clave conocida) ----
info "2/4 · Tomando el handshake WPA de ejemplo (modo 22000)..."
salida=$(hashcat -m 22000 --example-hashes 2>/dev/null)
ejemplo=$(printf '%s\n' "$salida" | grep -iE '^(HASH|Example\.Hash)' | grep -vi format | head -1 | sed -E 's/^[^:]*:[[:space:]]*//')
clave=$(printf '%s\n'   "$salida" | grep -iE '^(PASS|Example\.Pass)' | head -1 | sed -E 's/^[^:]*:[[:space:]]*//')
if [ -z "$ejemplo" ]; then error "No pude extraer el hash de ejemplo de hashcat."; exit 1; fi
printf '%s\n' "$ejemplo" > ejemplo.hc22000
ok "Handshake de ejemplo guardado en ejemplo.hc22000  (clave a encontrar: '${clave:-hashcat}')."

# ---- 3. diccionario pequeno que INCLUYE la clave del ejemplo ----
info "3/4 · Creando un diccionario de demostracion..."
printf '%s\n' password 123456 qwerty superman iloveyou dragon monkey "${clave:-hashcat}" > lista-demo.txt
ok "Diccionario listo (lista-demo.txt)."

# ---- 4. crackear ----
info "4/4 · Crackeando el handshake (esto es EXACTAMENTE el paso final del ataque real)..."
echo
rm -f resultado.txt
hashcat -m 22000 ejemplo.hc22000 lista-demo.txt --potfile-disable --force -o resultado.txt 2>&1 | tail -25
echo
if [ -s resultado.txt ]; then
  pass=$(awk -F: '{print $NF}' resultado.txt | head -1)
  ok "CLAVE ENCONTRADA  ->  $pass"
  echo "Eso mismo veras con TU captura real (con adaptador): un handshake -> el diccionario -> la clave."
else
  aviso "No aparecio la clave en esta corrida."
  aviso "Suele ser el backend de hashcat en la VM. Prueba:  hashcat -I    (debe listar un dispositivo CPU)."
  aviso "Si dice 'No devices', instala:  sudo apt install -y pocl-opencl-icd  y reintenta."
fi
