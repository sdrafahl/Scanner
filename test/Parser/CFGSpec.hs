{-# LANGUAGE NoImplicitPrelude #-}
module Parser.CFGSpec (spec) where

import Import
import Util
import Test.Hspec
import Test.Hspec.QuickCheck
import RegularExpression
import NFAtoDFA
import StateMachine
import DFA
import NFA
import Data.Map (Map)
import Data.Map
import Data.Set
import Parser.CFG

-------------------- CASE A
-- Fee -> A to Fee -> B Fee'
--     -> B    Fee' -> A Fee'
--                  -> δ


-- removeLeftRecursion :: NonTerminalOrTerminal -> [ProductionChildren] -> (Set ProductionRule)

spec :: Spec
spec = do
  describe "eleminateLeftRecursion" $ do
    it "Should elimate left recursion from case A" $ eleminateLeftRecursion (CFG (Data.Set.fromList [(NonTerminal "Fee")]) (Data.Set.fromList [(Terminal "A"), (Terminal "B")])  (Data.Set.fromList [(ProductionRule (NonTerm (NonTerminal "Fee"), [(NonTerm (NonTerminal "Fee")) ,(Term (Terminal "A"))])), (ProductionRule (NonTerm (NonTerminal "Fee"), [(Term (Terminal "B"))])) ]) (NonTerm (NonTerminal "Fee")))
      `shouldBe`
      (CFG (Data.Set.fromList [(NonTerminal "Fee"), (NonTerminal "Fee'")]) (Data.Set.fromList [(Terminal "A"), (Terminal "B"), (Terminal "δ")]) (Data.Set.fromList [ProductionRule (NonTerm (NonTerminal "Fee"),[Term (Terminal "B"),NonTerm (NonTerminal "Fee'")]),ProductionRule (NonTerm (NonTerminal "Fee'"),[Term (Terminal "A"),NonTerm (NonTerminal "Fee'")]),ProductionRule (NonTerm (NonTerminal "Fee'"),[Term (Terminal "\948")])]) (NonTerm (NonTerminal "Fee")))
