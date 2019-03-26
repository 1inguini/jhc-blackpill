#!/usr/bin/env stack
{- stack
  runghc
-}

module Main where

import           Data.List
import           System.Directory
import           System.Process

projname = "main"
projsrc pwd = pwd ++ "/" ++ "my-project"

hsSrcDir pwd = projsrc pwd ++  "/hs_src"
hsFiles pwd = hsSrcDir pwd ++ "/Main.hs"

device = "stm32f103cbt6"
chip = "STM32F1"

jhcrts pwd = projsrc pwd  ++ "/" ++ "jhc_custom"

opencm3_dir pwd = pwd ++ "/libopencm3"

target = "arm-none-eabi"
-- cc = "clang -target" +++ target
cc = target ++ "-gcc"
cpp = "clang++ -target" +++ target
ld = target ++ "-gcc"
objcopy = target ++ "-objcopy"
objdump = target ++ "-objdump"
size = target ++ "-size"
gdb = target ++ "-gdb"
ar = target ++ "-ar"

devicesData pwd =
  opencm3_dir pwd ++ "/ld/devices.data"

genlink :: String -> FilePath -> IO String
genlink something pwd =
  readProcess (opencm3_dir pwd ++ "/scripts/genlink.py")
  [devicesData pwd, device, something] []

libDeps pwd = do
  family <- genlink "FAMILY" pwd
  -- I was too lazy to add support for chipis that need to be called with subfamily
  return $ opencm3_dir pwd ++ "/lib/libopencm3_" ++ family ++ ".a"

archflags pwd = do
  cpu <- genlink "CPU" pwd
  fpu <- genlink "FPU" pwd
  return ((case fpu of
           "soft"             -> "-msoft-float"
           "hard-fpv4-sp-d16" -> "-mfloat-abi=hard -mfpu=fpv4-sp-d16"
           "hard-fpv5-sp-d16" -> "-mfloat-abi=hard -mfpu=fpv5-sp-d16"
           otherwise          -> "unknown fpu")
           +++
           (if cpu `elem`["cortex-m0",
                          "cortex-m0plus",
                          "cortex-m3",
                          "coretex-m4",
                          "cortex-m7"]
             then ("-mthumb" +++)
             else ("" ++))
           "-mcpu=" ++ cpu)


cflags pwd = do
  arch <-archflags pwd
  cpp <- genlink "CPPFLAGS" pwd
  family <- genlink "FAMiLY" pwd
  return (arch +++
          cpp +++
          "-g -O0 -Wall -v \
          \-fno-common -ffunction-sections -fdata-sections -ffreestanding" +++
           "-nostdlib -nostartfiles" +++
           -- "-L" ++ opencm3_dir pwd ++ "/lib" +++ "-lopencm3_" ++  family +++
           -- "-L" ++ projsrc pwd +++ "-ljhcrts" +++
           -- "-I" ++ jhcrts pwd ++ "/cbits" +++
           -- "-I" ++ jhcrts pwd ++ "/src" +++
           "-I" ++ opencm3_dir pwd ++ "/include" +++
           -- "-I" ++ jhcrts pwd +++
           -- "-I" ++ projsrc pwd +++
           -- "-I" ++ projsrc pwd ++ "/src" +++
           "-std=gnu99" +++
           "-DNDEBUG -D_JHC_GC=_JHC_GC_JGC -D_JHC_STANDALONE=0 \
           \-D_LITTLE_ENDIAN \
           \-D_JHC_ARM_STAY_IN_THUMB_MODE \
           \-D_JHC_JGC_STACKGROW=16 -D_JHC_JGC_LIMITED_NUM_MEGABLOCK=38 \
           \-D_JHC_JGC_BLOCK_SHIFT=8 -D_JHC_JGC_MEGABLOCK_SHIFT=13 \
           \-D_JHC_JGC_GC_STACK_SHIFT=8 -D_JHC_JGC_LIMITED_NUM_GC_STACK=20 \
           \-D_JHC_JGC_NAIVEGC -D_JHC_JGC_SAVING_MALLOC_HEAP \
           \-D_JHC_CONC=_JHC_CONC_CUSTOM ")


listToString seperator =
  foldl1 (\words word -> word ++  seperator ++ words)


(+++) a b = a ++ " " ++ b
infixr 5 +++

whitespaceToSpace =
  listToString " " . words

gsub :: String -> String -> String -> String
gsub _ _ [] = []
gsub x y str@(s:ss)
  | x `isPrefixOf` str = y ++ gsub x y (drop (length x) str)
  | otherwise = s:gsub x y ss

----------------------------------------------------------------------

hsMainC :: FilePath -> IO [FilePath]
hsMainC pwd = do
  putStr "hsMainC was called\n"
  callCommand
    ("jhc -v -fffi --tdir=" ++ jhcrts pwd +++ "-C --include=" ++ hsSrcDir pwd ++ " -o" +++ out +++ input)
  putStr "hsMainC done\n"
  return [out]
  where
    out   = projsrc pwd ++ "/hs_main.c"
    input = hsFiles pwd



-- jhcRtsObjects :: FilePath -> IO [FilePath]
-- jhcRtsObjects pwd = do
--   putStr "jhcRtsObjects was called\n"
--   generatedBins <- hsMainC pwd
--   cFiles        <- readProcess
--                    "fish" ["-c","ls " ++ jhcrts pwd ++ "/**.c"] []
--   mapM_ (callCommand . (\input ->
--                           cc +++ cflags pwd +++ "-c -o" +++ (init . init) input ++ ".o" +++ input))
--     $ words cFiles
--   putStr "jhcRtsObjects done\n"
--   return
--     (generatedBins ++
--       map (\input ->
--               (init . init) input ++ ".o") (words cFiles))
--     -- $ generatedBins ++
--     -- map (\input -> pwd ++ "/" ++ (init . init) input ++ ".o")
--     -- (words cFiles)
--     -- where
--     --   cFiles = listToString " "
--     --            (map (\x -> jhcrts pwd ++ "/rts/" ++ x)
--     --             (words "gc_jgc.c jhc_rts.c stableptr.c rts_support.c conc_custom.c"))

-- libjhcrtsA :: FilePath -> IO [FilePath]
-- libjhcrtsA pwd = do
--   putStr "libjhcrtsA was called\n"
--   generatedBins <- hsMainC pwd
--   objs          <- jhcRtsObjects pwd

--   source <- readFile header
--   removeFile header
--   writeFile
--     header
--     (gsub "void _amain(void);\nvoid jhc_hs_init(void);" "\n// remove\n"
--       source)
--   -- objs <- readProcess "fish" ["-c","ls" +++ jhcrts pwd ++ "/**.o"] []
--   putStr $ listToString " " objs ++ "\n"
--   callCommand
--     $ ar +++ "-r" +++ out +++ listToString " " objs
--   putStr "libjhcrtsA done\n"
--   return $ out:generatedBins
--   where
--     header = jhcrts pwd ++ "/jhc_rts_header.h"
--     out    = projsrc pwd ++ "/libjhcrts.a"


ldScript :: FilePath -> IO [FilePath]
ldScript pwd = do
  putStr "ldScript was called\n"
  archflags <- archflags pwd
  callCommand
    ("make -C" +++ projsrc pwd ++ "/../" +++
     "DEVICE=\"" ++ device ++ "\"" +++
     "ARCHFLAGS=\"" ++ archflags ++ "\"" +++
     "OPENCM3_DIR=\"" ++ opencm3_dir pwd ++ "\"" +++
     "CPP=\"" ++ cc ++ "\"")

  putStr "ldScript done\n"
  return [out]
    where
      out = pwd ++ "/generated." ++ device ++ ".ld"


options :: FilePath -> IO String
options pwd = do
  [hsMain] <- hsMainC pwd
  gsub
    ("-o" +++ projsrc pwd ++ "/hs_main.c")
    ""
    . drop 28
    . init . init
    . takeWhile (/= '\n')
    <$> readFile hsMain

  -- drop 32 firstLine

-- removeImportStd pwd = do
--   files <- words <$> readProcess "find" [jhcrts pwd , "-name", "*.c"] []
--   mapM_ (\file -> do
--             source <- readFile file
--             removeFile file
--             writeFile file
--               (gsub "#include <stdio.h>" "// removed #include <stdio.h>"
--                source))
--     files



cToO :: FilePath -> IO [FilePath]
cToO pwd = do
  putStr "cToO called\n"
  cflags <- cflags pwd
  options <- options pwd
  -- removeImportStd pwd
  cFiles  <- listToString " "
             . words
             <$> readProcess "find" [projsrc pwd, "-name", "*.c"] []
  callCommand
    (cc +++ cFiles +++ options +++ cflags +++ "-I" ++ projsrc pwd ++ "/src -c")
  putStr "cToO done\n"
  return [""]


link pwd = do
  cToO pwd
  [ldScript] <- ldScript pwd
  archflags  <- archflags pwd
  libDeps    <- libDeps pwd
  objFiles  <- listToString " " . words <$> readProcess "find" [pwd, "-maxdepth", "1", "-name", "*.o"] []
  ldLib <- ("-lopencm3_" ++) <$> genlink "FAMILY" pwd
  callCommand
    (ld +++ "-T" ++ ldScript +++
     objFiles +++
     "-L" ++ opencm3_dir pwd ++ "/lib" +++
     "-nostartfiles" +++
     archflags +++
     "-specs=nano.specs -Wl,--gc-sections -Wl,--start-group -lc -lgcc" +++ "-lnosys -Wl,--end-group" +++
     "-L" ++ opencm3_dir pwd ++ "/lib" +++ ldLib +++
     libDeps)
  return []


proj :: FilePath -> IO [FilePath]
proj pwd = do
  putStr "proj was called\n"
  cflags <- cflags pwd
  -- archive <- libjhcrtsA pwd
  [ld]   <- ldScript pwd
  -- cFiles  <- readProcess "fish" ["-c","ls " ++ projsrc pwd ++ "/src/**.c"] []
  cFiles <- words
            <$> readProcess "find" [projsrc pwd ++ "/src/" ,"-name", "*.c"] []

  callCommand
    (cc +++ cflags +++ "-o" +++ outElf +++
      listToString " " cFiles +++
      -- listToString " " archive +++
      projsrc pwd ++ "/hs_main.c" +++
      "-T" ++ ld +++
      "-D" ++ chip)

  callCommand $ objcopy +++ "-O ihex" +++ outElf +++ outHex
  callCommand $ objcopy +++ "-O binary" +++ outElf +++ outBin
  callCommand $ objcopy +++ "-St" +++ outElf +++ ">" ++ outLst
  callCommand $ size +++ outElf

  putStr "proj done\n"
  return $ ld:outElf:outHex:outBin:[outLst]-- :(archive ++ words cFiles)
  where
    outElf = projname ++ ".elf"
    outHex = projname ++ ".hex"
    outBin = projname ++ ".bin"
    outLst = projname ++ ".lst"


clean :: [FilePath] -> FilePath -> IO()
clean generatedBins pwd = do
  putStr "clean was called\n"
  mapM_ (callCommand . ("rm " ++)) generatedBins
  callCommand ("rm" +++ projsrc pwd ++ "/*.o")
  putStr "clean done\n"


main :: IO ()
main = do
  pwd <- getCurrentDirectory
  -- _             <- hsMainC pwd
  -- generatedBins <- proj pwd
  -- print =<< options pwd
  link pwd

  -- clean generatedBins
  -- generatedBins <- jhcRtsObjects (projsrc pwd)
  -- putStr $ "output was" ++ "\n\t" ++ listToString "\n\t" generatedBins ++ "\n"
  putStr "done\n"