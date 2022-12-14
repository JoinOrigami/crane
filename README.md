# The Origami family of smart contracts

## contract synopsis

| Contract                        | Purpose                                                        |
| :------------------------------ | :------------------------------------------------------------- |
| `OrigamiMembershipToken`        | A membership NFT issued to DAO members                         |
| `OrigamiMembershipTokenFactory` | A factory contract for cheaply deploying new membership tokens |
| `OrigamiGovernanceToken`        | An ERC20 token appropriate for use in governance               |
| `OrigamiGovernanceTokenFactory` | A factory contract for cheaply deploying new governance tokens |

## Development

We power our solidity development with `foundry`. The [book](https://book.getfoundry.sh) is a great jumping off point. [Awesome Foundry](https://github.com/crisgarner/awesome-foundry) does a great job of showcasing common patterns implemented using `foundry`. Run `forge` from the project directory after installing the prerequisites to get an idea of the capabilities.

### Pre Requisites

1. Install `cargo`: `curl https://sh.rustup.rs -sSf | sh`
2. Install `foundry` ([instructions and details](https://book.getfoundry.sh/getting-started/installation)):
   - `curl -L https://foundry.paradigm.xyz | bash`
   - `foundryup`
3. Install `argc`: `cargo install argc`
4. Install `solhint`: `npm install -g solhint`


NB: if you intend to run the scripts in `./script` directly or via `./bin/jib`, ensure you've created a `.envrc` file (`cp {example,}.envrc`), populated its values and exported them to your shell (`direnv` is a convenient way of managing this).

### Documentation

All documentation is in `NatSpec` format and available alongside the code. You can also generate the documentation for the project as HTML using the [`go-natspec`](https://github.com/sambacha/go-natspec) project. Here's a brief overview of usage on macOS:

```sh
$ brew install pygments
$ curl -O https://github.com/sambacha/go-natspec/releases/download/v0.0.1/dappspec
$ chmod +x dappspec
$ ./dappspec src/OrigamiGovernanceToken.sol
$ open docs/OrigamiGovernanceToken.sol
```

### Testing

Tests are implemented in Solidity and use `foundry` to power them. The documentation for writing tests using `foundry` is [thorough](https://book.getfoundry.sh/forge/tests) and there is an active community in their telegram.

The simplest test invocation is:

```sh
$ forge test
```

Running tests with 3 levels of verbosity provides extensive feedback on failures and gas usage estimates. Combining this with watch mode makes for a tight feedback loop:

```sh
$ forge test -vvv -w
```

### Coverage

Generate a coverage report:

```sh
$ forge coverage
```

## Linting

Run the linter manually:

```sh
$ solhint src/*.sol
```

## Deploying

This is handled via the `jib` command (a jib is the arm that supports the load on a crane). The command self-documents by passing `--help` to its commands, as in:

```sh
$ ./bin/jib --help
```

or

```sh
$ ./bin/jib cmt --help
```

Some commands require the address of a previously deployed contract (e.g. the clone commands). Team members can find these on the notion page for deployed contract addresses.
