#' ---
#' title: "Práctica: ARIMA + ARCH/GARCH sobre retornos de Micron Technology (MU)"
#' author: "Andrés Londoño"
#' output:
#'   html_document:
#'     toc: true
#'     toc_float: true
#'     theme: flatly
#' ---
#'
#' Ejercicio de práctica para el parcial de Gerencia de Riesgos Financieros —
#' replica el mismo flujo de la parte práctica del examen (SPY), pero con
#' **Micron Technology (MU)** como instrumento, para poder practicar el
#' procedimiento completo sin usar el instrumento real del examen.
#'
#' ## 1. Descarga de precios y cálculo de retornos
#'
#' Precios de cierre ajustado, frecuencia diaria, de **MU** entre el
#' 2024-08-31 y el 2026-09-04 (vía Yahoo Finance).
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

#' **Retornos continuos (log-retornos)**: \( r_t = \log(P_t) - \log(P_{t-1}) \).
mu_ret <- diff(log(mu_precio))
mu_ret <- na.omit(mu_ret)

forecast::autoplot(mu_ret) +
  labs(title = "MU — retornos continuos (diarios)", x = "Fecha", y = "Retorno") +
  theme_light() + theme(panel.grid = element_blank())
