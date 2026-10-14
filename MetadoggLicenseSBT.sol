// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MetadoggLicenseSBT
 * @dev ERC-5192 準拠のSoulbound Token。車のトランク（TBA）に付与され、他者への譲渡は不可能。
 */
contract MetadoggLicenseSBT is ERC721, Ownable {
    uint256 private _nextTokenId;
    address public paController;

    // ERC-5192: 譲渡のロック状態を示すイベント
    event Locked(uint256 tokenId);

    constructor() ERC721("Metadogg Driving License", "MDL") Ownable(msg.sender) {}

    function setPaController(address _paController) external onlyOwner {
        paController = _paController;
    }

    /**
     * @notice 一定のマス目を走破したTBA（車）に対してライセンスを発行
     */
    function issueLicense(address tbaAddress) external {
        require(msg.sender == owner() || msg.sender == paController, "Not authorized");
        uint256 tokenId = _nextTokenId++;
        _safeMint(tbaAddress, tokenId);
        
        // 発行と同時にロック状態（SBT化）を宣言
        emit Locked(tokenId);
    }

    /**
     * @notice Soulbound Tokenのため、転送を無効化するフック
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        // Mint(from == 0)の時のみ許可。それ以外の転送(Transfer)はRevert。
        require(from == address(0), "Err: This is a Soulbound Token");
        return super._update(to, tokenId, auth);
    }
}