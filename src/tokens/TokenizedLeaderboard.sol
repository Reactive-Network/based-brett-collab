// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol';

contract TokenizedLeaderboard is AbstractCallback {
    event Position(uint256 indexed position, address indexed addr, int256 indexed value);
    event BoardUpdated();

    struct DataPoint {
        address _address;
        int256 value;
    }

    uint256 public immutable num_top;

    DataPoint[] private leaderboard;

    constructor(
        address _callback_sender_addr,
        uint256 _num_top
    ) AbstractCallback(_callback_sender_addr) payable {
        num_top = _num_top;
        for (uint256 ix = 0; ix != num_top; ++ix) {
            leaderboard.push();
        }
    }

    function getLeaderboard() external view returns (DataPoint[] memory lb) {
        lb = leaderboard;
    }

    function getLeaderboardPosition(uint256 position) external view returns (DataPoint memory data) {
        require(position < num_top, 'Invalid position');
        data = leaderboard[position];
    }

    // @dev Deprecated.
    function getCurrentAchievementHolder(uint256 /* metric */, uint256 position) external view returns (address) {
        return leaderboard[position]._address;
    }

    function updateBoards(
        address rvm_id,
        DataPoint[] calldata top
    ) external authorizedSenderOnly rvmIdOnly(rvm_id) {
        require(top.length <= num_top, 'Too much data');
        uint256 ix;
        for (; ix != top.length; ++ix) {
            if (top[ix]._address == address(0)) {
                break;
            }
            leaderboard[ix] = top[ix];
            emit Position(ix, top[ix]._address, top[ix].value);
        }
        for (; ix != num_top; ++ix) {
            leaderboard[ix] = DataPoint(address(0), 0);
        }
        emit BoardUpdated();
    }
}
