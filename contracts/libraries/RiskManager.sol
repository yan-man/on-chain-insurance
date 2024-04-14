// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

library RiskManager {
    /**
     * @dev Calculates insurance premium based on the insured value and risk factor.
     * @param value_ The insured value.
     * @param riskFactor_ The risk factor, ranging from 1 to 100.
     * @return premium The calculated premium in paymentToken, not incorporating decimals. Still need to multiply by 10 ** decimals.
     */
    function calculatePremium(
        uint256 value_,
        uint256 riskFactor_
    ) internal pure returns (uint256) {
        // Base premium is 1% of the value
        uint256 basePercentageInBIPs = 100;
        // Additional premium is up to 2% of the value based on riskFactor_
        uint256 additionalPercentageInBIPs = (200 * riskFactor_) / 100; // Max 400 when riskFactor is 100

        uint256 totalPercentage = basePercentageInBIPs +
            additionalPercentageInBIPs;
        uint256 premium = (value_ * totalPercentage) / 10000; // Dividing by 10000 to account for percentage calculation

        return premium;
    }

    function calculateDuration(
        uint256 amount_,
        uint256 premium_
    ) internal pure returns (uint256) {
        return amount_ / premium_;
    }
}