module Scanner.DFAMinimization (Minimization(..)) where

import Scanner.StateMachine
import Data.Map
import Data.List
import Data.Set
import Scanner.Minimization
import Scanner.TokenType
import Data.Tuple
import Scanner.DFA

type DFAPartition = [State]
type AlphaCharacter = Char
type AlphaBet = [AlphaCharacter]
type T = [DFAPartition]

getPartitionFromState :: DFA -> State -> AlphaCharacter -> T -> Maybe DFAPartition 
getPartitionFromState dfa state character partitions =
  let maybeTransition = (Data.List.uncons (Data.List.filter (\(Transition fromState input toState) -> input == character && fromState == state) (Scanner.DFA.transitions dfa)))
  in case maybeTransition of
          Just (trans, _) -> Just (head (Data.List.filter (\partition -> elem (fromState trans) partition) partitions))
          Nothing -> Nothing
      
    
splitThePartition :: T -> DFA -> DFAPartition -> AlphaCharacter -> T
splitThePartition partitions dfa partionToSplit alphaCharacter =
  let stateAndCorrespondingPartition = (Data.List.map (\stateInPartition -> (stateInPartition, getPartitionFromState dfa stateInPartition alphaCharacter partitions)) partionToSplit)
      splitPartitionMap = Data.List.foldr (\(state, partition) partMap -> (Data.Map.insert partition ([state] ++ (maybe [] (\a -> a) (Data.Map.lookup partition partMap))) partMap)) (Data.Map.empty) stateAndCorrespondingPartition
  in  Data.List.map (\(partition, newPartitions) -> (newPartitions)) (Data.Map.toList splitPartitionMap)
      
split :: DFA -> AlphaBet -> T -> DFAPartition -> T
split dfa alphaBet partitionsInDFA partition = let isSplit = Data.List.foldr (\alphaCharacter (completed, splited) ->
                                                                              case completed of
                                                                                True -> (True ,splited)
                                                                                False ->
                                                                                  let splittedVal = splitThePartition partitionsInDFA dfa partition alphaCharacter
                                                                                  in  case length splittedVal of
                                                                                    1 -> (False, [])
                                                                                    _ -> (True, splittedVal)
                                                                           ) (False, []) alphaBet
                                               in case isSplit of
                                                    (True, splited) -> splited
                                                    (False, _) -> [partition]


splitUntilEqual :: T -> DFA -> AlphaBet -> T -> T
splitUntilEqual ps dfa alpha ts  =
  case ((Data.Set.fromList ts) == (Data.Set.fromList ps)) of
    True -> ps
    False ->
     splitUntilEqual (Data.List.foldr (\parti newT -> (Scanner.DFAMinimization.split dfa alpha ps parti) ++ newT) [] ps) dfa alpha ps

doesPartitionContainGivenStates :: DFAPartition -> [State] -> Bool
doesPartitionContainGivenStates partition states = Data.List.foldr (\stateInPartition result -> result || elem stateInPartition states) False partition

getARepresentativeStateForPartitions :: T -> [State]
getARepresentativeStateForPartitions partitions = Data.List.map head partitions

getTransitionsForState :: State -> DFA -> [Transition AlphaCharacter]
getTransitionsForState state dfa = Data.List.filter (\(Transition frmState chr tState) -> frmState == state) (transitions dfa)

getPartitionOfGivenState :: State -> T -> DFAPartition
getPartitionOfGivenState givenState allPartitions = head (Data.List.filter (\partition -> elem givenState partition) allPartitions)

mapOldStateToNewState :: State -> Map DFAPartition State -> T -> State
mapOldStateToNewState oldState partitionToNewState allPartitions = (maybe "-1" (\a -> a) (Data.Map.lookup (getPartitionOfGivenState oldState allPartitions) partitionToNewState))

convertTransitions :: [Transition AlphaCharacter] -> T -> Map DFAPartition State -> [Transition AlphaCharacter] 
convertTransitions oldTransitions allPartitions partToStateMap = Data.List.map (\(Transition frmState chr tState) -> (Transition (mapOldStateToNewState frmState partToStateMap allPartitions) chr (mapOldStateToNewState tState partToStateMap allPartitions))) oldTransitions

createListOfTransitionsFromPartitions :: T -> DFA -> Map DFAPartition State -> [Transition AlphaCharacter]
createListOfTransitionsFromPartitions partitions dfa partMap =
  let representatives = getARepresentativeStateForPartitions partitions
      transitionsPerParition = Data.List.map (\stateRep -> getTransitionsForState stateRep dfa) representatives
  in  transitionsPerParition >>= (\transitionsPerPart -> convertTransitions transitionsPerPart partitions partMap)



getDFATokenTypeMapFromDFATokenTypeMap :: Map State [State] -> Map State TokenType -> [State] -> Map State TokenType
getDFATokenTypeMapFromDFATokenTypeMap newDFAToDFAPartition nfaTokenTypeMap terminalStates = Data.Map.fromList (Data.List.map
                                                                                (\(dfaState, collectionOfNFAStates) ->
                                                                                    (case (Data.List.filter
                                                                                           (\(_, maybeTokenType) ->
                                                                                               case maybeTokenType of
                                                                                                 Just BadTokenType -> False
                                                                                                 Just _ -> True
                                                                                                 _ -> False
                                                                                           ) (Data.List.map (\dfaState -> (elem dfaState terminalStates ,Data.Map.lookup dfaState nfaTokenTypeMap)) collectionOfNFAStates)
                                                                                          )
                                                                                      of
                                                                                       [] -> (dfaState, BadTokenType)
                                                                                       categories -> (dfaState, Data.List.foldr (\(isTerminal, category) chosenSoFar -> case isTerminal of
                                                                                                               True -> maybe BadTokenType (\a -> a) category
                                                                                                               False -> chosenSoFar
                                                                                                               ) (maybe BadTokenType (\a -> a) (snd (head categories))) categories)
                                                                                    )) (Data.Map.toList newDFAToDFAPartition))

reverseAMap :: Ord b => Ord a => Map a b -> Map b a
reverseAMap givenMap = Data.Map.fromList (Data.List.map swap (Data.Map.toList givenMap))

createDFAFromPartitions :: T -> DFA -> DFA
createDFAFromPartitions partitions dfa =
  let (newStates, _, partitionToNewStateMap) = Data.List.foldr (\partition (statesNewlyCreated, count, partitionToNewStateMap) -> (statesNewlyCreated ++ [show count], count + 1, Data.Map.insert partition (show count) partitionToNewStateMap)) ([], 0, Data.Map.empty) partitions
      newStartState = maybe "-99" (\a -> a) (Data.Map.lookup (head (Data.List.filter (\partition -> doesPartitionContainGivenStates partition [startState dfa]) partitions)) partitionToNewStateMap)
      newTerminalStates = (Data.List.map (\terminalPartition -> (maybe [] (\a -> a) (Data.Map.lookup terminalPartition partitionToNewStateMap))) (Data.List.filter (\partition -> doesPartitionContainGivenStates partition (terminalStates dfa)) partitions))
      newTransitions = createListOfTransitionsFromPartitions partitions dfa partitionToNewStateMap
      newTokenTypeMap = getDFATokenTypeMapFromDFATokenTypeMap (reverseAMap partitionToNewStateMap) (categories dfa) (terminalStates dfa) 
   in (DFA newStates newStartState newTerminalStates newTransitions newTokenTypeMap)

minimizeDFA :: DFA -> DFA
minimizeDFA dfa =
  let ts = [terminalStates dfa ,reverse (Data.List.filter (\state -> not (elem state (terminalStates dfa))) (states dfa))]
      alpha = getAlphaBet dfa
      partitionsForNewDFA = splitUntilEqual ts dfa alpha []
  in  createDFAFromPartitions partitionsForNewDFA dfa

instance Minimization DFA where
  minimize dfa = minimizeDFA dfa
