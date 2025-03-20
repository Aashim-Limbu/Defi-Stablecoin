// SPDX-License-Identifier: MTI
pragma solidity >=0.8.0 <0.9.0;

import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title Oracle Lib
 * @author Aashim Limbu
 * @notice This library is used to check for the chainlink stale data.
 * If a price is stale, the function will revert, and render the DSCEngine unusuable - this is by design
 * We want the DSCEngine to freeze if the prices become stale.
 *
 * So if the Chainlink network explodes and you have a lot of money locked in the protocol . you're screwed
 */
library OracleLib {
    error OracleLb__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function stalePriceCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed.latestRoundData();
        uint256 timeSince = block.timestamp - updatedAt;
        if (timeSince > TIMEOUT) revert OracleLb__StalePrice();
    }
}
