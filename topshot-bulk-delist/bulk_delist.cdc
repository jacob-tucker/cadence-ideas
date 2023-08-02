import TopShotMarketV3 from "../contracts/TopShotMarketV3.cdc"

transaction(tokenIDs: [UInt64]) {

    let SaleCollection: &TopShotMarketV3.SaleCollection

    prepare(acct: AuthAccount) {
        // borrow a reference to the owner's sale collection
        self.SaleCollection = acct.borrow<&TopShotMarketV3.SaleCollection>(from: TopShotMarketV3.marketStoragePath)
                                                        ?? panic("Signer does not have a Sale Collection.")
    }

    execute {
        for tokenID in tokenIDs {
            // cancel the moment from the sale, thereby de-listing it
            self.SaleCollection.cancelSale(tokenID: tokenID)
        }
    }
}