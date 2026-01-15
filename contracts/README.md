# Sistema de Smart Contracts - Previdência Blockchain

## Visão Geral

Este sistema implementa uma previdência descentralizada usando blockchain, substituindo o modelo tradicional de INSS/FGTS por um sistema de investimento forçado em ações de empresas brasileiras tokenizadas.

## Arquitetura de Contratos

### 1. RetirementVault.sol (Contrato Principal)

**Responsabilidade**: Gerenciar carteiras individuais de aposentadoria com sistema Multi-Sig.

**Funcionalidades principais**:
- Criação de vaults individuais com data de nascimento
- Depósitos de INSS/FGTS e contribuições voluntárias
- Sistema de trades limitado a 1 por mês
- Bloqueio de liquidação antes dos 65 anos
- Gestão de beneficiários para herança
- Distribuição de herança após óbito
- Liquidação após 100 anos sem prova de vida

**Poderes Multi-Sig**:

| Operação | Chave do Indivíduo | Chave do Governo | Condição |
|----------|-------------------|------------------|----------|
| Trade mensal | ✅ Requerida | ✅ Validação automática | Sempre |
| Liquidação | ✅ Requerida | ❌ Bloqueada | Antes de 65 anos |
| Liquidação | ✅ Suficiente | ➖ Não requerida | Após 65 anos |
| Confisco judicial | ❌ Não pode impedir | ✅ Requerida | Com ordem judicial |
| Execução herança | ➖ Não participa | ✅ Requerida | Após óbito |
| Liquidação após 100 anos | ➖ Não requerida | ✅ Plenos poderes | Após 100 anos sem vida |

### 2. TradeController.sol

**Responsabilidade**: Validar e controlar trades mensais.

**Funcionalidades**:
- Validação de limite de 1 trade/mês
- Registro histórico de todas operações
- Verificação de valores mínimos
- Proteção contra auto-trading

### 3. DividendDistributor.sol

**Responsabilidade**: Gerenciar distribuição automática de dividendos.

**Funcionalidades**:
- Recebimento de dividendos das empresas
- Cálculo proporcional por holder
- Reinvestimento automático na vault
- Histórico de dividendos recebidos

### 4. RWAToken.sol (Real World Asset Token)

**Responsabilidade**: Tokenizar ações reais da B3.

**Características**:
- ERC-20 padrão
- Paridade 1:1 com ações custodiadas
- Sistema de auditoria trimestral
- Mint/Burn apenas por custodiante
- Pausável para emergências

**Exemplo**: 
- 1 RWA-PETR4 = 1 ação real de Petrobras (PETR4) custodiada

## Fluxo de Operação

### 1. Criação de Vault
```solidity
// Usuário cria vault informando data de nascimento
retirementVault.createVault(birthDate);
```

### 2. Depósito Mensal (INSS/FGTS)
```solidity
// Governo deposita automaticamente INSS do trabalhador
IERC20(rwaPETR4).approve(vaultAddress, amount);
retirementVault.deposit(rwaPETR4, amount);
```

### 3. Trade Mensal
```solidity
// Trabalhador decide trocar PETR4 por VALE3
retirementVault.trade(
    rwaPETR4,      // De: Petrobras
    rwaVALE3,      // Para: Vale
    100,           // Quantidade PETR4
    250,           // Quantidade esperada VALE3
    priceOracle    // Preço do oracle
);
```

### 4. Aposentadoria (65+ anos)
```solidity
// Trabalhador pode sacar livremente
retirementVault.withdraw(rwaPETR4, amount);
```

### 5. Herança
```solidity
// 1. Cadastrar beneficiários (antes de falecer)
retirementVault.addBeneficiary(filhoAddress);

// 2. Governo registra óbito
retirementVault.registerDeath(
    deceasedAddress,
    deathDate,
    certidaoHash
);

// 3. Governo distribui para beneficiários
retirementVault.distributeInheritance(
    deceasedAddress,
    rwaPETR4
);
```

## Segurança Multi-Sig

### Implementação da Multi-Signature

O sistema usa **lógica condicional** ao invés de assinaturas criptográficas tradicionais:

```solidity
// ANTES DOS 65 ANOS - Bloqueio de saque
function withdraw(...) external isRetired { // Reverte se idade < 65
    // Só executa se idade >= 65
}

// TRADE - Requer validação temporal
function trade(...) external canTrade { // Verifica cooldown
    require(block.timestamp >= lastTrade + 30 days);
    // Executa trade
}

// CONFISCO - Requer role do governo
function emergencyWithdrawal(...) external onlyRole(GOVERNMENT_ROLE) {
    require(judicialOrderHash != bytes32(0));
    // Executa confisco
}
```

### Proteções Implementadas

1. **ReentrancyGuard**: Proteção contra ataques de reentrada
2. **AccessControl**: Sistema de roles para governo/oracle/custodiantes
3. **Pausable** (em RWAToken): Pausar operações em emergências
4. **Slippage Protection**: Proteção de 5% em trades
5. **Cooldown temporal**: 30 dias entre trades
6. **Validação de idade**: Bloqueio automático baseado em timestamp

## Integração com B3

### Bridge Blockchain ↔ B3

```
[Investidor] → [Vault Blockchain] → [Smart Contract] 
                                            ↓
                                    [Custodiante CBLC]
                                            ↓
                                    [Ações Reais B3]
```

**Fluxo de tokenização**:
1. Custodiante recebe ações reais na CBLC
2. Custodiante minta RWATokens equivalentes
3. RWATokens depositados na vault do trabalhador
4. Oracle sincroniza preços B3 → Blockchain

**Auditoria**:
- Trimestral: Verificação de que `totalSupply() == açõesCustodiadas`
- Hash de auditoria registrado on-chain
- Auditores independentes verificam custódia física

## Deployment

### Pré-requisitos
```bash
npm install --save-dev hardhat
npm install @openzeppelin/contracts
```

### Script de Deploy
```javascript
// deploy.js
const { ethers } = require("hardhat");

async function main() {
  // 1. Deploy RetirementVault
  const RetirementVault = await ethers.getContractFactory("RetirementVault");
  const vault = await RetirementVault.deploy(governmentAddress);
  await vault.deployed();
  
  // 2. Deploy TradeController
  const TradeController = await ethers.getContractFactory("TradeController");
  const tradeController = await TradeController.deploy();
  await tradeController.deployed();
  
  // 3. Deploy DividendDistributor
  const DividendDistributor = await ethers.getContractFactory("DividendDistributor");
  const dividendDist = await DividendDistributor.deploy();
  await dividendDist.deployed();
  
  // 4. Deploy RWA Tokens
  const RWAToken = await ethers.getContractFactory("RWAToken");
  const petr4Token = await RWAToken.deploy(
    "Petrobras Token",
    "RWA-PETR4",
    "PETR4",
    "33.000.167/0001-01",
    custodianAddress
  );
  await petr4Token.deployed();
  
  console.log("RetirementVault deployed to:", vault.address);
  console.log("RWA-PETR4 deployed to:", petr4Token.address);
}

main();
```

### Configuração Hardhat
```javascript
// hardhat.config.js
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    polygon: {
      url: process.env.POLYGON_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    },
    localhost: {
      url: "http://127.0.0.1:8545"
    }
  }
};
```

## Testes

### Exemplo de Teste
```javascript
// test/RetirementVault.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RetirementVault", function() {
  it("Deve criar vault corretamente", async function() {
    const [owner, user] = await ethers.getSigners();
    const RetirementVault = await ethers.getContractFactory("RetirementVault");
    const vault = await RetirementVault.deploy(owner.address);
    
    const birthDate = Math.floor(Date.now() / 1000) - (30 * 365 * 24 * 60 * 60); // 30 anos atrás
    await vault.connect(user).createVault(birthDate);
    
    const vaultInfo = await vault.getVaultInfo(user.address);
    expect(vaultInfo.owner).to.equal(user.address);
    expect(vaultInfo.currentAge).to.be.closeTo(30, 1);
  });
  
  it("Deve bloquear saque antes dos 65 anos", async function() {
    // ... setup ...
    
    await expect(
      vault.connect(user).withdraw(tokenAddress, 100)
    ).to.be.revertedWith("Not retired yet");
  });
});
```

## Governança e Upgrades

### Whitelist de Ativos
```solidity
// Apenas governo pode adicionar ativos
vault.whitelistAsset(
    rwaVALE3Address,
    "VALE3"
);
```

### DAO Híbrida (Futuro)
- 40% votos: Governo (BC + CVM)
- 30% votos: Participantes (weighted by stake)
- 30% votos: Instituições validadoras

## Gas Optimization

### Estimativas de Gas

| Operação | Gas Estimado | Custo (Polygon ~30 gwei) |
|----------|--------------|--------------------------|
| createVault() | ~150,000 | ~$0.001 |
| deposit() | ~80,000 | ~$0.0005 |
| trade() | ~120,000 | ~$0.0008 |
| withdraw() | ~70,000 | ~$0.0004 |
| distributeInheritance() | ~200,000 | ~$0.0013 |

### Otimizações Implementadas
- Uso de `storage` apenas quando necessário
- Batch operations para herança
- Eventos para indexação off-chain
- ReentrancyGuard seletivo

## Roadmap

### Fase 1 (Q1 2026) ✅
- [x] Smart contracts base
- [x] Sistema Multi-Sig
- [x] Integração com RWA tokens

### Fase 2 (Q2 2026)
- [ ] Oracle descentralizado (Chainlink)
- [ ] Interface web (dApp)
- [ ] Testes em testnet

### Fase 3 (Q3 2026)
- [ ] Auditoria de segurança
- [ ] Deploy em mainnet
- [ ] Integração com gov.br (DID)

### Fase 4 (Q4 2026)
- [ ] Programa piloto com 1000 usuários
- [ ] Integração com B3
- [ ] DAO de governança

## Licença

MIT

## Contato

Para questões técnicas sobre os smart contracts, consulte a documentação em `/docs` ou abra uma issue.
