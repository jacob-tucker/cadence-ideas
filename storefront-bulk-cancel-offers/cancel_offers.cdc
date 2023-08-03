import NFTStorefront from "../contracts/NFTStorefront.cdc"

transaction(saleOfferResourceIDs: [UInt64]) {

    let Storefront: &NFTStorefront.Storefront

    prepare(acct: AuthAccount) {
        // borrow a reference to the owner's storefront
        self.Storefront = acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
                                                        ?? panic("Signer does not have a Storefront.")
    }

    execute {
        for saleOfferResourceID in saleOfferResourceIDs {
            // cancel the offer
            self.Storefront.removeSaleOffer(saleOfferResourceID: saleOfferResourceID)
        }
    }
}