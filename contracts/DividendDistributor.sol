// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title DividendDistributor
 * @dev Distribui dividendos automaticamente para holders de RWA tokens
 */
contract DividendDistributor is AccessControl, ReentrancyGuard {
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    
    struct DividendInfo {
        address asset;
        uint256 totalDividends;
        uint256 dividendPerShare;
        uint256 timestamp;
        bool distributed;
    }
    
    struct UserDividendInfo {
        uint256 lastClaimedIndex;
        uint256 totalClaimed;
    }
    
    mapping(address => DividendInfo[]) public dividendHistory; // asset => dividends
    mapping(address => mapping(address => UserDividendInfo)) public userDividends; // user => asset => info
    
    event DividendsDeposited(address indexed asset, uint256 amount, uint256 perShare);
    event DividendsClaimed(address indexed user, address indexed asset, uint256 amount);
    event AutoReinvested(address indexed user, address indexed asset, uint256 amount);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev Deposita dividendos para distribuição
     */
    function depositDividends(
        address asset,
        uint256 amount,
        uint256 totalShares
    ) external onlyRole(DISTRIBUTOR_ROLE) {
        require(amount > 0, "Amount must be greater than 0");
        require(totalShares > 0, "No shares");
        
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        
        uint256 dividendPerShare = (amount * 1e18) / totalShares;
        
        DividendInfo memory info = DividendInfo({
            asset: asset,
            totalDividends: amount,
            dividendPerShare: dividendPerShare,
            timestamp: block.timestamp,
            distributed: false
        });
        
        dividendHistory[asset].push(info);
        
        emit DividendsDeposited(asset, amount, dividendPerShare);
    }
    
    /**
     * @dev Calcula dividendos pendentes
     */
    function getPendingDividends(
        address user,
        address asset,
        uint256 userShares
    ) public view returns (uint256) {
        UserDividendInfo storage userInfo = userDividends[user][asset];
        DividendInfo[] storage divHistory = dividendHistory[asset];
        
        uint256 pending = 0;
        
        for (uint i = userInfo.lastClaimedIndex; i < divHistory.length; i++) {
            pending += (divHistory[i].dividendPerShare * userShares) / 1e18;
        }
        
        return pending;
    }
    
    /**
     * @dev Reinveste dividendos automaticamente
     */
    function autoReinvest(
        address user,
        address asset,
        uint256 userShares,
        address vaultAddress
    ) external onlyRole(DISTRIBUTOR_ROLE) nonReentrant returns (uint256) {
        uint256 pending = getPendingDividends(user, asset, userShares);
        
        if (pending > 0) {
            userDividends[user][asset].lastClaimedIndex = dividendHistory[asset].length;
            userDividends[user][asset].totalClaimed += pending;
            
            // Transfere para a vault do usuário
            IERC20(asset).transfer(vaultAddress, pending);
            
            emit AutoReinvested(user, asset, pending);
        }
        
        return pending;
    }
}
