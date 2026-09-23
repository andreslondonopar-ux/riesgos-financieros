knitr::opts_chunk$set(echo = TRUE, warning = FALSE, message = FALSE, fig.align = "center")
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, xts, tseries, magrittr, zoo, forecast, quantmod,
               MTS, FinTS, fGarch, lmtest, scales, psych, patchwork, knitr)
options(scipen = 999)

acciones <- c("MU", "WDC")

precios <- quantmod::getSymbols(acciones, src = "yahoo",
                                from = "2023-12-31", to = "2026-08-31",
                                periodicity = "daily",
                                auto.assign = TRUE, warnings = FALSE) %>%
  purrr::map(~quantmod::Ad(get(.))) %>%
  purrr::reduce(merge.xts) %>%
  `colnames<-`(acciones)

retorno.mu  <- TTR::ROC(precios$MU,  type = "continuous", na.pad = TRUE) %>% na.omit()
retorno.wdc <- TTR::ROC(precios$WDC, type = "continuous", na.pad = TRUE) %>% na.omit()

p.precio.mu <- forecast::autoplot(precios$MU) +
  labs(title = "Precio MU", x = "Fecha", y = "USD") +
  theme_light() + theme(panel.grid = element_blank())
p.precio.wdc <- forecast::autoplot(precios$WDC) +
  labs(title = "Precio WDC", x = "Fecha", y = "USD") +
  theme_light() + theme(panel.grid = element_blank())
p.precio.mu | p.precio.wdc

p.ret.mu <- forecast::autoplot(retorno.mu) +
  labs(title = "Retornos diarios MU", x = "Fecha", y = "Retorno") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank())
p.ret.wdc <- forecast::autoplot(retorno.wdc) +
  labs(title = "Retornos diarios WDC", x = "Fecha", y = "Retorno") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank())
p.ret.mu | p.ret.wdc

desc.mu  <- psych::describe(coredata(retorno.mu))
desc.wdc <- psych::describe(coredata(retorno.wdc))
tabla.desc <- rbind(MU = round(desc.mu[,c("mean","sd","median","skew","kurtosis","min","max")], 4),
                    WDC = round(desc.wdc[,c("mean","sd","median","skew","kurtosis","min","max")], 4))
kable(tabla.desc, caption = "Estadísticas descriptivas de los retornos diarios")

calc_vol_hist <- function(retorno) {
  n <- nrow(retorno)
  v <- vector()
  for (i in 2:n) v[i-1] <- sd(retorno[1:i])
  xts(v, order.by = index(retorno)[-1])
}
vol.hist.mu  <- calc_vol_hist(retorno.mu)
vol.hist.wdc <- calc_vol_hist(retorno.wdc)

p.hist.mu <- forecast::autoplot(vol.hist.mu) +
  labs(title = "Volatilidad histórica MU", x = "Fecha", y = "Volatilidad") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank())
p.hist.wdc <- forecast::autoplot(vol.hist.wdc) +
  labs(title = "Volatilidad histórica WDC", x = "Fecha", y = "Volatilidad") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank())
p.hist.mu | p.hist.wdc

ventana <- 20
vol.movil.mu  <- zoo::rollapply(retorno.mu,  width = ventana, FUN = sd) %>% na.omit()
vol.movil.wdc <- zoo::rollapply(retorno.wdc, width = ventana, FUN = sd) %>% na.omit()

p.mov.mu <- forecast::autoplot(vol.movil.mu) +
  labs(title = "Volatilidad móvil (20d) MU", x = "Fecha", y = "Volatilidad") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank())
p.mov.wdc <- forecast::autoplot(vol.movil.wdc) +
  labs(title = "Volatilidad móvil (20d) WDC", x = "Fecha", y = "Volatilidad") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank())
p.mov.mu | p.mov.wdc

lambda.riskmetrics <- 0.94
lambda.datos <- 1 - (2/(length(retorno.mu)+1))

ewma_sigma <- function(retorno, lambda) {
  e <- MTS::EWMAvol(retorno, lambda = lambda)
  xts(sqrt(e$Sigma.t), order.by = index(retorno))
}

sigma.ewma94.mu   <- ewma_sigma(retorno.mu,  lambda.riskmetrics)
sigma.ewma94.wdc  <- ewma_sigma(retorno.wdc, lambda.riskmetrics)
sigma.ewmad.mu    <- ewma_sigma(retorno.mu,  lambda.datos)
sigma.ewmad.wdc   <- ewma_sigma(retorno.wdc, lambda.datos)

lbl.d <- paste0("lambda=", round(lambda.datos, 3))

df_series <- function(...) {
  args <- list(...)
  nombres <- names(args)
  purrr::map2_dfr(args, nombres, ~ tibble(fecha = index(.x), valor = as.numeric(.x), serie = .y))
}

d.ewma.mu  <- df_series("lambda=0.94" = sigma.ewma94.mu, "d" = sigma.ewmad.mu) %>%
  mutate(serie = recode(serie, "d" = lbl.d))
d.ewma.wdc <- df_series("lambda=0.94" = sigma.ewma94.wdc, "d" = sigma.ewmad.wdc) %>%
  mutate(serie = recode(serie, "d" = lbl.d))

p.ewma.mu <- ggplot(d.ewma.mu, aes(x = fecha, y = valor, color = serie)) +
  geom_line() +
  labs(title = "EWMA MU", x = "Fecha", y = "Volatilidad", color = "") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank(), legend.position = "bottom")
p.ewma.wdc <- ggplot(d.ewma.wdc, aes(x = fecha, y = valor, color = serie)) +
  geom_line() +
  labs(title = "EWMA WDC", x = "Fecha", y = "Volatilidad", color = "") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank(), legend.position = "bottom")
p.ewma.mu | p.ewma.wdc

f.arima.mu  <- forecast::auto.arima(retorno.mu,  d = 0)
f.arima.wdc <- forecast::auto.arima(retorno.wdc, d = 0)
f.arima.mu
f.arima.wdc

f.arch.mu  <- fGarch::garchFit(formula = ~arma(0,0)+garch(1,0), data = retorno.mu,
                               trace = FALSE, include.mean = TRUE)
f.arch.wdc <- fGarch::garchFit(formula = ~arma(0,0)+garch(1,0), data = retorno.wdc,
                               trace = FALSE, include.mean = TRUE)

summary(f.arch.mu)

summary(f.arch.wdc)

sigma.arch.mu  <- xts(f.arch.mu@sigma.t,  order.by = index(retorno.mu))
sigma.arch.wdc <- xts(f.arch.wdc@sigma.t, order.by = index(retorno.wdc))

p.arch.mu <- forecast::autoplot(sigma.arch.mu) +
  labs(title = "Volatilidad ARCH(1) MU", x = "Fecha", y = "Volatilidad") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank())
p.arch.wdc <- forecast::autoplot(sigma.arch.wdc) +
  labs(title = "Volatilidad ARCH(1) WDC", x = "Fecha", y = "Volatilidad") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank())
p.arch.mu | p.arch.wdc

f.garch.mu  <- fGarch::garchFit(formula = ~arma(0,0)+garch(1,1), data = retorno.mu,
                                trace = FALSE, include.mean = TRUE)
f.garch.wdc <- fGarch::garchFit(formula = ~arma(0,0)+garch(1,1), data = retorno.wdc,
                                trace = FALSE, include.mean = TRUE)

summary(f.garch.mu)

summary(f.garch.wdc)

sigma.garch.mu  <- xts(f.garch.mu@sigma.t,  order.by = index(retorno.mu))
sigma.garch.wdc <- xts(f.garch.wdc@sigma.t, order.by = index(retorno.wdc))

p.garch.mu <- forecast::autoplot(sigma.garch.mu) +
  labs(title = "Volatilidad GARCH(1,1) MU", x = "Fecha", y = "Volatilidad") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank())
p.garch.wdc <- forecast::autoplot(sigma.garch.wdc) +
  labs(title = "Volatilidad GARCH(1,1) WDC", x = "Fecha", y = "Volatilidad") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank())
p.garch.mu | p.garch.wdc

d.comp.mu <- df_series("Histórica" = vol.hist.mu, "EWMA (lambda=0.94)" = sigma.ewma94.mu,
                       "ARCH(1)" = sigma.arch.mu, "GARCH(1,1)" = sigma.garch.mu)
d.comp.wdc <- df_series("Histórica" = vol.hist.wdc, "EWMA (lambda=0.94)" = sigma.ewma94.wdc,
                        "ARCH(1)" = sigma.arch.wdc, "GARCH(1,1)" = sigma.garch.wdc)

comp.mu <- ggplot(d.comp.mu, aes(x = fecha, y = valor, color = serie)) +
  geom_line() +
  labs(title = "Comparación de métodos — MU", x = "Fecha", y = "Volatilidad", color = "") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank(), legend.position = "bottom")
comp.wdc <- ggplot(d.comp.wdc, aes(x = fecha, y = valor, color = serie)) +
  geom_line() +
  labs(title = "Comparación de métodos — WDC", x = "Fecha", y = "Volatilidad", color = "") +
  scale_y_continuous(labels = label_percent()) +
  theme_light() + theme(panel.grid = element_blank(), legend.position = "bottom")
comp.mu | comp.wdc

alpha <- 0.05
z <- qnorm(alpha)
phi_z <- dnorm(z)
var_calc <- function(mu, sigma) -(mu + z*sigma)
es_calc  <- function(mu, sigma) -mu + sigma*(phi_z/alpha)

tabla_pronostico <- function(pred, activo, modelo) {
  data.frame(
    Activo = activo, Modelo = modelo, Periodo = 1:5,
    `Retorno pronosticado` = percent(pred$meanForecast, accuracy = 0.01),
    `Volatilidad` = percent(pred$standardDeviation, accuracy = 0.01),
    `VaR 95%` = percent(var_calc(pred$meanForecast, pred$standardDeviation), accuracy = 0.01),
    `Pérdida Esperada 95%` = percent(es_calc(pred$meanForecast, pred$standardDeviation), accuracy = 0.01),
    check.names = FALSE
  )
}

pred.arch.mu   <- predict(f.arch.mu,  n.ahead = 5, plot = FALSE)
pred.arch.wdc  <- predict(f.arch.wdc, n.ahead = 5, plot = FALSE)
pred.garch.mu  <- predict(f.garch.mu, n.ahead = 5, plot = FALSE)
pred.garch.wdc <- predict(f.garch.wdc,n.ahead = 5, plot = FALSE)

tabla.completa <- rbind(
  tabla_pronostico(pred.arch.mu,   "MU",  "ARCH(1)"),
  tabla_pronostico(pred.garch.mu,  "MU",  "GARCH(1,1)"),
  tabla_pronostico(pred.arch.wdc,  "WDC", "ARCH(1)"),
  tabla_pronostico(pred.garch.wdc, "WDC", "GARCH(1,1)")
)
kable(tabla.completa, caption = "Pronóstico a 5 días: retorno, volatilidad, VaR y Pérdida Esperada (95%)")
