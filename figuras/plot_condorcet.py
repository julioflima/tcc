#!/usr/bin/env python3
"""Gera o gráfico de convergência do Teorema do Júri de Condorcet."""

import numpy as np
from scipy.stats import binom
import matplotlib.pyplot as plt
import matplotlib

matplotlib.rcParams.update({
    'font.family': 'serif',
    'font.size': 12,
    'axes.labelsize': 14,
    'legend.fontsize': 11,
    'figure.figsize': (8, 5),
})

ns = np.arange(1, 102, 2)  # apenas ímpares para evitar empate

probabilidades = [0.45, 0.51, 0.55, 0.6, 0.7, 0.8]
cores = ['#d62728', '#ff7f0e', '#2ca02c', '#1f77b4', '#9467bd', '#17becf']
estilos = ['--', '-', '-', '-', '-', '-']

fig, ax = plt.subplots()

for p, cor, estilo in zip(probabilidades, cores, estilos):
    P_majority = np.array([
        1 - binom.cdf(n // 2, n, p) for n in ns
    ])
    ax.plot(ns, P_majority, estilo, color=cor, linewidth=2, label=f'$p = {p}$')

ax.axhline(y=0.5, color='gray', linestyle=':', linewidth=0.8, alpha=0.6)
ax.axhline(y=1.0, color='gray', linestyle=':', linewidth=0.8, alpha=0.4)

ax.set_xlabel('Número de votantes ($n$)')
ax.set_ylabel('$P(\\mathrm{maioria\\ correta})$')
ax.set_title('Teorema do Júri de Condorcet — Convergência')
ax.legend(loc='center right')
ax.set_xlim(1, 101)
ax.set_ylim(0, 1.05)
ax.grid(True, alpha=0.3)

fig.tight_layout()
fig.savefig('condorcet_convergencia.pdf', bbox_inches='tight')
fig.savefig('condorcet_convergencia.png', dpi=200, bbox_inches='tight')
print('Gráficos salvos: condorcet_convergencia.{pdf,png}')
