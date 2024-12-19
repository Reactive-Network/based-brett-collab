// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

contract BasedBrettChallenge {
    error AlreadyEnlisted(address traidingWarrior);
    error ChallengeRegistrationClosed();
    error ChallengeNotStarted();

    event ChallengeAccepted(address traidingWarrior);

    mapping(address => bool) private warriors;

    uint256 private challengeStartBlock;
    uint256 private challengeEndBlock;

    constructor(uint256 _challengeStartBlock,uint256 _challengeEndBlock) {
        challengeStartBlock = _challengeStartBlock;
        challengeEndBlock = _challengeEndBlock;
    }

    function participate() external {
        if (block.number < challengeStartBlock) {
            revert ChallengeNotStarted();
        }

        if (block.number > challengeEndBlock) {
            revert ChallengeRegistrationClosed();
        }

        if (warriors[msg.sender]) {
            revert AlreadyEnlisted(msg.sender);
        }

        warriors[msg.sender] = true;

        emit ChallengeAccepted(msg.sender);
    }

    function isWarrior() external view returns (bool) {
        return warriors[msg.sender];
    }
}
