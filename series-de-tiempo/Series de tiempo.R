##' @description Practica rendimiento, riesgo y series de tiempo 
##' @author Andres Salas

# Carga de paquetes e instalación (en caso de ser necesario) ----
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, xts, tseries, forecast, lmtest, quantmod, psych, TTR,
               stats, zoo, aTSA, scales, FinTS)
options(scipen = 999)

# Definicion automatica de la ruta de trabajo -----------------------------
#if (!require("rstudioapi")) install.packages("rstudioapi")
#setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

source(file = "Setup/Pruebas residuales ARIMA.R")
# Series de tiempo --------------------------------------------------------

## Cargando y graficando los datos de pasajeros ----

data("AirPassengers")

p.air <- forecast::autoplot(AirPassengers) +
    labs(title = "Pasajeros aereos entre 1949 y 1961",
       x = "Mes", 
       y = "Número de pasajeros (1000's)") +
    theme_light() + 
    theme(panel.grid = element_blank())
p.air

## Descomposicion de los datos ----

descomposicion <- stats::decompose(x = AirPassengers, type = "additive")

p.decompose <- forecast::autoplot(decompose(x = AirPassengers, type = "additive")) +
  labs(title = "Descomposición del número de pasajeros") +
  theme_light() +
  theme(panel.grid = element_blank())
p.decompose

## Pruebas formales de raiz unitaria ----

### Dickey Fuller Aumentada ----

AirPassengers %>% aTSA::adf.test(x = .)

### Phillips Perron ----

AirPassengers %>% aTSA::pp.test(x = .)

### Kwiatkowski-Phillips-Schmidt-Shin ----

AirPassengers %>% aTSA::kpss.test(x = ., lag.short = F)

## Diferenciacion ----

# La funcion diff permite hacer la diferenciacion de la serie.
diff.air <- AirPassengers %>% diff()

p.diff.air <- forecast::autoplot(diff.air) +
  labs(title = "Serie diferenciada pasajeros aereos",
       x = "Mes", 
       y = "Pasajeros (1000's)") +
  theme_light() +
  theme(panel.grid = element_blank())
p.diff.air

## Transformacion y diferenciacion ----

trans.air <- AirPassengers %>% 
    log() %>% 
    diff()

p.trans.air <- forecast::autoplot(trans.air) +
    labs(title = "Serie diferenciada y transformada pasajeros",
       x = "Mes", 
       y = "Pasajeros (1000's)") +
    scale_y_continuous(labels = label_percent()) +
    theme_light() +
    theme(panel.grid = element_blank())
p.trans.air

# Descomposicion de la serie transformada y diferenciada del numero de pasajeros
forecast::autoplot(stats::decompose(x = trans.air, type = "additive")) +
  labs(title = "Descomposición de transformación número de pasajeros") +
  theme_light() + 
  theme(panel.grid = element_blank())

# Pruebas de raices unitarias en la serie transformada

trans.air %>%
    aTSA::adf.test()

trans.air %>% 
    aTSA::pp.test(x = .)

## Identificacion ----

# Se emplea el acf para identificar el orden q de la parte media movil
forecast::Acf(trans.air)
# El pacf se emplea para identificar el orden p de la parte autoregresiva
forecast::Pacf(trans.air)

## Difrenciacion estacional ----

# Con el parametro lag de la funcion diff se determina el orden de la diferencia
# para casos estacionales.

diff.estacional <- diff(x = trans.air, lag = 4)

forecast::autoplot(diff.estacional) +
  labs(title = "Serie transformada con diferencia estacional [4]") +
  theme_light() + 
  theme(panel.grid = element_blank())

forecast::Acf(diff.estacional)
forecast::Pacf(diff.estacional)

## Ajuste del modelo  ----

# Al momento de ajustar el modelo se emplea order para los parametros (p,d,q).
# El parametro seasonal para los valores (P,D,Q) y el numero de periodos de la
# estacionalidad.
# El valor lambda = 0, hace referencia a la transformacion logaritmo natural.
# Esto facilita el proceso de pronostico.
fitARIMA <- forecast::Arima(y = AirPassengers,
                            order = c(1,1,1), 
                            seasonal = list(order = c(1,1,3), period = 4),
                            lambda = 0)
fitARIMA

#La funcion coeftest permite observal los coeficientes del modelo y sus pruebas
#de significancia.
lmtest::coeftest(fitARIMA)

# Se generan los residuales del modelo estimado
residuals <- fitARIMA$residuals

# Se calcula la media para observar si se aproxima a 0
mean(residuals)
t.test(residuals)

# Se grafican los residuales para observar su comportamiento
forecast::autoplot(residuals)

# Se grafica el acf para observar si existe la posibilidad de problemas de
# autocorrelacion
forecast::Acf(residuals, lag.max=20)

# Se realiza la prueba formal de autocorrelacion de Ljung-Box
tabla.Box.Pierce(residuo = residuals, max.lag = 20, type = "Ljung-Box")

# El grafico acf de los residuales al cuadrado permite una idea de la exitencia
# de heterocedasticidad condicionada (No varianza constante)
forecast::Acf(residuals^2, lag.max=20)

# La prueba de Ljung-Box aplicada a los residuales al cuadrado es una buena
# aproximacion a la existencia de problemas de varianza no constante.
tabla.Box.Pierce(residuo = residuals^2, max.lag = 20, type = "Ljung-Box")
tabla.ARCH.LM(residuo = residuals, max.lag = 20)

# Grafico QQ para observar normalidad
stats::qqnorm(residuals)
stats::qqline(residuals)

# Prueba formal de normalidad de Jarque Bera
tseries::jarque.bera.test(residuals)

## Correcion del modelo ----

fitARIMA.ajustado <- forecast::Arima(y = AirPassengers,
                                     order = c(0,1,0), 
                                     seasonal = list(order = c(5,1,1), period = 4),
                                     lambda = 0)
fitARIMA.ajustado

lmtest::coeftest(fitARIMA.ajustado)

residuals.ajustado <- fitARIMA.ajustado$residuals
mean(residuals.ajustado)
t.test(residuals.ajustado)

forecast::autoplot(residuals.ajustado) +
  labs(title = "Residuales del modelo ajustado") +
  theme_light() +
  theme(panel.grid = element_blank())

forecast::Acf(residuals.ajustado, lag.max=20)

tabla.Box.Pierce(residuo = residuals.ajustado, max.lag = 20, type = "Ljung-Box")

forecast::Acf(residuals.ajustado^2, lag.max=20)
tabla.Box.Pierce(residuo = residuals.ajustado^2, max.lag = 20, type = "Ljung-Box")
tabla.ARCH.LM(residuo = residuals.ajustado, max.lag = 20)

stats::qqnorm(residuals.ajustado)
stats::qqline(residuals.ajustado)

tseries::jarque.bera.test(residuals.ajustado)

## Realizando los pronosticos ----

# La funcion forecast permite pronosticar h periodos a partir del modelo.
pronostico.pasajeros <- forecast::forecast(object = fitARIMA.ajustado, 
                                           h = 4)
pronostico.pasajeros
forecast::autoplot(pronostico.pasajeros) +
  labs(title = "Pronostico número de pasajeros",
       x = "Mes", 
       y = "Pasajeros (1000's)") +
  theme_light() + 
  theme(panel.grid = element_blank())

## Usando el metodo automatico----

# El metodo automatico permite al programa buscar el que pueda ser el mejor 
# modelo a partir de los coeficientes de informacion.
# En este caso es muy importante asegurarse del cumplimiento de los 
# supuestos
auto.ARIMA <- forecast::auto.arima(y = AirPassengers, 
                                   stepwise = F, 
                                   lambda = 0)

auto.ARIMA

lmtest::coeftest(auto.ARIMA)

residual.auto <- auto.ARIMA$residuals
mean(residual.auto)
t.test(residual.auto)

autoplot(residual.auto) +
  labs(title = "Residuales del modelo automatico") +
  theme_light() +
  theme(panel.grid = element_blank())

forecast::Acf(residual.auto, lag.max=20)
tabla.Box.Pierce(residuo = residual.auto, max.lag = 20, type = "Ljung-Box")

forecast::Acf(residual.auto^2, lag.max=20)
tabla.Box.Pierce(residuo = residual.auto^2, max.lag = 20, type = "Ljung-Box")
tabla.ARCH.LM(residuo = residual.auto, max.lag = 20)

stats::qqnorm(residual.auto)
stats::qqline(residual.auto)

tseries::jarque.bera.test(residual.auto)

pronostico.auto.pasajeros <- forecast::forecast(object = auto.ARIMA,
                                                h = 4)
pronostico.auto.pasajeros
forecast::autoplot(pronostico.auto.pasajeros) +
  labs(title = "Pronostico número de pasajeros",
       x = "Mes", 
       y = "Pasajeros (1000's)") +
  theme_light() +
  theme(panel.grid = element_blank())
