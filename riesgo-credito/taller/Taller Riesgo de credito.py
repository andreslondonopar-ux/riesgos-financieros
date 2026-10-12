# %% [markdown]
# # Taller — Riesgo de crédito
# Gerencia de riesgos financieros 2026-2 · Actividad en clase (septiembre 2026)

# %%
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.metrics import confusion_matrix

loan_data = pd.read_csv("https://raw.githubusercontent.com/salas317/Data/main/GRF/loan_data_ch1.csv", index_col=0)
loan_data.head()

# %% [markdown]
# ## Parte 1
# ### 1. `value_counts` del estado del préstamo (conteo y proporción)

# %%
print(loan_data["loan_status"].value_counts())
print(loan_data["loan_status"].value_counts(normalize=True).round(3))

# %% [markdown]
# `loan_status = 1` es *default* (impago) y `0` es no default. La base está muy desbalanceada: alrededor del 11% de los préstamos están en default.

# %% [markdown]
# ### 2. `crosstab` de `grade` (filas) vs `loan_status` (columnas)

# %%
pd.crosstab(index=loan_data["grade"], columns=loan_data["loan_status"], margins=True)

# %%
pd.crosstab(index=loan_data["grade"], columns=loan_data["loan_status"], normalize="index").round(3)

# %% [markdown]
# La proporción de default crece de forma monótona al pasar de la calificación A (mejor) a G (peor): 5.9 %, 10.6 %, 14.7 %, 18.0 %, 20.3 %, 26.5 % y 37.5 % (A a G). La calificación sí discrimina el riesgo. Ojo: la categoría G tiene solo 56 casos, así que su proporción de 37.5 % es poco precisa (un intervalo de confianza amplio).

# %% [markdown]
# ## Parte 2
# ### 3. Histograma de la cantidad prestada

# %%
plt.figure(figsize=(10,6))
plt.hist(loan_data["loan_amnt"], color="skyblue", edgecolor="black")
plt.title("Histograma de la cantidad prestada"); plt.xlabel("Cantidad prestada"); plt.ylabel("Frecuencia")
plt.show()

# %% [markdown]
# ### 4. Información de los cortes del histograma

# %%
n, bins, _ = plt.hist(loan_data["loan_amnt"], color="skyblue", edgecolor="black"); plt.close()
for i in range(len(n)):
    print(f"Corte {i+1}: [{bins[i]:,.0f}, {bins[i+1]:,.0f}) -> {int(n[i])} observaciones")

# %% [markdown]
# ### 5. 200 cortes, eje x y título

# %%
plt.figure(figsize=(12,6))
plt.hist(loan_data["loan_amnt"], bins=200, color="skyblue", edgecolor="black")
plt.title("Histograma de la cantidad prestada"); plt.xlabel("Cantidad prestada"); plt.ylabel("Frecuencia")
plt.show()

# %% [markdown]
# **¿Por qué ocurren los picos donde ocurren?** Con más cortes aparecen picos regulares en montos “redondos”. El más frecuente es 10.000 con 2.372 préstamos, seguido de 5.000 (1.798), 6.000 (1.629), 12.000 (1.594), 15.000 (1.334) y 8.000 (1.304). Solo hay 753 valores distintos de monto, y el 74 % de los montos son múltiplos de 500 y el 64 % múltiplos de 1.000. Los préstamos no se piden en montos continuos: tanto los solicitantes como la entidad tienden a pedir y aprobar cifras redondas, por lo que la cantidad prestada se concentra en esos valores y no se reparte de forma suave.

# %% [markdown]
# ### 6. Diagrama de dispersión de la edad

# %%
plt.figure(figsize=(10,6))
plt.scatter(range(len(loan_data)), loan_data["age"], color="teal", alpha=0.3)
plt.xlabel("Observación"); plt.ylabel("Edad"); plt.show()
print("Edad máxima:", loan_data["age"].max())

# %% [markdown]
# ### 7. Eliminar la observación de la persona con edad imposible
# En esta versión de la base no existe la edad 122 que menciona el enunciado. El único atípico es de 144 años (fila 19486, que además tiene un ingreso de 6.000.000); la siguiente edad más alta es 94. Se elimina esa observación (edad > 100), quedando 29.091 filas.

# %%
print(loan_data[loan_data["age"] > 100])
new_data = loan_data[loan_data["age"] <= 100]
print(loan_data.shape, new_data.shape)

# %% [markdown]
# ### 8. Edad vs ingreso anual (`new_data`)

# %%
plt.figure(figsize=(10,6))
plt.scatter(new_data["age"], new_data["annual_inc"], color="teal", alpha=0.3)
plt.xlabel("Edad"); plt.ylabel("Ingreso anual"); plt.show()

# %% [markdown]
# ## Parte 3
# ### 9. Valores omitidos en la tasa de interés

# %%
print(loan_data["int_rate"].isna().sum())
loan_data.isna().sum()

# %% [markdown]
# ### 10. `loan_data_delrow_na`: eliminar registros con tasa omitida

# %%
loan_data_delrow_na = loan_data.dropna(subset=["int_rate"])
loan_data_delrow_na.shape

# %% [markdown]
# ### 11. `loan_data_replace`: reemplazar con la mediana

# %%
loan_data_replace = loan_data.copy()
mediana = loan_data_replace["int_rate"].median()
loan_data_replace["int_rate"] = loan_data_replace["int_rate"].fillna(mediana)
print("Mediana:", mediana)

# %% [markdown]
# ### 12. Verificación de que no quedan omitidos

# %%
print(loan_data_delrow_na["int_rate"].isna().sum(), loan_data_replace["int_rate"].isna().sum())

# %% [markdown]
# ### 13. Variable `ir_cat`

# %%
# Convención: intervalos cerrados a la derecha (a, b], igual que emp_cat en clase (right=True).
# Las etiquetas "0-8", "8-11"... se leen como (0,8], (8,11], (11,13.5], (13.5,inf).
# El límite inferior es -1 solo para incluir el 0; una tasa exactamente 8.00 queda en "0-8".
cortes = [-1, 8, 11, 13.5, np.inf]
etiquetas = ["0-8", "8-11", "11-13.5", "13.5+"]
loan_data["ir_cat"] = pd.cut(loan_data["int_rate"], bins=cortes, labels=etiquetas, right=True)
loan_data["ir_cat"] = loan_data["ir_cat"].cat.add_categories("missing")
loan_data.loc[loan_data["int_rate"].isna(), "ir_cat"] = "missing"
loan_data["ir_cat"].value_counts(sort=False)

# %% [markdown]
# ### 14. Gráfico de `ir_cat`

# %%
plt.figure(figsize=(10,6))
loan_data["ir_cat"].value_counts(sort=False).plot(kind="bar", color="skyblue", edgecolor="black")
plt.title("Categorías de la tasa de interés"); plt.xlabel("Rango"); plt.ylabel("Frecuencia"); plt.xticks(rotation=0)
plt.show()

# %% [markdown]
# ## Parte 4
# ### 15. Entrenamiento (4/5) y prueba (1/5), semilla 567

# %%
training_set, test_set = train_test_split(loan_data, train_size=4/5, random_state=567)
print(training_set.shape, test_set.shape)

# %% [markdown]
# ### 16. Predicciones simuladas `model_pred`

# %%
np.random.seed(42)
model_pred = np.random.choice([0, 1], size=test_set.shape[0], p=[0.8, 0.2])
pd.Series(model_pred).value_counts()

# %% [markdown]
# ### 17. Matriz de confusión

# %%
pd.crosstab(index=test_set["loan_status"], columns=model_pred, rownames=["Real"], colnames=["Predicho"])

# %%
tn, fp, fn, tp = confusion_matrix(test_set["loan_status"], model_pred).ravel()
print(tn, fp, fn, tp)

# %% [markdown]
# ### 18. Precisión, sensibilidad y especificidad

# %%
precision = (tp + tn) / (tp + tn + fp + fn)
sensibilidad = tp / (tp + fn)
especificidad = tn / (tn + fp)
print(f"Precisión (accuracy): {precision:.2%}")
print(f"Sensibilidad:         {sensibilidad:.2%}")
print(f"Especificidad:        {especificidad:.2%}")

# %% [markdown]
# Como `model_pred` es aleatorio (independiente de la realidad), la sensibilidad ≈ 20 % y la especificidad ≈ 80 % salen directamente de `p=[0.8, 0.2]` en `np.random.choice`: el vector no depende de la realidad, así que acierta el 20 % de los defaults y el 80 % de los no defaults. El “modelo” no tiene poder predictivo.
# 
# Nota de terminología: el enunciado llama “precisión” a (TP+TN)/total, que en rigor es la **exactitud (accuracy)**; no es la precisión TP/(TP+FP). La exactitud de 73.67 % es incluso **peor** que la del clasificador trivial “todos 0” (nadie en default), que acertaría 88.78 % en el test (11.22 % de defaults): con clases desbalanceadas, la exactitud sola engaña.
