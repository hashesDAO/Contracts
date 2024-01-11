# Contracts
A [Foundry](https://book.getfoundry.sh/) repo for easy testing and integrations with Hashes DAO smart contracts

## Notes
- Built with Openzeppelin v4.9.0

## Roles

It is worth reviewing the roles specific to the Hashes Collection NFT_v1 ecosystem. The privelages are meant to balance security, usability with third-party platforms, and flexibility of operations management.

-   Hashes DAO
    -   The entity at the core of the infrastructure. Has general authority over most parts of the system except for some sensitive creator actions on collections (setting baseTokenURI, royalties, transfering creatorship). The full list of function permissions are documented below. This entity performs actions that are voted on by the DAO after a three day timelock has passed.
-   Factory Maintainer
    -   An address designed to perform factory maintenance and interface with third-party sites; can be an EOA or multi-sig if this is supported on the relevant sites. The key attribute here is being the 'Owner' for all Collections contract (openzeppelin spec). This makes certain tasks feasible such as configuring royalties on OpenSea (off-chain), which wouldn't be possible for the DAO to perform directly. The initial factory maintainer will be set to the deployer of these contracts which will be DEX Labs.
-   Creator
    -   This is initially set to the address which clones a Hashes Collections through the Factory method. Likely the artist or creator of the specific NFT project. After creating the collection, has some unique permissions such as baseTokenURI management, setting on-chain royalties, and ability to withdraw creator-owed funds.
-   Signature Block Address
    -   This is an optional role that can be used with the NFT contract. The concept of a signature block is taken from traditional legal documents. It refers to the text surrounding a signature which gives that signature context and provides additional information. In this context, it means that the creator has provided a place where a particular address can 'sign off' on the contract and establish provenance. This can be useful for famous NFT artist to prove that this contract represents their work, especially since they may not be cloning the Contract or entering the metadata.

## CollectionFactory

|                             | Hashes DAO | Factory Maintainer | Creator | Any User |
| --------------------------- | ---------- | ------------------ | ------- | -------- |
| setFactoryMaintainerAddress | ✓          | ✓                  |         |          |
| addImplementationAddress    | ✓          | ✓                  | ✓       | ✓        |
| removeImplementationAddress | ✓          | ✓                  |         |          |
| createEcosystemSettings     | ✓          | ✓                  |         |          |
| updateEcosystemSettings     | ✓          |                    |         |          |
| createCollection            | ✓          | ✓                  | ✓       | ✓        |
| removeCollection            | ✓          | ✓                  |         |          |
|                             |            |                    |         |          |
| openzeppelin 'Owner'        | ✓          |                    |         |          |
| transferOwnership           | ✓          |                    |         |          |

Notes:

-   The factory maintainer is able to transfer its role to another address. While this could allow for the unlikely case of a bad actor paying off the current factory maintainer to gain access, it was decided to do this for better ops management.
-   Anyone can add a new implementation address to the Factory (cloneable or standalone). This was done to encourage more contributors to the Factory. To combat spammers or bad actors, the factory maintainer has the ability to remove implementation contracts. The same create/delete permissioning pattern holds for individual collections (ie clones) created through the Factory.
-   New ecosystem settings can be created by either the factory maintainer or HashesDAO. This was done to more easily allow for the bootstrapping of new ecosystems. However, only the DAO can pass proposals to update ecosystem settings. The idea here is that the impact for these changes will be greater on already established ecosystems (setting mint fee percent, royalty percent etc.)

## CollectionNFTCloneableV1

|                          | Hashes DAO | Factory Maintainer | Creator | Any User | Signature Block Address |
| ------------------------ | ---------- | ------------------ | ------- | -------- | ----------------------- |
| initialize               |            |                    | ✓       |          |                         |
| mint                     | ✓          | ✓                  | ✓       | ✓        |                         |
| setBaseTokenURI          |            |                    | ✓       |          |                         |
| setRoyaltyBps            |            |                    | ✓       |          |                         |
| transferCreator          |            |                    | ✓       |          |                         |
| withdraw                 | ✓          | ✓                  | ✓       | ✓        |                         |
| burn (owner/approved)    | ✓          | ✓                  | ✓       | ✓        |                         |
| setSignatureBlockAddress |            |                    | ✓       |          |                         |
| completeSignatureBlock   |            |                    |         |          | ✓                       |
|                          |            |                    |         |          |                         |
| openzeppelin 'Owner'     |            | ✓                  |         |          |                         |
| transferOwnership        | ✓          | ✓                  |         |          |                         |

Notes:

-   Initialize is automatically called through the creation of a new clone via the createCollection method in the Factory. So in essence, it is the creator that is triggering this call and passing through the NFT settings.
-   Only the creator can update the baseTokenURI and royaltyBps for their collection, as well as transfer this role to others. Hopefully this helps provide peace of mind for creators to build on the platform and have the most important settings locked into place.
-   The openzeppelin 'Owner' _must_ be the factory maintainer because of how royalties are configured on third-party platforms such as OpenSea. In order to enforce a HashesDAO royalty fee percent, all royalties are sent to the cloned collection contract, where additional logic separates royalties owed to the creator as well as HashesDAO. The Owner has permission to configure the royalty address to be the cloned contract address on OpenSea. If this was the 'Creator' role, they could just switch the royalty address to their own address and bypass the Hashes Collecton fee. OpenSea has plans to support ERC2981 eventually for on-chain royalties, but we need to use this workaround in the interim.
-   While the Owner of the contract is the factory maintainer address, HashesDAO also has the ability to transfer ownership of collections. This was done as a backup in case the factory maintainer becomes a bad actor or the address is lost. There is some operational security added with DEX Labs controlling this address, since the entity is implicitly staking its reputation.
