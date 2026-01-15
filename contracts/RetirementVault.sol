// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RetirementVault
 * @dev Gerencia carteiras de aposentadoria com multi-sig entre cidadão e governo
 * @notice Este contrato implementa o sistema de previdência descentralizada
 * conforme proposta de reforma previdenciária via blockchain
 */
contract RetirementVault is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant GOVERNMENT_ROLE = keccak256("GOVERNMENT_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant ASSET_MANAGER_ROLE = keccak256("ASSET_MANAGER_ROLE");

    // Constantes
    uint256 public constant RETIREMENT_AGE = 65;
    uint256 public constant ESTATE_CLAIM_PERIOD = 100 * 365 days; // 100 anos
    uint256 public constant TRADE_COOLDOWN = 30 days; // 1 trade por mês
    
    // Estruturas de dados
    struct UserVault {
        address owner;
        uint256 birthDate;
        uint256 lastTradeTimestamp;
        uint256 createdAt;
        mapping(address => uint256) assetBalances;
        address[] beneficiaries;
        bool isDeceased;
        uint256 deathDate;
        bool isActive;
    }

    struct AssetInfo {
        bool isWhitelisted;
        string ticker;
        address tokenAddress;
        uint256 addedAt;
    }

    // Mapeamentos
    mapping(address => UserVault) public vaults;
    mapping(address => AssetInfo) public whitelistedAssets;
    mapping(bytes32 => bool) public usedDeathCertificates;
    
    address[] public allVaultOwners;
    address[] public whitelistedAssetsList;

    // Eventos
    event VaultCreated(address indexed owner, uint256 birthDate);
    event Deposit(address indexed owner, address indexed asset, uint256 amount);
    event Trade(address indexed owner, address indexed fromAsset, address indexed toAsset, uint256 amountFrom, uint256 amountTo);
    event Withdrawal(address indexed owner, address indexed asset, uint256 amount);
    event BeneficiaryAdded(address indexed owner, address indexed beneficiary);
    event BeneficiaryRemoved(address indexed owner, address indexed beneficiary);
    event DeathRegistered(address indexed owner, uint256 deathDate, bytes32 certificateHash);
    event InheritanceDistributed(address indexed deceased, address indexed beneficiary, address indexed asset, uint256 amount);
    event AssetWhitelisted(address indexed asset, string ticker);
    event AssetDelisted(address indexed asset);
    event EmergencyWithdrawal(address indexed owner, address indexed asset, uint256 amount, string reason);

    // Modificadores
    modifier onlyVaultOwner() {
        require(vaults[msg.sender].owner == msg.sender, "Not vault owner");
        require(vaults[msg.sender].isActive, "Vault not active");
        _;
    }

    modifier canTrade() {
        require(
            block.timestamp >= vaults[msg.sender].lastTradeTimestamp + TRADE_COOLDOWN,
            "Trade cooldown active"
        );
        _;
    }

    modifier isRetired() {
        require(getCurrentAge(msg.sender) >= RETIREMENT_AGE, "Not retired yet");
        _;
    }

    modifier notDeceased(address user) {
        require(!vaults[user].isDeceased, "User is deceased");
        _;
    }

    modifier onlyWhitelistedAsset(address asset) {
        require(whitelistedAssets[asset].isWhitelisted, "Asset not whitelisted");
        _;
    }

    /**
     * @dev Constructor
     * @param _governmentAddress Endereço da carteira do governo
     */
    constructor(address _governmentAddress) {
        require(_governmentAddress != address(0), "Invalid government address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNMENT_ROLE, _governmentAddress);
        _grantRole(ASSET_MANAGER_ROLE, _governmentAddress);
    }

    /**
     * @dev Cria uma nova vault de aposentadoria
     * @param birthDate Data de nascimento do usuário (timestamp Unix)
     */
    function createVault(uint256 birthDate) external {
        require(vaults[msg.sender].owner == address(0), "Vault already exists");
        require(birthDate < block.timestamp, "Invalid birth date");
        require(getCurrentAgeFromBirthDate(birthDate) >= 16, "Must be at least 16 years old");
        
        UserVault storage vault = vaults[msg.sender];
        vault.owner = msg.sender;
        vault.birthDate = birthDate;
        vault.createdAt = block.timestamp;
        vault.lastTradeTimestamp = 0;
        vault.isActive = true;
        vault.isDeceased = false;
        
        allVaultOwners.push(msg.sender);
        
        emit VaultCreated(msg.sender, birthDate);
    }

    /**
     * @dev Deposita ativos na vault
     * @param asset Endereço do token ERC20
     * @param amount Quantidade a depositar
     */
    function deposit(address asset, uint256 amount) 
        external 
        onlyVaultOwner 
        onlyWhitelistedAsset(asset)
        notDeceased(msg.sender)
        nonReentrant 
    {
        require(amount > 0, "Amount must be greater than 0");
        
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        vaults[msg.sender].assetBalances[asset] += amount;
        
        emit Deposit(msg.sender, asset, amount);
    }

    /**
     * @dev Realiza trade entre ativos (limitado a 1 por mês)
     * @param fromAsset Ativo de origem
     * @param toAsset Ativo de destino
     * @param amountFrom Quantidade do ativo de origem
     * @param amountTo Quantidade esperada do ativo de destino
     * @param priceOracle Preço fornecido pelo oracle (verificação)
     */
    function trade(
        address fromAsset,
        address toAsset,
        uint256 amountFrom,
        uint256 amountTo,
        uint256 priceOracle
    )
        external
        onlyVaultOwner
        canTrade
        onlyWhitelistedAsset(fromAsset)
        onlyWhitelistedAsset(toAsset)
        notDeceased(msg.sender)
        nonReentrant
    {
        require(fromAsset != toAsset, "Cannot trade same asset");
        require(amountFrom > 0 && amountTo > 0, "Invalid amounts");
        require(vaults[msg.sender].assetBalances[fromAsset] >= amountFrom, "Insufficient balance");
        
        // Validação de preço (proteção contra slippage)
        uint256 expectedPrice = (amountTo * 1e18) / amountFrom;
        require(
            expectedPrice >= priceOracle * 95 / 100 && 
            expectedPrice <= priceOracle * 105 / 100,
            "Price deviation too high"
        );
        
        // Executa o trade
        vaults[msg.sender].assetBalances[fromAsset] -= amountFrom;
        vaults[msg.sender].assetBalances[toAsset] += amountTo;
        vaults[msg.sender].lastTradeTimestamp = block.timestamp;
        
        emit Trade(msg.sender, fromAsset, toAsset, amountFrom, amountTo);
    }

    /**
     * @dev Saque de ativos (apenas após aposentadoria)
     * @param asset Endereço do token
     * @param amount Quantidade a sacar
     */
    function withdraw(address asset, uint256 amount)
        external
        onlyVaultOwner
        isRetired
        notDeceased(msg.sender)
        nonReentrant
    {
        require(amount > 0, "Amount must be greater than 0");
        require(vaults[msg.sender].assetBalances[asset] >= amount, "Insufficient balance");
        
        vaults[msg.sender].assetBalances[asset] -= amount;
        IERC20(asset).safeTransfer(msg.sender, amount);
        
        emit Withdrawal(msg.sender, asset, amount);
    }

    /**
     * @dev Adiciona beneficiário para herança
     * @param beneficiary Endereço do beneficiário
     */
    function addBeneficiary(address beneficiary)
        external
        onlyVaultOwner
        notDeceased(msg.sender)
    {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(beneficiary != msg.sender, "Cannot add self");
        
        // Verifica se já não é beneficiário
        for (uint i = 0; i < vaults[msg.sender].beneficiaries.length; i++) {
            require(vaults[msg.sender].beneficiaries[i] != beneficiary, "Already beneficiary");
        }
        
        vaults[msg.sender].beneficiaries.push(beneficiary);
        
        emit BeneficiaryAdded(msg.sender, beneficiary);
    }

    /**
     * @dev Remove beneficiário
     * @param beneficiary Endereço do beneficiário a remover
     */
    function removeBeneficiary(address beneficiary)
        external
        onlyVaultOwner
        notDeceased(msg.sender)
    {
        address[] storage beneficiaries = vaults[msg.sender].beneficiaries;
        
        for (uint i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i] == beneficiary) {
                beneficiaries[i] = beneficiaries[beneficiaries.length - 1];
                beneficiaries.pop();
                emit BeneficiaryRemoved(msg.sender, beneficiary);
                return;
            }
        }
        
        revert("Beneficiary not found");
    }

    /**
     * @dev Registra óbito (apenas governo)
     * @param deceased Endereço do falecido
     * @param deathDate Data do óbito
     * @param certificateHash Hash do certificado de óbito
     */
    function registerDeath(
        address deceased,
        uint256 deathDate,
        bytes32 certificateHash
    )
        external
        onlyRole(GOVERNMENT_ROLE)
    {
        require(vaults[deceased].owner == deceased, "Vault does not exist");
        require(!vaults[deceased].isDeceased, "Already registered as deceased");
        require(!usedDeathCertificates[certificateHash], "Certificate already used");
        require(deathDate <= block.timestamp, "Invalid death date");
        
        vaults[deceased].isDeceased = true;
        vaults[deceased].deathDate = deathDate;
        usedDeathCertificates[certificateHash] = true;
        
        emit DeathRegistered(deceased, deathDate, certificateHash);
    }

    /**
     * @dev Distribui herança para beneficiários (apenas governo após óbito)
     * @param deceased Endereço do falecido
     * @param asset Ativo a distribuir
     */
    function distributeInheritance(address deceased, address asset)
        external
        onlyRole(GOVERNMENT_ROLE)
        nonReentrant
    {
        require(vaults[deceased].isDeceased, "User not deceased");
        require(vaults[deceased].assetBalances[asset] > 0, "No balance to distribute");
        
        address[] memory beneficiaries = vaults[deceased].beneficiaries;
        require(beneficiaries.length > 0, "No beneficiaries");
        
        uint256 totalBalance = vaults[deceased].assetBalances[asset];
        uint256 sharePerBeneficiary = totalBalance / beneficiaries.length;
        
        for (uint i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            
            // Cria vault para beneficiário se não existir
            if (vaults[beneficiary].owner == address(0)) {
                // Beneficiário receberá na sua conta diretamente se não tiver vault
                IERC20(asset).safeTransfer(beneficiary, sharePerBeneficiary);
            } else {
                // Transfere para vault do beneficiário
                vaults[beneficiary].assetBalances[asset] += sharePerBeneficiary;
            }
            
            emit InheritanceDistributed(deceased, beneficiary, asset, sharePerBeneficiary);
        }
        
        vaults[deceased].assetBalances[asset] = 0;
    }

    /**
     * @dev Liquidação de vault após 100 anos (apenas governo)
     * @param user Endereço do usuário
     * @param asset Ativo a liquidar
     * @param treasuryAddress Endereço do tesouro para enviar fundos
     */
    function liquidateEstate(
        address user,
        address asset,
        address treasuryAddress
    )
        external
        onlyRole(GOVERNMENT_ROLE)
        nonReentrant
    {
        require(vaults[user].isDeceased, "User not deceased");
        require(
            block.timestamp >= vaults[user].deathDate + ESTATE_CLAIM_PERIOD,
            "Estate claim period not elapsed"
        );
        require(treasuryAddress != address(0), "Invalid treasury address");
        
        uint256 balance = vaults[user].assetBalances[asset];
        require(balance > 0, "No balance");
        
        vaults[user].assetBalances[asset] = 0;
        IERC20(asset).safeTransfer(treasuryAddress, balance);
        
        emit Withdrawal(user, asset, balance);
    }

    /**
     * @dev Adiciona ativo à whitelist (apenas governo)
     * @param asset Endereço do token
     * @param ticker Símbolo do ativo
     */
    function whitelistAsset(address asset, string calldata ticker)
        external
        onlyRole(ASSET_MANAGER_ROLE)
    {
        require(asset != address(0), "Invalid asset address");
        require(!whitelistedAssets[asset].isWhitelisted, "Asset already whitelisted");
        
        whitelistedAssets[asset] = AssetInfo({
            isWhitelisted: true,
            ticker: ticker,
            tokenAddress: asset,
            addedAt: block.timestamp
        });
        
        whitelistedAssetsList.push(asset);
        
        emit AssetWhitelisted(asset, ticker);
    }

    /**
     * @dev Remove ativo da whitelist (apenas governo)
     * @param asset Endereço do token
     */
    function delistAsset(address asset)
        external
        onlyRole(ASSET_MANAGER_ROLE)
    {
        require(whitelistedAssets[asset].isWhitelisted, "Asset not whitelisted");
        
        whitelistedAssets[asset].isWhitelisted = false;
        
        emit AssetDelisted(asset);
    }

    /**
     * @dev Saque emergencial com ordem judicial (apenas governo)
     * @param user Endereço do usuário
     * @param asset Ativo a sacar
     * @param amount Quantidade
     * @param reason Razão do confisco
     * @param judicialOrderHash Hash da ordem judicial
     */
    function emergencyWithdrawal(
        address user,
        address asset,
        uint256 amount,
        string calldata reason,
        bytes32 judicialOrderHash
    )
        external
        onlyRole(GOVERNMENT_ROLE)
        nonReentrant
    {
        require(vaults[user].assetBalances[asset] >= amount, "Insufficient balance");
        require(judicialOrderHash != bytes32(0), "Invalid judicial order");
        
        vaults[user].assetBalances[asset] -= amount;
        IERC20(asset).safeTransfer(msg.sender, amount);
        
        emit EmergencyWithdrawal(user, asset, amount, reason);
    }

    // ============ View Functions ============

    /**
     * @dev Retorna idade atual do usuário
     */
    function getCurrentAge(address user) public view returns (uint256) {
        require(vaults[user].owner != address(0), "Vault does not exist");
        return getCurrentAgeFromBirthDate(vaults[user].birthDate);
    }

    /**
     * @dev Calcula idade a partir da data de nascimento
     */
    function getCurrentAgeFromBirthDate(uint256 birthDate) internal view returns (uint256) {
        return (block.timestamp - birthDate) / 365 days;
    }

    /**
     * @dev Verifica se usuário pode fazer trade
     */
    function canUserTrade(address user) external view returns (bool) {
        if (vaults[user].isDeceased) return false;
        return block.timestamp >= vaults[user].lastTradeTimestamp + TRADE_COOLDOWN;
    }

    /**
     * @dev Retorna saldo de um ativo
     */
    function getAssetBalance(address user, address asset) external view returns (uint256) {
        return vaults[user].assetBalances[asset];
    }

    /**
     * @dev Retorna lista de beneficiários
     */
    function getBeneficiaries(address user) external view returns (address[] memory) {
        return vaults[user].beneficiaries;
    }

    /**
     * @dev Retorna todos os ativos whitelistados
     */
    function getWhitelistedAssets() external view returns (address[] memory) {
        return whitelistedAssetsList;
    }

    /**
     * @dev Retorna informações completas da vault
     */
    function getVaultInfo(address user) external view returns (
        address owner,
        uint256 birthDate,
        uint256 currentAge,
        uint256 lastTradeTimestamp,
        bool isDeceased,
        bool canTrade,
        address[] memory beneficiaries
    ) {
        UserVault storage vault = vaults[user];
        return (
            vault.owner,
            vault.birthDate,
            getCurrentAge(user),
            vault.lastTradeTimestamp,
            vault.isDeceased,
            block.timestamp >= vault.lastTradeTimestamp + TRADE_COOLDOWN,
            vault.beneficiaries
        );
    }

    /**
     * @dev Retorna tempo restante até próximo trade
     */
    function getTimeUntilNextTrade(address user) external view returns (uint256) {
        uint256 nextTradeTime = vaults[user].lastTradeTimestamp + TRADE_COOLDOWN;
        if (block.timestamp >= nextTradeTime) {
            return 0;
        }
        return nextTradeTime - block.timestamp;
    }
}
