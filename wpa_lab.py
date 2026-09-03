#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
wpa_lab.py — motor de laboratorio WPA/WPA2 (sin radio).
============================================================================
 Genera y descifra handshakes WPA usando EXACTAMENTE la misma criptografia
 que un ataque real: PMK = PBKDF2-HMAC-SHA1(clave, ESSID, 4096, 32) y
 PMKID = HMAC-SHA1(PMK, "PMK Name" | BSSID | STA)[:16].
 Solo usa la libreria estandar de Python: corre en cualquier Kali, sin
 adaptador WiFi, sin hashcat y sin OpenCL.

 Uso:
   python3 wpa_lab.py gen   <ESSID> <CLAVE>            -> imprime linea 22000
   python3 wpa_lab.py crack <archivo.hc22000> <dicc>   -> imprime la clave hallada
============================================================================
"""
import sys, os, hmac, hashlib


def pmk(essid, clave):
    return hashlib.pbkdf2_hmac("sha1", clave.encode("utf-8"),
                               essid.encode("utf-8"), 4096, 32)


def pmkid(essid, clave, ap, sta):
    return hmac.new(pmk(essid, clave), b"PMK Name" + ap + sta,
                    hashlib.sha1).digest()[:16]


def gen(essid, clave, ap=None, sta=None):
    ap = ap or os.urandom(6)
    sta = sta or os.urandom(6)
    pid = pmkid(essid, clave, ap, sta)
    # Formato hashcat 22000 para PMKID: WPA*01*PMKID*BSSID*STA*ESSID(hex)***
    return "WPA*01*%s*%s*%s*%s***" % (
        pid.hex(), ap.hex(), sta.hex(), essid.encode("utf-8").hex())


def parse(linea):
    p = linea.strip().split("*")
    return {
        "pmkid": p[2],
        "ap": bytes.fromhex(p[3]),
        "sta": bytes.fromhex(p[4]),
        "essid": bytes.fromhex(p[5]).decode("utf-8", "replace"),
    }


def crack(linea, ruta_dicc):
    h = parse(linea)
    objetivo = h["pmkid"].lower()
    with open(ruta_dicc, "r", encoding="utf-8", errors="ignore") as f:
        for w in f:
            w = w.rstrip("\r\n")
            if len(w) < 8:            # WPA2 exige >= 8 caracteres
                continue
            cand = pmkid(h["essid"], w, h["ap"], h["sta"]).hex()
            if cand == objetivo:
                return w
    return None


def main():
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "gen":
        print(gen(sys.argv[2], sys.argv[3]))
    elif cmd == "crack":
        linea = open(sys.argv[2], "r", encoding="utf-8").read().strip()
        hallada = crack(linea, sys.argv[3])
        print(hallada if hallada else "")
    else:
        print("Comando desconocido:", cmd); sys.exit(1)


if __name__ == "__main__":
    main()
