// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../lib/reactive-lib/src/interfaces/IReactive.sol';
import '../../lib/reactive-lib/src/abstract-base/AbstractPausableReactive.sol';
import '../../lib/reactive-lib/src/interfaces/ISubscriptionService.sol';

contract MonotonicSingleMetricReactive is IReactive, AbstractPausableReactive {
    event Updating(address indexed addr, int256 indexed value, int256 indexed new_value);

    event AddCpt(address indexed addr);
    event DelCpt(address indexed addr);

    event BanPcpt(address indexed addr);

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event UnknownTopic0(uint256 indexed topic_0);

    struct BrettParam {
        uint256 _token_chain_id;
        address _token;
        uint256 _registration_chain_id;
        address _registration;
        uint256 _leaderboard_chain_id;
        address _leaderboard;
        uint256 _num_top;
        uint8 _metric_type;
        uint256 _block_tick;
        uint256 _start_block;
        uint256 _end_block;
        address[] _counterparties;
    }

    struct TransferData {
        uint256 tokens;
    }

    enum MetricType {
        TURNOVER,
        MONOTONIC_INFLOW
    }

    struct DataPoint {
        address addr;
        int256 value;
    }

    uint256 private constant REACTIVE_CHAIN_ID = 5318008;

    uint256 private constant ERC20_TRANSFER_TOPIC_0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    uint256 private constant CHALLENGE_ACCEPTED_TOPIC_0 = 0x235d3c92abef402ad8969f43056a1212760efee2e4357b1e165a93aed19329e3;
    uint256 private constant ADDCPT_TOPIC_0 = 0x492d1cc279f99d6278b8757cede01a07e91de27e33bfec5f36a040d91d2d30de;
    uint256 private constant DELCPT_TOPIC_0 = 0x81c65dde108f2aa7f1d8b3eb8d3687d7f32ccf9f13fdb1120bb45f25a87567c5;
    uint256 private constant BANPCPT_TOPIC_0 = 0x903e4eaf85c762a280796e37733457e2bad2a9cccc8b57c1ecd0d8dd644cf5da;

    uint64 private constant CALLBACK_GAS_LIMIT = 10000000;

    uint256 private immutable token_chain_id;
    uint256 private immutable registration_chain_id;
    uint256 private immutable leaderboard_chain_id;

    uint256 private immutable num_top;

    address private token;
    address private registration;
    address private leaderboard;

    MetricType private immutable metric_type;
    uint256 private immutable block_tick;

    uint256 private last_block;

    mapping(address => int256)[] private metrics;
    DataPoint[] private top;

    mapping(address => bool) private addresses;
    mapping(address => bool) private counterparties;

    uint256 private start_block;
    uint256 private end_block;

    bool private all_done;

    constructor(BrettParam memory param) payable {
        require(param._metric_type <= uint8(type(MetricType).max), 'Invalid metric type');
        require(param._block_tick > 0, 'Invalid block tick');
        owner = msg.sender;
        token_chain_id = param._token_chain_id;
        token = param._token;
        registration_chain_id = param._registration_chain_id;
        registration = param._registration;
        leaderboard_chain_id = param._leaderboard_chain_id;
        leaderboard = param._leaderboard;
        num_top = param._num_top;
        metric_type = MetricType(param._metric_type);
        block_tick = param._block_tick;
        start_block = param._start_block;
        end_block = param._end_block;
        last_block = start_block;
        for (uint256 ix = 0; ix != param._counterparties.length; ++ix) {
            counterparties[param._counterparties[ix]] = true;
        }
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(0x0000000000000000000000000000000000fffFfF) }
        vm = size == 0;
        if (!vm) {
            // TODO: This tracks all Transfer events, inflating reactive costs, but is safer atm than
            // hundreds/thousands of sumiltaneous subscriptions.
            service.subscribe(
                token_chain_id,
                token,
                ERC20_TRANSFER_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                registration_chain_id,
                registration,
                CHALLENGE_ACCEPTED_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                REACTIVE_CHAIN_ID,
                address(this),
                ERC20_TRANSFER_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                REACTIVE_CHAIN_ID,
                address(this),
                ADDCPT_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                REACTIVE_CHAIN_ID,
                address(this),
                DELCPT_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            service.subscribe(
                REACTIVE_CHAIN_ID,
                address(this),
                BANPCPT_TOPIC_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
        if (vm) {
            metrics.push();
        }
    }

    function getPausableSubscriptions() override internal view returns (Subscription[] memory) {
        Subscription[] memory result = new Subscription[](1);
        result[0] = Subscription(
            token_chain_id,
            token,
            ERC20_TRANSFER_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        return result;
    }

    function addCpt(address addr) external onlyOwner {
        emit AddCpt(addr);
    }

    function delCpt(address addr) external onlyOwner {
        emit DelCpt(addr);
    }

    function banPcpt(address addr) external onlyOwner {
        emit BanPcpt(addr);
    }

    function emulateTransfer(address from, address to, uint256 amount) external onlyOwner {
        emit Transfer(from, to, amount);
    }

    function react(
        uint256 /* chain_id */,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 /* topic_3 */,
        bytes calldata data,
        uint256 block_number,
        uint256 op_code
    ) external vmOnly {
        if (all_done) {
            return;
        }
        if (topic_0 == ERC20_TRANSFER_TOPIC_0) {
            if (_contract == address(this)) {
                block_number = last_block;
            }
            if (block_number >= start_block) {
                if (block_number > end_block) {
                    _processLeaderboard(block_number, true);
                    // TODO: pause automatically?
                    all_done = true;
                } else {
                    if (last_block == 0) {
                        last_block = block_number;
                    }
                    if (block_number >= last_block + block_tick) {
                        _processLeaderboard(block_number, false);
                    }
                    if (op_code == 3) {
                        TransferData memory xfer = abi.decode(data, ( TransferData ));
                        _processMetric(
                            address(uint160(topic_1)),
                            address(uint160(topic_2)),
                            int256(xfer.tokens)
                        );
                    }
                }
            }
        } else if (topic_0 == CHALLENGE_ACCEPTED_TOPIC_0) {
            address challenger = abi.decode(data, ( address ));
            addresses[challenger] = true;
        } else if (topic_0 == ADDCPT_TOPIC_0) {
            counterparties[address(uint160(topic_1))] = true;
        } else if (topic_0 == DELCPT_TOPIC_0) {
            counterparties[address(uint160(topic_1))] = false;
        } else if (topic_0 == BANPCPT_TOPIC_0) {
            addresses[address(uint160(topic_1))] = false;
        } else {
            emit UnknownTopic0(topic_0);
        }
    }

    function _processMetric(address from, address to, int256 value) internal {
        if (
            (addresses[from] && counterparties[to]) ||
            (counterparties[from] && addresses[to])
        ) {
            if (metric_type == MetricType.TURNOVER) {
                _updateMetric(from, value);
                _updateMetric(to, value);
            } else if (metric_type == MetricType.MONOTONIC_INFLOW) {
                _updateMetric(to, value);
            }
        }
    }

    function _updateMetric(address addr, int256 value) internal {
        if (!_excluded(addr)) {
            int256 new_value = metrics[metrics.length - 1][addr] += value;
            emit Updating(addr, value, new_value);
            _updateTop(addr, new_value);
        }
    }

    function _updateTop(address cnd, int256 val) internal {
        if (top.length == 0 || val > top[top.length - 1].value) {
            address candidate = cnd;
            int256 value = val;
            uint256 ix;
            for (; ix < top.length; ++ix) {
                if (top[ix].value <= value) {
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
            if (ix < num_top) {
                top.push(DataPoint(candidate, value));
            }
        }
    }

    function _processLeaderboard(uint256 block_number, bool force) internal {
        uint256 elapsed_ticks = _computeElapsedTicks(block_number);
        if (elapsed_ticks > 0 || force) {
            last_block += elapsed_ticks * block_tick;
            if (top.length > 0) {
                while (top.length < num_top) {
                    top.push();
                }
                bytes memory payload = abi.encodeWithSignature(
                    "updateBoards(address,(address,int256)[])",
                    address(0),
                    top
                );
                emit Callback(leaderboard_chain_id, leaderboard, CALLBACK_GAS_LIMIT, payload);
            }
        }
    }

    function _computeElapsedTicks(uint256 block_number) internal view returns (uint256) {
        return (block_number - last_block) / block_tick;
    }

    function _excluded(address addr) internal view returns (bool) {
        return !addresses[addr] || counterparties[addr];
    }
}
