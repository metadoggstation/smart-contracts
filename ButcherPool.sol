// Staking / Gas Station	TBAから $MEAT をデポジット（ステーク）し、日次の双六用「流動性ポイント」を計算・管理する。
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ButcherPool
 * @dev $MEATトークンをステークし、双六（PA）用の流動性ポイント（燃料）を生成するGas Station。
 */
contract ButcherPool is Ownable {
    IERC20 public meatToken;

    // ステーク情報の構造体
    struct Stake {
        uint256 amount;
        uint256 lastClaimTime;
    }

    // TBAアドレスごとのステーキング状況
    mapping(address => Stake) public stakes;

    // 1 $MEATあたり、1秒間に生成される流動性ポイント（計算用レート）
    uint256 public constant REWARD_RATE_PER_SECOND = 100;

    event MeatStaked(address indexed tba, uint256 amount);
    event MeatUnstaked(address indexed tba, uint256 amount);
    event FuelClaimed(address indexed tba, uint256 fuelAmount);

    constructor(address _meatToken) Ownable(msg.sender) {
        meatToken = IERC20(_meatToken);
    }

    /**
     * @notice $MEATをプールに沈める（ステーク）
     * @param amount ステークする量
     */
    function stakeMeat(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");
        
        // 事前に未請求の燃料を計算して付与（内部状態の更新）
        _claimFuel(msg.sender);

        // トークンをTBAからこのプールへ移動
        require(meatToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        stakes[msg.sender].amount += amount;
        stakes[msg.sender].lastClaimTime = block.timestamp;

        emit MeatStaked(msg.sender, amount);
    }

    /**
     * @notice ステークした$MEATを引き上げる
     */
    function unstakeMeat(uint256 amount) external {
        require(stakes[msg.sender].amount >= amount, "Insufficient staked amount");

        _claimFuel(msg.sender);

        stakes[msg.sender].amount -= amount;
        require(meatToken.transfer(msg.sender, amount), "Transfer failed");

        emit MeatUnstaked(msg.sender, amount);
    }

    /**
     * @notice 蓄積された流動性ポイント（双六の燃料）を計算
     */
    function calculatePendingFuel(address tba) public view returns (uint256) {
        Stake memory userStake = stakes[tba];
        if (userStake.amount == 0) return 0;

        uint256 timeElapsed = block.timestamp - userStake.lastClaimTime;
        return timeElapsed * userStake.amount * REWARD_RATE_PER_SECOND;
    }

    /**
     * @notice 燃料を確定し、PA（双六）コントラクト等で利用できるようにする（内部処理）
     */
    function _claimFuel(address tba) internal {
        uint256 pendingFuel = calculatePendingFuel(tba);
        if (pendingFuel > 0) {
            stakes[tba].lastClaimTime = block.timestamp;
            // ※ここでPAの進行コントラクトへ燃料データを送信、または内部マッピングに記録します
            emit FuelClaimed(tba, pendingFuel);
        }
    }
}