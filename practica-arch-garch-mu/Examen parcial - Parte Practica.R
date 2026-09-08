## Examen parcial - Parte Practica
## Gerencia de Riesgos Financieros
## Instrumento: Micron Technology (MU)

if (!require("pacman")) install.packages("pacman")
pacman::p_load(quantmod, tseries, aTSA, forecast, lmtest, ggplot2)
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

# ADF y PP: no rechazan H0 (p>0.6) -> hay raiz unitaria -> no estacionario.
# KPSS: borderline, pero ADF+PP+tendencia visible coinciden -> hay que
# diferenciar.

precio_diff <- diff(precio_num)

adf.test(precio_diff)
pp.test(precio_diff)

# Con d=1, ADF y PP ya rechazan H0 (p<=0.01) -> una diferencia alcanza.
