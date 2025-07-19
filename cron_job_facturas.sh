#!/bin/bash

echo "🚀 Generando nuevas compras..."
python generador_compras.py

CSV_FILE=$(ls -t compras/*.csv | grep -v log | head -1)

echo "🖨 Generando facturas con $CSV_FILE"
./generador_facturas.sh "$CSV_FILE"

echo "✔ Facturas generadas correctamente."
