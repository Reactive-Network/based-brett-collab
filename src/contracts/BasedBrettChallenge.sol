// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

contract BasedBrettChallenge {
    error AlreadyEnlisted(address tradingWarrior);
    error ChallengeRegistrationClosed();
    error ChallengeNotStarted();

    event ChallengeAccepted(address tradingWarrior);

    address private owner;

    mapping(address => bool) private warriors;

    uint256 private challengeStartBlock;
    uint256 private challengeEndBlock;

    constructor(uint256 _challengeStartBlock, uint256 _challengeEndBlock) {
        owner = msg.sender;
        challengeStartBlock = _challengeStartBlock;
        challengeEndBlock = _challengeEndBlock;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Not authorized');
        _;
    }

    function participate() external {
        _participate(msg.sender);
    }

    function participate(address addr) external onlyOwner {
        _participate(addr);
    }

    function _participate(address participant) internal {
        if (block.number < challengeStartBlock) {
            revert ChallengeNotStarted();
        }

        if (block.number > challengeEndBlock) {
            revert ChallengeRegistrationClosed();
        }

        if (warriors[participant]) {
            revert AlreadyEnlisted(participant);
        }

        warriors[participant] = true;

        emit ChallengeAccepted(participant);
    }

    function isWarrior() external view returns (bool) {
        return warriors[msg.sender];
    }

    function isWarrior(address addr) external view returns (bool) {
        return warriors[addr];
    }
}
