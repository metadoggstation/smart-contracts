// ERC-20 / 基軸燃料	ユーザー（またはTBA）が保有する $MEAT 残高。
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title MeatToken
 * @dev PoF (Proof of Forecast) の報酬としてTBAに付与される基軸トークン（燃料）。
 * バックエンドで計算されたスコアをEIP-712署名で検証し、安全にTBAへMintする。
 */
contract MeatToken is ERC20, Ownable, EIP712 {
    using ECDSA for bytes32;

    // 署名者（Pythonバックエンド / Oracle）のアドレス
    address public trustedSigner;
    address public paController;

    // リプレイ攻撃防止のためのnonce管理（各TBAアドレスごとに管理）
    mapping(address => uint256) public nonces;

    // EIP-712 の型ハッシュ
    bytes32 private constant POF_REWARD_TYPEHASH =
        keccak256("PoFReward(address tbaAddress,uint256 amount,uint256 nonce)");

    event PoFRewardClaimed(address indexed tbaAddress, uint256 amount);

    constructor(address _trustedSigner) 
        ERC20("Meat Token", "MEAT") 
        Ownable(msg.sender) 
        EIP712("MetadoggStation", "1") 
    {
        trustedSigner = _trustedSigner;
    }

    modifier onlyPaController() {
        require(msg.sender == paController, "Not authorized");
        _;
    }

    function setPaController(address _paController) external onlyOwner {
        paController = _paController;
    }

    function mintFor(address to, uint256 amount) external onlyPaController {
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyPaController {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
    }

    /**
     * @notice バックエンドからの署名付きスコアを検証し、TBA（車）へ直接 $MEAT をMintする
     * @param tbaAddress EOA（ユーザーのメインウォレット）ではなく、弾倉NFTに紐づくERC-6551のスマートアカウントアドレス
     * @param amount 獲得した $MEAT トークンの量
     * @param signature サーバー側で生成されたEIP-712署名
     */
    function claimPoFReward(
        address tbaAddress,
        uint256 amount,
        bytes calldata signature
    ) external {
        uint256 currentNonce = nonces[tbaAddress];
        
        // 1. EIP-712の構造体ハッシュを作成
        bytes32 structHash = keccak256(
            abi.encode(
                POF_REWARD_TYPEHASH,
                tbaAddress,
                amount,
                currentNonce
            )
        );

        // 2. ドメインセパレーターと結合して最終的なダイジェストを生成
        bytes32 digest = _hashTypedDataV4(structHash);

        // 3. 署名からアドレスを復元し、trustedSignerと一致するか確認
        address signer = ECDSA.recover(digest, signature);
        require(signer == trustedSigner, "Invalid signature: signer is not trusted");

        // 4. リプレイ攻撃を防ぐためnonceをインクリメント
        nonces[tbaAddress]++;

        // 5. TBAへ $MEAT をMint（車のトランクへ燃料を装填）
        _mint(tbaAddress, amount);

        emit PoFRewardClaimed(tbaAddress, amount);
    }

    /**
     * @notice オラクル（署名者）のアドレスを更新する
     */
    function setTrustedSigner(address _trustedSigner) external onlyOwner {
        trustedSigner = _trustedSigner;
    }
}