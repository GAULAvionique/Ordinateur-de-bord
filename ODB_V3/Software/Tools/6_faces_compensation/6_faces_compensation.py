import numpy as np
from scipy.optimize import minimize

# ==============================================================================
# 0. CALCUL DE LA GRAVITÉ LOCALE DEPUIS LA POSITION GPS
# ==============================================================================
def get_local_gravity(latitude_deg, altitude_m=0.0):
    lat_rad = np.radians(latitude_deg)
    g_lat = 9.780327 * (1.0 + 0.0053024 * np.sin(lat_rad)**2 - 0.0000058 * np.sin(2 * lat_rad)**2)
    g_local = g_lat - 3.086e-6 * altitude_m
    
    return g_local

# REMPLACER ICI (https://www.sensorsone.com/local-gravity-calculator/#height)
MA_LATITUDE = 46.86216552246366     # deg
MON_ALTITUDE = 164.827              # m https://mylocationlab.com/fr/tools/elevation-finder/

GRAVITE_CIBLE = get_local_gravity(MA_LATITUDE, MON_ALTITUDE)
print(f"GPS ({MA_LATITUDE}°, {MON_ALTITUDE}m) -> GRAVITE_CIBLE calculée : {GRAVITE_CIBLE:.5f} m/s²\n")

# ==============================================================================
# 1. ENTRÉE DES DONNÉES DES 6 FACES (EN m/s²)
# ==============================================================================
mesures_brutes = np.array([
    [-1.680400609, -0.036314053, 10.31908595], # Face 1: Z vers le ciel (+9.8 m/s²)
    [-1.690862848, -0.01630127, -9.771821561],  # Face 2: Z vers le sol (-9.8 m/s²)
    [-1.230620741,  9.708350566, 0.379518869],  # Face 3: Y vers le ciel (+9.8 m/s²)
    [-1.956445974, -9.81566922,  0.340347006],  # Face 4: Y vers le sol (-9.8 m/s²)
    [8.111913553,  -0.140702713, 0.399014263],  # Face 5: X vers le ciel (+9.8 m/s²)
    [-11.44803221, 0.063700109, 0.385190079],   # Face 6: X vers le sol (-9.8 m/s²)
])

# ==============================================================================
# 2. FONCTION DE COÛT
# ==============================================================================
def cost_function(params, measurements):
    M = params[0:9].reshape((3, 3))
    B = params[9:12]
    
    erreur_totale = 0.0
    for acc in measurements:
        acc_corr = M @ (acc - B)
        norme = np.linalg.norm(acc_corr)
        erreur_totale += (norme - GRAVITE_CIBLE)**2
        
    return erreur_totale

# ==============================================================================
# 3. OPTIMISATION
# ==============================================================================
initial_guess = np.array([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0])

print("--- Début de l'optimisation 6-faces (m/s²) ---")
resultat = minimize(cost_function, initial_guess, args=(mesures_brutes,), method='BFGS')

if resultat.success:
    M_opt = resultat.x[0:9].reshape((3, 3))
    B_opt = resultat.x[9:12]
    
    print("\nOptimisation réussie !\n")
    
    c_code = f"""// Vecteur de biais statique (B) en m/s2
.bias = {{{B_opt[0]:.6f}f, {B_opt[1]:.6f}f, {B_opt[2]:.6f}f}},

// Matrice d'échelle et d'orthogonalité (M)
.scale_matrix = {{
    {{{M_opt[0,0]:.6f}f, {M_opt[0,1]:.6f}f, {M_opt[0,2]:.6f}f}},
    {{{M_opt[1,0]:.6f}f, {M_opt[1,1]:.6f}f, {M_opt[1,2]:.6f}f}},
    {{{M_opt[2,0]:.6f}f, {M_opt[2,1]:.6f}f, {M_opt[2,2]:.6f}f}}
}},
"""
    print(c_code)
    
    print("\n--- Vérification des normes (Cible : 9.80665 m/s²) ---")
    for i, acc in enumerate(mesures_brutes):
        acc_corr = M_opt @ (acc - B_opt)
        print(f"Face {i+1} : Norme = {np.linalg.norm(acc_corr):.5f} m/s²")
else:
    print("\n❌ Échec de l'optimisation :", resultat.message)