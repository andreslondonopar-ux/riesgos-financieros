## Examen parcial - Parte Practica (ejercicio de practica) ----
## Gerencia de Riesgos Financieros
## Instrumento de practica: Micron Technology (MU)
## (mismo flujo de la parte practica del examen real, aplicado a otro
##  instrumento para poder practicar el procedimiento completo)

## 1. Descarga de precios y calculo de retornos ----
## Precios de cierre ajustado, frecuencia diaria, de MU entre el
## 2024-08-31 y el 2026-09-04 (via Yahoo Finance).
if (!require("pacman")) install.packages("pacman")
pacman::p_load(quantmod, tidyverse, tseries, aTSA, forecast, lmtest, scales)
options(scipen = 999)

mu_xts <- getSymbols("MU", src = "yahoo",
                      from = "2024-08-31", to = "2026-09-04",
                      auto.assign = FALSE)
mu_precio <- Ad(mu_xts)
colnames(mu_precio) <- "MU"

forecast::autoplot(mu_precio) +
  labs(title = "MU — precio de cierre ajustado (diario)", x = "Fecha", y = "USD") +
  theme_light() + theme(panel.grid = element_blank())

## **Retornos continuos (log-retornos)**: \( r_t = \log(P_t) - \log(P_{t-1}) \).
mu_ret <- diff(log(mu_precio))
mu_ret <- na.omit(mu_ret)

forecast::autoplot(mu_ret) +
  labs(title = "MU — retornos continuos (diarios)", x = "Fecha", y = "Retorno") +
  theme_light() + theme(panel.grid = element_blank())

## **Interpretación del gráfico de retornos**: a diferencia del precio (que
## sube con tendencia clara), los retornos oscilan alrededor de un nivel
## parejo cercano a cero, sin tendencia — la firma visual típica de una
## serie ya estacionaria. Se ven además "clusters" de volatilidad (rachas de
## oscilaciones grandes seguidas de rachas más calmadas), el hecho estilizado
## que después motiva agregar un modelo ARCH/GARCH.
##
## ## 2. Estadísticas descriptivas de los retornos
## Estadisticas descriptivas ----
media_ret    <- mean(mu_ret)
sd_ret       <- sd(mu_ret)
min_ret      <- min(mu_ret)
max_ret      <- max(mu_ret)
mediana_ret  <- median(mu_ret)

fecha_min <- index(mu_ret)[which.min(mu_ret)]
fecha_max <- index(mu_ret)[which.max(mu_ret)]

tabla_desc <- data.frame(
  Estadística = c("Media", "Desviación estándar", "Mínimo", "Máximo", "Mediana"),
  Valor       = c(media_ret, sd_ret, min_ret, max_ret, mediana_ret)
)
knitr::kable(tabla_desc, digits = 5)

## **a. La media** (0.4756%): el retorno diario promedio de MU en el período
## es positivo — coherente con el rally enorme que ya se ve en el gráfico de
## precios (de ~USD 88 a ~USD 958). En términos anualizados (×252 días
## hábiles) equivale a un retorno esperado de más de 100% anual — un
## desempeño extraordinario, no lo típico de una acción promedio.
##
## **b. La desviación estándar** (4.50%): mide la volatilidad diaria — un
## retorno diario típico se mueve ±4.5 puntos porcentuales alrededor de la
## media. Es una volatilidad alta (los índices amplios como el S&P 500 suelen
## moverse ±1% diario en periodos normales); consistente con ser una acción
## individual de semiconductores, sector conocido por su ciclicidad y
## sensibilidad a noticias de demanda de chips/IA.
##
## **c. El mínimo** (-17.65%, el 2024-12-19): la peor caída de un solo día
## en todo el período — una caída de esta magnitud normalmente refleja una
## sorpresa negativa puntual (ej. resultados trimestrales peor de lo
## esperado, guidance débil), no un movimiento típico del mercado en general.
##
## **d. El máximo** (+17.64%, el 2026-05-26): la mejor subida de un solo día
## — de magnitud casi idéntica al mínimo (17.65% vs 17.64%), lo que sugiere
## que ambos extremos vienen del mismo tipo de evento (reacción a noticias
## puntuales de la empresa), no de un movimiento gradual del mercado.
##
## **e. La mediana** (0.346%): está por debajo de la media (0.476%) — cuando
## la media es mayor que la mediana, es señal de **asimetría hacia la
## derecha** (positiva): unos pocos retornos extremadamente altos (como el
## +17.64%) empujan el promedio hacia arriba, mientras que el retorno
## "típico" de un día cualquiera (la mediana) es más modesto. Esto conecta
## directo con el hecho estilizado de colas pesadas que ya vimos: la
## distribución de retornos no es simétrica ni normal.

## 3. ¿Es necesario diferenciar el precio diario para hacerlo estacionario? ----
## Se corren las 3 pruebas de raíz unitaria (ADF, Phillips-Perron, KPSS)
## sobre el PRECIO en niveles (no sobre el retorno).
precio_num <- as.numeric(mu_precio)

cat("=== ADF sobre el precio ===\n")
print(aTSA::adf.test(precio_num))

cat("\n=== Phillips-Perron sobre el precio ===\n")
print(aTSA::pp.test(precio_num))

cat("\n=== KPSS sobre el precio ===\n")
print(aTSA::kpss.test(precio_num, lag.short = FALSE))

## Interpretación:
## - ADF: en las 3 especificaciones (sin deriva/tendencia, con deriva,
##   con deriva y tendencia) el p-value es muy alto (>0.6 en todos los
##   rezagos probados) -> NO se rechaza H0 (hay raíz unitaria) -> NO es
##   estacionario.
## - Phillips-Perron: mismo resultado -- p-values entre 0.68 y 0.98,
##   no se rechaza H0 en ninguna especificación -> confirma no estacionario.
## - KPSS: aquí la H0 está invertida (H0 = SÍ es estacionaria). Con
##   deriva/tendencia (type 3) el p-value es 0.075 -- rechazaría al 10%
##   pero no al 5%; sin tendencia (type 1/2) no rechaza. Es un resultado
##   borderline, pero dado que ADF y PP coinciden con total claridad (y
##   el gráfico de la serie 1 muestra una tendencia enorme, de ~88 a
##   ~958 USD) el peso de la evidencia es claro.
##
## CONCLUSIÓN: sí es necesario diferenciar el precio -- no es
## estacionario en niveles. d=1 (una diferencia regular) es el punto de
## partida natural, a confirmar repitiendo las pruebas sobre la serie
## ya diferenciada.
precio_diff <- diff(precio_num)
precio_diff <- precio_diff[!is.na(precio_diff)]

cat("\n=== ADF sobre el precio YA diferenciado (d=1) ===\n")
print(aTSA::adf.test(precio_diff))

cat("\n=== Phillips-Perron sobre el precio YA diferenciado (d=1) ===\n")
print(aTSA::pp.test(precio_diff))

## Con una sola diferencia, ADF y PP ya rechazan H0 con claridad
## (p<=0.01 en la mayoría de especificaciones) -> con d=1 alcanza.
