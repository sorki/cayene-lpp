{-|
Description : Cayenne Low Power Protocol encoding and decoding
Maintainer  : srk <srk@48.io>

Encoding example:

> import qualified Data.Cayenne as CLPP
> import qualified Data.ByteString.Base16.Lazy as B16L
> import qualified Data.ByteString.Lazy.Char8 as BSL
>
> BSL.putStrLn $ B16L.encode . CLPP.encodeMany [(7, Illum 1337), (0, Power 13.5)]

-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveGeneric       #-}

module Data.Cayenne.Types (
    Sensor(..)
  , Channel
  , Reading
  , encode
  , encodeMany
  , decode
  , decodeMany
  , decodeMaybe
  ) where

import Control.Monad
import Control.Applicative
import Data.Monoid
import GHC.Generics

import Data.Bits
import Data.Binary.Get
import Data.Binary.Put
import Data.Word
import Data.Int
import qualified Data.ByteString.Lazy.Char8 as BL

type Channel = Int
type Reading = (Channel, Sensor)

data Sensor =
    DigitalIn     Word8              -- ^ Digital input (8 bits)
  | DigitalOut    Word8              -- ^ Digital output (8 bits)
  | AnalogIn      Float              -- ^ Analog input
  | AnalogOut     Float              -- ^ Analog output
  | Illum         Word16             -- ^ Illuminance sensor (Lux)
  | Presence      Word8              -- ^ Presence
  | Temperature   Float              -- ^ Temperature (Celsius)
  | Humidity      Float              -- ^ Humidity (%)
  | Accelerometer Float Float Float  -- ^ Accelerometer (G)
  | Barometer     Float              -- ^ Barometer (hPa)
  | Voltage       Float              -- ^ Voltage (V)
  | Current       Float              -- ^ Current (A)
  | Percentage    Float              -- ^ Percentage
  | Pressure      Float              -- ^ Pressure
  | Power         Float              -- ^ Power (W)
  | Energy        Float              -- ^ Energy (J)
  | Direction     Float              -- ^ Angle (Deg)
  | Gyrometer     Float Float Float  -- ^ Gyrometer (°/s)
  | GPS           Float Float Float  -- ^ GPS Latitude (°) ,Longitude (°), Altitude (m)
  deriving (Eq, Ord, Show, Generic)

toID :: Sensor -> Int
toID (DigitalIn _)         = 0x00
toID (DigitalOut _)        = 0x01
toID (AnalogIn _)          = 0x02
toID (AnalogOut _)         = 0x03
toID (Illum _)             = 0x65
toID (Presence _)          = 0x66
toID (Temperature _)       = 0x67
toID (Humidity _)          = 0x68
toID (Accelerometer _ _ _) = 0x71
toID (Barometer _)         = 0x73
toID (Voltage _)           = 0x74
toID (Current _)           = 0x75
toID (Percentage _)        = 0x78
toID (Pressure _)          = 0x7b
toID (Power _)             = 0x80
toID (Energy _)            = 0x83
toID (Direction _)         = 0x84
toID (Gyrometer _ _ _)     = 0x86
toID (GPS _ _ _)           = 0x88

getSensor :: Get Sensor
getSensor =
      (isID 0x0 ) *> (DigitalIn     <$> getWord8)
  <|> (isID 0x1 ) *> (DigitalOut    <$> getWord8)
  <|> (isID 0x2 ) *> (AnalogIn      <$> ((/100) <$> getFloat16))
  <|> (isID 0x3 ) *> (AnalogOut     <$> ((/100) <$> getFloat16))
  <|> (isID 0x65) *> (Illum         <$> getWord16)
  <|> (isID 0x66) *> (Presence      <$> getWord8)
  <|> (isID 0x67) *> (Temperature   <$> ((/10)  <$> getFloat16))
  <|> (isID 0x68) *> (Humidity      <$> ((/2) . fromIntegral <$> getWord8))
  <|> (isID 0x71) *> (Accelerometer <$> ((/1000) <$> getFloat16) <*> ((/1000) <$> getFloat16) <*> ((/1000) <$> getFloat16))
  <|> (isID 0x73) *> (Barometer     <$> ((/10)  <$> getFloat16))
  <|> (isID 0x74) *> (Voltage       <$> ((/10)  <$> getFloat16))
  <|> (isID 0x75) *> (Current       <$> ((/10)  <$> getFloat16))
  <|> (isID 0x78) *> (Percentage    <$> getFloat16)
  <|> (isID 0x7b) *> (Pressure      <$> ((/10)  <$> getFloat16))
  <|> (isID 0x80) *> (Power         <$> ((/10)  <$> getFloat16))
  <|> (isID 0x83) *> (Energy        <$> ((/10)  <$> getFloat16))
  <|> (isID 0x84) *> (Direction     <$> getFloat16)
  <|> (isID 0x86) *> (Gyrometer     <$> ((/100) <$> getFloat16) <*> ((/100) <$> getFloat16) <*> ((/100) <$> getFloat16))
  <|> (isID 0x88) *> (GPS           <$> ((/10000) <$> getFloat24) <*> ((/10000) <$> getFloat24) <*> ((/100) <$> getFloat24))

isID :: Word8 -> Get ()
isID x = do
  y <- getWord8
  unless (x == y) $ empty

putSensor :: Sensor -> Put
putSensor s = putWord8 (fromIntegral $ toID s) >> putSensor' s

putSensor'  (DigitalIn x)         =  putWord8 x
putSensor'  (DigitalOut x)        =  putWord8 x
putSensor'  (AnalogIn x)          = (putFloat16 . (*100)) x
putSensor'  (AnalogOut x)         = (putFloat16 . (*100)) x
putSensor'  (Illum x)             =  putWord16 x
putSensor'  (Presence x)          =  putWord8 x
putSensor'  (Temperature x)       = (putFloat16 . (*10)) x
putSensor'  (Humidity x)          = (putWord8 . round . (*2)) x
putSensor'  (Accelerometer x y z) = (putFloat16 . (*1000)) x >> (putFloat16 . (*1000)) y >> (putFloat16 . (*1000)) z
putSensor'  (Barometer x)         = (putFloat16 . (*10)) x
putSensor'  (Voltage x)           = (putFloat16 . (*10)) x
putSensor'  (Current x)           = (putFloat16 . (*10)) x
putSensor'  (Percentage x)        =  putFloat16 x
putSensor'  (Pressure x)          = (putFloat16 . (*10)) x
putSensor'  (Power x)             = (putFloat16 . (*10)) x
putSensor'  (Energy x)            = (putFloat16 . (*10)) x
putSensor'  (Direction x)         =  putFloat16 x
putSensor'  (Gyrometer x y z)     = (putFloat16 . (*100)) x >> (putFloat16 . (*100)) y >> (putFloat16 . (*100)) z
putSensor'  (GPS x y z)           = (putFloat24 . (*10000)) x >> (putFloat24 . (*10000)) y >> (putFloat24 . (*100)) z

putReading :: Reading -> Put
putReading (chan, sens) = putChannel chan >> putSensor sens

putChannel :: Channel -> Put
putChannel = putWord8 . fromIntegral

putWord16 :: Word16 -> Put
putWord16 = putWord16be

putFloat16 :: Float -> Put
putFloat16 = putInt16be . round

putFloat24 :: Float -> Put
putFloat24 x = do
  let x' = round x :: Word32
  putWord8 $ fromIntegral $ x' `shiftR` 16
  putWord16be $ fromIntegral $ x'

-- | Encode a single 'Reading'
encode :: Reading -> BL.ByteString
encode = runPut . putReading

-- | Encode a list of 'Reading's
encodeMany :: [Reading] -> BL.ByteString
encodeMany = runPut . (mapM_ putReading)

getWord16 :: Get Word16
getWord16 = getWord16be

getFloat16 :: Get Float
getFloat16 = fromIntegral <$> getInt16be

getFloat24 :: Get Float
getFloat24 = do
  h :: Word32 <- fromIntegral <$> getWord8
  l :: Word32 <- fromIntegral <$> getWord16be
  let sum = (h `shiftL` 16) + l
      cast = fromIntegral :: Word32 -> Int32
      pls = (cast (h `shiftL` 16 + l) `shiftL` 8) `shiftR` 8
  return $ fromIntegral pls -- as in pls float24..

getChannel :: Get Channel
getChannel = fromIntegral <$> getWord8

clppP :: Get Reading
clppP = (,) <$> getChannel <*> getSensor

-- | Decode a single 'Reading', may fail
decode :: BL.ByteString -> Reading
decode = runGet clppP

-- | Decode multiple 'Reading's, returns empty list if nothing is decoded
decodeMany :: BL.ByteString -> [Reading]
decodeMany = runGet $ many clppP

-- | Maybe decode a single 'Reading'
decodeMaybe :: BL.ByteString -> Maybe Reading
decodeMaybe x = case runGetOrFail clppP x of
  Left _ -> Nothing
  Right (_, _, y) -> Just y
