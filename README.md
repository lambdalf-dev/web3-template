# Web3 Template

A Foundry-based template for Solidity smart contract development.

## What's Inside

- [Forge](https://github.com/foundry-rs/foundry/blob/master/forge): compile, test, fuzz, format, and deploy smart
  contracts
- [Forge Std](https://github.com/foundry-rs/forge-std): collection of helpful contracts and utilities for testing

## Getting Started

Click the [`Use this template`](https://github.com/lambdalf-dev/web3-template/generate) button at the top of the page to
create a new repository with this repo as the initial state.

Or, if you prefer to install the template manually:

```sh
$ mkdir my-project
$ cd my-project
$ forge init --template lambdalf-dev/web3-template
$ yarn install
```

If this is your first time with Foundry, check out the
[installation](https://github.com/foundry-rs/foundry#installation) instructions.

## Features

This template builds upon the frameworks and libraries mentioned above, so please consult their respective documentation
for details about their specific features.

For example, if you're interested in exploring Foundry in more detail, you should look at the
[Foundry Book](https://book.getfoundry.sh/). In particular, you may be interested in reading the
[Writing Tests](https://book.getfoundry.sh/forge/writing-tests.html) tutorial.

### Default Settings

This template comes with a set of sensible default configurations for you to use. These defaults can be found in the
following files:

```text
├── .gitignore
├── foundry.toml
└── remappings.txt
```

### Preconfigured Tasks

This template comes with a set of preconfigured tasks. You can find them in `package.json`.

## Installation

Foundry typically uses git submodules to manage dependencies, but this template uses Node.js packages because
[submodules don't scale](https://twitter.com/PaulRBerg/status/1736695487057531328).

This is how to install dependencies:

1. Install the dependency using your preferred package manager, e.g. `yarn install dependency-name`
   - Use this syntax to install from GitHub: `yarn install github:username/repo-name`
2. Add a remapping for the dependency in [remappings.txt](./remappings.txt), e.g.
   `dependency-name=node_modules/dependency-name`

## Writing Tests

To write a new test contract, you start by importing `Test` from `forge-std`, and then you inherit it in your test
contract. Forge Std comes with a pre-instantiated [cheatcodes](https://book.getfoundry.sh/cheatcodes/) environment
accessible via the `vm` property. If you would like to view the logs in the terminal output, you can add the `-vvv` flag
and use [console.log](https://book.getfoundry.sh/faq?highlight=console.log#how-do-i-use-consolelog).

This template comes with an example test contract [Foo.t.sol](./test/Foo.t.sol)

## Usage

### Build/Compile

Build the contracts:

- ```yarn build```
- ```forge build```
- ```forge compile```

### Clean

Delete the build artifacts and cache directories:

- ```yarn clean```
- ```forge clean```

### Coverage

Get a test coverage report:

- ```yarn coverage```
- ```forge coverage```

### Gas Report

Get a gas report:

- ```yarn gas```
- ```forge test --gas-report```

### Lint

Format the contracts:

- ```yarn lint```
- ```forge fmt check```

### Test

Run all tests:

- ```yarn test```
- ```forge test```

Run all tests with verbose output:

- ```yarn test:verbose```
- ```forge test -vvvv```

Run all unit tests (test name starts with "test_unit_"):

- ```yarn test:unit```
- ```forge test --mt test_unit_```

Run all fuzz tests (test name starts with "test_fuzz_"):

- ```yarn test:fuzz```
- ```forge test --mt test_fuzz_```

Run all edge tests (test name starts with "test_edge_"):

- ```yarn test:edge```
- ```forge test --mt test_edge_```
