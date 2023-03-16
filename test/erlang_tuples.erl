%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright © 2021-2023 VMware, Inc. or its affiliates.  All rights reserved.
%%

-module(erlang_tuples).

-include_lib("eunit/include/eunit.hrl").

-include("test/helpers.hrl").

select_tuple_arity_var_info_test() ->
    Nodes = [node() | nodes()],
    StandaloneFun = ?make_standalone_fun(
                       begin
                           Tuple = make_tuple(Nodes),
                           handle_tuple(Tuple)
                       end),
    ?assertStandaloneFun(StandaloneFun),
    ?assertEqual(true, horus:exec(StandaloneFun, [])).

make_tuple([A]) ->
    {a, A};
make_tuple([A, B]) ->
    {b, A, B};
make_tuple([_, B, C]) ->
    {c, B, C}.

handle_tuple(Tuple) when is_tuple(Tuple) ->
    case Tuple of
        {a, _}    -> true;
        {b, _, _} -> false;
        {c, _, _} -> false
    end.
