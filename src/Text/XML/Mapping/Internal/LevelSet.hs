-- |
-- Module      : Text.XML.Mapping.Internal.LevelSet
-- Copyright   : (c) Joseph Abrahamson 2013
-- License     : MIT
-- .
-- Maintainer  : me@jspha.com
-- Stability   : experimental
-- Portability : non-portable
-- .
-- Fixed contextual state for a particular stage in an XML tree
-- traversal.
-- .
-- Whenever we \"descend\" into a new XML element we add a new step to
-- an implicit path from the root node. We also get a fresh XML
-- Namespace lexical scope and a new attribtue context.
-- .
-- This particular collection of state at a given \"level\" in the XML
-- tree is called the 'LevelState'. We can also view these states as a
-- stack which gets pushed and popped as we step into and out of
-- elements called a 'LevelSet'.

module Text.XML.Mapping.Internal.LevelSet where

import           Control.Applicative
import qualified Data.ByteString                   as S
import           Data.Foldable
import qualified Data.HashMap.Strict               as Map
import           Data.Monoid
import qualified Data.Text                         as T
import           Text.XML.Mapping.NSMap
import           Text.XML.Mapping.Schema.Namespace
import           Text.XML.Mapping.Types

type AttrMap = Map.HashMap QName S.ByteString

-- | The 'LevelState' is the parse-constant contextual state at this
-- \"level\" of the tree. It includes the current location, attributes
-- (metadata) in scope, and a set of currently in-scope namespaces.
data LevelState =
  LevelState { name       :: !QName
             , attributes :: !AttrMap
             , namespaces :: !NSMap
             }

-- | Kick off a 'LevelSet' from element data.
initialize :: Tag -> Maybe (Either [Prefix] LevelState)
initialize t = case rawName t of
  Nothing   -> Nothing -- text node
  Just rName -> Just $ do
    let rAttrs             = rawAttrs t
        nsmap@(NSMap _ hm) = defaultNSMap <> fromAttrs rAttrs
    nm@(QName def _) <- resolve nsmap rName

    -- We adjust the default namespace to match the element namespace
    -- while performing attribute namespace resolution.

    attrs <- foldrM (mkAttrs (NSMap def hm)) Map.empty rAttrs
    return LevelState { name       = nm
                      , attributes = attrs
                      , namespaces = nsmap
                      }
  where
    mkAttrs :: NSMap
               -> (T.Text, S.ByteString)
               -> Map.HashMap QName S.ByteString
               -> Either [Prefix] (Map.HashMap QName S.ByteString)
    mkAttrs nsmap (key, val) m0 = (\nsn -> Map.insert nsn val m0) <$> resolve nsmap key

-- | Appends a new derived 'LevelState' to the end of a
-- 'LevelSet'. See 'initialize'.
(!<<) :: Tag -> LevelSet -> Either [Prefix] LevelSet
(!<<) t lset = (`In` lset) <$> initialize t (levelState lset)

-- | As we traverse the XML tree we build a stack of 'LevelState's
-- representing the attribute and element context that we're
-- descending through. This allows for fairly targeted parser error
-- messages.
--
-- To be more clear, this is isomorphic to `NonEmpty LevelSet`.
data LevelSet = In   { levelState :: !LevelState, _out :: !(LevelSet) }
              | Root { levelState :: !LevelState }

-- | Safe '_out'.
out :: LevelSet -> Maybe LevelSet
out i@In{} = Just (_out i)
out _      = Nothing