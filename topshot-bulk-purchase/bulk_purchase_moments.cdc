import FungibleToken from "../contracts/FungibleToken.cdc"
import DapperUtilityCoin from "../contracts/DapperUtilityCoin.cdc"
import TopShot from "../contracts/TopShot.cdc"
import TopShotMarketV3 from "../contracts/TopShotMarketV3.cdc"
import Market from "../contracts/Market.cdc"

transaction(sellerAddresses: [Address], tokenIDs: [UInt64], purchaseAmounts: [UFix64]) {
    
    let DUCVault: &DapperUtilityCoin.Vault
    let MomentCollection: [&TopShot.Collection]
    let SellerMarket: [&{Market.SalePublic}]
    
    prepare(signer: AuthAccount) {
        self.MomentCollection = signer.borrow<&TopShot.Collection>(from: /storage/MomentCollection)
            ?? panic("Could not borrow reference to the Moment Collection")

        self.DUCVault = signer.borrow<&DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)!

        self.SellerMarket = getAccount(sellerAddress).getCapability(TopShotMarketV3.marketPublicPath)
            .borrow<&{Market.SalePublic}>()
            ?? panic("Could not borrow public sale reference")
    
        // purchase the moment
        let purchasedToken <- topshotSaleCollection.purchase(tokenID: tokenID, buyTokens: <-tokens)

        // deposit the purchased moment into the signer's collection
        collection.deposit(token: <-purchasedToken)
    }

    execute {
      let tokens <- self.DUCVault.withdraw(amount: purchaseAmount) as! @DapperUtilityCoin.Vault
    }
}