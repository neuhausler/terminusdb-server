:- module(path,[
              compile_pattern/3,
              calculate_path_solutions/6
          ]).

:- use_module(core(util)).
:- use_module(core(triple)).
:- use_module(core(validation)).

hop(type_filter{ types : Types}, X, P, Y, Transaction_Object) :-
    memberchk(instance,Types),
    inference:inferredEdge(X,P,Y,Transaction_Object).
hop(type_name_filter{ type : instance , names : _Names}, X, P, Y, Transaction_Object) :-
    inference:inferredEdge(X,P,Y,Transaction_Object).
hop(type_filter{ types : Types}, X, P, Y, Transaction_Object) :-
    memberchk(schema,Types),
    xrdf(Transaction_Object.schema_objects, X, P, Y).
hop(type_name_filter{ type : schema , names : _Names}, X, P, Y, Transaction_Object) :-
    xrdf(Transaction_Object.schema_objects, X, P, Y).
hop(type_filter{ types : Types}, X, P, Y, Transaction_Object) :-
    memberchk(inference,Types),
    xrdf(Transaction_Object.inference_objects, X, P, Y).
hop(type_name_filter{ type : inference , names : _Names}, X, P, Y, Transaction_Object) :-
    xrdf(Transaction_Object.inference_objects, X, P, Y).

calculate_path_solutions(Pattern,XE,YE,Path,Filter,Transaction_Object) :-
    run_pattern(Pattern,XE,YE,Path,Filter,Transaction_Object).

/**
 * in_open_set(+Elt,+Set) is semidet.
 *
 * memberchk for partially bound objects
 */
in_open_set(_Elt,Set) :-
    var(Set),
    !,
    fail.
in_open_set(Elt,[Elt|_]) :-
    !.
in_open_set(Elt,[_|Set]) :-
    in_open_set(Elt,Set).

run_pattern(P,X,Y,Path,Filter,Transaction_Object) :-
    ground(Y),
    var(X),
    !,
    run_pattern_backward(P,X,Y,Rev,Rev-[],Filter,Transaction_Object),
    reverse(Rev,Path).
run_pattern(P,X,Y,Path,Filter,Transaction_Object) :-
    run_pattern_forward(P,X,Y,Path,Path-[],Filter,Transaction_Object).

run_pattern_forward(p(P),X,Y,Open_Set,_Path,_Filter,_Transaction_Object) :-
    in_open_set(edge(X,P,Y),Open_Set),
    !,
    fail.
run_pattern_forward(p(P),X,Y,_Open_Set,[edge(X,P,Y)|Tail]-Tail,Filter,Transaction_Object) :-
    hop(Filter,X,P,Y,Transaction_Object).
run_pattern_forward((P,Q),X,Y,Open_Set,Path-Tail,Filter,Transaction_Object) :-
    run_pattern_forward(P,X,Z,Open_Set,Path-Path_M,Filter,Transaction_Object),
    run_pattern_forward(Q,Z,Y,Open_Set,Path_M-Tail,Filter,Transaction_Object).
run_pattern_forward((P;Q),X,Y,Open_Set,Path-Tail,Filter,Transaction_Object) :-
    (   run_pattern_forward(P,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object)
    ;   run_pattern_forward(Q,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object)).
run_pattern_forward(plus(P),X,Y,Open_Set,Path-Tail,Filter,Transaction_Object) :-
    run_pattern_n_m_forward(P,1,-1,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object).
run_pattern_forward(times(P,N,M),X,Y,Open_Set,Path-Tail,Filter,Transaction_Object) :-
    run_pattern_n_m_forward(P,N,M,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object).

run_pattern_n_m_forward(P,1,_,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object) :-
    run_pattern_forward(P,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object).
run_pattern_n_m_forward(P,N,M,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object) :-
    \+ M = 1, % M=1 is finished! M<1 is infinite.
    Np is max(1,N-1),
    Mp is M-1,
    run_pattern_forward(P,X,Z,Open_Set,Path-Path_IM,Filter,Transaction_Object),
    run_pattern_n_m_forward(P,Np,Mp,Z,Y,Open_Set,Path_IM-Tail,Filter,Transaction_Object).

run_pattern_backward(p(P),X,Y,Open_Set,_Path,_Filter,_Transaction_Object) :-
    in_open_set(edge(X,P,Y),Open_Set),
    !,
    fail.
run_pattern_backward(p(P),X,Y,_Open_Set,[edge(X,P,Y)|Tail]-Tail,Filter,Transaction_Object) :-
    hop(Filter,X,P,Y,Transaction_Object).
run_pattern_backward((P,Q),X,Y,Open_Set,Path-Tail,Filter,Transaction_Object) :-
    run_pattern_backward(Q,ZE,Y,Open_Set,Path_M-Tail,Filter,Transaction_Object),
    run_pattern_backward(P,X,ZE,Open_Set,Path-Path_M,Filter,Transaction_Object).
run_pattern_backward((P;Q),X,Y,Open_Set,Path-Tail,Filter,Transaction_Object) :-
    (   run_pattern_backward(P,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object)
    ;   run_pattern_backward(Q,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object)).
run_pattern_backward(plus(P),X,Y,Open_Set,Path-Tail,Filter,Transaction_Object) :-
    run_pattern_n_m_backward(P,1,-1,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object).
run_pattern_backward(times(P,N,M),X,Y,Open_Set,Path-Tail,Filter,Transaction_Object) :-
    run_pattern_n_m_backward(P,N,M,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object).

run_pattern_n_m_backward(P,1,_,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object) :-
    run_pattern_backward(P,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object).
run_pattern_n_m_backward(P,N,M,X,Y,Open_Set,Path-Tail,Filter,Transaction_Object) :-
    \+ M = 1, % M=1 is finished! M<1 is infinite.
    Np is max(1,N-1),
    Mp is M-1,
    run_pattern_backward(P,Z,Y,Open_Set,Path-Path_IM,Filter,Transaction_Object),
    run_pattern_n_m_backward(P,Np,Mp,X,Z,Open_Set,Path_IM-Tail,Filter,Transaction_Object).

/*
 * patterns have the following syntax:
 *
 * P,Q,R := p(P) | P,Q | P;Q | plus(P) | times(P,N,M)
 *
 */
compile_pattern(p(Pred), Compiled, Transaction_Object) :-
    sol_set({Transaction_Object,Pred}/[p(Sub)]>>(
                subsumption_properties_of(Sub,Pred,Transaction_Object)
            ), Predicates),
    xfy_list(';',Compiled,Predicates).
compile_pattern((X,Y), (XC,YC), Transaction_Object) :-
    compile_pattern(X,XC,Transaction_Object),
    compile_pattern(Y,YC,Transaction_Object),
    % Only compose compatible edges
    left_edges(XC,Left_Edges),
    right_edges(YC,Right_Edges),
    assert_compatible_edges(Left_Edges, Right_Edges, Transaction_Object).
compile_pattern((X;Y), (XC;YC), Transaction_Object) :-
    compile_pattern(X,XC,Transaction_Object),
    compile_pattern(Y,YC,Transaction_Object).
compile_pattern(star(X), star(XC), Transaction_Object) :-
    compile_pattern(X,XC,Transaction_Object).
compile_pattern(plus(X), plus(XC), Transaction_Object) :-
    compile_pattern(X,XC,Transaction_Object).
compile_pattern(times(X,N,M), times(XC,N,M), Transaction_Object) :-
    compile_pattern(X,XC,Transaction_Object).

right_edges(p(P),[P]).
right_edges((X,_Y),Ps) :-
    right_edges(X,Ps).
right_edges((X;Y),Rs) :-
    right_edges(X,Ps),
    right_edges(Y,Qs),
    append(Ps,Qs,Rs).

left_edges(p(P),[P]).
left_edges((_X,Y),Ps) :-
    left_edges(Y,Ps).
left_edges((X;Y),Rs) :-
    left_edges(X,Ps),
    left_edges(Y,Qs),
    append(Ps,Qs,Rs).

assert_compatible_edges(Left_Edges,Right_Edges,Database) :-
    forall(
        (   member(Left,Left_Edges),
            member(Right,Right_Edges)
        ),
        (   range(Left,Range,Database),
            domain(Right,Domain,Database),
            (   subsumption_of(Range, Domain, Database)
            ->  true
            ;   format(atom(M),'Incompatible domain', []),
                throw(error(M))
            )
        )
    ).