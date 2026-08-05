# riesgos-financieros — 8vo Semestre (ICESI)

Material de la clase de Gestión de Riesgos Financieros. Código en Python (Jupyter
notebooks) para practicar en clase, publicado como GitHub Pages.

**Este proyecto es independiente de `c:\QUANT` y de `TO`** — no comparten contexto,
memoria ni histórico de conversación.

## Estructura

- `index.html` — landing page (mismo estilo visual que usa `TO`/`simulaciones-montecarlo-r`:
  tema oscuro, cards por tema, se va agregando conforme avanza el semestre).
- `fundamentos-python/` — `Basicos_Python.ipynb` (fuente) + `index.html` (export HTML,
  tema oscuro + código colapsable + botón volver al índice).
- `rendimiento-riesgo/` — `Rendimiento_y_riesgo.ipynb` (fuente) + `index.html` (export).
- **Fuente original de los notebooks**: `OneDrive\Documentos\ICESI\8vo Semestre\Riesgos\Practica\`
  (ahí es donde el usuario los va escribiendo/editando en clase). Este repo tiene una
  copia ejecutada y publicable — cuando se agregue o edite un notebook ahí, hay que
  volver a copiarlo aquí, ejecutarlo y regenerar el HTML (ver "Cómo publicar un notebook
  nuevo" abajo).

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
6. Aplicar el override de estilo (tema oscuro + código colapsable + botón volver) — el
   bloque exacto de CSS/JS a inyectar antes de `</head>`/`</body>` está en cualquier
   `index.html` ya publicado de este repo (buscar `rf-code-toggle`, `rf-back-link`) o en
   el equivalente de QUANT (`reports/*.html`, buscar `quant-code-toggle`) — mismo patrón,
   solo cambia el prefijo `rf-` en vez de `quant-`.
7. Agregar una card nueva en `index.html` (raíz) apuntando a la carpeta nueva.
8. `git add`, commit, `git push` — GitHub Pages se sirve desde `main` / raíz, se
   actualiza solo en 1-2 minutos tras el push.

## Notas de trabajo

- Los notebooks fuente (en OneDrive) no tienen outputs guardados (se escriben en blanco,
  sin ejecutar) — este repo sí los ejecuta antes de exportar, para que el sitio muestre
  gráficas y resultados reales, no solo el código.
- `Rendimiento_y_riesgo.ipynb` descarga datos en vivo de Yahoo Finance vía `yfinance` —
  si Yahoo cambia algo o el activo/rango cambia entre corridas, los números del HTML
  publicado pueden no coincidir exactamente con una re-ejecución futura.
