{-# LANGUAGE ScopedTypeVariables #-}

module Cryptokami.Wallet.API.V1.Handlers.Transactions where

import           Universum

import           Pos.Core (TxAux)
import           Cryptokami.Wallet.API.V1.Migration (HasCompileInfo, HasConfigurations, MonadV1,
                                                  migrate)
import qualified Pos.Wallet.Web.ClientTypes.Types as V0
import qualified Pos.Wallet.Web.Methods.History as V0
import qualified Pos.Wallet.Web.Methods.Payment as V0
import qualified Pos.Wallet.Web.Methods.Txp as V0

import           Cryptokami.Wallet.API.Request
import           Cryptokami.Wallet.API.Response
import qualified Cryptokami.Wallet.API.V1.Transactions as Transactions
import           Cryptokami.Wallet.API.V1.Types
import qualified Data.IxSet.Typed as IxSet

import           Data.Default
import qualified Data.List.NonEmpty as NE
import           Servant
import           Test.QuickCheck (arbitrary, generate)

handlers :: ( HasConfigurations
            , HasCompileInfo
            )
         => (TxAux -> MonadV1 Bool) -> ServerT Transactions.API MonadV1

handlers submitTx =
             newTransaction submitTx
        :<|> allTransactions
        :<|> estimateFees

newTransaction
    :: forall ctx m . (V0.MonadWalletTxFull ctx m)
    => (TxAux -> m Bool) -> Payment -> m (WalletResponse Transaction)
newTransaction submitTx Payment {..} = do
    let spendingPw = fromMaybe mempty pmtSpendingPassword
    cAccountId <- migrate (pmtSourceWallet, pmtSourceAccount)
    addrCoinList <- migrate $ NE.toList pmtDestinations
    policy <- migrate $ fromMaybe def pmtGroupingPolicy
    let batchPayment = V0.NewBatchPayment cAccountId addrCoinList policy
    cTx <- V0.newPaymentBatch submitTx spendingPw batchPayment
    single <$> migrate cTx

-- | The conclusion is that we want just the walletId for now, the details
-- in CSL-1917.
allTransactions
    :: forall ctx m. (V0.MonadWalletHistory ctx m)
    => WalletId
    -> RequestParams
    -> m (WalletResponse [Transaction])
allTransactions walletId requestParams = do
    cIdWallet    <- migrate walletId

    -- TODO(ks): We need the type signature, fix this?
    let transactions :: m [Transaction]
        transactions = do
            (V0.WalletHistory wh, V0.WalletHistorySize whs) <-
                V0.getHistory cIdWallet mempty Nothing
            migrate (wh, whs)

    respondWith requestParams (NoFilters :: FilterOperations Transaction)
                              (NoSorts :: SortOperations Transaction)
                              (IxSet.fromList <$> transactions)

estimateFees :: Payment -> MonadV1 (WalletResponse EstimatedFees)
estimateFees _ = single <$> liftIO (generate arbitrary)
