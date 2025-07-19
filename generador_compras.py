#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import csv
import random
import os
from faker import Faker
from datetime import datetime

# Faker para Colombia
fake = Faker('es_CO')

NUM_COMPRAS = 10
OUTPUT_DIR = "compras"

if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

now = datetime.now()
file_name = f"compras_{now.strftime('%Y%m%d_%H%M')}.csv"
file_path = os.path.join(OUTPUT_DIR, file_name)
log_path = os.path.join(OUTPUT_DIR, f"log_errores_{now.strftime('%Y%m%d_%H%M')}.log")

# Lista de ciudades colombianas para más realismo
ciudades_colombia = ["Bogotá", "Medellín", "Cali", "Barranquilla", "Bucaramanga", "Cartagena", "Pereira", "Manizales"]

with open(file_path, mode='w', newline='', encoding='utf-8') as csvfile, \
     open(log_path, mode='w', encoding='utf-8') as logfile:
    fieldnames = ["id_transaccion","fecha_emision","nombre","correo","telefono",
                  "direccion","ciudad","cantidad","monto","pago","estado_pago",
                  "ip","timestamp","observaciones"]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames, delimiter=';')
    writer.writeheader()

    for i in range(NUM_COMPRAS):
        try:
            id_transaccion = random.randint(100000, 999999)
            fecha_emision = now.strftime("%Y-%m-%d")
            nombre = fake.name()
            correo = fake.email()
            telefono = fake.phone_number()
            direccion = fake.street_address()
            ciudad = random.choice(ciudades_colombia)
            cantidad = random.randint(1, 10)
            monto = cantidad * random.randint(10000, 50000)  # Pesos colombianos
            pago = random.choice(["completo", "fraccionado"])
            estado_pago = random.choice(["exitoso", "fallido"])
            ip = fake.ipv4()
            timestamp = now.strftime("%Y-%m-%d %H:%M:%S")
            observaciones = random.choice(["Cliente frecuente", "Promoción aplicada", "Cliente nuevo", ""])

            # Introducir un fallo aleatorio en el correo
            if random.random() < 0.1:
                correo = "correo_invalido@@"

            writer.writerow({
                "id_transaccion": id_transaccion,
                "fecha_emision": fecha_emision,
                "nombre": nombre,
                "correo": correo,
                "telefono": telefono,
                "direccion": direccion,
                "ciudad": ciudad,
                "cantidad": cantidad,
                "monto": monto,
                "pago": pago,
                "estado_pago": estado_pago,
                "ip": ip,
                "timestamp": timestamp,
                "observaciones": observaciones
            })

        except Exception as e:
            logfile.write(f"Error en la transacción {i}: {str(e)}\n")

print(f"✔ CSV generado: {file_path}")
print(f"✔ Log generado: {log_path}")
