# INSTRUCTIONS.md - Guia para Futuras Iterações de IA

## Visão Geral do Projeto

Este é um Trabalho de Conclusão de Curso (TCC) em **Engenharia Elétrica** da **Universidade Federal do Ceará - Campus Sobral**, de autoria de **Julio Cesar Ferreira Lima**, com previsão de conclusão em **2026**.

### Título do Trabalho
**Proposta de Reforma Previdenciária: Um Mercado Financeiro Poupador via Blockchain como Alternativa ao INSS e FGTS**

---

## Estrutura do Projeto

```
tcc/
├── documento.tex           # Arquivo principal LaTeX
├── latexmkrc              # Configuração do latexmk
├── Makefile               # Comandos de build
├── raw.md                 # Rascunho original das ideias
├── INSTRUCTIONS.md        # Este arquivo
│
├── 1-pre-textuais/        # Elementos pré-textuais
│   ├── resumo.tex         # Resumo em português
│   ├── abstract.tex       # Abstract em inglês
│   ├── lista-de-abreviaturas-e-siglas.tex
│   ├── lista-de-simbolos.tex
│   └── ...
│
├── 2-textuais/            # Corpo do trabalho
│   ├── 1-introducao.tex   # Introdução
│   ├── 2-fundamentacao-teorica.tex  # Fundamentação
│   ├── 3-metodologia.tex  # Metodologia
│   ├── 4-resultados.tex   # Proposta do Sistema
│   └── 5-conclusao.tex    # Conclusões
│
├── 3-pos-textuais/        # Elementos pós-textuais
│   ├── referencias.bib    # Referências bibliográficas
│   └── ...
│
├── figuras/               # Imagens e diagramas
├── lib/                   # Arquivos de estilo
└── temp/                  # Arquivos auxiliares de compilação
```

---

## Tema Central

### Problema
O sistema previdenciário brasileiro (INSS + FGTS) é fiscalmente insustentável:
- Déficit previdenciário consome ~70% do orçamento federal
- FGTS rende menos que a inflação (perda real para o trabalhador)
- Trabalhador não é dono dos recursos que contribui
- Herança limitada em caso de falecimento

### Solução Proposta
Um mercado financeiro poupador baseado em blockchain onde:
1. Trabalhadores investem diretamente em empresas brasileiras
2. Governança compartilhada via carteiras **multi-sig 2-de-3**
3. Limite de **1 operação por mês** (evita especulação)
4. **Herança integral** do patrimônio
5. Inspirado no modelo australiano de **Superannuation**

---

## Referências Teóricas Importantes

### Escolas Econômicas
- **Escola Austríaca**: Mises, Hayek, Rothbard - defesa da poupança e livre mercado
- **Desenvolvimentista**: Furtado, Keynes - papel do Estado no desenvolvimento

### Modelos de Referência
- **Superannuation** (Austrália): Sistema de capitalização obrigatória desde 1992
- Acumulou >3.5 trilhões AUD (~170% do PIB)

### Tecnologia
- **Blockchain**: Transparência, imutabilidade, descentralização
- **Smart Contracts**: Automação de regras
- **Multi-sig**: Governança compartilhada (2-de-3 chaves)

---

## Comandos de Build

```bash
# Compilar o documento
make

# Limpar arquivos temporários
make clean

# Usando latexmk diretamente
latexmk -pdf documento.tex
```

### Configuração Importante
- PDF gerado na raiz do projeto
- Arquivos auxiliares em `temp/`
- Configurado em `latexmkrc`

---

## Diretrizes para Edição

### Estilo de Escrita
- Linguagem formal acadêmica
- Terceira pessoa ou impessoal
- Citações no formato ABNT (usando abnTeX2)

### Citações
Use `\cite{chave}` para citar. Referências definidas em `referencias.bib`.

### Siglas
Use `\gls{SIGLA}` para primeira ocorrência (expandida) e ocorrências subsequentes.

### Figuras
```latex
\begin{figure}[htb]
    \centering
    \caption{Título da Figura}
    \label{fig:identificador}
    % conteúdo da figura
    \fonte{Elaborado pelo autor (2026).}
\end{figure}
```

### Tabelas
```latex
\begin{table}[htb]
    \centering
    \caption{Título da Tabela}
    \label{tab:identificador}
    \begin{tabular}{...}
        % conteúdo
    \end{tabular}
    \fonte{Elaborado pelo autor (2026).}
\end{table}
```

---

## Labels de Referência Cruzada

- `\ref{cap:introducao}` - Introdução
- `\ref{cap:fundamentacao-teorica}` - Fundamentação Teórica
- `\ref{chap:metodologia}` - Metodologia
- `\ref{chap:resultados}` - Proposta do Sistema
- `\ref{chap:conclusoes-e-trabalhos-futuros}` - Conclusões

---

## Próximos Passos Sugeridos

### Pendências Técnicas
- [ ] Adicionar mais figuras/diagramas (arquitetura, fluxos)
- [ ] Criar diagramas com TikZ ou importar PDFs
- [ ] Revisar consistência das referências cruzadas

### Conteúdo a Expandir
- [ ] Detalhar aspectos técnicos do blockchain
- [ ] Adicionar análise quantitativa (simulações)
- [ ] Incluir comparativo detalhado Brasil vs Austrália
- [ ] Desenvolver aspectos jurídicos da proposta

### Validação
- [ ] Compilar e verificar erros de LaTeX
- [ ] Revisar formatação ABNT
- [ ] Verificar citações e referências

---

## Informações do Autor

- **Nome**: Julio Cesar Ferreira Lima
- **Curso**: Engenharia Elétrica
- **Instituição**: Universidade Federal do Ceará - Campus Sobral
- **Ano de Conclusão Previsto**: 2026

---

## Notas para IA

1. **raw.md** contém as ideias originais em formato livre - use como referência para o espírito da proposta
2. O trabalho usa a classe **abnTeX2** com template personalizado da UFC
3. Prefira editar arquivos individuais em vez do documento principal
4. Ao adicionar referências, atualize `referencias.bib`
5. Mantenha consistência com a terminologia já utilizada
6. O foco é em **proposta conceitual**, não implementação técnica completa
