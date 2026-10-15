import numpy as np
import matplotlib.pyplot as plt

# ==============================================================================
# 1. ENTRÉE DES DONNÉES DE CALIBRATION (À REMPLACER)
# ==============================================================================

# Températures internes lues par l'ADXL382 lors des paliers (en °C)
temperatures = np.array([-60.0, -50.0, -40.0, -30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0])

# Erreurs d'offset mesurées pour chaque axe (en g)
# (Erreur = Valeur lue - Valeur attendue)
# Exemple: si l'axe Z devrait être à 1.000g mais lit 1.015g, l'erreur est de 0.015
offset_x = np.array([-0.006, -0.003, -0.001,  0.001,  0.002,  0.002,  0.001, -0.002, -0.005])
offset_y = np.array([ 0.004,  0.002,  0.001,  0.000, -0.001, -0.002, -0.003, -0.003, -0.002])
offset_z = np.array([-0.012, -0.005,  0.002,  0.008,  0.004,  0.000, -0.003,  0.001,  0.009])

# Degré du polynôme
ORDRE_POLYNOME = 3

# ==============================================================================
# 2. CALCUL DES COEFFICIENTS (RÉGRESSION POLYNOMIALE)
# ==============================================================================

# np.polyfit retourne les coefficients du plus haut degré au plus bas [C3, C2, C1, C0]
coefs_x = np.polyfit(temperatures, offset_x, ORDRE_POLYNOME)
coefs_y = np.polyfit(temperatures, offset_y, ORDRE_POLYNOME)
coefs_z = np.polyfit(temperatures, offset_z, ORDRE_POLYNOME)

# On inverse le tableau pour avoir [C0, C1, C2, C3] (plus facile pour le C)
c_x = coefs_x[::-1]
c_y = coefs_y[::-1]
c_z = coefs_z[::-1]

# ==============================================================================
# 3. GÉNÉRATION DU CODE C POUR VOTRE STM32
# ==============================================================================

coeffs = f"""
// ================= COEFFICIENTS =================
    // Coefficients Axe X (C0 à C3)
    .c0 = {c_x[0]:.8e}f,
    .c1 = {c_x[1]:.8e}f,
    .c2 = {c_x[2]:.8e}f,
    .c3 = {c_x[3]:.8e}f,

    // Coefficients Axe Y (C0 à C3)
    .c0 = {c_y[0]:.8e}f,
    .c1 = {c_y[1]:.8e}f,
    .c2 = {c_y[2]:.8e}f,
    .c3 = {c_y[3]:.8e}f,

    // Coefficients Axe Z (C0 à C3)
    .c0 = {c_z[0]:.8e}f,
    .c1 = {c_z[1]:.8e}f,
    .c2 = {c_z[2]:.8e}f,
    .c3 = {c_z[3]:.8e}f
// =================================================================
"""
print(coeffs)

# ==============================================================================
# 4. AFFICHAGE DU GRAPHIQUE DE VÉRIFICATION
# ==============================================================================

# Création d'une courbe lisse pour l'affichage
t_lisse = np.linspace(min(temperatures), max(temperatures), 100)
fit_x = np.polyval(coefs_x, t_lisse)
fit_y = np.polyval(coefs_y, t_lisse)
fit_z = np.polyval(coefs_z, t_lisse)

plt.figure(figsize=(12, 4))

# Axe X
plt.subplot(1, 3, 1)
plt.scatter(temperatures, offset_x * 1000, color='red', label='Mesures (mg)')
plt.plot(t_lisse, fit_x * 1000, color='blue', label='Modèle 3e Ordre')
plt.title("Axe X")
plt.xlabel("Température (°C)")
plt.ylabel("Offset (mg)")
plt.grid(True)
plt.legend()

# Axe Y
plt.subplot(1, 3, 2)
plt.scatter(temperatures, offset_y * 1000, color='red', label='Mesures (mg)')
plt.plot(t_lisse, fit_y * 1000, color='blue', label='Modèle 3e Ordre')
plt.title("Axe Y")
plt.xlabel("Température (°C)")
plt.grid(True)

# Axe Z
plt.subplot(1, 3, 3)
plt.scatter(temperatures, offset_z * 1000, color='red', label='Mesures (mg)')
plt.plot(t_lisse, fit_z * 1000, color='blue', label='Modèle 3e Ordre')
plt.title("Axe Z")
plt.xlabel("Température (°C)")
plt.grid(True)

plt.tight_layout()
plt.show()