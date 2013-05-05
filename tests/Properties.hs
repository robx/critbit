{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module Properties
    where

import Control.Applicative ((<$>))
import Data.ByteString (ByteString)
import Data.CritBit.Map.Lazy (CritBitKey, CritBit)
import Data.Text (Text)
import Data.Word (Word8)
import Test.Framework (Test, testGroup)
import Test.Framework.Providers.QuickCheck2 (testProperty)
import Test.QuickCheck (Arbitrary(..), Args(..), quickCheckWith, stdArgs)
import qualified Data.ByteString as BB
import qualified Data.ByteString.Char8 as B
import qualified Data.CritBit.Map.Lazy as C
import qualified Data.Map as Map
import qualified Data.Text as T

instance Arbitrary ByteString where
    arbitrary = BB.pack <$> arbitrary
    shrink    = map B.pack . shrink . B.unpack

instance Arbitrary Text where
    arbitrary = T.pack <$> arbitrary
    shrink    = map T.pack . shrink . T.unpack

type V = Word8

newtype KV a = KV { fromKV :: [(a, V)] }
        deriving (Show, Eq, Ord)

instance Arbitrary a => Arbitrary (KV a) where
    arbitrary = (KV . flip zip [0..]) <$> arbitrary
    shrink = map (KV . flip zip [0..]) . shrink . map fst . fromKV

instance (CritBitKey k, Arbitrary k, Arbitrary v) =>
  Arbitrary (CritBit k v) where
    arbitrary = C.fromList <$> arbitrary
    shrink = map C.fromList . shrink . C.toList

newtype CB k = CB (CritBit k V)
    deriving (Show, Eq, Arbitrary)

blist :: [ByteString] -> CritBit ByteString Word8
blist = C.fromList . flip zip [0..]

tlist :: [Text] -> CritBit Text Word8
tlist = C.fromList . flip zip [0..]

mlist :: [ByteString] -> Map.Map ByteString Word8
mlist = Map.fromList . flip zip [0..]

qc n = quickCheckWith stdArgs { maxSuccess = n }

t_lookup_present :: (CritBitKey k) => k -> k -> V -> CB k -> Bool
t_lookup_present _ k v (CB m) = C.lookup k (C.insert k v m) == Just v

t_lookup_missing :: (CritBitKey k) => k -> k -> CB k -> Bool
t_lookup_missing _ k (CB m) = C.lookup k (C.delete k m) == Nothing

t_fromList_toList :: (CritBitKey k, Ord k) => k -> KV k -> Bool
t_fromList_toList _ (KV kvs) =
    Map.toList (Map.fromList kvs) == C.toList (C.fromList kvs)

t_fromList_size :: (CritBitKey k, Ord k) => k -> KV k -> Bool
t_fromList_size _ (KV kvs) =
    Map.size (Map.fromList kvs) == C.size (C.fromList kvs)

t_delete_present :: (CritBitKey k, Ord k) => k -> KV k -> k -> V -> Bool
t_delete_present _ (KV kvs) k v =
    C.toList (C.delete k c) == Map.toList (Map.delete k m)
  where
    c = C.insert k v $ C.fromList kvs
    m = Map.insert k v $ Map.fromList kvs

propertiesFor :: (Arbitrary k, CritBitKey k, Ord k, Show k) => k -> [Test]
propertiesFor t = [
    testProperty "t_fromList_toList" $ t_fromList_toList t
  , testProperty "t_fromList_size" $ t_fromList_size t
  , testProperty "t_lookup_present" $ t_lookup_present t
  , testProperty "t_lookup_missing" $ t_lookup_missing t
  , testProperty "t_delete_present" $ t_delete_present t
  ]

properties :: [Test]
properties = [
    testGroup "text" $ propertiesFor T.empty
  , testGroup "bytestring" $ propertiesFor B.empty
  ]
