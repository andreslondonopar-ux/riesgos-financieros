##' @description Practica rendimiento, riesgo y series de tiempo
##' @author Andres Salas

#' # Series de tiempo: ARIMA sobre pasajeros aéreos
#'
#' Guía rápida de qué hace cada bloque de código, en el mismo orden en que
#' aparece. Estos comentarios no son del script original de clase — se
#' agregaron aparte para que el reporte se pueda leer paso a paso sin tener
#' que interpretar el código línea por línea.

#' ## 0. Cargar paquetes
#' `pacman::p_load()` instala (si hace falta) y carga de una sola vez todos
#' los paquetes que se van a usar: manejo de series (`xts`, `zoo`), pruebas
#' de raíz unitaria (`aTSA`), modelos ARIMA (`forecast`), pruebas de
#' significancia (`lmtest`) y heterocedasticidad (`FinTS`).
# Carga de paquetes e instalación (en caso de ser necesario) ----
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, xts, tseries, forecast, lmtest, quantmod, psych, TTR,
               stats, zoo, aTSA, scales, FinTS)
options(scipen = 999)

# Definicion automatica de la ruta de trabajo -----------------------------
#if (!require("rstudioapi")) install.packages("rstudioapi")
#setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

#' `source()` ejecuta el archivo `Setup/Pruebas residuales ARIMA.R`, que
#' define dos funciones auxiliares que se usan más abajo: `tabla.Box.Pierce()`
#' (prueba de autocorrelación de residuales) y `tabla.ARCH.LM()` (prueba de
#' heterocedasticidad condicional).
source(file = "Setup/Pruebas residuales ARIMA.R")
# Series de tiempo --------------------------------------------------------

#' ## 1. Cargar y graficar la serie
#' `AirPassengers` es el dataset clásico de pasajeros aéreos mensuales
#' (1949-1961), incluido en R base. Se grafica primero para ver a simple
#' vista si hay tendencia y/o estacionalidad, antes de correr nada formal.
## Cargando y graficando los datos de pasajeros ----

data("AirPassengers")

p.air <- forecast::autoplot(AirPassengers) +
    labs(title = "Pasajeros aereos entre 1949 y 1961",
       x = "Mes",
       y = "Número de pasajeros (1000's)") +
    theme_light() +
    theme(panel.grid = element_blank())
p.air

#' ## 2. Descomponer la serie
#' `decompose()` separa la serie en sus 4 componentes (tendencia, estacional,
#' cíclico/aleatorio) — confirma visualmente lo que ya se veía en el gráfico
#' anterior: tendencia creciente y un patrón que se repite cada 12 meses.
## Descomposicion de los datos ----

descomposicion <- stats::decompose(x = AirPassengers, type = "additive")

p.decompose <- forecast::autoplot(decompose(x = AirPassengers, type = "additive")) +
  labs(title = "Descomposición del número de pasajeros") +
  theme_light() +
  theme(panel.grid = element_blank())
p.decompose

#' ## 3. Probar estacionariedad (sobre la serie original)
#' Las 3 pruebas de raíz unitaria (ADF, Phillips-Perron, KPSS) sobre la serie
#' <strong>en niveles</strong>, sin transformar todavía — el resultado
#' esperado es que NO sea estacionaria (hay tendencia visible), lo que
#' justifica transformar y diferenciar a continuación.
## Pruebas formales de raiz unitaria ----

### Dickey Fuller Aumentada ----

AirPassengers %>% aTSA::adf.test(x = .)

### Phillips Perron ----

AirPassengers %>% aTSA::pp.test(x = .)

### Kwiatkowski-Phillips-Schmidt-Shin ----

AirPassengers %>% aTSA::kpss.test(x = ., lag.short = F)

#' ## 4. Diferenciar (sin transformar todavía)
#' Un primer vistazo de qué hace `diff()` por sí solo (sin log), solo para
#' comparar contra el paso siguiente — elimina la tendencia pero la varianza
#' sigue sin estabilizarse (se nota que las oscilaciones crecen con el tiempo).
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

#' ## 5. Transformar (log) + diferenciar — la combinación correcta
#' Ahora sí, `log()` primero (estabiliza varianza) y `diff()` después (quita
#' tendencia) — el orden importa, ver el glosario de la guía de resumen. El
#' resultado (`trans.air`) es, en la práctica, el log-retorno mensual de
#' pasajeros: una serie mucho más plana y con varianza más estable que las
#' anteriores.
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

#' Se repiten las pruebas de raíz unitaria, ahora sobre la serie ya
#' transformada y diferenciada — para confirmar que con esto ya alcanza
#' (d=1) y no hace falta diferenciar una segunda vez.
# Pruebas de raices unitarias en la serie transformada

trans.air %>%
    aTSA::adf.test()

trans.air %>%
    aTSA::pp.test(x = .)

#' ## 6. Identificar candidatos de p y q (ACF / PACF)
#' Con la serie ya estacionaria, se calculan ACF (ayuda a leer q) y PACF
#' (ayuda a leer p) — de acá salen los valores candidatos que se prueban más
#' abajo al ajustar el modelo.
## Identificacion ----

# Se emplea el acf para identificar el orden q de la parte media movil
forecast::Acf(trans.air)
# El pacf se emplea para identificar el orden p de la parte autoregresiva
forecast::Pacf(trans.air)

#' ## 7. Diferencia estacional
#' Si en la ACF/PACF anterior quedan picos que se repiten cada N rezagos, hay
#' estacionalidad residual — se aplica una diferencia estacional (`lag=4` en
#' este ejemplo) y se vuelve a mirar ACF/PACF sobre esa serie.
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

#' ## 8. Ajustar el primer modelo candidato
#' `Arima()` recibe el orden no estacional `order=c(p,d,q)`, el orden
#' estacional `seasonal=list(order=c(P,D,Q), period=S)`, y `lambda=0` (para
#' que el pronóstico revierta la transformación log automáticamente). Este
#' es un primer candidato con p=1,d=1,q=1 y estacional (1,1,3).
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

#' ## 9. Validar los residuales del primer modelo
#' Los 4 supuestos en orden: media cero (t-test), no autocorrelación
#' (ACF + Ljung-Box), varianza constante (Ljung-Box sobre residuales² +
#' ARCH-LM) y normalidad (QQ-plot + Jarque-Bera). Si algo falla acá, hay que
#' volver al paso 8 y probar otro orden — eso es justo lo que pasa a
#' continuación (paso 10).
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

#' ## 10. Corregir y reajustar el modelo
#' Segundo candidato, con otro orden (p=0,d=1,q=0 y estacional (5,1,1)) — y
#' se repite exactamente la misma batería de validación de residuales del
#' paso 9 sobre este modelo corregido.
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

#' ## 11. Pronosticar con el modelo corregido
#' Con el modelo ya validado, `forecast(modelo, h=4)` pronostica 4 meses
#' hacia adelante. Gracias a `lambda=0` (paso 8), el resultado ya viene en
#' número real de pasajeros, no en log-retorno.
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

#' ## 12. Comparar contra la búsqueda automática (auto.arima)
#' En vez de conjeturar p,q a mano (pasos 6-10), `auto.arima()` prueba muchos
#' modelos candidatos y se queda con el mejor AIC/BIC — acá con
#' `stepwise=FALSE` (busca todas las combinaciones, no solo un atajo greedy).
#' Sigue haciendo falta correr la misma validación de residuales sobre lo que
#' devuelva, no es garantía de que pase la batería.
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

#' ## 13. Pronóstico final (con el modelo de auto.arima)
#' Mismo paso que en 11, pero sobre el modelo que encontró `auto.arima()` —
#' este es el pronóstico que queda citado en la guía de resumen de la
#' materia (SARIMA(0,1,1)(0,1,1)[12]).
pronostico.auto.pasajeros <- forecast::forecast(object = auto.ARIMA,
                                                h = 4)
pronostico.auto.pasajeros
forecast::autoplot(pronostico.auto.pasajeros) +
  labs(title = "Pronostico número de pasajeros",
       x = "Mes",
       y = "Pasajeros (1000's)") +
  theme_light() +
  theme(panel.grid = element_blank())
