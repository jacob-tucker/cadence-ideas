import FungibleToken from "../contracts/FungibleToken.cdc"
import DapperUtilityCoin from "../contracts/DapperUtilityCoin.cdc"
import TopShot from "../contracts/TopShot.cdc"
import TopShotMarketV3 from "../contracts/TopShotMarketV3.cdc"
import Market from "../contracts/Market.cdc"
import NonFungibleToken from "../contracts/NonFungibleToken.cdc"

transaction(sellerAddresses: [Address], tokenIDs: [UInt64], purchaseAmounts: [UFix64]) {
    
    let DUCVault: &DapperUtilityCoin.Vault
    let MomentCollection: &TopShot.Collection{NonFungibleToken.CollectionPublic}
    let SellerMarket: [&{Market.SalePublic}]
    
    prepare(signer: AuthAccount) {
        self.MomentCollection = signer.getCapability(/public/MomentCollection)
                                    .borrow<&TopShot.Collection{NonFungibleToken.CollectionPublic}>()
                                    ?? panic("Could not borrow the public moment collection from the user")

        self.DUCVault = signer.borrow<&DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)!

        self.SellerMarket = []
        for sellerAddress in sellerAddresses {
            let sellerMarket: &{Market.SalePublic} = getAccount(sellerAddress).getCapability(TopShotMarketV3.marketPublicPath)
                                                        .borrow<&{Market.SalePublic}>()
                                                        ?? panic("Could not borrow public sale reference")
            self.SellerMarket.append(sellerMarket)
        }
    }

    execute {
        for i, sellerMarket in self.SellerMarket {
            let tokens: @DapperUtilityCoin.Vault <- self.DUCVault.withdraw(amount: purchaseAmounts[i]) as! @DapperUtilityCoin.Vault
            let purchasedToken: @TopShot.NFT <- sellerMarket.purchase(tokenID: tokenIDs[i], buyTokens: <- tokens)
            self.MomentCollection.deposit(token: <-purchasedToken)
        }
    }
}