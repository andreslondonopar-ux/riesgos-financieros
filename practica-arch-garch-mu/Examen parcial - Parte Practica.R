## Examen parcial - Parte Practica
## Gerencia de Riesgos Financieros
## Instrumento: Micron Technology (MU)

if (!require("pacman")) install.packages("pacman")
pacman::p_load(quantmod, tseries, aTSA, forecast, lmtest, ggplot2, FinTS)
options(scipen = 999)

## 1. Precios y retornos ----
mu_xts <- getSymbols("MU", src = "yahoo",
                      from = "2024-08-31", to = "2026-09-04",
                      auto.assign = FALSE)
precio <- Ad(mu_xts)
colnames(precio) <- "MU"

autoplot(precio) +
  labs(title = "MU - precio de cierre ajustado", x = "Fecha", y = "USD")

# Tendencia creciente clara (de ~88 a ~958 USD) -> no estacionaria en niveles.

retorno <- na.omit(diff(log(precio)))

autoplot(retorno) +
  labs(title = "MU - retorno continuo diario", x = "Fecha", y = "Retorno")

# Retornos oscilan alrededor de cero, sin tendencia -> ya estacionarios.

## 2. Estadisticas descriptivas de los retornos ----
media   <- mean(retorno)
desv    <- sd(retorno)
minimo  <- min(retorno)
maximo  <- max(retorno)
mediana <- median(retorno)

c(media = media, sd = desv, min = minimo, max = maximo, mediana = mediana)

# a. Media (0.48% diario): retorno promedio positivo, consistente con el
#    rally del precio en el periodo.
# b. Desviacion estandar (4.50% diario): volatilidad alta para una accion.
# c. Minimo (-17.65%): peor caida de un solo dia, evento puntual.
# d. Maximo (+17.64%): mejor subida de un solo dia, evento puntual.
# e. Mediana (0.35%) < media (0.48%): asimetria positiva, la distribucion
#    no es simetrica ni normal.

## 3. Raices unitarias sobre el precio ----
precio_num <- as.numeric(precio)

adf.test(precio_num)
pp.test(precio_num)
kpss.test(precio_num, lag.short = FALSE)

precio_diff <- diff(precio_num)

adf.test(precio_diff)
pp.test(precio_diff)

# Con d=1, ADF y PP ya rechazan H0 (p<=0.01) -> una diferencia alcanza.

## 4. Modelo ARIMA sobre los retornos ----
r <- as.numeric(retorno)
modelo <- auto.arima(r, stepwise = FALSE)
modelo
coeftest(modelo)

# a. Al 10% de significancia: todos los coeficientes son significativos
#    (ar1, ar2, ma1, ma2 con p<0.001; intercepto con p=0.018) -> los 4
#    rezagos aportan al modelo, ninguno sobra.
# b. Modelo ARIMA(2,0,2): 2 rezagos AR y 2 rezagos MA. Significa que el
#    retorno de hoy depende de sus propios 2 valores pasados (parte AR)
#    Y de los errores de los ultimos 2 periodos (parte MA) a la vez -- un
#    ARMA(2,2), sin necesidad de diferenciar mas (d=0, el retorno ya era
#    estacionario).

## 5. Validacion de supuestos del modelo ----
res <- residuals(modelo)

t.test(res)
Box.test(res, lag = 10, type = "Ljung-Box")
Box.test(res^2, lag = 10, type = "Ljung-Box")
FinTS::ArchTest(res, lags = 10)
jarque.bera.test(res)

# Media cero: no se rechaza (p=0.987) -> cumple.
# Autocorrelacion (Ljung-Box): no se rechaza a 10 rezagos (p=0.485), pero
# SI se rechaza a 20 rezagos (p=0.009) -> resultado mixto, hay algo de
# autocorrelacion residual a rezagos mas largos.
# Varianza constante (Ljung-Box^2 y ARCH-LM): se rechaza en ambas
# (p=3.5e-06 y p=0.0012) -> SI hay heterocedasticidad condicional -> no
# toca p,d,q, hay que agregar ARCH/GARCH.
# Normalidad (Jarque-Bera): se rechaza con fuerza (p<2.2e-16) -> no son
# normales, colas pesadas -- se anota como limitacion.

## 6. Pronostico de los siguientes 5 periodos ----
pron <- forecast(modelo, h = 5)
pron

autoplot(pron) +
  labs(title = "MU - pronostico de retornos (5 periodos)", x = "Periodo", y = "Retorno")

# a. Primer pronostico: -0.14% (intervalo 95%: -8.91% a +8.62%). El punto
# central es chico y cercano a cero -- coherente con un modelo de retornos
# sin tendencia clara. El intervalo es muy ancho respecto al punto central
# (~8-9 puntos porcentuales de cada lado) porque la volatilidad diaria de
# MU es alta (sd=4.50%) y el modelo ARIMA todavia no distingue periodos de
# alta o baja volatilidad -- eso se resuelve en el siguiente punto con
# ARCH/GARCH. (Nota: al descargar datos en vivo de Yahoo, el precio
# ajustado se puede recalcular levemente entre consultas -- si vuelves a
# correr el script los numeros pueden variar un poco, pero la lectura es
# la misma.)
