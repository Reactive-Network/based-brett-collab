// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import '../AbstractCallback.sol';

contract TokenizedLeaderboard is ERC721, AbstractCallback {
    event IsContract(address indexed addr, bool indexed yes);

    struct DataPoint {
        address _address;
        int256 value;
    }

    uint256 public immutable num_metrics;
    uint256 public immutable num_top;
    uint256 public immutable num_awards;

    int256[] private awards;
    int256[] private achievements;

    constructor(
        string memory name,
        string memory symbol,
        uint256 metrics,
        uint256 top,
        address callback_sender_addr
    ) ERC721(name, symbol) AbstractCallback(callback_sender_addr) payable {
        num_metrics = metrics;
        num_top = top;
        num_awards = metrics * top;
        awards = new int256[](num_awards);
        achievements = new int256[](num_awards);
        for (uint256 ix = 0; ix != num_awards; ++ix) {
            awards[ix] = -1;
        }
    }

    receive() external payable {}

    function getCurrentAchievementToken(uint256 metric, uint256 position) external view returns (int256) {
        return _getCurrentAchievementToken(metric, position);
    }

    function getCurrentAchievementHolder(uint256 metric, uint256 position) external view returns (address) {
        int256 token_id = _getCurrentAchievementToken(metric, position);
        return token_id < 0 ? address(0) : ownerOf(uint256(token_id));
    }

    function updateBoards(
        address rvm_id,
        uint256 metric,
        uint256 /* block_number */,
        DataPoint[] calldata top
    ) external authorizedSenderOnly rvmIdOnly(rvm_id) {
        require(metric < num_metrics, 'Invalid metric');
        require(top.length <= num_top, 'Too much data');
        uint256 ix;
        for (; ix != top.length; ++ix) {
            if (top[ix]._address == address(0)) {
                break;
            }
            uint256 award_ix = uint256(metric) * num_top + ix;
            uint256 token_id = uint256(++awards[award_ix]) * num_awards + award_ix;
            _mint(top[ix]._address, token_id);
            achievements[award_ix] = int256(token_id);
        }
        for (; ix != num_top; ++ix) {
            uint256 award_ix = uint256(metric) * num_top + ix;
            achievements[award_ix] = -1;
        }
    }

    function checkCodeSize(
        address rvm_id,
        address addr
    ) external authorizedSenderOnly rvmIdOnly(rvm_id) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(addr) }
        emit IsContract(addr, size > 0);
    }

    function _getCurrentAchievementToken(uint256 metric, uint256 position) internal view returns (int256) {
        require(metric < num_metrics, 'No such metric');
        require(position < num_top, 'Beyond leaderboard');
        return achievements[metric * num_top + position];
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        from = super._update(to, tokenId, auth);
        require(from == address(0), 'Tokens are not transferrable');
    }
}
