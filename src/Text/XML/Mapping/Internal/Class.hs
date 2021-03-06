{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE RankNTypes    #-}

-- |
-- Module      : Text.XML.Mapping.Internal.Class
-- Copyright   : (c) Joseph Abrahamson 2013
-- License     : MIT
-- .
-- Maintainer  : me@jspha.com
-- Stability   : experimental
-- Portability : non-portable
-- .
-- Abstract definition of the XML representation class.
-- .

module Text.XML.Mapping.Internal.Class where

import           Control.Applicative
import qualified Data.Attoparsec                    as A
import qualified Data.ByteString                    as S
import           Data.List.NonEmpty                 (NonEmpty ((:|)))
import qualified Data.List.NonEmpty                 as NEL
import           Data.Maybe                         (fromJust)
import qualified Data.Text                          as T
import           Text.XML.Mapping.Schema.Mixed
import           Text.XML.Mapping.Schema.Namespace
import           Text.XML.Mapping.Schema.SimpleType

-- | A field contains a key and a type.
data El a = El { name :: QName, el :: a } deriving ( Eq, Show, Functor )

-- | An abstract definition of the parser.
class Alternative f => X f where

  -- | Run a parser on an attribute value in the current context.
  pAttr :: A.Parser a -> QName -> f a

  -- | Run a parser on the next text value in the current stream,
  -- consuming it if successful.
  pText :: A.Parser a -> f a

  -- | Run a new 'p'-type parser on the children of the next element,
  -- using the improved element context and consuming the element if
  -- successful.
  pElem :: (QName -> Bool) -> f a -> f (El a)

attr :: (FromSimple a, X f) => QName -> f a
attr = pAttr parseSimple

text :: (FromSimple a, X f) => f a
text = pText parseSimple

element :: (XML a, X f) => (QName -> Bool) -> f (El a)
element check = pElem check xml

(#>) :: X f => QName -> f a -> f a
qn #> p = el <$> pElem (== qn) p

nonEmpty :: X f => f a -> f (NonEmpty a)
nonEmpty p = (:|) <$> p <*> many p

class XML a where
  xml :: forall f . X f => f a

instance XML () where
  xml = pure ()

instance XML S.ByteString where
  xml = text

-- | Blind match on any element. Use 'element' or '(#>)' to match a
-- particular element.
instance XML a => XML (El a) where
  xml = pElem (const True) xml

instance XML T.Text where
  xml = text

instance XML a => XML [a] where
  xml = many xml

instance XML a => XML (NonEmpty a) where
  xml = (fromJust . NEL.nonEmpty) <$> some xml

eitherX :: X f => f a -> f b -> f (Either a b)
eitherX fa fb = Left <$> fa <|> Right <$> fb

mixed :: X f => f a -> f (Mixed a)
mixed pa = Mixed <$> many (eitherX text pa)
