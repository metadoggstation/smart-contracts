// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ChamberCartridge
 * @dev 弾倉NFT（ERC-721）。ERC-6551 Registryと連携し、各トークンがスマートアカウント（車）を保有する起点となる。
 */
contract ChamberCartridge is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;
    
    // 戦術メタデータのオンチェーン記録
    mapping(uint256 => uint256) public beefRatio;
    mapping(uint256 => uint256) public chickenRatio;
    mapping(uint256 => uint256) public lifetimeWinRate;

    // TBA (ERC-6551) Registryコントラクトのアドレス
    address public erc6551Registry;

    constructor(address _registry) ERC721("Metadogg Cartridge", "CHAMBER") Ownable(msg.sender) {
        erc6551Registry = _registry;
    }

    /**
     * @notice 未認証ユーザーがオンボーディングを果たした際に弾倉NFTをMintする
     */
    function mintCartridge(address to, string memory uri, uint256 _beefRatio, uint256 _chickenRatio) external {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        beefRatio[tokenId] = _beefRatio;
        chickenRatio[tokenId] = _chickenRatio;
        
        // TODO: Mint成功後、フロントエンドからERC-6551 Registryを呼び出し、
        // このtokenIdに紐づくTBA（Token Bound Account）をデプロイするフローを構築。
    }

    /**
     * @notice バックテストの結果に応じて勝率を更新（動的NFTとしての成長）
     */
    function updateWinRate(uint256 tokenId, uint256 newWinRate) external onlyOwner {
        lifetimeWinRate[tokenId] = newWinRate;
    }
}
