// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../IReactive.sol';
import '../AbstractPausableReactive.sol';
import '../ISubscriptionService.sol';

contract MonotonicMultimetricsReactive is IReactive, AbstractPausableReactive {
    struct Transfer {
        uint256 tokens;
    }

    enum Metric {
        TURNOVER_10_BLOCKS,
        TURNOVER_100_BLOCKS,
        MONOTONIC_INFLOW_100_BLOCKS
    }

    uint256 private constant NUM_METRICS = 3;
    uint256 private constant BLOCK_TICK = 10;
    uint256 private constant NUM_TOP = 3;

    struct MetricData {
        bool init;
        int248 value;
    }

    struct DataPoint {
        address addr;
        int256 value;
    }

    uint256 private constant ORIGIN_CHAIN_ID = 8453; // Base (change to Sepolia for testing)
    uint256 private constant DESTINATION_CHAIN_ID = 11155111; // Sepolia

    uint256 private constant ERC20_TRANSFER_TOPIC_0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    uint64 private constant CALLBACK_GAS_LIMIT = 1000000;

    address private token;
    address private leaderboard;

    uint256 private last_block;
    uint256[NUM_METRICS] private last_blocks_by_metric;

    address[][NUM_METRICS] private participants;
    mapping(address => MetricData)[NUM_METRICS] private metrics;
    DataPoint[][NUM_METRICS] private top;

    constructor(
        address _token,
        address _leaderboard
    ) payable {
        require(NUM_METRICS == uint256(type(Metric).max) + 1, 'Invalid metric spec');
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(0x0000000000000000000000000000000000fffFfF) }
        vm = size == 0;
        owner = msg.sender;
        token = _token;
        leaderboard = _leaderboard;
        if (!vm) {
            service.subscribe(
                ORIGIN_CHAIN_ID,
                token,
                ERC20_TRANSFER_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    receive() external payable {}

    function getPausableSubscriptions() override internal view returns (Subscription[] memory) {
        Subscription[] memory result = new Subscription[](1);
        result[0] = Subscription(
            ORIGIN_CHAIN_ID,
            token,
            ERC20_TRANSFER_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        return result;
    }

    function react(
        uint256 /* chain_id */,
        address /* _contract */,
        uint256 /* topic_0 */,
        uint256 topic_1,
        uint256 topic_2,
        uint256 /* topic_3 */,
        bytes calldata data,
        uint256 block_number,
        uint256 op_code
    ) external /* vmOnly */ { // TODO: fixme.
        if (last_block == 0) {
            last_block = block_number;
            for (uint256 ix; ix != NUM_METRICS; ++ix) {
                last_blocks_by_metric[ix] = last_block;
            }
        }
        if (block_number >= last_block + BLOCK_TICK) {
            for (uint256 ix; ix != NUM_METRICS; ++ix) {
                _processLeaderboard(Metric(ix), block_number);
            }
            last_block = block_number;
        }
        if (op_code == 3) {
            Transfer memory xfer = abi.decode(data, ( Transfer ));
            for (uint256 ix; ix != NUM_METRICS; ++ix) {
                _processMetric(
                    Metric(ix),
                    address(uint160(topic_1)),
                    address(uint160(topic_2)),
                    int256(xfer.tokens)
                );
            }
        }
    }

    function _processMetric(Metric m, address from, address to, int256 value) internal {
        if (m == Metric.TURNOVER_10_BLOCKS || m == Metric.TURNOVER_100_BLOCKS) {
            _updateMetric(m, from, value);
            _updateMetric(m, to, value);
        } else if (m == Metric.MONOTONIC_INFLOW_100_BLOCKS) {
            _updateMetric(m, to, value);
        }
    }

    function _updateMetric(Metric m, address addr, int256 value) internal {
        if (!_excluded(addr)) {
            if (!metrics[uint256(m)][addr].init) {
                metrics[uint256(m)][addr].init = true;
                participants[uint256(m)].push(addr);
            }
            int248 new_value = metrics[uint256(m)][addr].value += int248(value);
            _updateTop(m, addr, int256(new_value));
        }
    }

    function _updateTop(Metric m, address candidate, int256 value) internal {
        if (top[uint256(m)].length == 0 || value > top[uint256(m)][top[uint256(m)].length - 1].value) {
            uint256 ix;
            for (; ix < top[uint256(m)].length && ix < NUM_TOP; ++ix) {
                if (top[uint256(m)][ix].value < value) {
                    address tmp_cand = candidate;
                    int256 tmp_val = value;
                    candidate = top[uint256(m)][ix].addr;
                    value = top[uint256(m)][ix].value;
                    top[uint256(m)][ix].addr = tmp_cand;
                    top[uint256(m)][ix].value = tmp_val;
                }
            }
            if (ix < NUM_TOP) {
                top[uint256(m)].push(DataPoint({ addr: candidate, value: value }));
            }
        }
    }

    function _processLeaderboard(Metric m, uint256 block_number) internal {
        uint256 elapsed_ticks = _computeElapsedTicks(m, block_number);
        if (elapsed_ticks >= _ticks(m)) {
            if (top[uint256(m)].length > 0) {
                while (top[uint256(m)].length < NUM_TOP) {
                    top[uint256(m)].push();
                }
                bytes memory payload = abi.encodeWithSignature(
                    "updateBoards(address,uint256,uint256,(address,int256)[])",
                    address(0),
                    uint256(m),
                    last_blocks_by_metric[uint256(m)],
                    top[uint256(m)]
                );
                emit Callback(DESTINATION_CHAIN_ID, leaderboard, CALLBACK_GAS_LIMIT, payload);
            }
            // Clean up metric's state
            while (top[uint256(m)].length > 0) {
                top[uint256(m)].pop();
            }
            while (participants[uint256(m)].length > 0) {
                address participant = participants[uint256(m)][participants[uint256(m)].length - 1];
                participants[uint256(m)].pop();
                delete metrics[uint256(m)][participant];
            }
            // Update metric's block number
            last_blocks_by_metric[uint256(m)] = block_number;
        }
    }

    function _computeElapsedTicks(Metric m, uint256 block_number) internal view returns (uint256) {
        return (block_number - last_blocks_by_metric[uint256(m)]) / BLOCK_TICK;
    }

    function _ticks(Metric m) internal pure returns (uint256) {
        if (m == Metric.TURNOVER_10_BLOCKS) {
            return 1;
        } else {
            return 10;
        }
    }

    // TODO: Implement EOA oracle.
    function _excluded(address /* addr */) internal pure returns (bool) {
        return false;
    }
}
