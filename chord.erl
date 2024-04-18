%%% Chord Protocol
%%% Authors: 
%%% Vaibhavi Deshpande
%%% Ishan Kunkolikar
%%% October 2022
-module ( chord ).
-export( [ start_main_process/2 ] ).

start_main_process( NumNodes, NumRequests ) ->
    M=20,
    RingSize = round(math:pow(2,M)),
    NodesList = create_nodes(NumNodes,RingSize),
    NodeIDs = create_node_ids(RingSize,NumNodes,[{-1}]),
    SortedNodeIDs = lists:sort(NodeIDs),
    NodesMap = maps:from_list(create_nodesmap(NumNodes,NodesList,SortedNodeIDs)),
    io:format("~p~n",[NodesMap]),
    create_ring(1,NodesMap,SortedNodeIDs,NumNodes,M),
    register(trackHopCount, spawn(fun() -> track_hop_count(0,0,NumNodes,NumRequests) end)),
    start_lookup_requests(NumNodes,NodesMap,SortedNodeIDs,NumRequests, 1).

% Average hop count
track_hop_count(NumberOfHops,HopSum,NumNodes,NumRequests) ->
    receive 
        {receivedHopCount,HopCount,NodeID,LookupNode} ->
            TotalHopSum = HopSum + HopCount,
            NumReq = NumNodes*NumRequests,
            AverageHopCount = TotalHopSum/NumReq,
            io:format("Number of Nodes : ~p~n",[NumNodes]),
            io:format("Average Hop Count : ~p~n",[AverageHopCount]),
            track_hop_count(NumberOfHops + 1 , HopSum + HopCount,NumNodes,NumRequests)
    end,
    track_hop_count(NumberOfHops , HopSum, NumNodes,NumRequests).

create_node_ids(_,0,_) -> [];
create_node_ids(RingSize,NumNodes,NodesIDList) when NumNodes > 0 ->
    NodeID = rand:uniform(RingSize),
    HasVal =lists:member(NodeID,NodesIDList),
    if
        HasVal ->
            create_node_ids(RingSize,NumNodes,NodesIDList);
        true->
            create_node_ids(RingSize,NumNodes-1,NodesIDList ++ [NodeID]) ++ [NodeID]
    end.
    

create_nodes(0,_) -> [];
create_nodes(NumNodes,RingSize) when NumNodes > 0 ->
    ProcessID = spawn(fun() -> create_node(NumNodes,RingSize,{},-1,-1,{},{}) end),
    create_nodes(NumNodes-1,RingSize) ++ [ProcessID].

create_node(NumNodes,RingSize,FingerTable,Predecessor,Successor,NodesMap,SortedNodeIDs)->
    receive
        {update,FingerTableNew, PredecessorNew, SuccessorNew, NewNodedMap}-> 
            create_node(NumNodes,RingSize,FingerTableNew,PredecessorNew,SuccessorNew,NewNodedMap,SortedNodeIDs);

        {requests,NumRequests,CurrentNodeID} -> 
            generate_requests(NumNodes,RingSize,FingerTable,Predecessor,Successor,NodesMap,SortedNodeIDs,NumRequests,NumRequests, CurrentNodeID),
            create_node(NumNodes,RingSize,FingerTable,Predecessor,Successor,NodesMap,SortedNodeIDs);

        {lookup, NodeToLookup, HopCount, CurrentNodeID} ->
            lookup(NodeToLookup,RingSize,FingerTable,HopCount,Predecessor,Successor,CurrentNodeID,NodesMap),
            create_node(NumNodes,RingSize,FingerTable,Predecessor,Successor,NodesMap,SortedNodeIDs)

    end.

create_nodesmap(0,_,_) -> [];
create_nodesmap(NumNodes,NodesList,SortedNodeIDs)->
    NodeID = lists:nth(NumNodes,SortedNodeIDs),
    NodePID = lists:nth(NumNodes, NodesList),
    create_nodesmap(NumNodes-1,NodesList,SortedNodeIDs) ++ [{NodeID,NodePID}].


create_ring(NumNodes,NodesMap,SortedNodeIDs,TotalNodes,M) when NumNodes == TotalNodes+1 -> [];
create_ring(NumNodes,NodesMap,SortedNodeIDs,TotalNodes,M) when NumNodes < TotalNodes+1 ->

    NodeID = lists:nth(NumNodes,SortedNodeIDs),
    NodePID = maps:get(NodeID,NodesMap),
    FingerTable = fix_finger_table(M,NodeID,NodePID,SortedNodeIDs,1,TotalNodes),
    FingerTableMap = maps:from_list(FingerTable),
    Successor = maps:get(1,FingerTableMap),
    NodePID ! {update, FingerTableMap, -1, Successor, NodesMap},
    create_ring(NumNodes+1,NodesMap,SortedNodeIDs,TotalNodes,M).

fix_finger_table(M,NodeID,NodePID,SortedNodeIDs,Counter,TotalNodes)  when Counter == M+1 -> [];
fix_finger_table(M,NodeID,NodePID,SortedNodeIDs,Counter,TotalNodes)  when Counter < M+1 ->
    FIndex = round(math:pow(2,Counter-1)),
    RingSize = round(math:pow(2,M)),
    CorrectedIndex = (NodeID+FIndex) rem RingSize,
    if
        CorrectedIndex == 0 ->
            CorrectedIndexNew = RingSize;
        true ->
            CorrectedIndexNew = CorrectedIndex
    end,        
    FVal = find_next_value(RingSize,SortedNodeIDs,CorrectedIndexNew,TotalNodes, 1),
    fix_finger_table(M,NodeID,NodePID,SortedNodeIDs,Counter+1,TotalNodes) ++ [{FIndex,FVal}].

find_next_value(_,_,_,_,-1) -> [];
find_next_value(RingSize,SortedNodeIDs, Index,TotalNodes,Counter) ->
    if
        Counter > TotalNodes  ->
            lists:nth(1,SortedNodeIDs);
        true ->
            Curr = lists:nth(Counter,SortedNodeIDs),
            if Index - 1 < Curr ->
                Curr;
            true->
                find_next_value(RingSize,SortedNodeIDs, Index,TotalNodes,Counter+1 )
            end      
    end.

start_lookup_requests (NumNodes,NodesMap,SortedNodeIDs,NumRequests,Counter) when Counter == NumNodes+1 -> [];
start_lookup_requests (NumNodes,NodesMap,SortedNodeIDs,NumRequests,Counter) when Counter<NumNodes+1->
    NodeID = lists:nth(Counter,SortedNodeIDs),
    NodePID = maps:get(NodeID,NodesMap),
    NodePID ! {requests, NumRequests, NodeID},
    timer:sleep(100),    
    start_lookup_requests (NumNodes,NodesMap,SortedNodeIDs,NumRequests, Counter+1). 

generate_requests(NumNodes,RingSize,FingerTable,Predecessor,Successor,NodesMap,SortedNodeIDs,NumRequests,Counter,CurrentNodeID) when Counter == 0 -> [];
generate_requests(NumNodes,RingSize,FingerTable,Predecessor,Successor,NodesMap,SortedNodeIDs,NumRequests,Counter,CurrentNodeID) when Counter > 0->
    NodeToLookup = rand:uniform(RingSize),
    if
        NodeToLookup == CurrentNodeID ->
            trackHopCount ! {receivedHopCount,0,Successor,NodeToLookup};  
        true->
            NodePID = maps:get(CurrentNodeID,NodesMap),
            NodePID ! {lookup, NodeToLookup, 0, CurrentNodeID},
            generate_requests(NumNodes,RingSize,FingerTable,Predecessor,Successor,NodesMap,SortedNodeIDs,NumRequests,Counter-1,CurrentNodeID)
        end.

lookup(NodeToLookup,RingSize,FingerTable,HopCount,Predecessor,Successor,CurrentNodeID,NodesMap) ->
    if 
       (Successor < CurrentNodeID) and ( ((NodeToLookup +1 > CurrentNodeID ) and (NodeToLookup < RingSize)) or ((NodeToLookup > 0) and (NodeToLookup < Successor+1) ))->
            trackHopCount ! {receivedHopCount,HopCount+1,Successor,NodeToLookup};   
        true ->
            if 
                (NodeToLookup+1 > CurrentNodeID) and (NodeToLookup < Successor+1)->
                    trackHopCount ! {receivedHopCount,HopCount+1,Successor,NodeToLookup};   
            true ->
                Counter = round(RingSize/2),
                SuccessorToHop = find_node_successor(NodeToLookup,RingSize,Counter,FingerTable,CurrentNodeID),
                if SuccessorToHop == [] ->
                    io:format(" EMPTY WARNING ");
                true ->    
                SuccessorToHopPID = maps:get(SuccessorToHop,NodesMap),
                SuccessorToHopPID ! {lookup, NodeToLookup, HopCount+1, SuccessorToHop} 
                end
            end            
    end.
    
find_node_successor(NodeToLookup,RingSize,Counter,FingerTable,CurrentNodeID) when Counter == 0 -> [];
find_node_successor(NodeToLookup,RingSize,Counter,FingerTable,CurrentNodeID) when Counter > 0 ->
    FingerTableVal = maps:get(Counter,FingerTable),      
    if
        CurrentNodeID < NodeToLookup ->
        if
            (FingerTableVal < NodeToLookup+1) and (FingerTableVal+1 > CurrentNodeID) ->
                FingerTableVal; 
            true ->
                NewCount = floor(Counter/2),
                find_node_successor(NodeToLookup,RingSize,NewCount,FingerTable,CurrentNodeID)
            end;
        true ->
            if
                 ( ((FingerTableVal +1 > CurrentNodeID ) and (FingerTableVal < RingSize + 1)) or ((FingerTableVal > 0) and (FingerTableVal < NodeToLookup+1) ))->
                % jump to finger table val node
                FingerTableVal;        
            true ->
                find_node_successor(NodeToLookup,RingSize,floor(Counter/2),FingerTable,CurrentNodeID)
            end
        end.




    
