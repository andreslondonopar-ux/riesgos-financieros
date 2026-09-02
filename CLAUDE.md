# riesgos-financieros — 8vo Semestre (ICESI)

Material de la clase de Gestión de Riesgos Financieros. Código en Python (Jupyter
notebooks) y, desde el tema de series de tiempo, también en R (scripts `.R` con
`knitr::spin()`), publicado como GitHub Pages.

**Este proyecto es independiente de `c:\QUANT` y de `TO`** — no comparten contexto,
memoria ni histórico de conversación.

## Estructura

- `index.html` — landing page (mismo estilo visual que usa `TO`/`tecnicas-de-optimizacion`:
  tema oscuro, cards por tema, se va agregando conforme avanza el semestre).
- `fundamentos-python/` — `Basicos_Python.ipynb` (fuente) + `index.html` (export HTML,
  tema claro por defecto de Jupyter + banner simple de vuelta al índice — mismo estilo
  que `TO`/`tecnicas-de-optimizacion`, sin código colapsable).
- `rendimiento-riesgo/` — `Rendimiento_y_riesgo.ipynb` (fuente) + `index.html` (export,
  mismo estilo simple que `fundamentos-python/`).
- `trabajo-retornos-riesgo/` — solución del taller real (`Taller
  Trabajo-retornos-y-riesgo.pdf`, agosto 2026): `Trabajo Retornos y Riesgo.ipynb`
  (fuente) + `index.html`. Aplica todo lo de `rendimiento-riesgo/` a 5 acciones
  reales elegidas deliberadamente de sectores distintos (AAPL tecnología, JPM
  financiero, XOM energía, KO consumo, JNJ salud — para que la matriz de
  correlaciones tenga variedad genuina que analizar, no 5 tecnológicas
  correlacionadas entre sí), mensual, últimos 10 años: retornos discretos y
  continuos, estadísticas descriptivas, histogramas, prueba de Jarque-Bera
  (H0/H1 explícitas + conclusión), intervalo de confianza al 95% de la media, y
  matriz de correlaciones + mapa de calor. Publicado como botón "📝 Trabajo
  (taller)" dentro de la misma card "2. Rendimiento y riesgo" del hub (no como
  tema nuevo — es una aplicación del mismo tema, mismo criterio ya usado en
  `TO`/`tecnicas-de-optimizacion` para no separar taller y teoría cuando
  comparten unidad conceptual).
- `series-de-tiempo/` — `Series de tiempo.R` (fuente) + `Setup/Pruebas residuales
  ARIMA.R` (funciones auxiliares `tabla.Box.Pierce`/`tabla.ARCH.LM` que el script
  principal carga con `source("Setup/...")` — por eso hay que conservar esa
  subcarpeta exacta, no aplanar) + `index.html` (export). Descomposición de
  `AirPassengers`, pruebas de raíz unitaria (ADF/PP/KPSS), diferenciación/
  transformación log, identificación ACF/PACF, ARIMA manual y `auto.arima`,
  diagnóstico de residuales (Ljung-Box, ARCH-LM, Jarque-Bera, QQ-plot) y
  pronóstico. Primer contenido en R del repo — ver "Cómo publicar código en R"
  abajo, es un flujo distinto al de los notebooks Python.
- `taller-series-de-tiempo/` — `Taller series de tiempo.R` (fuente, con YAML
  `output: pdf_document / html_document` al inicio del bloque roxygen) + `Setup/`
  (misma función auxiliar copiada) + `data/colcap_daily.csv` (histórico diario
  COLCAP, ver nota de la fuente abajo) + `index.html` (export) + `Taller series
  de tiempo.pdf` (el entregable real del taller, generado con `pdf_document(latex_engine
  = "xelatex")` — **no uses el `pdflatex` por defecto**, no soporta caracteres
  Unicode como tildes/≤/— directamente, y falla a mitad de compilación). Taller
  real (`OneDrive\...\Riesgos\Taller Series de Tiempo\Taller-series-de-tiempo.pdf`):
  identificación + estimación + validación + pronóstico de un ARIMA sobre COLCAP
  y Bitcoin, en precio y en retorno mensual (4 series completas), 2021-01 a
  2026-08. **Fuente del histórico de COLCAP**: no hay ticker de Yahoo Finance
  para COLCAP — se encontró el histórico diario completo (2008-hoy, fuente BVC)
  en la API pública (sin autenticación) del Banco de la República:
  `https://suameca.banrep.gov.co/estadisticas-economicas-back/rest/estadisticaEconomicaRestService/consultaMenuXId?idMenu=2500`
  (requiere header `Referer` apuntando a la página `suameca.banrep.gov.co` de la
  serie, si no responde vacío) — devuelve JSON con `data: [[timestamp_ms, valor], ...]`.
  Bitcoin sí viene de Yahoo (`quantmod::getSymbols("BTC-USD")`).
- **Fuente original de los notebooks Python**: `OneDrive\Documentos\ICESI\8vo
  Semestre\Riesgos\Practica\` (ahí es donde el usuario los va escribiendo/editando
  en clase). **Fuente original de los scripts R**: `OneDrive\...\Riesgos\Practica
  series de tiempo\Practica series de tiempo\`. Este repo tiene una copia ejecutada
  y publicable — cuando se agregue o edite algo ahí, hay que volver a copiarlo
  aquí, ejecutarlo y regenerar el HTML (ver las dos secciones "Cómo publicar"
  abajo, una por lenguaje).

## Por qué este repo NO vive dentro de OneDrive

Se intentó primero construir el sitio directamente dentro de la carpeta de OneDrive
(`Riesgos/site/`), pero cualquier escritura de archivo NUEVO desde Python (`open(path,
"w")`, `nbformat.write`, `nbconvert --execute --inplace`) fallaba con
`OSError: [Errno 9] Bad file descriptor` o `FileNotFoundError`, mientras que `cp`/`mkdir`
de Git Bash sí funcionaban sin problema en la misma carpeta — consistente con que Windows
Defender (Acceso controlado a carpetas, protección contra ransomware) bloquea a
`python.exe` para crear archivos nuevos dentro de `Documents`/OneDrive, pero no bloquea
`cp.exe`/`bash.exe` de Git for Windows. Se replicó el mismo patrón que ya usa el usuario
para otros proyectos de clase separados de QUANT (`C:\markowitz_portfolio`,
`C:\daily_strategy_papers`): un repo propio en la raíz de `C:\`, fuera de cualquier
carpeta protegida.

## Cómo publicar un notebook nuevo o actualizado

1. Copiar el `.ipynb` desde `OneDrive\...\Riesgos\Practica\` (o donde viva) a una carpeta
   nueva o existente dentro de este repo (nombre de carpeta en kebab-case).
2. Si usa librerías que no están instaladas globalmente, instalarlas primero
   (`py -m pip install <paquete>`).
3. Si el notebook usa `plotly` con `fig.show()`, agregar `import plotly.io as pio` +
   `pio.renderers.default = "notebook"` justo después de los imports — sin esto,
   `nbconvert --to html` no logra embeber las gráficas interactivas (se exportan como
   JSON crudo no representable). Mismo bug ya documentado en `daily_strategy_papers`.
4. Ejecutar: `py -m jupyter nbconvert --to notebook --execute --inplace "<archivo>.ipynb"`
5. Convertir a HTML: `py -m jupyter nbconvert --to html "<archivo>.ipynb" --output index.html`
6. Agregar solo un banner simple de vuelta al índice (mismo estilo que `TO`, un `<div>`
   con fondo oscuro `#0f1115` y un link, insertado justo después de `<body>` — NO aplicar
   el patrón de tema oscuro completo / código colapsable de QUANT, se probó y se
   revirtió a pedido del usuario: quería que este repo se viera como `TO`, no al revés).
7. Agregar una card nueva en `index.html` (raíz) apuntando a la carpeta nueva.
8. `git add`, commit, `git push` — GitHub Pages se sirve desde `main` / raíz, se
   actualiza solo en 1-2 minutos tras el push.

## Cómo publicar código en R (distinto del flujo de notebooks Python)

1. Copiar el/los `.R` desde `OneDrive\...\Riesgos\Practica series de tiempo\...\`
   (o donde viva el tema nuevo) a una carpeta nueva dentro de este repo
   (kebab-case), **preservando cualquier subcarpeta que un `source(...)` del
   script espere** (ej. `Setup/`) — no aplanar la estructura de carpetas del
   script original.
2. Verificar/instalar los paquetes de R que use el script
   (`Rscript -e 'install.packages(c("pkg1","pkg2"), repos="https://cloud.r-project.org")'`);
   el propio script suele traer `pacman::p_load(...)` que auto-instala lo que
   falte, pero es más confiable pre-instalar antes de knitear.
3. **Pandoc no viene instalado con R base** (`rmarkdown::render()` a HTML lo
   necesita) — si `rmarkdown::pandoc_available()` da `FALSE`, descargar el zip
   de Windows desde `github.com/jgm/pandoc/releases/latest`, extraerlo a una
   carpeta temporal, y apuntar `Sys.setenv(RSTUDIO_PANDOC = "<carpeta con
   pandoc.exe>")` antes de renderizar (no hace falta un instalador con permisos
   de administrador).
4. Convertir el `.R` a reporte con `knitr::spin(hair = "<archivo>.R", knit =
   FALSE)` (genera el `.Rmd`) y `rmarkdown::render(...)` a `index.html`
   (`output_format = html_document(toc = TRUE, toc_float = TRUE, theme =
   "flatly")`, mismo tema en los reportes de R de este repo) — hay que correr
   con el working directory puesto en la carpeta del script (`setwd(...)`),
   para que los `source()` relativos del script (ej. `Setup/...`) resuelvan
   bien. Si el script no tiene comentarios `#'` estilo roxygen para separar
   texto de código, `spin()` genera un único chunk grande — no es un problema,
   cada `plot()`/`autoplot()`/`print()` del chunk igual genera su propia figura
   o salida en el HTML final, en el mismo orden en que se ejecutan.
5. Insertar el mismo banner simple de vuelta al índice que los reportes Python
   (ver paso 6 de "Cómo publicar un notebook nuevo" arriba) justo después de
   `<body>` — el HTML de `rmarkdown::render` con tema `flatly` no lo trae por
   defecto.
6. Agregar una card nueva en `index.html` (raíz) apuntando a la carpeta nueva.
7. `git add`, commit, `git push`.
8. **Si además hay que entregar un PDF** (ej. un taller real, no solo el
   reporte del hub): agregar un bloque YAML al inicio del bloque roxygen
   (`#' ---` / `#' title: "..."` / `#' author: "..."` / `#' output:` con
   `pdf_document:` y `html_document:` / `#' ---`) y renderizar dos veces,
   una por formato (`output_format = html_document(...)` y
   `output_format = pdf_document(latex_engine = "xelatex")`). **Usar
   `latex_engine = "xelatex"`, no el `pdflatex` por defecto** — pdflatex
   no soporta caracteres Unicode (tildes, ≤, —, subíndices) sin paquetes
   extra y falla a mitad de compilación con "Unicode character not set up
   for use with LaTeX". La primera vez que se instala tinytex puede hacer
   falta `mktexlsr` (`C:/ProgramData/TinyTeX/bin/windows/mktexlsr.exe`)
   para que pdflatex/xelatex encuentren paquetes recién verificados como
   ya instalados (`tlmgr install` decía "already present" pero
   `! LaTeX Error: File 'X.sty' not found` igual, típico tras instalar
   tinytex por primera vez — reindexar la base de nombres lo arregla).
9. **Gotcha de `spin()` que rompe secciones silenciosamente**: una línea
   en blanco entre dos bloques `#'` (párrafo → encabezado, o párrafo →
   párrafo) **debe ser `#'` sola, no una línea vacía sin el prefijo** — si
   no, pandoc fusiona el texto siguiente con el párrafo anterior en vez de
   crear una sección/párrafo nuevo, y el encabezado desaparece del TOC sin
   ningún error visible. Antes de dar un reporte por terminado, contar que
   el número de `<h2>`/secciones en el HTML final coincida con los
   encabezados `## N. ...` del script — no asumir que si `spin()`/
   `render()` corrieron sin error, el resultado está completo.

## Notas de trabajo

- Los notebooks fuente (en OneDrive) no tienen outputs guardados (se escriben en blanco,
  sin ejecutar) — este repo sí los ejecuta antes de exportar, para que el sitio muestre
  gráficas y resultados reales, no solo el código.
- `Rendimiento_y_riesgo.ipynb` descarga datos en vivo de Yahoo Finance vía `yfinance` —
  si Yahoo cambia algo o el activo/rango cambia entre corridas, los números del HTML
  publicado pueden no coincidir exactamente con una re-ejecución futura.
- **El tema oscuro + código colapsable (patrón `rf-code-toggle`/`rf-back-link`,
  heredado de QUANT) se probó pero se revirtió** — el usuario pidió que este repo se
  viera como `TO`/`tecnicas-de-optimizacion` estaba originalmente (tema claro por
  defecto de Jupyter + un banner simple, no sticky, sin código colapsable), no que
  `TO` adoptara el estilo de acá. Si se agrega un notebook nuevo, seguir el paso 6 de
  "Cómo publicar" (banner simple), no reintroducir el patrón oscuro.
