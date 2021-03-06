-- | Types describing runtime errors related to Txp.

module Pos.Txp.Error
       ( TxpError (..)
       ) where

import           Control.Exception.Safe (Exception (..))
import qualified Data.Text.Buildable
import           Formatting (bprint, stext, (%))
import           Universum

import           Pos.Exception (cryptokamiExceptionFromException, cryptokamiExceptionToException)

data TxpError
    = TxpInternalError !Text
    -- ^ Something bad happened inside Txp
    deriving (Show)

instance Exception TxpError where
    toException = cryptokamiExceptionToException
    fromException = cryptokamiExceptionFromException
    displayException = toString . pretty

instance Buildable TxpError where
    build (TxpInternalError msg) =
        bprint ("internal error in Transaction processing: "%stext) msg
