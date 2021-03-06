:- module(graph_load, [graph_load/6]).
:- use_module(core(util)).
:- use_module(core(query)).
:- use_module(core(transaction)).
:- use_module(core(account)).
:- use_module(core(triple/turtle_utils)).

graph_load(System_DB, Auth, Path, Commit_Info, Format, String) :-
    do_or_die(
        resolve_absolute_string_descriptor_and_graph(Path, Descriptor, Graph),
        error(invalid_graph_descriptor(Path), _)),

    askable_settings_context(
        Descriptor,
        _{  commit_info : Commit_Info,
            system: System_DB,
            authorization : Auth,
            write_graph : Graph
        }, Context),

    assert_write_access(Context),

    % We can extend formats here..
    (   Format = "turtle"
    ->  update_turtle_graph(Context,String)
    ;   throw(error(unknown_format(Format), _))).
