%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright © 2023 VMware, Inc. or its affiliates.  All rights reserved.
%%

-module(cover_compile).

-include_lib("eunit/include/eunit.hrl").

-include("src/horus_fun.hrl").

cover_compilation_works_test() ->
    Module = cover_compiled_mod1,
    Arg = arg,
    Ret = Module:run(Arg),

    Fun = fun Module:run/1,
    {_, _, ModFile} = code:get_object_code(Module),
    ?assertEqual(false, cover:is_compiled(Module)),
    InitialState = [{{Module, run, 1},
                     {0, %% Covered
                      2  %% Not covered
                     }}],
    Analysis = [{{Module, run, 1},
                 {2, %% Covered
                  0  %% Not covered
                 }}],

    %% We extract the regular module before we cover-compile it. We do this to
    %% compare the standalone functions to make sure that their module names
    %% are different because the code and the checksum are different.
    StandaloneFun1 = horus:to_standalone_fun(Fun, #{debug_info => true}),
    ?assertEqual(Ret, horus:exec(StandaloneFun1, [Arg])),

    %% We ensure that cover-compilation works and that we get the expected
    %% analysis results.
    ?assertEqual({ok, Module}, cover:compile_beam(ModFile)),
    ?assertEqual({file, ModFile}, cover:is_compiled(Module)),
    ?assertEqual({ok, InitialState}, cover:analyse(Module)),

    ?assertEqual(Ret, Module:run(Arg)),
    ?assertEqual({ok, Analysis}, cover:analyse(Module)),

    ok = cover:reset(Module),

    %% Now, we try to extract the cover-compiled module. We then execute the
    %% standalone function and verify the analysis again.
    ?assertEqual({file, ModFile}, cover:is_compiled(Module)),
    ?assertEqual({ok, InitialState}, cover:analyse(Module)),

    StandaloneFun2 = horus:to_standalone_fun(Fun, #{debug_info => true}),
    ?assertEqual(Ret, horus:exec(StandaloneFun2, [Arg])),
    ?assertEqual({ok, Analysis}, cover:analyse(Module)),

    ok = cover:reset(Module),

    %% We finally compare the standalone functions: they must have a different
    %% module name and checksum.
    GeneratedName1 = StandaloneFun1#horus_fun.module,
    GeneratedName2 = StandaloneFun2#horus_fun.module,
    ?assertNotEqual(GeneratedName1, GeneratedName2),

    Info1 = maps:get(fun_info, StandaloneFun1#horus_fun.debug_info),
    Info2 = maps:get(fun_info, StandaloneFun2#horus_fun.debug_info),
    ?assertEqual(Info1, Info2),

    Checksums1 = maps:get(checksums, StandaloneFun1#horus_fun.debug_info),
    Checksums2 = maps:get(checksums, StandaloneFun2#horus_fun.debug_info),
    ?assertNotEqual(
       maps:get(Module, Checksums1),
       maps:get(Module, Checksums2)),

    ok.

cover_on_remote_node_works_test() ->
    ok = helpers:start_epmd(),
    {ok, _} = net_kernel:start(?FUNCTION_NAME, #{name_domain => shortnames}),
    _ = cover:start(),
    [Node] = helpers:start_n_nodes(?FUNCTION_NAME, 1),
    ?assert(is_atom(Node)),

    Module = cover_compiled_mod2,
    Arg = arg,
    Ret = Module:run(Arg),
    ?assertEqual(Ret, erpc:call(Node, Module, run, [Arg])),

    Fun = fun Module:run/1,
    {_, _, ModFile} = code:get_object_code(Module),
    ?assertEqual(false, cover:is_compiled(Module)),
    InitialState = [{{Module, run, 1},
                     {0, %% Covered
                      2  %% Not covered
                     }}],
    Analysis = [{{Module, run, 1},
                 {2, %% Covered
                  0  %% Not covered
                 }}],

    %% We extract the regular module before we cover-compile it. We do this to
    %% compare the standalone functions to make sure that their module names
    %% are different because the code and the checksum are different.
    StandaloneFun1 = erpc:call(
                       Node,
                       horus, to_standalone_fun, [Fun, #{debug_info => true}]),
    ?assertEqual(Ret, erpc:call(Node, horus, exec, [StandaloneFun1, [Arg]])),

    %% We ensure that cover-compilation works and that we get the expected
    %% analysis results.
    %%
    %% The cover-compiled module is not available from `cover''s own state on
    %% the remote node, because it was loaded into the code server only.
    ?assertEqual({ok, Module}, cover:compile_beam(ModFile)),
    ?assertEqual(
       {error, not_main_node},
       erpc:call(Node, cover, is_compiled, [Module])),
    ?assertEqual({ok, InitialState}, cover:analyse(Module)),

    ?assertEqual(Ret, Module:run(Arg)),
    ?assertEqual({ok, Analysis}, cover:analyse(Module)),

    ok = cover:reset(Module),

    %% Now, we try to extract the cover-compiled module. We then execute the
    %% standalone function and verify the analysis again.
    ?assertEqual(
       {error, not_main_node},
       erpc:call(Node, cover, is_compiled, [Module])),
    ?assertEqual({ok, InitialState}, cover:analyse(Module)),

    StandaloneFun2 = erpc:call(
                       Node,
                       horus, to_standalone_fun, [Fun, #{debug_info => true}]),
    ?assertEqual(Ret, erpc:call(Node, horus, exec, [StandaloneFun2, [Arg]])),
    ?assertEqual({ok, Analysis}, cover:analyse(Module)),

    ok = cover:reset(Module),

    %% We finally compare the standalone functions: they must have a different
    %% module name and checksum.
    GeneratedName1 = StandaloneFun1#horus_fun.module,
    GeneratedName2 = StandaloneFun2#horus_fun.module,
    ?assertNotEqual(GeneratedName1, GeneratedName2),

    Info1 = maps:get(fun_info, StandaloneFun1#horus_fun.debug_info),
    Info2 = maps:get(fun_info, StandaloneFun2#horus_fun.debug_info),
    ?assertEqual(Info1, Info2),

    Checksums1 = maps:get(checksums, StandaloneFun1#horus_fun.debug_info),
    Checksums2 = maps:get(checksums, StandaloneFun2#horus_fun.debug_info),
    ?assertNotEqual(
       maps:get(Module, Checksums1),
       maps:get(Module, Checksums2)),

    _ = net_kernel:stop(),
    ok.
