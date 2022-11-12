<p align="center"> <img src="assets/morphous_logo.svg"></p>
<p align="center"> Get out of the Matrix and Leverage your positions using Morpho.</p>

![Github Actions](https://github.com/kobe-eth/lockers-room/workflows/CI/badge.svg)

# How it works ?

Morphous gives back the power of flash loans to the people. Each user can access a variety of ways to leverage its position and maximise its rewards.

```mermaid
graph TD
	DSProxy --> delegateCall
	delegateCall --> Neo
	Neo --> Morpheus
	delegateCall --> Morpheus
    Morpheus --> Morpho
    Morpheus --> Paraswap
```

# Three main components

* `Neo`: Flashloan router. DSProxy delegatecall to this contract in order to take a floashloan.
* `BalancerFL`:  Flashloan Recipient. Transfers the flashloaned tokens to DSProxy and execute through Morpheus actions.
* `Morpheus`: Main router that enables to uses Morpho and Paraswap through DSProxy.