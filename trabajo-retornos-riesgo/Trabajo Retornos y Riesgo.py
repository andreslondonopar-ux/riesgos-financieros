# %% [markdown]
# # Diversificacion sectorial: retornos y riesgo de 5 acciones
# ### Andres Londono
# 
# Gerencia de riesgos financieros 2026-2 -- Trabajo retornos y riesgo

# %% [markdown]
# ## 1. Descripcion de las acciones descargadas
# 
# Se eligieron 5 acciones de sectores distintos del S&P 500, buscando variedad
# real para el analisis de correlaciones (en vez de 5 tecnologicas, que
# tienden a moverse juntas):
# 
# - **AAPL (Apple Inc.)** -- Tecnologia. Fabricante de hardware (iPhone, Mac,
#   iPad) y servicios digitales.
# - **JPM (JPMorgan Chase & Co.)** -- Financiero. El banco mas grande de
#   EE.UU. por activos, banca de inversion y banca comercial.
# - **XOM (Exxon Mobil Corporation)** -- Energia. Una de las petroleras
#   integradas mas grandes del mundo (exploracion, refinacion, quimicos).
# - **KO (The Coca-Cola Company)** -- Consumo basico. Bebidas, un sector
#   clasicamente defensivo (demanda estable sin importar el ciclo economico).
# - **JNJ (Johnson & Johnson)** -- Salud. Farmaceutica y dispositivos
#   medicos, otro sector defensivo.
# 
# Se descargan los precios de cierre ajustados **mensuales** de los ultimos
# 10 anos.

# %%
import pandas as pd
import numpy as np
import yfinance as yf
import matplotlib.pyplot as plt
import matplotlib.ticker as mtick
import plotly.express as px
import plotly.graph_objects as go
import plotly.io as pio
pio.renderers.default = "notebook"
import statsmodels.stats.api as sms
from scipy import stats
import ffn

# %%
acciones = ["AAPL", "JPM", "XOM", "KO", "JNJ"]

df_diario = yf.download(acciones,
                         start="2016-08-25",
                         end="2026-08-25",
                         progress=False,
                         auto_adjust=False,
                         multi_level_index=False)

df_diario = df_diario.loc[:, ["Adj Close"]]
df_diario.columns = df_diario.columns.droplevel()
df_diario = df_diario[acciones]

print(f"Descargadas {len(df_diario)} filas diarias, de {df_diario.index[0].date()} a {df_diario.index[-1].date()}")
df_diario.tail()

# %% [markdown]
# Se resamplea a frecuencia mensual (fin de mes), como se pide en el enunciado.

# %%
df_mensual = df_diario.resample(rule="ME").ffill()
print(f"{len(df_mensual)} precios mensuales por accion")
df_mensual.tail()

# %% [markdown]
# ## 2. Calculo de los retornos discretos y continuos de las acciones
# 
# Se calcula el retorno discreto (`pct_change`) y el retorno continuo/logaritmico
# (`log(P_t/P_{t-1})`) para cada accion, y se grafican ambos juntos en una
# misma grafica por accion.

# %%
df_rtn_discreto = df_mensual.pct_change().dropna()
df_rtn_continuo = np.log(df_mensual / df_mensual.shift(1)).dropna()

df_rtn_discreto.head()

# %%
for accion in acciones:
    fig = go.Figure()
    fig.add_trace(go.Scatter(x=df_rtn_discreto.index, y=df_rtn_discreto[accion],
                              mode="lines", name="Retorno discreto"))
    fig.add_trace(go.Scatter(x=df_rtn_continuo.index, y=df_rtn_continuo[accion],
                              mode="lines", name="Retorno continuo"))
    fig.update_layout(title=f"Retornos mensuales de {accion} -- discreto vs. continuo",
                       xaxis_title="Fecha", yaxis_title="Retorno",
                       yaxis_tickformat=".1%", height=350)
    fig.show()

# %% [markdown]
# **Analisis:** para los 5 activos, el retorno discreto y el continuo son
# visualmente casi indistinguibles en la mayoria de los meses -- son
# aproximaciones matematicas muy cercanas cuando el retorno es pequeno
# (`log(1+r) ~ r`). La diferencia solo se nota en los meses de movimientos
# extremos (por ejemplo, la caida de marzo de 2020 por COVID-19, visible en
# las 5 series), donde el retorno continuo queda ligeramente por debajo del
# discreto en las caidas fuertes y ligeramente por debajo tambien en las
# subidas fuertes -- consistente con que el logaritmo comprime valores
# extremos de forma asimetrica.

# %% [markdown]
# ## 3. Calculo de las estadisticas descriptivas de los retornos continuos

# %%
estadisticas = df_rtn_continuo.describe(percentiles=[0.05, 0.25, 0.5, 0.75, 0.95]).T
estadisticas["skew"] = df_rtn_continuo.skew()
estadisticas["kurtosis"] = df_rtn_continuo.kurtosis()
estadisticas

# %% [markdown]
# **Analisis:** con 120 retornos mensuales por accion (10 anos), **AAPL tiene
# el mayor rendimiento promedio** (2.12%/mes, ~25% anualizado) seguido de
# **JPM** (1.61%/mes). Las tres acciones "defensivas" del grupo -- XOM, KO y
# JNJ -- rondan un rendimiento promedio mucho mas bajo (0.87-0.91%/mes), como
# se esperaria de sectores menos ciclicos que la tecnologia. En volatilidad
# (desviacion estandar), **XOM es la mas volatil** (8.12%/mes) pese a no ser
# tecnologica -- consistente con su exposicion directa al precio del petroleo
# -- mientras que **KO es la menos volatil** (4.76%/mes), el perfil clasico de
# consumo defensivo. En cuanto a la forma de la distribucion, **KO muestra el
# sesgo negativo mas fuerte** (skew = -0.83, con curtosis alta de 1.87) --
# caidas ocasionales bruscas frente a subidas mas graduales -- mientras que
# JNJ y AAPL tienen distribuciones bastante mas cercanas a la simetria
# (skew cerca de 0).

# %% [markdown]
# ## 4. Elaboracion del histograma de los retornos continuos

# %%
for accion in acciones:
    fig = px.histogram(df_rtn_continuo, x=accion,
                        title=f"Histograma de retornos continuos mensuales -- {accion}",
                        labels={accion: "Retorno continuo"}, nbins=25)
    fig.update_layout(xaxis_tickformat=".1%", height=350, showlegend=False)
    fig.show()

# %% [markdown]
# **Analisis:** los histogramas confirman visualmente lo que ya mostraban las
# estadisticas descriptivas: AAPL y JNJ tienen formas relativamente
# simetricas y acampanadas, cercanas a una normal; JPM y XOM muestran una
# cola izquierda visiblemente mas larga que la derecha (consistente con su
# kurtosis alta, cerca de 2); y KO es el caso mas marcado -- una
# concentracion fuerte de retornos positivos moderados con algunos meses de
# caida muy pronunciada que estiran la cola izquierda, el reflejo grafico de
# su skew de -0.83.

# %% [markdown]
# ## 5. Elaboracion de la prueba de normalidad de Jarque-Bera para los retornos continuos
# 
# **Hipotesis nula (H0):** los retornos continuos siguen una distribucion
# normal (asimetria = 0 y curtosis = 3).
# 
# **Hipotesis alternativa (H1):** los retornos continuos NO siguen una
# distribucion normal.

# %%
resultados_jb = []
for accion in acciones:
    JB, p_JB, skew, kurt = sms.jarque_bera(resids=df_rtn_continuo[accion])
    resultados_jb.append({"accion": accion, "JB": JB, "p_valor": p_JB,
                           "skew": skew, "kurtosis": kurt,
                           "rechaza_H0_al_5pct": p_JB < 0.05})

tabla_jb = pd.DataFrame(resultados_jb).set_index("accion")
tabla_jb

# %% [markdown]
# **Conclusion:** con un nivel de significancia del 5%, la prueba **no
# rechaza la normalidad para AAPL** (p = 0.464) **ni para JNJ** (p = 0.922) --
# sus retornos mensuales son estadisticamente compatibles con una
# distribucion normal. Para **JPM** (p = 0.0013), **XOM** (p = 0.00016) y
# **KO** (p < 0.0001) la prueba **si rechaza H0**: sus retornos muestran
# suficiente asimetria y/o exceso de curtosis para descartar la normalidad
# con alta confianza -- KO es el caso mas extremo, con el estadistico JB mas
# alto del grupo (28.72), coherente con el sesgo negativo ya visto en las
# estadisticas descriptivas y en el histograma.

# %% [markdown]
# ## 6. Elaboracion del intervalo de confianza para el rendimiento promedio de cada una de las acciones
# 
# Intervalo de confianza al 95% para la media del retorno continuo mensual de
# cada accion, usando la distribucion t de Student (varianza poblacional
# desconocida).

# %%
resultados_ic = []
for accion in acciones:
    serie = df_rtn_continuo[accion]
    li, ls = stats.t.interval(confidence=0.95, df=len(serie) - 1,
                               loc=np.mean(serie), scale=stats.sem(serie))
    resultados_ic.append({"accion": accion, "media": np.mean(serie),
                           "limite_inferior": li, "limite_superior": ls,
                           "incluye_cero": li <= 0 <= ls})

tabla_ic = pd.DataFrame(resultados_ic).set_index("accion")
tabla_ic

# %% [markdown]
# **Interpretacion (caso AAPL):** el intervalo de confianza al 95% para el
# rendimiento promedio mensual de AAPL es **[0.73%, 3.52%]**. Esto significa
# que, si se repitiera el proceso de muestreo muchas veces, el 95% de los
# intervalos construidos de esta forma contendrian el verdadero rendimiento
# promedio poblacional de AAPL. Como el intervalo **no incluye el 0**, se
# puede concluir con 95% de confianza que el rendimiento promedio mensual de
# AAPL en este periodo es **estadisticamente distinto de cero** (positivo) --
# no es simplemente ruido de muestreo alrededor de un rendimiento esperado
# nulo. El unico caso del grupo donde el intervalo **si incluye el 0** es
# **XOM** ([-0.58%, 2.36%]): para el petroleo no se puede rechazar, al 95% de
# confianza, que su verdadero rendimiento promedio sea cero -- coherente con
# ser el activo mas volatil del grupo (mas ruido, intervalo mas ancho) y con
# el menor rendimiento promedio observado.

# %% [markdown]
# ## 7. La matriz de correlaciones de los retornos continuos

# %%
matriz_corr = df_rtn_continuo.corr()
matriz_corr

# %%
fig = px.imshow(matriz_corr, text_auto=".2f", color_continuous_scale="RdBu_r",
                 aspect="auto", zmin=-1, zmax=1,
                 title="Matriz de correlaciones -- retornos continuos mensuales")
fig.show()

# %% [markdown]
# **Analisis:** la correlacion mas alta del grupo es **KO-JNJ (0.54)** -- dos
# sectores clasicamente defensivos (consumo y salud) que tienden a moverse
# juntos en episodios de aversion al riesgo del mercado. La segunda mas alta
# es **JPM-XOM (0.48)** -- financiero y energia, ambos sectores ciclicos
# sensibles al crecimiento economico y a las tasas de interes, aunque por
# canales distintos. En el otro extremo, **AAPL es la accion menos
# correlacionada con el resto del grupo** (0.16 a 0.28 con las demas,
# la mas baja siendo AAPL-XOM en 0.16) -- su patron de crecimiento
# tecnologico se comporta de forma bastante independiente de las otras
# cuatro. Ninguna correlacion del grupo supera 0.54, lo que confirma que la
# eleccion deliberada de sectores distintos (tecnologia, financiero, energia,
# consumo, salud) sí logro un grupo genuinamente diversificado -- ningun par
# se mueve de forma casi identica, a diferencia de lo que pasaria con 5
# acciones tecnologicas.
