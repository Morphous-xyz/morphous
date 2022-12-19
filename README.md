<p align="center"> <img src="assets/morphous_logo.svg"></p>
<p align="center"> Get out of the Matrix and Leverage your positions using Morpho.</p>

![Github Actions](https://github.com/Morphous-xyz/morphous/workflows/CI/badge.svg)

## Installation

Install eth_abi:

```bash
# This is needed in order to run the test. Foundry calls a python script for some test to retrieve Paraswap API calls.
pip install eth_abi
```
Install Foundry:
```bash
# This will install Foundryup
curl -L https://foundry.paradigm.xyz | bash
# Then Run
foundryup
```

Install Dependencies:
```bash
forge install
```

Build:
```bash
forge build
```

Test:
```bash
make test
```

# How it works ?

Morphous gives back the power of flash loans to the people. Each user can access a variety of ways to leverage its position and maximise its rewards.

```mermaid
graph TD
	DSProxy --> delegateCall
	delegateCall --> Neo
<<<<<<< HEAD
	Neo --> Morpheus
	delegateCall --> Morpheus
    Morpheus --> Morpho
    Morpheus --> Exchanges
=======
	Neo --> Morphous
	delegateCall --> Morphous
    Morphous --> Morpho
    Morphous --> Paraswap
>>>>>>> a8620b9 (refactor: fix pr comments)
```

### Three main components

* `Neo`: Flashloan router. DSProxy delegatecall to this contract in order to take a floashloan.
<<<<<<< HEAD
* `FL`:  Flashloan Recipient. Transfers the flashloaned tokens to DSProxy and execute through Morpheus actions.
<<<<<<< HEAD
* `Morpheus`: Main router that enables to uses Morpho and Aggregators like Paraswap/1nch through DSProxy.
=======
* `Morpheus`: Main router that enables to uses Morpho and Paraswap through DSProxy.
>>>>>>> 60f3dde (feat: add receiver + 1nch router + aave fl)
=======
* `FL`:  Flashloan Recipient. Transfers the flashloaned tokens to DSProxy and execute through Morphous actions.
* `Morphous`: Main router that enables to uses Morpho and Paraswap through DSProxy.
>>>>>>> a8620b9 (refactor: fix pr comments)
