// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {BasedBrettChallenge} from "../src/contracts/BasedBrettChallenge.sol";

contract BasedBrettChallengeTest is Test {
    BasedBrettChallenge private bbc;

    address private someAddress = 0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5;

    function setUp() public {
        bbc = new BasedBrettChallenge(1_000);
    }

    function test_Participate() public {
        vm.prank(someAddress);

        bbc.participate();
    }

    function testFail_NoDoubleParticipate() public {
        vm.startPrank(someAddress);

        bbc.participate();
        bbc.participate();
    }

    function testFail_NoParticipationAfterEnd() public {
        vm.startPrank(someAddress);
        vm.roll(1_001);

        bbc.participate();
    }
}
