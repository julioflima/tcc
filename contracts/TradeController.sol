// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title TradeController
 * @dev Gerencia validações e restrições de trades
 */
contract TradeController is AccessControl {
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    
    uint256 public constant MAX_SLIPPAGE = 5; // 5%
    uint256 public constant MIN_TRADE_AMOUNT = 100; // Valor mínimo em reais tokenizados
    
    struct TradeRecord {
        address user;
        address fromAsset;
        address toAsset;
        uint256 amountFrom;
        uint256 amountTo;
        uint256 timestamp;
        uint256 priceAtTrade;
    }
    
    mapping(address => TradeRecord[]) public userTradeHistory;
    mapping(address => mapping(uint256 => bool)) public monthlyTradeUsed; // user => month => used
    
    event TradeValidated(address indexed user, uint256 indexed month);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev Valida se trade pode ser executado
     */
    function validateTrade(
        address user,
        address fromAsset,
        address toAsset,
        uint256 amountFrom,
        uint256 amountTo
    ) external onlyRole(VALIDATOR_ROLE) returns (bool) {
        uint256 currentMonth = getCurrentMonth();
        
        require(!monthlyTradeUsed[user][currentMonth], "Monthly trade already used");
        require(amountFrom >= MIN_TRADE_AMOUNT, "Amount below minimum");
        require(fromAsset != toAsset, "Same asset trade");
        
        return true;
    }
    
    /**
     * @dev Registra trade executado
     */
    function recordTrade(
        address user,
        address fromAsset,
        address toAsset,
        uint256 amountFrom,
        uint256 amountTo,
        uint256 price
    ) external onlyRole(VALIDATOR_ROLE) {
        uint256 currentMonth = getCurrentMonth();
        
        TradeRecord memory record = TradeRecord({
            user: user,
            fromAsset: fromAsset,
            toAsset: toAsset,
            amountFrom: amountFrom,
            amountTo: amountTo,
            timestamp: block.timestamp,
            priceAtTrade: price
        });
        
        userTradeHistory[user].push(record);
        monthlyTradeUsed[user][currentMonth] = true;
        
        emit TradeValidated(user, currentMonth);
    }
    
    /**
     * @dev Retorna mês atual (desde Unix epoch)
     */
    function getCurrentMonth() public view returns (uint256) {
        return block.timestamp / 30 days;
    }
    
    /**
     * @dev Retorna histórico de trades do usuário
     */
    function getUserTradeHistory(address user) external view returns (TradeRecord[] memory) {
        return userTradeHistory[user];
    }
}
