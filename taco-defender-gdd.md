# Documento de Diseño de Juego (GDD) - Versión 1.1
**Proyecto:** Taco Defender  
**Estudio:** GuacamoleBit  
**Plataforma:** Android / iOS (Mobile)  
**Género:** Tower Defense Casual  

---

## 1. Visión General

**Taco Defender** es un juego de estrategia hipercasual donde el jugador coloca torres de ingredientes picantes y refrescantes para defender la barra de una taquería contra oleadas de plagas hambrientas. Diseñado para sesiones rápidas de 3 a 5 minutos.

---

## 2. Reglas del Juego y Economía In-Game

* **Condición de Victoria:** Sobrevivir a 10 oleadas consecutivas.
* **Condición de Derrota:** Que los enemigos que lleguen al final del camino reduzcan la Vida de la Barra a 0 (Vida Inicial Base = 3).
* **Economía In-Game:**
  * **Oro Inicial al empezar partida:** $100.
  * **Venta de Torres:** Otorga el 70% del valor total invertido en la torre.
  * **Transición de Oleadas:** Botón manual "Iniciar Oleada" o auto-start tras 5 segundos.
* **Controles:**
  * **Tap:** Seleccionar casilla libre para construir / Tap sobre torre construida para ver rango, mejorar o vender.
  * **Drag:** Desplazar la cámara por el escenario.

---

## 3. Matriz de Entidades

### Enemigos
*Lógica de Movimiento:* Siguen el Path fijo hacia la Taquería.  
*Targeting de Torres:* Por defecto, las torres atacan al enemigo más cercano al final del camino (*First*).

| Tipo | Vida (HP) | Velocidad | Recompensa | Apariencia Visual |
| :--- | :--- | :--- | :--- | :--- |
| **Básico** | 10 | 80 px/s | $5 | Mosca común |
| **Rápido** | 5 | 200 px/s | $8 | Cucaracha veloz |
| **Tank** | 100 | 30 px/s | $25 | Ratón de carga pesado |

### Torres y Escalado In-Game (Upgrades)
Las torres se pueden mejorar dentro de la partida hasta Nivel 3.

| Torre | Costo Base | Daño | Rango | Cooldown | Efecto / Escalado |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Salsa Verde** | $50 | 15 | 150 px | 1.2s | Disparo único. Upgrade (+ $35): +5 Daño, +15 Rango. |
| **Hielo Horchata**| $75 | 8 | 120 px | 1.5s | Ralentiza 50% por 2s. Upgrade (+ $50): +25% Duración ralentizado. |
| **Catapulta Guac**| $120 | 25 | 200 px | 2.5s | Daño en Área ($R=50\text{px}$). Upgrade (+ $80$): +10 Daño AoE. |

---

## 4. Diseño de las 10 Oleadas (Spawning)

1. **Oleada 1:** 5 Básicos (intervalo 1.5s)
2. **Oleada 2:** 8 Básicos (intervalo 1.2s)
3. **Oleada 3:** 5 Básicos + 3 Rápido (intervalo 1.0s)
4. **Oleada 4:** 10 Rápido (intervalo 0.6s)
5. **Oleada 5:** 6 Básicos + 1 Tank (intervalo 1.0s)
6. **Oleada 6:** 12 Rápido + 2 Tank (intervalo 0.8s)
7. **Oleada 7:** 15 Básicos + 8 Rápido (intervalo 0.5s)
8. **Oleada 8:** 4 Tank + 10 Rápido (intervalo 1.0s)
9. **Oleada 9:** Enjambre: 20 Básicos + 15 Rápido (intervalo 0.4s)
10. **Oleada Final:** 6 Tank + 15 Rápido + 10 Básicos (intervalo 0.5s)

---

## 5. Metagame y Tienda Permanente

### Moneda de Propina (Recompensas)
* **Oleada superada:** 10 Propinas.
* **Bono por Victoria (Oleada 10):** 50 Propinas adicionales.

### Upgrades Permanentes (Tienda Menú Principal)
Cada mejora tiene 5 niveles. Costo por nivel: **100 / 250 / 500 / 1000 / 2000 Propinas**.

1. **Salsa Más Picante:** $+5\%$ daño global por nivel.
2. **Vista de Águila:** $+5\%$ rango global por nivel.
3. **Despacho Rápido:** $-3\%$ cooldown global por nivel.
4. **Clientes Generosos:** $+10\%$ multiplicador de propinas ganadas.
5. **Barra Blindada:** Vida inicial de la Taquería ($3 \rightarrow 4 \rightarrow 5 \rightarrow 6 \rightarrow 7$).

## 6. Bocetos (solo como ejemplo o guía)

1. bocetos/Taco-Defender-ejemplo.png
2. bocetos/Taco-Defender-Como-Jugar.png
