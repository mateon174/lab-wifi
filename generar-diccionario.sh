#!/usr/bin/env bash
#
# generar-diccionario.sh — construye un diccionario de laboratorio a la medida.
# ============================================================================
#  Por que existe: descargar rockyou entero (14M de claves) es lento y para el
#  lab no hace falta. Aqui generas un diccionario PEQUENO y DIRIGIDO a partir de
#  palabras base + mutaciones (anios, sufijos, mayusculas, leet). Es exactamente
#  como se construye un ataque dirigido real: no pruebas "todo", pruebas lo probable.
#
#  Uso:
#    ./generar-diccionario.sh                     -> set de palabras debiles por defecto
#    ./generar-diccionario.sh casa perro juan     -> alrededor de TUS palabras base
#    ./generar-diccionario.sh casa perro > mi.txt -> guardar en archivo
#
#  Nota WPA2: la clave minima es de 8 caracteres, asi que este script descarta
#  automaticamente cualquier candidato de menos de 8 (probarlos seria inutil).
# ============================================================================
set -euo pipefail

if (( $# > 0 )); then
  bases=("$@")
else
  bases=(password admin qwerty iloveyou superman dragon monkey shadow master
         welcome sunshine princess football baseball computer internet
         familia amor casa colombia bogota medellin althura wifi
         hola verano invierno secreto milton laura carlos)
fi

anios=(2018 2019 2020 2021 2022 2023 2024 2025 2026)
sufijos=(123 1234 12345 123456 12345678 1 12 21 00 007 321 "!" "!!" "01" ".")

emit(){ printf '%s\n' "$1"; }

for w in "${bases[@]}"; do
  lw=$(printf '%s' "$w" | tr 'A-Z' 'a-z')
  cap=$(printf '%s' "$lw" | sed 's/^\(.\)/\U\1/')       # Casa
  up=$(printf '%s' "$lw" | tr 'a-z' 'A-Z')              # CASA
  for base in "$lw" "$cap" "$up"; do
    emit "$base"
    for s in "${sufijos[@]}"; do emit "${base}${s}"; done
    for y in "${anios[@]}"; do emit "${base}${y}"; done
  done
  leet=$(printf '%s' "$lw" | sed 'y/aeiost/4310$7/')    # c4s4 -> leet basico
  emit "$leet"; emit "${leet}!"; emit "${leet}2025"; emit "${leet}123"
done | awk '{ if (length($0) >= 8) print }' | sort -u
