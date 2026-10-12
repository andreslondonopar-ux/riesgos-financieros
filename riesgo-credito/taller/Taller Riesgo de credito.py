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
# La proporción de default crece de forma monótona al pasar de la calificación A (mejor) a G (peor): la calificación sí discrimina el riesgo.

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
# **¿Por qué ocurren los picos donde ocurren?** Con más cortes aparecen picos regulares en montos “redondos” (10.000, 5.000, 6.000, 12.000, 15.000, 8.000…; el más frecuente es 10.000 con 2.372 préstamos). Los préstamos no se piden en montos continuos: tanto los solicitantes como la entidad tienden a pedir y aprobar cifras redondas, por lo que la cantidad prestada se concentra en esos valores y no se reparte de forma suave.

# %% [markdown]
# ### 6. Diagrama de dispersión de la edad

# %%
plt.figure(figsize=(10,6))
plt.scatter(range(len(loan_data)), loan_data["age"], color="teal", alpha=0.3)
plt.xlabel("Observación"); plt.ylabel("Edad"); plt.show()
print("Edad máxima:", loan_data["age"].max())

# %% [markdown]
# ### 7. Eliminar la observación de la persona con edad imposible
# El enunciado habla de 122 años; en esta versión de la base la edad máxima es 144. Es el mismo caso (un error de captura), así que se elimina esa observación atípica (edad > 100).

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
cortes = [0, 8, 11, 13.5, np.inf]
etiquetas = ["0-8", "8-11", "11-13.5", "13.5+"]
loan_data["ir_cat"] = pd.cut(loan_data["int_rate"], bins=cortes, labels=etiquetas, right=False)
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
# Como `model_pred` es aleatorio (independiente de la realidad), sensibilidad ≈ 20% y especificidad ≈ 80%: el “modelo” no tiene poder predictivo; detecta tantos defaults como los que acertaría al azar.
