// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/**
 * @title CartridgeAccount (ERC-6551 準拠スマートアカウント)
 * @dev 弾倉NFTに紐づく「車」。\$MEATやPAアイテムを保有し、所有者の指示で自律的に動く。
 */
contract CartridgeAccount is ERC1155Holder {
    // 自身を保有しているNFTコントラクトのアドレス
    address public immutable tokenContract;
    // 自身を保有しているNFTのID
    uint256 public immutable tokenId;
    // ブロックチェーンのチェーンID
    uint256 public immutable chainId;

    // 実行エラー定義
    error NotAuthorized();

    constructor(address _tokenContract, uint256 _tokenId, uint256 _chainId) {
        tokenContract = _tokenContract;
        tokenId = _tokenId;
        chainId = _chainId;
    }

    /**
     * @notice 車の所有者（親NFTを持っているEOA）を返す
     */
    function owner() public view returns (address) {
        return IERC721(tokenContract).ownerOf(tokenId);
    }

    /**
     * @notice 車を運転する（任意のコントラクトを呼び出す）
     * 例：ButcherPoolの `stakeMeat` をこのTBAから呼び出す場合に使用。
     */
    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory result) {
        // 親NFTの所有者だけがこの車を運転（トランザクション実行）できる
        if (msg.sender != owner()) revert NotAuthorized();

        bool success;
        (success, result) = to.call{value: value}(data);
        require(success, "Call failed");

        return result;
    }

    // ETHを受け取るためのフォールバック
    receive() external payable {}
}