import FungibleToken from "./contracts/FungibleToken.cdc"
import NonFungibleToken from "./contracts/NonFungibleToken.cdc"
import TopShot from "./contracts/TopShot.cdc"
import DapperUtilityCoin from "./contracts/DapperUtilityCoin.cdc"
import TopShotLocking from "./contracts/TopShotLocking.cdc"

pub contract TopShotSetMarket {

    pub event SetListed(setID: UInt32, tokenIDs: [UInt64], price: UFix64, seller: Address?)
    pub event SetPriceChanged(id: UInt32, newPrice: UFix64, seller: Address?)
    pub event SetPurchased(id: UInt32, price: UFix64, seller: Address?)
    pub event SetWithdrawn(id: UInt32, owner: Address?)

    pub let SetMarketStoragePath: StoragePath
    pub let SetMarketPublicPath: PublicPath

    pub struct SetSaleData {
        pub let price: UFix64
        pub let tokenIDs: [UInt64]

        init(price: UFix64, tokenIDs: [UInt64]) {
            self.price = price
            self.tokenIDs = tokenIDs
        }
    }

    pub resource interface SalePublic {
        pub var cutPercentage: UFix64
        pub fun purchase(setID: UInt32, buyTokens: @DapperUtilityCoin.Vault): @[TopShot.NFT]
        pub fun getSaleData(setID: UInt32): SetSaleData?
        pub fun getIDs(): [UInt32]
        pub fun getSetData(id: UInt32): TopShot.QuerySetData?
    }

    pub resource SaleCollection: SalePublic {
        access(self) var ownerCollection: Capability<&TopShot.Collection>
        access(self) var listings: {UInt32: SetSaleData}
        access(self) var ownerCapability: Capability<&{FungibleToken.Receiver}>
        access(self) var beneficiaryCapability: Capability<&{FungibleToken.Receiver}>
        pub var cutPercentage: UFix64

        init (
            ownerCollection: Capability<&TopShot.Collection>,
            ownerCapability: Capability<&{FungibleToken.Receiver}>,
            beneficiaryCapability: Capability<&{FungibleToken.Receiver}>,
            cutPercentage: UFix64
        ) {
            pre {
                ownerCollection.check(): "Owner's Moment Collection Capability is invalid!"
                ownerCapability.check(): "Owner's Receiver Capability is invalid!"
                beneficiaryCapability.check(): "Beneficiary's Receiver Capability is invalid!" 
            }
            self.ownerCollection = ownerCollection
            self.ownerCapability = ownerCapability
            self.beneficiaryCapability = beneficiaryCapability
            self.listings = {}
            self.cutPercentage = cutPercentage
        }

        pub fun listForSale(setID: UInt32, tokenIDs: [UInt64], price: UFix64) {
            // make sure the user actually has the set
            var coveredPlays: [UInt32] = []
            let numOfPlaysInSet: Int = TopShot.getPlaysInSet(setID: setID)!.length
            let collection = self.ownerCollection.borrow()!
            for id in tokenIDs {
                let moment: &TopShot.NFT = collection.borrowMoment(id: id)!
                if moment.data.setID == setID && !coveredPlays.contains(moment.data.playID) && !TopShotLocking.isLocked(nftRef: collection.borrowNFT(id: id)) {
                    coveredPlays.append(moment.data.playID)
                }
            }
            assert(coveredPlays.length >= numOfPlaysInSet, message: "This user does not own this Set.")
 
            // Set the listing
            self.listings[setID] = SetSaleData(price: price, tokenIDs: tokenIDs)

            emit SetListed(setID: setID, tokenIDs: tokenIDs, price: price, seller: self.owner?.address)
        }

        pub fun cancelSale(setID: UInt32) {
            if self.listings[setID] == nil {
                return
            }

            // Remove the price from the prices dictionary
            self.listings.remove(key: setID)

            // Emit the event for withdrawing a moment from the Sale
            emit SetWithdrawn(id: setID, owner: self.owner?.address)
        }

        /// purchase lets a user send tokens to purchase a Set that is for sale
        /// the purchased Set is returned to the transaction context that called it
        pub fun purchase(setID: UInt32, buyTokens: @DapperUtilityCoin.Vault): @[TopShot.NFT] {
            pre {
                self.listings[setID] == nil: "No set matching this ID for sale!"
            }

            // Read the price for the set
            let saleData: SetSaleData = self.listings[setID]!

            assert(
                buyTokens.balance == saleData.price,
                message: "Not enough tokens to buy the Set!"
            )

            // Take the cut of the tokens that the beneficiary gets from the sent tokens
            let beneficiaryCut <- buyTokens.withdraw(amount: saleData.price * self.cutPercentage)

            // Deposit it into the beneficiary's Vault
            self.beneficiaryCapability.borrow()!.deposit(from: <-beneficiaryCut)
            
            // Deposit the remaining tokens into the owners vault
            self.ownerCapability.borrow()!.deposit(from: <-buyTokens)

            emit SetPurchased(id: setID, price: saleData.price, seller: self.owner?.address)

            // Return the purchased set
            let set: @[TopShot.NFT] <- []
            for id in saleData.tokenIDs {
                set.append(<- (self.ownerCollection.borrow()!.withdraw(withdrawID: id) as! @TopShot.NFT))
            }

            // remove the listing
            self.listings.remove(key: setID)

            return <- set
        }

        pub fun changeOwnerReceiver(_ newOwnerCapability: Capability<&{FungibleToken.Receiver}>) {
            pre {
                newOwnerCapability.borrow() != nil: 
                    "Owner's Receiver Capability is invalid!"
            }
            self.ownerCapability = newOwnerCapability
        }

        pub fun changeBeneficiaryReceiver(_ newBeneficiaryCapability: Capability<&{FungibleToken.Receiver}>) {
            pre {
                newBeneficiaryCapability.borrow() != nil: 
                    "Beneficiary's Receiver Capability is invalid!" 
            }
            self.beneficiaryCapability = newBeneficiaryCapability
        }

        /// getPrice returns the price of a specific set in the sale
        ///
        /// Returns: UFix64: The price of the set
        pub fun getSaleData(setID: UInt32): SetSaleData? {
            return self.listings[setID]
        }

        /// getIDs returns an array of set IDs that are for sale
        pub fun getIDs(): [UInt32] {
            return self.listings.keys
        }

        pub fun getSetData(id: UInt32): TopShot.QuerySetData? {
            return TopShot.getSetData(setID: id)
        }
    }

    /// createCollection returns a new collection resource to the caller
    pub fun createSaleCollection(
        ownerCollection: Capability<&TopShot.Collection>,                    
        ownerCapability: Capability<&{FungibleToken.Receiver}>,
        beneficiaryCapability: Capability<&{FungibleToken.Receiver}>,
        cutPercentage: UFix64
    ): @SaleCollection {
        return <- create SaleCollection(ownerCollection: ownerCollection, ownerCapability: ownerCapability, beneficiaryCapability: beneficiaryCapability, cutPercentage: cutPercentage)
    }

    init() {
        self.SetMarketStoragePath = /storage/TopShotSetMarketSaleCollection
        self.SetMarketPublicPath = /public/TopShotSetMarketSaleCollection
    }
}