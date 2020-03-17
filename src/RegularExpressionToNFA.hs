module RegularExpressionToNFA (
    NFA (..),
    InputCharacter (..),
    Transition (..),
    REOrNFA (..),
    mapKleenClosure,
    mapOrs,
    reToNFA,
    mapSubNFA,
    parenSubStringRange,
    baseNfa,
    orNfa,
    kleanClosureNfa
  ) where

import Data.List
import Data.List.Index
import Data.Char
import Debug.Trace
import System.IO.Unsafe

type State = String
instance Show InputCharacter where
  show EmptyChar = " EmptyChar "
  show (Character ch) = " " ++ [ch] ++ " " 

instance Show Transition where
  show (Transition frmState input toState) = "Transition " ++ frmState ++ " " ++ (show input)  ++ " " ++ toState

instance Show NFA where
  show (NFA states startState terminalStates transitions) = "NFA " ++ (show states) ++ " " ++ startState ++ " " ++ (show terminalStates) ++ " " ++ (show transitions)

instance Show REOrNFA where
  show (FA nfa) = show nfa
  show (NotFA inCharacter) = show inCharacter

data InputCharacter = EmptyChar | Character Char deriving (Eq)
data Transition = Transition {fromState :: State, input :: InputCharacter, toState :: State} deriving (Eq)
data NFA = NFA {states :: [State], startState :: State, terminalStates :: [State], transitions :: [Transition]} deriving (Eq)
data REOrNFA = FA NFA | NotFA InputCharacter deriving (Eq)

homoMorphism :: NFA -> (State -> State) -> NFA
homoMorphism (NFA states startState terminalStates transitions) f = NFA (Data.List.map f states) (f startState) (Data.List.map f terminalStates) (Data.List.map (\transition -> (Transition (f (fromState transition)) (input transition) (f (toState transition)))) transitions)

getLastState :: [State] -> State
getLastState collectionOfStates = foldr (\currentMax nextNfa -> show (max (read (currentMax)::Int) (read (nextNfa)::Int))) (last collectionOfStates) collectionOfStates

absoluteLinearScale :: Int -> Int -> Int
absoluteLinearScale input additional
  | input >= 0 = input + additional + 1
  | input < 0 = input - additional - 1

baseNfa :: InputCharacter -> NFA
baseNfa input = NFA ["0" ,"1"] "0" ["1"] [Transition "0" input "1"]
andNfa :: NFA -> NFA -> NFA
andNfa leftNfa rightNfa =
  let lastNodeName = getLastState (states leftNfa)
      mapNewNfa = (\nodeName -> (show (absoluteLinearScale (read nodeName::Int) (read lastNodeName::Int))))
      newRightNfa = homoMorphism rightNfa mapNewNfa
      newConnectingTransitions =  Data.List.map (\terminalState -> Transition terminalState EmptyChar (startState newRightNfa)) (terminalStates leftNfa)
      leftTransitions = transitions leftNfa
      rightTransitions = transitions newRightNfa
      allTransitions = newConnectingTransitions ++ leftTransitions ++ rightTransitions
      in NFA (states leftNfa ++ states newRightNfa) (startState leftNfa) (terminalStates newRightNfa) allTransitions
         
orNfa :: NFA -> NFA -> NFA
orNfa leftNfa rightNfa =
  let mapNewNfa = (\nodeName -> (show (absoluteLinearScale  (read nodeName::Int) (read (getLastState (states leftNfa))::Int))))
      newRightNfa = homoMorphism rightNfa mapNewNfa
      newStartingState = show ((read (head (states leftNfa))::Int) - 1)
      newTerminalState = show ((read (last (states newRightNfa))::Int) + 1)
      allStates = newStartingState : (states leftNfa) ++ (states newRightNfa) ++ [newTerminalState]
      newFinalTransitions = (Data.List.map (\terminalState -> (Transition terminalState EmptyChar newTerminalState))) ((terminalStates leftNfa) ++ (terminalStates newRightNfa))
      newTransitions = [(Transition newStartingState EmptyChar (startState leftNfa)), (Transition newStartingState EmptyChar (startState newRightNfa))] ++ newFinalTransitions
      allTransitions = (transitions leftNfa) ++ (transitions newRightNfa) ++ newTransitions
      in NFA allStates newStartingState [newTerminalState] allTransitions 
      
kleanClosureNfa :: NFA -> NFA
kleanClosureNfa nfa =
  let newStartingState = show ((read (head (states nfa))::Int) - 1)
      newTerminalState = show ((read (last (states nfa))::Int) + 1)
      allStates = newStartingState : (states nfa) ++ [newTerminalState]
      newLoopTransitions = (Data.List.map (\terminalState -> (Transition terminalState EmptyChar (startState nfa))) (terminalStates nfa))
      newTransitionsToNewTerminal = (Data.List.map (\terminalState -> (Transition terminalState EmptyChar newTerminalState)) (terminalStates nfa))
      allTransitions = [(Transition newStartingState EmptyChar newTerminalState)] ++ newTransitionsToNewTerminal ++ newLoopTransitions ++ (transitions nfa) ++ [(Transition newStartingState EmptyChar (startState nfa))]
      in (NFA allStates newStartingState [newTerminalState] allTransitions)

parenSubStringRange :: [InputCharacter] -> [InputCharacter] -> Int -> [InputCharacter]
parenSubStringRange (Character ')' : input) stack 1 = stack ++ [Character ')']
parenSubStringRange (Character '(' : input) stack depth = parenSubStringRange input (stack ++ [Character '(' ]) (depth + 1)
parenSubStringRange (Character ')' : input) stack depth = parenSubStringRange input (stack ++ [Character ')']) (depth - 1)
parenSubStringRange input stack depth = parenSubStringRange (tail input) (stack ++ [(head input)]) depth

mapSubNFA :: [InputCharacter] -> [REOrNFA] -> [REOrNFA]
mapSubNFA [] mapped = mapped
mapSubNFA (Character '(' : input) mapped =
  let test = (Character '(') : input
      subStringParen = parenSubStringRange (Character '(' : input) [] 0
      subRe = (tail (take ((length subStringParen) - 1) subStringParen))
      nfa = reToNFA subRe
      newMappedStack = mapped ++ [FA nfa]
      lengthToSkip = (length subStringParen)
      in mapSubNFA (drop lengthToSkip (Character '(' : input)) newMappedStack
mapSubNFA input mapped = mapSubNFA (tail input) (mapped ++ [(NotFA (head input))])

mapKleenClosure :: [REOrNFA] -> [REOrNFA]
mapKleenClosure input =
  let indices = (map (\index -> index - 1) (elemIndices (NotFA (Character '*')) input))
      mappedArray = mapAtIndices indices input
      in filter (\va -> va /= (NotFA (Character '*')) )  mappedArray
      
mapAtIndices :: [Int] -> [REOrNFA] -> [REOrNFA]
mapAtIndices [] stack = stack
mapAtIndices (index : indices) stack =
  let value = stack!!index
      baseNFA = (case value of
                    (FA fa) -> fa
                    (NotFA notFa) -> baseNfa notFa
                )
      in mapAtIndices indices (setAt index (FA (kleanClosureNfa baseNFA)) stack)

mapOrs :: [REOrNFA] -> [REOrNFA] -> [REOrNFA]
mapOrs input stack
  | length input <= 2 = stack ++ (reverse input)
  | (head (tail input)) == (NotFA (Character '|')) =
      let leftNfa = case (head input) of
                      (FA fa) -> fa
                      (NotFA notFA) -> baseNfa notFA
          rightNfa = case (head (tail (tail input))) of
                       (FA fa) -> fa
                       (NotFA notFA) -> baseNfa notFA
          in mapOrs (drop 3 input) (FA (orNfa leftNfa rightNfa) : stack) 
  | otherwise = mapOrs (tail input) ((head input) : stack)

mapBaseCharacters :: [REOrNFA] -> [NFA]
mapBaseCharacters inputNfas = map (\nfaOrChar -> case nfaOrChar of
                                  (FA fa) -> fa
                                  (NotFA notFa) -> baseNfa notFa
                              ) inputNfas
  
reToNFA :: [InputCharacter] -> NFA
reToNFA input = 
  let mappedParen = mapSubNFA input []
      mappedKlean = mapKleenClosure mappedParen
      mappedOrs = mapOrs mappedKlean []
      mappedBase = mapBaseCharacters mappedOrs
      in foldr (\nfa nextNfa -> andNfa nfa nextNfa) (head mappedBase) (tail mappedBase)