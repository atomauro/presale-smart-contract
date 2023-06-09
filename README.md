# Presale and Test Token Repository

Welcome to the Presale and Test Token repository! This repository contains two contracts: one for the presale and another for the test token. The contracts are designed to provide a secure and efficient way to conduct a presale and manage a test token with advanced features.

## Contracts

### 1. Presale Contract

The presale contract enables the sale of the test token at a predetermined price before its official launch. Key features of the presale contract include:

- **Flexible Pricing:** The presale contract allows the setting of a minimum deposit amount and a price per dollar to determine the token's value during the presale.

- **Referral System:** Users can make referrals during the presale, and if a referral leads to a successful purchase, both the referrer and the purchaser receive rewards.

- **Pause Functionality:** The presale contract can be paused by the owner if necessary, providing additional control and security.

### 2. Test Token Contract

The test token contract represents the token being sold during the presale. It incorporates several advanced features:

- **Anti-Whale Mechanism:** The contract implements an anti-whale mechanism to prevent large-scale purchases that could disrupt the token's price and distribution.

- **ReentrancyGuard Security:** The presale contract incorporates the ReentrancyGuard security mechanism to protect against reentrancy attacks and ensure the safety of funds during the presale.

- **Role-Based Emission and Burning:** The token contract includes role-based emission and burning functions that enable controlled token supply adjustments.

- **Charity Wallet:** The contract includes a dedicated wallet address for charitable donations, allowing the project to contribute to meaningful causes.

- **Fee Collection Wallet:** A separate wallet address is provided to collect fees generated by token transactions, supporting the sustainability and development of the project.

## Deployment Considerations

Before deploying the contracts, it's important to note the following:

- **Solidity Version Compatibility:** Ensure that the contracts are compatible with the Solidity version you are using. Take note of any required version changes and make the necessary updates to ensure successful deployment.

- **Contract Interactions:** The presale contract and test token contract may have dependencies on each other. Review the contracts and their documentation to understand any necessary interactions or configurations between them.

## Getting Started

To get started with the Presale and Test Token repository, follow these steps:

1. Clone the repository: `git clone https://github.com/atomauro/presale-and-test-token.git`

2. Review the contract files and their documentation for detailed information on their functionality, usage, and deployment considerations.

3. Make any necessary modifications to the contracts to suit your specific project requirements, such as adjusting token parameters, wallet addresses, or price settings.

4. Compile and deploy the contracts to the desired Ethereum network, taking into account any version compatibility considerations mentioned earlier.

5. Test the functionality of the contracts to ensure they meet your project's requirements and security standards.

6. Integrate the deployed contracts into your project and utilize them according to your project's needs.

## Contributions

Contributions to the Presale and Test Token repository are welcome! If you have any suggestions, bug fixes, or additional features to propose, feel free to open an issue or submit a pull request.

Please ensure that your contributions align with the project's goals and adhere to best practices in smart contract development and security.

## License

The Presale and Test Token repository is released under the [MIT License](LICENSE). You are free to use, modify, and distribute the code in accordance with the terms and conditions of the license.

## Disclaimer

This repository and its contracts are provided for informational and educational purposes only. Use them at your own risk. The developers and contributors are not responsible for any losses, damages, or issues that may arise from the use of this code.
