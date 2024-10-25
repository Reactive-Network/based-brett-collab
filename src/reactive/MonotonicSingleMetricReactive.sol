// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../IReactive.sol';
import '../AbstractPausableReactive.sol';
import '../ISubscriptionService.sol';

contract MonotonicSingleMetricReactive is IReactive, AbstractPausableReactive {
    struct Transfer {
        uint256 tokens;
    }

    enum MetricType {
        TURNOVER,
        MONOTONIC_INFLOW
    }

    uint256 private constant NUM_TOP = 3;

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

    MetricType private immutable metric_type;
    uint256 private immutable metric_ix;
    uint256 private immutable block_tick;

    uint256 private last_block;

    mapping(address => int256)[] private metrics;
    DataPoint[] private top;

    constructor(
        address _token,
        address _leaderboard,
        uint8 _metric_type,
        uint256 _metric_ix,
        uint256 _block_tick
    ) payable {
        require(_metric_type <= uint8(type(MetricType).max), 'Invalid metric type');
        require(_block_tick > 0, 'Invalid block tick');
        owner = msg.sender;
        token = _token;
        leaderboard = _leaderboard;
        metric_type = MetricType(_metric_type);
        metric_ix = _metric_ix;
        block_tick = _block_tick;
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(0x0000000000000000000000000000000000fffFfF) }
        vm = size == 0;
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
        if (vm) {
            metrics.push();
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
        }
        if (block_number >= last_block + block_tick) {
            _processLeaderboard(block_number);
        }
        if (op_code == 3) {
            Transfer memory xfer = abi.decode(data, ( Transfer ));
            _processMetric(
                address(uint160(topic_1)),
                address(uint160(topic_2)),
                int256(xfer.tokens)
            );
        }
    }

    function _processMetric(address from, address to, int256 value) internal {
        if (metric_type == MetricType.TURNOVER) {
            _updateMetric(from, value);
            _updateMetric(to, value);
        } else if (metric_type == MetricType.MONOTONIC_INFLOW) {
            _updateMetric(to, value);
        }
    }

    function _updateMetric(address addr, int256 value) internal {
        if (!_excluded(addr)) {
            int256 new_value = metrics[metrics.length - 1][addr] += value;
            _updateTop(addr, new_value);
        }
    }

    function _updateTop(address cnd, int256 value) internal {
        address candidate = cnd;
        if (top.length == 0 || value > top[top.length - 1].value) {
            uint256 ix;
            for (; ix < top.length && ix < NUM_TOP; ++ix) {
                if (top[ix].value < value) {
                    address tmp_cand = candidate;
                    int256 tmp_val = value;
                    candidate = top[ix].addr;
                    value = top[ix].value;
                    top[ix].addr = tmp_cand;
                    top[ix].value = tmp_val;
                    if (candidate == cnd) {
                        return;
                    }
                }
            }
            if (ix < NUM_TOP) {
                top.push(DataPoint({ addr: candidate, value: value }));
            }
        }
    }

    function _processLeaderboard(uint256 block_number) internal {
        uint256 elapsed_ticks = _computeElapsedTicks(block_number);
        if (elapsed_ticks > 0) {
            last_block += elapsed_ticks * block_tick;
            if (top.length > 0) {
                while (top.length < NUM_TOP) {
                    top.push();
                }
                bytes memory payload = abi.encodeWithSignature(
                    "updateBoards(address,uint256,uint256,(address,int256)[])",
                    address(0),
                    metric_ix,
                    last_block,
                    top
                );
                emit Callback(DESTINATION_CHAIN_ID, leaderboard, CALLBACK_GAS_LIMIT, payload);
            }
            // Clean up metric's state
            while (top.length > 0) {
                top.pop();
            }
            metrics.push();
        }
    }

    function _computeElapsedTicks(uint256 block_number) internal view returns (uint256) {
        return (block_number - last_block) / block_tick;
    }

    // TODO: Implement EOA oracle.
    function _excluded(address /* addr */) internal pure returns (bool) {
        return false;
    }
}
