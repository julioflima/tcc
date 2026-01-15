// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RWAToken
 * @dev Token ERC20 que representa ações reais (Real World Asset)
 * Espelhamento 1:1 com ações da B3 custodiadas
 */
contract RWAToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant CUSTODIAN_ROLE = keccak256("CUSTODIAN_ROLE");
    
    string public companyTicker; // Ex: "PETR4"
    string public companyCNPJ;
    address public custodianAddress; // Endereço da instituição custodiante
    
    uint256 public totalRealSharesCustodied; // Total de ações reais em custódia
    bool public isPaused;
    
    struct CustodyProof {
        uint256 timestamp;
        uint256 sharesCount;
        bytes32 auditHash;
        address auditor;
    }
    
    CustodyProof[] public custodyAudits;
    
    event SharesTokenized(address indexed to, uint256 amount, bytes32 custodyReceipt);
    event SharesRedeemed(address indexed from, uint256 amount, bytes32 redemptionReceipt);
    event CustodyAuditRecorded(uint256 indexed auditId, uint256 sharesCount, bytes32 auditHash);
    event PauseStateChanged(bool isPaused);
    
    modifier whenNotPaused() {
        require(!isPaused, "Contract is paused");
        _;
    }
    
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _ticker,
        string memory _cnpj,
        address _custodian
    ) ERC20(_name, _symbol) {
        require(_custodian != address(0), "Invalid custodian");
        
        companyTicker = _ticker;
        companyCNPJ = _cnpj;
        custodianAddress = _custodian;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CUSTODIAN_ROLE, _custodian);
        _grantRole(MINTER_ROLE, _custodian);
        _grantRole(BURNER_ROLE, _custodian);
    }
    
    /**
     * @dev Tokeniza ações custodiadas (mint)
     * Apenas custodiante pode criar tokens quando ações são depositadas
     */
    function tokenizeShares(
        address to,
        uint256 amount,
        bytes32 custodyReceipt
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");
        require(custodyReceipt != bytes32(0), "Invalid custody receipt");
        
        _mint(to, amount);
        totalRealSharesCustodied += amount;
        
        emit SharesTokenized(to, amount, custodyReceipt);
    }
    
    /**
     * @dev Resgata ações (burn) e devolve ações reais
     */
    function redeemShares(
        address from,
        uint256 amount,
        bytes32 redemptionReceipt
    ) external onlyRole(BURNER_ROLE) whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(from) >= amount, "Insufficient balance");
        require(redemptionReceipt != bytes32(0), "Invalid redemption receipt");
        
        _burn(from, amount);
        totalRealSharesCustodied -= amount;
        
        emit SharesRedeemed(from, amount, redemptionReceipt);
    }
    
    /**
     * @dev Registra auditoria de custódia
     * Validação trimestral de que tokens = ações custodiadas
     */
    function recordCustodyAudit(
        uint256 sharesCount,
        bytes32 auditHash,
        address auditor
    ) external onlyRole(CUSTODIAN_ROLE) {
        require(sharesCount == totalSupply(), "Shares mismatch");
        require(auditHash != bytes32(0), "Invalid audit hash");
        require(auditor != address(0), "Invalid auditor");
        
        CustodyProof memory proof = CustodyProof({
            timestamp: block.timestamp,
            sharesCount: sharesCount,
            auditHash: auditHash,
            auditor: auditor
        });
        
        custodyAudits.push(proof);
        
        emit CustodyAuditRecorded(custodyAudits.length - 1, sharesCount, auditHash);
    }
    
    /**
     * @dev Pausa/despausa o contrato
     */
    function setPauseState(bool _isPaused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isPaused = _isPaused;
        emit PauseStateChanged(_isPaused);
    }
    
    /**
     * @dev Retorna último audit
     */
    function getLatestAudit() external view returns (CustodyProof memory) {
        require(custodyAudits.length > 0, "No audits recorded");
        return custodyAudits[custodyAudits.length - 1];
    }
    
    /**
     * @dev Verifica integridade (tokens = ações custodiadas)
     */
    function verifyCustodyIntegrity() external view returns (bool) {
        return totalSupply() == totalRealSharesCustodied;
    }
    
    /**
     * @dev Override transfer para adicionar pause
     */
    function transfer(address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }
    
    /**
     * @dev Override transferFrom para adicionar pause
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        return super.transferFrom(from, to, amount);
    }
}
