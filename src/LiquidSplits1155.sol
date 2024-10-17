// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

import { LiquidSplit } from "splits-liquid-template/LiquidSplit.sol";
import { Renderer } from "splits-liquid-template/libs/Renderer.sol";
import { utils } from "splits-liquid-template/libs/Utils.sol";

import { LibString } from "solmate/utils/LibString.sol";
import { Base64 } from "solady/utils/Base64.sol";

contract LiquidSplits1155 is LiquidSplit, ERC1155, AccessControl, ERC1155Pausable, ERC1155Supply {
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

    /// Array lengths of accounts & percentAllocations don't match (`accountsLength` != `allocationsLength`)
    /// @param accountsLength Length of accounts array
    /// @param allocationsLength Length of percentAllocations array
    error InvalidLiquidSplit__AccountsAndAllocationsMismatch(uint256 accountsLength, uint256 allocationsLength);

    /// Invalid initAllocations sum `allocationsSum` must equal `TOTAL_SUPPLY`
    /// @param allocationsSum Sum of percentAllocations array
    error InvalidLiquidSplit__InvalidAllocationsSum(uint32 allocationsSum);

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using LibString for uint256;

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    uint256 internal constant TOKEN_ID = 0;

    uint256 public immutable mintedOnTimestamp;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    constructor(
        address _splitMain,
        address[] memory accounts,
        uint32[] memory initAllocations,
        uint32 _distributorFee,
        address _owner,
        address pauser,
        address minter
    )
        ERC1155("imageURL")
        LiquidSplit(_splitMain, _distributorFee)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        /// checks
        if (accounts.length != initAllocations.length) {
            revert InvalidLiquidSplit__AccountsAndAllocationsMismatch(accounts.length, initAllocations.length);
        }

        // {
        //     uint32 sum = _getSum(initAllocations);
        //     if (sum != totalSupply) {
        //         revert InvalidLiquidSplit__InvalidAllocationsSum(sum);
        //     }
        // }

        /// effects

        mintedOnTimestamp = block.timestamp;

        /// interactions

        // mint NFTs to initial holders
        uint256 numAccs = accounts.length;
        unchecked {
            for (uint256 i; i < numAccs; ++i) {
                _mint(accounts[i], TOKEN_ID, initAllocations[i], "");
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external - view & pure
    /// -----------------------------------------------------------------------

    function scaledPercentBalanceOf(address account) public view override returns (uint32) {
        uint256 totalSupply = totalSupply(TOKEN_ID);
        if (totalSupply == 0) return 0;

        unchecked {
            return uint32((balanceOf(account, TOKEN_ID) * PERCENTAGE_SCALE) / totalSupply);
        }
    }

    function name() external view returns (string memory) {
        return string.concat("Liquid Split ", utils.shortAddressToString(address(this)));
    }

    function uri(uint256) public view override returns (string memory) {
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(
                bytes(
                    string.concat(
                        '{"name": "Liquid Split ',
                        utils.shortAddressToString(address(this)),
                        '", "description": ',
                        '"Each token represents 0.1% of this Liquid Split.", ',
                        '"external_url": ',
                        '"https://app.0xsplits.xyz/accounts/',
                        utils.addressToString(address(this)),
                        "/?chainId=",
                        utils.uint2str(block.chainid),
                        '", ',
                        '"image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(Renderer.render(address(this)))),
                        '"}'
                    )
                )
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// functions - private & internal
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - private & internal - pure
    /// -----------------------------------------------------------------------

    /// Sums array of uint32s
    /// @param numbers Array of uint32s to sum
    /// @return sum Sum of `numbers`
    function _getSum(uint32[] memory numbers) internal pure returns (uint32 sum) {
        uint256 numbersLength = numbers.length;
        for (uint256 i; i < numbersLength;) {
            sum += numbers[i];
            unchecked {
                // overflow should be impossible in for-loop index
                ++i;
            }
        }
    }

    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address account, uint256 amount, bytes memory data) public onlyRole(MINTER_ROLE) {
        _mint(account, TOKEN_ID, amount, data);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    )
        internal
        override(ERC1155, ERC1155Pausable, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }
}
