// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

contract CEPGovernor is Governor, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction {
    constructor(IVotes _token) Governor("CEP Governor") GovernorVotes(_token) GovernorVotesQuorumFraction(4) { }

    function votingDelay() public pure override returns (uint256) {
        return 1 days;
    }

    function votingPeriod() public pure override returns (uint256) {
        return 1 weeks;
    }

    // The following functions are overrides required by Solidity.

    function quorum(uint256 blockNumber)
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }
}
