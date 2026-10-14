// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC4907.sol"; // EIP-4907インターフェース

/**
 * @title ChamberCartridge (ERC-4907 拡張版)
 * @dev メカニックドッグ（開発者）が自身の車をドライバーに貸し出す（相乗り）機能。
 */
contract ChamberCartridge is ERC721URIStorage, Ownable, IERC4907 {
    uint256 private _nextTokenId;

    // トークンIDごとの利用者と有効期限の記録
    struct UserInfo {
        address user;
        uint64 expires;
    }
    mapping(uint256 => UserInfo) internal _users;

    // パラメータ記録
    mapping(uint256 => uint256) public beefRatio;
    mapping(uint256 => uint256) public chickenRatio;

    constructor() ERC721("Metadogg Cartridge", "CHAMBER") Ownable(msg.sender) {}

    /**
     * @notice ドライバーを車に乗せる（期限付きでUser権限を付与）
     */
    function setUser(uint256 tokenId, address user, uint64 expires) public virtual override {
        require(_isAuthorized(ownerOf(tokenId), msg.sender, tokenId), "Not authorized");
        UserInfo storage info = _users[tokenId];
        info.user = user;
        info.expires = expires;
        emit UpdateUser(tokenId, user, expires);
    }

    /**
     * @notice 現在ハンドルを握っているドライバー（User）を取得
     */
    function userOf(uint256 tokenId) public view virtual override returns (address) {
        if (uint256(_users[tokenId].expires) >= block.timestamp) {
            return _users[tokenId].user;
        } else {
            return address(0);
        }
    }

    /**
     * @notice レンタル期限を取得
     */
    function userExpires(uint256 tokenId) public view virtual override returns (uint256) {
        return _users[tokenId].expires;
    }
}

//{変更前} // ERC-721 / 弾倉NFT	beefRatio, chickenRatio, winRate のメタデータ。TBAの親アセットとなる。
// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;
//
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
//
// /**
//  * @title ChamberCartridge
//  * @dev 弾倉NFT。「鍵」として機能し、所有者は紐づくCartridgeAccount（TBA）を操作できる。
//  */
// contract ChamberCartridge is ERC721URIStorage, Ownable {
//     uint256 private _nextTokenId;
//
//     // PoFの戦績や設定パラメータ
//     mapping(uint256 => uint256) public beefRatio;
//     mapping(uint256 => uint256) public chickenRatio;
//     mapping(uint256 => uint256) public lifetimeWinRate;
//
//     event CartridgeMinted(address indexed to, uint256 indexed tokenId);
//     event TacticsUpdated(uint256 indexed tokenId, uint256 winRate);
//
//     constructor() ERC721("Metadogg Cartridge", "CHAMBER") Ownable(msg.sender) {}
//
//     /**
//      * @notice 未認証ユーザーがオンボーディングを果たした際に弾倉NFTをMint
//      */
//     function mintCartridge(
//         address to,
//         string memory uri,
//         uint256 _beefRatio,
//         uint256 _chickenRatio
//     ) external {
//         uint256 tokenId = _nextTokenId++;
//         _safeMint(to, tokenId);
//         _setTokenURI(tokenId, uri);
//
//         beefRatio[tokenId] = _beefRatio;
//         chickenRatio[tokenId] = _chickenRatio;
//
//         emit CartridgeMinted(to, tokenId);
//     }
//
//     /**
//      * @notice Oracle（バックエンド）から勝率などのステータスを動的に更新する
//      */
//     function updateWinRate(uint256 tokenId, uint256 newWinRate) external onlyOwner {
//         lifetimeWinRate[tokenId] = newWinRate;
//         emit TacticsUpdated(tokenId, newWinRate);
//     }
// }