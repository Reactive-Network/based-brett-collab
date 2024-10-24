// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../AbstractCallback.sol';
import '../../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';

contract TokenizedLeaderboard is ERC721, AbstractCallback {
    address private constant CALLBACK_SENDER_ADDR = 0x3316559B70Ee698DBD07505800263639F76a19d8;

    struct DataPoint {
        address _address;
        int256 value;
    }

    uint256 public constant NUM_METRICS = 3;
    uint256 public constant NUM_TOP = 3;

    uint256 public constant NUM_AWARDS = NUM_METRICS * NUM_TOP;

    int256[NUM_AWARDS] private awards;
    int256[NUM_AWARDS] private achievements;

    constructor() ERC721("Tokenized Leaderboard", "LDRBD") AbstractCallback(CALLBACK_SENDER_ADDR) payable {
        for (uint256 ix = 0; ix != NUM_AWARDS; ++ix) {
            awards[ix] = -1;
        }
    }

    receive() external payable {}

    function getCurrentAchievementHolder(uint256 metric, uint256 position) external view returns (address) {
        require(metric < NUM_METRICS, 'No such metric');
        require(position < NUM_TOP, 'Beyond leaderboard');
        int256 token_id = achievements[metric * NUM_TOP + position];
        return token_id < 0 ? address(0) : ownerOf(uint256(token_id));
    }

    function updateBoards(
        address /* rvm_id */,
        uint256 metric,
        uint256 /* block_number */,
        DataPoint[] calldata top
    ) external /* authorizedSenderOnly rvmIdOnly(rvm_id) */ { // TODO: fixme.
        require(metric < NUM_METRICS, 'Invalid metric');
        require(top.length <= NUM_TOP, 'Too much data');
        uint256 ix;
        for (; ix != top.length; ++ix) {
            if (top[ix]._address == address(0)) {
                break;
            }
            uint256 award_ix = uint256(metric) * NUM_TOP + ix;
            uint256 token_id = uint256(++awards[award_ix]) * NUM_AWARDS + award_ix;
            _mint(top[ix]._address, token_id);
            achievements[award_ix] = int256(token_id);
        }
        if (ix != NUM_TOP) {
            for (; ix != NUM_TOP; ++ix) {
                uint256 award_ix = uint256(metric) * NUM_TOP + ix;
                achievements[award_ix] = -1;
            }
        }
    }
}
