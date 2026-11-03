# Funcionamiento y decisiones de la app

Este documento registra cómo debe comportarse la app y los supuestos detrás de
sus cálculos. El guion de producto compartido por el usuario es la referencia
general; esta página anota en particular las decisiones acordadas durante el
desarrollo. Actualizarla cuando se añadan o cambien reglas funcionales.

## Navegación y ajustes

La barra inferior contiene, en este orden, Registro, Gráficas, Agua, Medidas y Calculadora.
El icono de persona de la barra superior abre **Perfil** y el engranaje abre Ajustes;
**Cerrar sesión** está dentro de
esa pantalla, en la sección Cuenta. Al cerrar sesión, la app vuelve a Inicio de
sesión y confirma la acción con un diálogo.

Perfil permite guardar un nombre visible junto al correo de la cuenta y, si
existe, muestra los datos guardados de la calculadora con las unidades elegidas.
En **Recordatorios**, se pueden configurar hasta diez horas diarias y elegir
entre recibir avisos siempre o solo mientras no se haya guardado peso ni kcal
ese día. Al registrar peso o calorías con el modo condicional, los avisos que
queden ese día se posponen hasta el día siguiente. Los horarios se guardan por
usuario en Firestore; las notificaciones son locales del dispositivo y se
reprograman al iniciar sesión. Se requiere permiso del sistema operativo.
También muestra dos rachas: **Racha de registro** cuenta días consecutivos con
un registro de peso o calorías; **Racha de kcal** cuenta días consecutivos cuyo
total queda dentro del margen del objetivo diario. Si hoy aún no hay registro,
la racha actual se mantiene durante el día cuando hubo actividad ayer. Se
muestran la racha actual y la mejor racha histórica.

Reúne dos logros con los mismos rangos:
**Constancia** cuenta los días únicos en los que se haya guardado un registro
de peso o de calorías; **Constancia con kcal** cuenta los días con un total de
calorías dentro del margen del objetivo diario. Los rangos son Bronce (3 días),
Plata (7), Oro (14), Esmeralda (30) y Diamante (60). Una barra muestra el
progreso hacia el rango siguiente; los recuentos son acumulados, no exigen días
consecutivos. El logro de kcal empieza cuando se guarda un objetivo diario.

En Registro, las listas **Últimos pesos** y **Últimas calorías** muestran como
máximo tres registros cada una.

En Ajustes se puede seleccionar tema (Sistema, Claro u Oscuro), unidad de peso
(kg o lb) y unidad de longitud/altura (cm o pulgadas). Los cambios se aplican
inmediatamente y se sincronizan en Firestore.

## Resumen semanal

- **Kcal restantes** muestra el objetivo diario de calorías menos el total
  registrado para la fecha de hoy. El resultado mínimo es cero. Si no hay
  objetivo de calorías, se muestra «Sin objetivo».
- La fila aparece en el resumen cuando la vista seleccionada es Semana. El
  cálculo siempre se refiere a hoy, incluso si se navega a otra semana.
- **Tiempo hasta el peso objetivo** aparece cuando hay un perfil de calculadora
  con meta «Ganar peso», un objetivo diario de calorías y un peso objetivo mayor
  que el peso actual. Si ya se alcanzó o superó el peso objetivo, muestra
  «Objetivo alcanzado».

## Calculadora de calorías

La pestaña pide edad, sexo usado por la fórmula, altura, peso actual, nivel de
actividad y meta (perder, mantener o ganar peso).

El gasto en reposo se estima con Mifflin-St Jeor:

- Hombre: `10 × peso (kg) + 6,25 × altura (cm) − 5 × edad + 5`.
- Mujer: `10 × peso (kg) + 6,25 × altura (cm) − 5 × edad − 161`.

El mantenimiento estimado es el gasto en reposo multiplicado por el factor de
actividad seleccionado:

| Actividad | Factor |
| --- | ---: |
| Sedentaria | 1,2 |
| Ligera (1–3 días por semana) | 1,375 |
| Moderada (3–5 días por semana) | 1,55 |
| Alta (6–7 días por semana) | 1,725 |
| Muy alta | 1,9 |

La app sugiere mantenimiento para «Mantener peso», mantenimiento menos 300 kcal
para «Perder peso» o mantenimiento más 300 kcal para «Ganar peso». El resultado
se redondea a múltiplos de 50 kcal. La persona debe pulsar **Guardar kcal como
objetivo** para guardar el perfil y aplicar las kcal sugeridas al objetivo diario
que usan las gráficas.

La fórmula limita la entrada a personas de 19 a 78 años, 100–250 cm y 30–300 kg.
El resultado es orientativo, no una medición del gasto real ni consejo médico.
La pantalla indica cuánto tiempo ha pasado desde la última vez que se guardó el
perfil y recomienda revisarlo cada 4 semanas, o antes si cambia el peso o la
actividad. La fecha se actualiza al guardar el perfil con el objetivo calculado.

### Meta de ganar peso

Al seleccionar «Ganar peso», la calculadora pide **¿A qué peso quieres llegar?**.
El valor debe ser mayor que el peso actual. Al guardar, se conserva como objetivo
de peso de la app, junto con el objetivo diario de calorías.

## Tiempo estimado para ganar peso

La estimación que aparece en el resumen semanal sigue estos pasos:

1. Usa como peso actual el registro de peso más reciente; si no hay ninguno,
   usa el peso introducido en la calculadora.
2. Recalcula el mantenimiento con ese peso actual y el resto de datos guardados
   del perfil (edad, sexo, altura y actividad).
3. Calcula el superávit como objetivo diario de calorías menos mantenimiento.
4. Si no hay superávit, informa que las kcal guardadas no superan el
   mantenimiento estimado. Si el peso actual ya alcanza el objetivo, informa
   «Objetivo alcanzado».
5. Si hay superávit, estima los días con una conversión simplificada de
   `7.700 kcal por kg`: `(peso objetivo − peso actual) × 7.700 ÷ superávit diario`.
   La tarjeta presenta el resultado en días, semanas o meses aproximados.

Es una proyección inicial y no modela la adaptación del gasto energético, los
cambios de composición corporal ni los errores de la estimación de mantenimiento.
Por eso no debe interpretarse como una fecha fiable. El valor de 7.700 kcal/kg
es una simplificación conocida; los modelos dinámicos muestran que la respuesta
del peso cambia con el tiempo ([Hall et al., 2011](https://pubmed.ncbi.nlm.nih.gov/21872751/),
[NIDDK Body Weight Planner](https://www.niddk.nih.gov/research-funding/at-niddk/labs-branches/laboratory-biological-modeling/integrative-physiology-section/research/body-weight-planner)).

## Persistencia

El perfil de la calculadora y los objetivos se guardan en el documento de ajustes
del usuario en Firestore. El perfil incluye edad, sexo de fórmula, altura, peso,
actividad y meta. El objetivo de peso se guarda en el mismo campo que usan las
gráficas y los demás resúmenes. Las preferencias de tema y unidades también se
guardan ahí. Los registros de peso y las medidas lineales se conservan en kg y
cm; la app convierte los valores al mostrarlos y al recibir entradas en lb o
pulgadas. Cambiar unidades o guardar otro campo no vuelve a escribir un peso o
medida que no se haya editado, para evitar cambios de precisión por redondeo.
La grasa corporal permanece en porcentaje.

## Referencias de las fórmulas

- [Mifflin-St Jeor et al., 1990: ecuación de gasto energético en reposo](https://pubmed.ncbi.nlm.nih.gov/2305711/).
- [Hall et al., 2011: dinámica del desequilibrio energético y el peso](https://pubmed.ncbi.nlm.nih.gov/21872751/).
