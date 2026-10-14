// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IButcherPoolSettlement {
    function consumeFuel(address tba, uint256 amount) external;
}

interface IMeatTokenSettlement {
    function mintFor(address to, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
}

interface ILicenseSettlement {
    function issueLicense(address tba) external;
}

contract MetadoggStationPA is Ownable, EIP712 {
    using ECDSA for bytes32;

    bytes32 private constant GAME_TURN_RESULT_TYPEHASH =
        keccak256(
            "GameTurnResult(address tbaAddress,uint256 fuelConsumed,uint256 meatReward,bool issueLicense,uint256 nonce)"
        );

    address public trustedSigner;
    IButcherPoolSettlement public immutable butcherPool;
    IMeatTokenSettlement public immutable meatToken;
    ILicenseSettlement public immutable licenseSBT;
    mapping(address => uint256) public nonces;

    event TurnSettled(
        address indexed tbaAddress,
        uint256 fuelConsumed,
        uint256 meatReward,
        bool issueLicense
    );
    bytes32 private constant GAME_TURN_PENALTY_TYPEHASH =
        keccak256(
            "GameTurnPenalty(address tbaAddress,uint256 fuelConsumed,int256 meatReward,bool issueLicense,uint256 nonce)"
        );

    constructor(
        address _trustedSigner,
        address _butcherPool,
        address _meatToken,
        address _licenseSBT
    ) Ownable(msg.sender) EIP712("MetadoggStationPA", "1") {
        trustedSigner = _trustedSigner;
        butcherPool = IButcherPoolSettlement(_butcherPool);
        meatToken = IMeatTokenSettlement(_meatToken);
        licenseSBT = ILicenseSettlement(_licenseSBT);
    }

    function setTrustedSigner(address _trustedSigner) external onlyOwner {
        trustedSigner = _trustedSigner;
    }

    function settleTurn(
        address tbaAddress,
        uint256 fuelConsumed,
        uint256 meatReward,
        bool issueLicense,
        uint256 nonce,
        bytes calldata signature
    ) external {
        require(nonce == nonces[tbaAddress], "Invalid nonce");
        bytes32 structHash = keccak256(
            abi.encode(
                GAME_TURN_RESULT_TYPEHASH,
                tbaAddress,
                fuelConsumed,
                meatReward,
                issueLicense,
                nonce
            )
        );
        require(
            _hashTypedDataV4(structHash).recover(signature) == trustedSigner,
            "Invalid signature: signer is not trusted"
        );

        nonces[tbaAddress]++;
        butcherPool.consumeFuel(tbaAddress, fuelConsumed);
        if (meatReward > 0) {
            meatToken.mintFor(tbaAddress, meatReward);
        }
        if (issueLicense) {
            licenseSBT.issueLicense(tbaAddress);
        }
        emit TurnSettled(tbaAddress, fuelConsumed, meatReward, issueLicense);
    }

    function settleTurnPenalty(
        address tbaAddress,
        uint256 fuelConsumed,
        int256 meatReward,
        bool issueLicense,
        uint256 nonce,
        bytes calldata signature
    ) external {
        require(nonce == nonces[tbaAddress], "Invalid nonce");
        bytes32 structHash = keccak256(
            abi.encode(
                GAME_TURN_PENALTY_TYPEHASH,
                tbaAddress,
                fuelConsumed,
                meatReward,
                issueLicense,
                nonce
            )
        );
        require(
            _hashTypedDataV4(structHash).recover(signature) == trustedSigner,
            "Invalid signature: signer is not trusted"
        );

        nonces[tbaAddress]++;
        butcherPool.consumeFuel(tbaAddress, fuelConsumed);
        if (meatReward > 0) {
            meatToken.mintFor(tbaAddress, uint256(meatReward));
        } else if (meatReward < 0) {
            meatToken.burnFrom(tbaAddress, uint256(-meatReward));
        }
        if (issueLicense) {
            licenseSBT.issueLicense(tbaAddress);
        }
        emit TurnSettled(
            tbaAddress,
            fuelConsumed,
            meatReward > 0 ? uint256(meatReward) : 0,
            issueLicense
        );
    }
}
