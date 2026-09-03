#!/usr/bin/env bash
#
# arrancar.sh — UN SOLO COMANDO: prepara todo y abre el asistente de auditoria.
# ============================================================================
#  Tras clonar el repo, ejecuta:   ./arrancar.sh
#  Hace por ti: permisos -> instala la suite -> comprueba el adaptador -> lanza el asistente.
#  Te pedira la contrasena de sudo UNA vez (para instalar y para el modo monitor).
# ============================================================================
set -uo pipefail                      # sin -e: queremos manejar los avisos sin abortar de golpe
cd "$(dirname "$0")"                   # trabajar siempre desde la carpeta del repo

azul=$'\e[36m'; verde=$'\e[32m'; amar=$'\e[33m'; rojo=$'\e[31m'; fin=$'\e[0m'
info(){ echo "${azul}==>${fin} $*"; }
ok(){   echo "${verde}[ok]${fin} $*"; }
aviso(){ echo "${amar}[aviso]${fin} $*"; }
error(){ echo "${rojo}[error]${fin} $*" >&2; }

echo
info "LAB DE AUDITORIA WiFi — arranque automatico"
aviso "Recuerda: esto es SOLO contra tu propia red o una con permiso escrito."
echo

# ---- 1/4 permisos ----
info "1/4 · Dando permisos de ejecucion a los scripts..."
chmod +x auditar-wifi.sh generar-diccionario.sh 2>/dev/null || true
ok "Permisos listos."

# ---- 2/4 dependencias ----
info "2/4 · Instalando la suite (aircrack-ng, iw, hcxtools, hashcat)..."
aviso "Si pide contrasena de sudo: escribela (no se ve al teclear) y pulsa Enter."
sudo apt-get update -y
if sudo apt-get install -y aircrack-ng iw hcxtools hashcat; then
  ok "Herramientas instaladas."
else
  error "Fallo la instalacion. Revisa que Kali tenga internet y reintenta."
  exit 1
fi

# ---- 3/4 adaptador ----
info "3/4 · Buscando adaptador WiFi..."
ifaces=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}')
if [ -z "$ifaces" ]; then
  aviso "Todavia no veo ningun adaptador inalambrico."
  aviso "Conecta tu adaptador USB. En una VM: menu Dispositivos > USB > [tu adaptador]."
  read -rp "Cuando este conectado, pulsa Enter para volver a mirar..." _
  ifaces=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}')
fi
if [ -z "$ifaces" ]; then
  error "Sigo sin ver adaptador. Comprueba a mano con:  lsusb   e   iw dev"
  error "Sin un adaptador con modo monitor no se puede continuar. Saliendo."
  exit 1
fi
ok "Adaptador(es) detectado(s): $(echo "$ifaces" | tr '\n' ' ')"

# ---- 4/4 lanzar asistente ----
echo
info "4/4 · Todo listo. Abriendo el asistente de auditoria..."
aviso "A partir de aqui te hara unas pocas preguntas (que solo tu puedes responder):"
aviso "  confirmar autorizacion, elegir TU red del escaneo, y su BSSID/canal."
echo
sudo ./auditar-wifi.sh
