# Solidity Smart Contracts Collection

This repository contains a collection of Solidity smart contracts and Foundry projects for blockchain development. The repository includes basic contracts, Foundry implementations, and zkSync-specific tools.

## Repository Structure

- **basics/** - Collection of fundamental Solidity smart contracts

  - Simple Storage contracts
  - Fund Me contract
  - ERC20 token implementation
  - Price converter utilities
  - Event emitters and handlers
  - And more utility contracts

- **Foundry-Fundamentals/** - Implementation of Foundry testing framework

  - Basic Foundry configuration
  - Deployment scripts
  - Test implementations
  - Simple Storage contract with Foundry setup

- **foundry-zksync/** - zkSync-specific Foundry implementation
  - Custom zkSync compiler configurations
  - Deployment tools for zkSync
  - Testing utilities for zkSync
  - Documentation for zkSync integration

## Key Features

- Basic Solidity contract implementations
- Foundry testing and deployment setup
- zkSync integration and tooling
- Event handling and logging
- Token implementations
- Price feed integrations

## Getting Started

### Prerequisites

- Solidity ^0.8.0
- Foundry
- Node.js and npm (for certain tools)
- Git

### Installation

1. Clone the repository:

```bash
git clone https://github.com/Dbriane208/solidity.git
cd solidity
```

2. For Foundry projects, install dependencies:

```bash
cd Foundry-Fundamentals
forge install
```

3. For zkSync specific tools:

```bash
cd foundry-zksync
cargo install
```

## Usage

### Basic Contracts

The `basics/` directory contains standalone Solidity contracts that can be compiled and deployed using any Solidity development environment.

### Foundry Projects

Navigate to the Foundry project directories to use the Foundry framework:

```bash
cd Foundry-Fundamentals
forge build
forge test
```

### zkSync Development

For zkSync-specific development, use the tools in the `foundry-zksync` directory.

## Testing

- Use Foundry's testing framework for contract tests
- Run tests using `forge test`
- Individual contract tests are available in their respective test directories

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details

## Contact

- GitHub: [@Dbriane208](https://github.com/Dbriane208)
