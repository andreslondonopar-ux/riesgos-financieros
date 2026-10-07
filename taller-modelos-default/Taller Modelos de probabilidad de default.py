# %% [markdown]
# # Taller — Modelos de probabilidad de default
# Gerencia de riesgos financieros 2026-2 · Taller en clase (septiembre 2026)

# %%
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import statsmodels.formula.api as smf
from pandas.api.types import CategoricalDtype
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn import metrics

link = "https://raw.githubusercontent.com/salas317/Data/main/GRF/loan_data.csv"
loan_data = pd.read_csv(link, index_col=0)

loan_data["home_ownership"] = loan_data["home_ownership"].astype("category")
loan_data["grade"] = loan_data["grade"].astype(CategoricalDtype(categories=list("GFEDCBA"), ordered=True))
# "Missing" va primero: es la categoría de referencia de ir_cat en los modelos
loan_data["ir_cat"] = loan_data["ir_cat"].astype(
    CategoricalDtype(categories=["Missing", "0-8", "8-11", "11-13.5", "13.5+"], ordered=True))

train_set, test_set = train_test_split(loan_data, test_size=1/3, random_state=567)
print(train_set.shape, test_set.shape)

# %% [markdown]
# ## 1. Regresión logística `log_model_ir` (único predictor: `ir_cat`)

# %%
log_model_ir = smf.logit("loan_status ~ ir_cat", data=train_set).fit()

# %% [markdown]
# ## 2. Parámetros estimados

# %%
print(log_model_ir.summary())

# %% [markdown]
# ## 3. Categoría de referencia de `ir_cat`

# %%
print(loan_data["ir_cat"].value_counts())
print("Categoría de referencia del modelo:", loan_data["ir_cat"].cat.categories[0])

# %% [markdown]
# **Respuesta:** la categoría de referencia es **Missing**: es la primera categoría de `ir_cat` y por eso `statsmodels` la deja fuera del modelo, mientras las demás se interpretan *respecto a ella*. Según `value_counts`, la categoría más frecuente es `0-8` (7.130 préstamos) y la menos frecuente es `Missing` (2.776), así que la referencia no es la más frecuente sino la que se fijó con el orden de las categorías. En el modelo de un solo predictor: `0-8` tiene un coeficiente de −0,689 (odds de default ≈ 0,50 veces los de Missing), `8-11` no es significativo (p = 0,464), `11-13.5` sube el log-odds en 0,225 y `13.5+` en 0,585 (odds ≈ 1,79 veces). A mayor tasa de interés, mayor probabilidad de default.

# %% [markdown]
# ## 4. Regresión logística múltiple `log_model_multi`

# %%
log_model_multi = smf.logit("loan_status ~ age + ir_cat + grade + loan_amnt + annual_inc", data=train_set).fit()
print(log_model_multi.summary())

# %% [markdown]
# ## 5. Variables significativas, odds y efectos marginales

# %%
pvals = log_model_multi.pvalues
signif = pvals[pvals < 0.05].drop("Intercept", errors="ignore")
print("Significativos al 5%:\n", signif.round(4), "\n")

odds = pd.DataFrame({"coef": log_model_multi.params, "odds = exp(coef)": np.exp(log_model_multi.params)}).loc[signif.index]
print(odds.round(4))
print()
me = log_model_multi.get_margeff().summary_frame()
print(me.loc[me.index.isin(signif.index)].round(5))
print()
b = log_model_multi.params["annual_inc"]
print(f"annual_inc, por cada 10.000 adicionales -> odds: {np.exp(b*1e4):.4f} | efecto marginal: {me.loc['annual_inc','dy/dx']*1e4:.4f}")

# %% [markdown]
# **Significativas al 5%:** `ir_cat` (0-8, 11-13.5 y 13.5+), `grade` (E, D, C, B y A) y `annual_inc`. **No significativas:** `age` (p = 0,056, queda en el límite), `loan_amnt` (p = 0,769), `ir_cat` 8-11 y `grade` F.
# 
# - **Tasa de interés** (referencia Missing): `0-8` multiplica los odds por 0,659 (−34 %) y baja la probabilidad de default 4,0 pp; `11-13.5` los multiplica por 1,214 (+1,9 pp) y `13.5+` por 1,270 (+2,3 pp).
# - **Calificación** (referencia G, la peor): cuanto mejor la calificación, menor el riesgo. Los odds se multiplican por 0,457 (E), 0,358 (D), 0,296 (C), 0,226 (B) y 0,190 (A). En probabilidad, la baja es de 7,5 pp (E) hasta 15,9 pp (A) respecto de la categoría G.
# - **Ingreso anual:** cada 10.000 adicionales multiplican los odds por 0,9425 (−5,8 %) y reducen la probabilidad de default 0,57 pp. A mayor ingreso, menos riesgo.
# 
# Todo *ceteris paribus*.

# %% [markdown]
# ## 6. Modelo `log_model_age_ir`

# %%
log_model_age_ir = smf.logit("loan_status ~ age + ir_cat", data=train_set).fit()
print(log_model_age_ir.summary())

# %% [markdown]
# ## 7. Predicciones sobre `test_set`: `predictions_all_small`

# %%
predictions_all_small = log_model_age_ir.predict(exog=test_set)
predictions_all_small.head()

# %% [markdown]
# ## 8. Rango de las predicciones: ¿qué tan bien discrimina?

# %%
print("Mínimo:", predictions_all_small.min().round(4), " Máximo:", predictions_all_small.max().round(4))
print("Rango:", (predictions_all_small.max() - predictions_all_small.min()).round(4))

# %% [markdown]
# **Respuesta:** las probabilidades predichas van de 3,6 % a 18,6 % (rango de 0,15). El modelo nunca asigna una probabilidad alta de default, aunque algunos préstamos sí caen en default, y sus predicciones están encerradas en una banda estrecha alrededor de la tasa base (≈ 11 %). Eso indica una **capacidad de discriminación limitada**: separa algo a los clientes (el pseudo-R² es solo 0,026), pero no identifica con claridad quién va a caer en default.

# %% [markdown]
# ## 9. Modelo completo `log_model_full` (sin `int_rate` ni `emp_length`)

# %%
f_full = "loan_status ~ loan_amnt + grade + home_ownership + annual_inc + age + ir_cat"
log_model_full = smf.logit(f_full, data=train_set).fit()
print(log_model_full.summary())

# %% [markdown]
# ## 10. Predicciones del modelo completo

# %%
predictions_all_full = log_model_full.predict(exog=test_set)
predictions_all_full.head()

# %% [markdown]
# ## 11. Rango de las probabilidades: modelo completo vs. `log_model_age_ir`

# %%
rangos = pd.DataFrame({
    "log_model_age_ir": [predictions_all_small.min(), predictions_all_small.max()],
    "log_model_full": [predictions_all_full.min(), predictions_all_full.max()]}, index=["mínimo", "máximo"])
rangos.loc["rango"] = rangos.loc["máximo"] - rangos.loc["mínimo"]
rangos.round(4)

# %% [markdown]
# **Respuesta:** con el modelo completo el rango se ensancha: de ≈ 0,0 % a 43,8 % (rango de 0,44), frente a 3,6 %–18,6 % del modelo `log_model_age_ir`. Al incorporar la calificación y el ingreso anual, el modelo se atreve a asignar probabilidades mucho más bajas y mucho más altas, es decir, distingue mejor entre buenos y malos pagadores. Aun así la mejora es moderada (pseudo-R² de 0,036).

# %% [markdown]
# ## 12. Modelos `probit_model_full` y `rf_model_full`

# %%
probit_model_full = smf.probit(f_full, data=train_set).fit()

cols = ["loan_amnt", "grade", "home_ownership", "annual_inc", "age", "ir_cat"]
X_train = pd.get_dummies(train_set[cols], columns=["grade", "home_ownership", "ir_cat"], dtype=int)
X_test = pd.get_dummies(test_set[cols], columns=["grade", "home_ownership", "ir_cat"], dtype=int)
y_train, y_test = train_set["loan_status"], test_set["loan_status"]

rf_model_full = RandomForestClassifier(n_estimators=500, random_state=567)
rf_model_full.fit(X_train, y_train)

# %% [markdown]
# ## 13. Pronósticos y vector de clasificación con corte 0,14

# %%
probs_logit = log_model_full.predict(exog=test_set)
probs_probit = probit_model_full.predict(exog=test_set)
probs_rf = rf_model_full.predict_proba(X_test)[:, 1]

corte = 0.14
preds_logit = (probs_logit >= corte).astype(int)
preds_probit = (probs_probit >= corte).astype(int)
preds_rf = (probs_rf >= corte).astype(int)
print("Predichos como default:", preds_logit.sum(), preds_probit.sum(), preds_rf.sum(), "de", len(y_test))

# %% [markdown]
# ## 14. Matrices de confusión

# %%
preds = {"Logit": preds_logit, "Probit": preds_probit, "Random forest": preds_rf}
fig, axes = plt.subplots(1, 3, figsize=(15, 4))
for ax, (nombre, p) in zip(axes, preds.items()):
    metrics.ConfusionMatrixDisplay(metrics.confusion_matrix(y_test, p)).plot(ax=ax, colorbar=False)
    ax.set_title(nombre)
plt.show()
for nombre, p in preds.items():
    print(nombre); print(pd.crosstab(y_test, p, rownames=["Real"], colnames=["Predicho"])); print()

# %% [markdown]
# ## 15. Precisión, sensibilidad y especificidad

# %%
res = pd.DataFrame({
    nombre: {"Precisión": metrics.accuracy_score(y_test, p),
             "Sensibilidad": metrics.recall_score(y_test, p),
             "Especificidad": metrics.recall_score(y_test, p, pos_label=0)}
    for nombre, p in preds.items()})
(res * 100).round(2)

# %% [markdown]
# **Respuesta:** con corte de 0,14, logit y probit son prácticamente idénticos (precisión ≈ 72,5 %, sensibilidad ≈ 44,4 %, especificidad ≈ 76,0 %). El bosque aleatorio es peor en las tres medidas (67,1 %, 39,3 % y 70,6 %). Como solo ≈ 11 % de los préstamos caen en default, la precisión global engaña un poco: lo que más importa a un prestamista es la sensibilidad, y con este corte se deja pasar a más de la mitad de los que luego incumplen.

# %% [markdown]
# ## 16. Curvas ROC

# %%
probs = {"Logit": probs_logit, "Probit": probs_probit, "Random forest": probs_rf}
plt.figure(figsize=(8, 6))
for nombre, pr in probs.items():
    fpr, tpr, _ = metrics.roc_curve(y_test, pr)
    plt.plot(fpr, tpr, label=nombre)
plt.plot([0, 1], [0, 1], "k--", label="Azar")
plt.xlabel("1 - Especificidad (FPR)"); plt.ylabel("Sensibilidad (TPR)"); plt.title("Curvas ROC")
plt.legend(); plt.show()

# %% [markdown]
# ## 17. AUC y mejor modelo

# %%
auc = {n: metrics.roc_auc_score(y_test, pr) for n, pr in probs.items()}
print(pd.Series(auc).round(4))
mejor = max(auc, key=auc.get)
print("Mejor modelo por AUC:", mejor)

# %% [markdown]
# **Respuesta:** el AUC del probit (0,6686) es el más alto, prácticamente empatado con el logit (0,6680). El bosque aleatorio queda en 0,5899, bastante más cerca del azar (0,5). Para estos datos el **probit** es el modelo más adecuado, aunque la diferencia con el logit es insignificante. El bosque, con 500 árboles sin ajustar, parece sobreajustar los datos de entrenamiento y no generaliza.

# %% [markdown]
# ## 18. Corte óptimo del mejor modelo (máxima distancia TPR − FPR, índice de Youden)

# %%
fpr, tpr, thr = metrics.roc_curve(y_test, probs[mejor])
k = np.argmax(tpr - fpr)
print(f"Corte óptimo ({mejor}): {thr[k]:.4f} | TPR = {tpr[k]:.4f} | FPR = {fpr[k]:.4f} | TPR-FPR = {tpr[k]-fpr[k]:.4f}")

# %% [markdown]
# **Respuesta:** para el probit, el corte que maximiza la distancia TPR − FPR (índice de Youden) es **0,1132**, con TPR = 67,5 %, FPR = 41,4 % y distancia de 0,260. Es menor que el 0,14 usado antes: clasifica más préstamos como default, así que la sensibilidad sube de 44,5 % a 67,5 % a cambio de más falsos positivos (rechazar a buenos clientes). La decisión final dependería del costo relativo de un default frente al de rechazar a un buen cliente.
