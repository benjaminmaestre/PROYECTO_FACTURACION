#!/bin/bash

echo "✉ Enviando facturas por correo..."
python enviador.py

echo "📊 Generando reporte administrativo..."

echo "--------------------------------------" > reporte.txt
echo "📊 Reporte Diario Mercado IRSI" >> reporte.txt
echo "Fecha: $(date)" >> reporte.txt
echo "--------------------------------------" >> reporte.txt

# Encuentra el último CSV de compras
CSV_FILE=$(ls -t compras/*.csv | grep -v log | head -1)

# Total de correos procesados
awk -F',' 'END{print "Total correos procesados: " NR}' log_envios.csv >> reporte.txt

# Total vendido
awk -F';' '{suma+=$9} END{print "Total vendido: $" suma}' "$CSV_FILE" >> reporte.txt

# Pedidos pagados en su totalidad
awk -F';' '$10=="completo"{c++} END{print "Pedidos pagados en su totalidad: " c}' "$CSV_FILE" >> reporte.txt

# Envíos exitosos y fallidos
awk -F',' '$3=="exitoso"{e++} $3=="fallido"{f++} END{print "Envíos exitosos: " e ", fallidos: " f}' log_envios.csv >> reporte.txt

echo "--------------------------------------" >> reporte.txt

echo "✅ Reporte generado en reporte.txt"
echo "✔ Proceso automatizado completado."
