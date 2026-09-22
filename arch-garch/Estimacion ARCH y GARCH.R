#' ---
#' title: "Estimación ARCH y GARCH — AMZN"
#' author: "Andrés Londoño"
#' output:
#'   html_document:
#'     toc: true
#'     toc_float: true
#'     theme: flatly
#' ---
#'
#' Continuación directa de
#' [Volatilidad histórica y EWMA](../volatilidad-historica-ewma/) sobre el mismo
#' activo (AMZN): se ajusta primero el modelo de la **media** (ARIMA), se valida
#' que sus residuales tengan varianza cambiante (heterocedasticidad), y luego se
#' modela esa varianza con **ARCH(1)** y **GARCH(1,1)**, comparando cuál deja
#' menos estructura sin explicar.

if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, xts, tseries, magrittr, ggpubr, zoo, forecast,
               quantmod, MTS, zoo, FinTS, fGarch, lmtest, scales, aTSA)

## 1. Definicion automatica de la ruta de trabajo ----
if (!require("rstudioapi")) install.packages("rstudioapi")
tryCatch(setwd(dirname(rstudioapi::getActiveDocumentContext()$path)), error = function(e) NULL)
options(scipen = 999)
source("Pruebas residuales ARIMA.R")

#' Igual que en la clase de series de tiempo, las pruebas de raíz unitaria y de
#' heterocedasticidad (ARCH-LM) que se usan más abajo no vienen de una función
#' de un solo paquete, sino de dos funciones tabuladas (`tabla.Box.Pierce` y
#' `tabla.ARCH.LM`) que corren la prueba para varios rezagos de una sola vez —
#' definidas en `Pruebas residuales ARIMA.R`, en la misma carpeta.
#'
#' ## 1. Datos y comprobación de estacionariedad
# 2. Carga de precios y calculo de retornos diarios ----

acciones <- c("AMZN")

precio <- quantmod::getSymbols(acciones, src = "yahoo",
                               from = "2023-12-31",
                               to = "2026-08-31",
                               periodicity = "daily",
                               auto.assign = TRUE,
                               warnings = FALSE) %>%
  purrr::map(~quantmod::Ad(get(.))) %>%
  purrr::reduce(merge.xts) %>%
  `colnames<-`(acciones)

retornos <- TTR::ROC(precio,
                     type = "continuous",
                     na.pad = TRUE) %>%
  na.omit()

## 2.1 Probando la existencia de raices unitarias ----

precio %>% aTSA::adf.test()
precio %>% aTSA::pp.test()
precio %>% aTSA::kpss.test()

retornos %>% aTSA::adf.test()
retornos %>% aTSA::pp.test()
retornos %>% aTSA::kpss.test()

#' **Interpretación**: sobre el **precio** (en niveles), ADF y PP no rechazan
#' la hipótesis nula de raíz unitaria en ninguna especificación (p≈0.99) — el
#' precio no es estacionario, como se espera de cualquier serie de precios con
#' tendencia. Sobre los **retornos**, en cambio, ADF y PP **sí rechazan**
#' la raíz unitaria con fuerza (p≤0.01 en las tres especificaciones) — los
#' retornos ya son estacionarios sin necesidad de diferenciarlos (son, de
#' hecho, la primera diferencia del log-precio). Con esto queda justificado
#' trabajar directamente con los retornos para el modelo ARIMA.
#'
#' ## 1.1 Heterocedasticidad, antes de ajustar cualquier modelo
tabla.ARCH.LM(residuo = retornos)

#' **Interpretación**: la prueba ARCH-LM sobre los retornos crudos ya rechaza
#' homocedasticidad desde el primer rezago (p≈0.0006) — es una primera señal,
#' *antes incluso de ajustar el ARIMA*, de que la varianza de estos retornos
#' no es constante. Esto es justo lo que motiva pasar a ARCH/GARCH más
#' adelante.
#'
#' ## 2. Modelo de la media: ARIMA
# 3. Estimación modelo de la media -------------------------------------------

## 3.1. Estimacion del modelo ARIMA ----
f.arima <- forecast::auto.arima(y = retornos,
                                stepwise = F,
                                d = 0,
                                lambda = NULL)
f.arima

#' **Hallazgo real de esta ejecución**: `auto.arima()` encontró un
#' **ARIMA(0,0,0) con media cero** — es decir, **ningún** coeficiente
#' autorregresivo ni de media móvil. Esto conecta directo con lo visto en la
#' clase de eficiencia de mercado: un ARIMA vacío (p=q=0) es la firma
#' estadística de que no hay estructura predecible en los retornos diarios de
#' AMZN con esta muestra — el mercado se comporta de forma eficiente respecto
#' a esta acción, en el sentido de esa prueba.
#'
#' **Consecuencia práctica**: un modelo sin coeficientes no tiene nada que
#' `coeftest()` pueda probar (no hay términos ni errores estándar que calcular)
#' — por eso, a diferencia de otras clases donde sí se corre `coeftest()`
#' directo, aquí se salta ese paso con una condición explícita en vez de dejar
#' que el código truene.
if (length(coef(f.arima)) > 0) {
  lmtest::coeftest(f.arima)
} else {
  cat("El modelo no tiene coeficientes que probar (ARIMA(0,0,0)).\n")
}

## 3.2. Genreacion de los residuales ----
residuals <- f.arima[["residuals"]] %>%
    xts(order.by = index(retornos$AMZN))

forecast::autoplot(residuals) +
  labs(title = "Residuales modelo AMZN") +
  theme_light() +
  theme(panel.grid = element_blank())

#' **Nota**: como el ARIMA es (0,0,0), los "residuales" del modelo son,
#' matemáticamente, los mismos retornos originales — el modelo no le restó
#' nada a la serie porque no encontró ninguna parte predecible que restar.
#'
#' ## 2.1 Validando el modelo de la media (los 4 supuestos de siempre)
forecast::Acf(residuals, lag.max=20)

## 3.3. Prueba de la media ----
t.test(x = coredata(residuals), mu = 0)

## 3.4. Prueba de autocorrelacion ----
tabla.Box.Pierce(residuo = residuals, type = "Ljung-Box")

## 3.5. Prueba de heterocedasticidad ----
tabla.Box.Pierce(residuo = residuals^2, type = "Ljung-Box")
tabla.ARCH.LM(residuo = residuals)

## 3.6. Prueba de normalidad ----
tseries::jarque.bera.test(x = residuals)

#' **Interpretación — exactamente el patrón que se esperaba (y buscaba)**:
#'
#' | Supuesto | Resultado | ¿Se cumple? |
#' |---|---|---|
#' | Media = 0 | p=0.28 | Sí |
#' | No autocorrelación (Ljung-Box) | p entre 0.40 y 0.63 en los primeros 5 rezagos | Sí |
#' | Varianza constante (Ljung-Box sobre residuales², ARCH-LM) | p entre 0.0006 y 0.008 | **No** |
#' | Normalidad (Jarque-Bera) | p≈0 | No (la menos crítica) |
#'
#' El modelo de la media está bien especificado (media cero, sin
#' autocorrelación) — el problema real es exactamente el que motiva esta
#' clase: la varianza **no** es constante. Por la jerarquía de supuestos ya
#' vista (autocorrelación indispensable de corregir, varianza no constante se
#' arregla con un modelo de volatilidad sin tocar el ARIMA), el siguiente paso
#' correcto es ajustar ARCH/GARCH sobre esta misma serie — no replantear el
#' ARIMA, que ya está bien.
#'
#' ## 3. Modelo ARCH(1)
# 4. Modela ARCH para la varianza --------------------------------------------

## 4.1. Estimacion del modelo ARCH(1) en conjunto con un ARIMA(0,0) ----
f.arch <- fGarch::garchFit(formula = AMZN ~ arma(0,0)+garch(1,0),
                           data = retornos,
                           trace = FALSE,
                           include.mean = T)
summary(f.arch)

# Eliminemos la constante de la media de la serie

f.arch <- fGarch::garchFit(formula = AMZN ~ arma(0,0)+garch(1,0),
                           data = retornos,
                           trace = FALSE,
                           include.mean = F)
summary(f.arch)

#' **Interpretación**: se corre primero con `include.mean = T` (constante
#' libre) y luego con `include.mean = F` — coherente con haber encontrado un
#' ARIMA(0,0,0) de media cero: no hace falta estimar una media aparte, ya se
#' sabe que es ≈0. El ARCH(1) resultante:
#'
#' ```
#' omega  = 0.000277  (***, p < 0.001)
#' alpha1 = 0.4229    (***, p < 0.001)
#' ```
#'
#' Ambos coeficientes son muy significativos y α₁ es positivo (cumple la
#' restricción de no negatividad de la varianza).
#'
#' ## 3.1 Validando los residuales estandarizados del ARCH(1)
residuales.arch <- fGarch::residuals(object = f.arch, standardize = T)

t.test(residuales.arch)

tabla.Box.Pierce(residuo = residuales.arch, type = "Ljung-Box")

tabla.Box.Pierce(residuo = residuales.arch^2, type = "Ljung-Box")
tabla.ARCH.LM(residuo = residuales.arch)

jarque.bera.test(residuales.arch)

#' **Interpretación**: aquí es donde se aplica el concepto de **residuo
#' estandarizado** (zₜ = εₜ/σ̂ₜ, dividiendo cada retorno por la volatilidad que
#' el propio ARCH(1) estimó para ese día) — el diagnóstico correcto de un
#' modelo de volatilidad no se hace sobre los residuales crudos, sino sobre
#' estos. Resultado: media (p=0.34) y autocorrelación en la media (p entre
#' 0.31 y 0.48) siguen bien. Pero en la varianza (Ljung-Box y ARCH-LM sobre
#' zₜ²) los primeros 3 rezagos ya pasan (p>0.39), y **el rezago 4 empieza a
#' fallar** (p≈0.035-0.038) — el ARCH(1), con solo un rezago, no alcanza a
#' capturar del todo la persistencia de la volatilidad a un poco más de
#' plazo. Exactamente la limitación de ARCH vista en teoría: para capturar
#' más persistencia hace falta más rezagos (menos parsimonioso), o pasar a
#' GARCH.
#'
#' ## 3.2 Volatilidad estimada por el ARCH(1)
## 4.3. Volatilidad estimada por el modelo ARCH ----
sigma.arch <- xts(f.arch@sigma.t, order.by = index(retornos))

## 4.5. Grafico de la volatilidad ----
p.sigma.arch <- forecast::autoplot(sigma.arch)+
    labs(title = paste("Volatilidades ARCH(1) de AMZN"),
       x = "Tiempo",
       y = "Volatilidad ARCH") +
    scale_y_continuous(labels = label_percent()) +
    theme_light() +
    theme(panel.grid = element_blank())
p.sigma.arch

## 4.6. Prediccion de los retornos y la volatilidad ----
predict(object = f.arch, n.ahead = 5, plot = T, p_loss = 0.05)

#' **Interpretación del pronóstico**: el retorno pronosticado es 0% en los
#' 5 períodos (coherente con el ARIMA(0,0,0) — sin estructura, no hay nada
#' que pronosticar salvo la media cero). Lo que sí cambia es la **volatilidad**
#' pronosticada: empieza en ≈3.03% y decae hacia ≈2.22% en el quinto período —
#' el ARCH(1) "olvida" rápido el nivel de volatilidad reciente y converge
#' hacia su volatilidad de largo plazo, precisamente porque solo tiene un
#' rezago de memoria.
#'
#' ## 4. Volatilidad con modelo GARCH(1,1)
# 5. Volatilidad con modelo GARCH(1,1) ---------------------------------------

garch.arma <- fGarch::garchFit(formula=~arma(0,0)+garch(1,1),
                               data=retornos,
                               trace=FALSE,
                               include.mean = F)
summary(garch.arma)

#' **Interpretación**: el GARCH(1,1) resultante:
#'
#' ```
#' omega  = 0.000178  (***, p < 0.001)
#' alpha1 = 0.3924    (***, p < 0.001)
#' beta1  = 0.2588    (·,   p = 0.061 — significativo al 10%)
#' ```
#'
#' α₁+β₁ ≈ 0.65 — bien por debajo de 1 (modelo estable) y con persistencia
#' moderada. β₁ (el término que le da "memoria de sí mismo" al modelo, ver
#' sección 3 del apunte de EWMA/ARCH-GARCH) es significativo al 10%, aunque
#' menos fuerte que α₁.
#'
#' ## 4.1 Validando los residuales estandarizados del GARCH(1,1)
residuales.garch <- fGarch::residuals(object = garch.arma, standardize = T)

t.test(residuales.garch)

tabla.Box.Pierce(residuo = residuales.garch, type = "Ljung-Box")

tabla.Box.Pierce(residuo = residuales.garch^2, type = "Ljung-Box")
tabla.ARCH.LM(residuo = residuales.garch)

jarque.bera.test(residuales.garch)

#' **Interpretación — el punto clave de esta clase**: con el GARCH(1,1), el
#' rezago 4 de la varianza (Ljung-Box y ARCH-LM sobre zₜ²) **ya no rechaza**
#' (p≈0.09-0.10, frente a p≈0.035-0.038 del ARCH(1)) — y lo mismo se confirma
#' con el resumen nativo de `fGarch` a rezagos más largos (Q(10), Q(15),
#' Q(20) sobre R² con p entre 0.36 y 0.72, todos sin rechazar). El GARCH(1,1)
#' deja **menos estructura sin explicar** que el ARCH(1) — exactamente la
#' ventaja teórica de GARCH (equivalente a un ARCH de muchísimos rezagos, con
#' solo 2 parámetros) puesta a prueba con datos reales. Ninguno de los dos
#' modelos arregla la normalidad (ambos rechazan Jarque-Bera con fuerza) —
#' pero, como ya se vio, ese es el supuesto menos crítico de los cuatro.
#'
#' ## 4.2 Volatilidad estimada por el GARCH(1,1)
## 5.1. Volatilidad estimada por el modelo ARCH ----
sigma.garch <- xts(x = garch.arma@sigma.t, order.by = index(retornos))

## 5.2. Grafico de la volatilidad ----
p.sigma.garch <- forecast::autoplot(sigma.garch)+
    labs(title = paste("Volatilidades GARCH(1,1) de AMZN"),
       x = "Tiempo",
       y = "Volatilidad GARCH") +
    scale_y_continuous(labels = label_percent()) +
    theme_light() +
    theme(panel.grid = element_blank())
p.sigma.garch

## 5.3. Prediccion de los retornos y la volatilidad ----
predict(object = garch.arma,
        n.ahead = 5,
        plot = T,
        p_loss = 0.05)

#' **Interpretación**: la volatilidad pronosticada por GARCH(1,1) va de
#' ≈2.93% a ≈2.39% en 5 períodos — decae más **lento** que la del ARCH(1)
#' (3.03%→2.22%), justo la propiedad de mayor persistencia que le da el
#' término β₁ (memoria de la propia varianza pasada, no solo del último
#' error).
#'
#' ## 4.3 Comparando el camino completo: in-sample + pronóstico
## 5.4. Grafico de prediccion de la volatilidad ----

sigma_in <- volatility(garch.arma, type = "sigma")
sigma_out <- predict(garch.arma, n.ahead = 5, plot = F)[["standardDeviation"]]
sigma_all <- c(sigma_in, sigma_out)
time_all <- 1:(length(sigma_all))

plot(time_all, sigma_all, type = "n",
    xlab = "Tiempo", ylab = "Sd condicional",
    main = "Volatilidades GARCH(1,1) de AMZN")

# in-sample part
lines(1:length(sigma_in), sigma_in, col = "steelblue", lwd = 2)

# forecast part
lines((length(sigma_in) + 1):(length(sigma_in) + 5), sigma_out,
      col = "darkgreen", lwd = 2, lty = 2)

abline(v = length(sigma_in), col = "black", lty = 3)

#' **Interpretación**: la línea azul es la volatilidad condicional estimada
#' históricamente (in-sample), y la línea verde punteada es el pronóstico a 5
#' días — la línea vertical marca dónde termina la historia y empieza el
#' pronóstico. Se ve claramente cómo el pronóstico arranca desde el último
#' nivel de volatilidad observado y converge de forma gradual hacia el nivel
#' de largo plazo del modelo, en vez de saltar de golpe.
#'
#' ## Conclusión de la clase
#'
#' | | ARIMA(0,0,0) | ARCH(1) | GARCH(1,1) |
#' |---|---|---|---|
#' | Qué modela | La media (nada que modelar aquí) | Varianza, 1 rezago de memoria | Varianza, memoria de sí misma + 1 rezago |
#' | Autocorrelación en la media | Resuelta | — | — |
#' | Heterocedasticidad (varianza²) | Sin resolver (p<0.01) | Parcial (falla desde rezago 4) | Resuelta en los rezagos probados |
#' | Normalidad | — | No se cumple | No se cumple |
#'
#' El flujo completo de esta clase — eficiencia de mercado (ARIMA vacío) →
#' heterocedasticidad detectada con ARCH-LM → ARCH(1) insuficiente en
#' rezagos largos → GARCH(1,1) sí la captura — es el mismo patrón que se vio
#' en teoría, ahora confirmado con datos reales de AMZN.
