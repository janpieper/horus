%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright © 2021-2022 VMware, Inc. or its affiliates.  All rights reserved.
%%

%% Structure representing an anonymous function "extracted" as a compiled
%% module for storage.
-record(standalone_fun, {module :: module(),
                         beam :: binary(),
                         arity :: arity(),
                         literal_funs :: [khepri_fun:standalone_fun()],
                         env :: list()}).

-define(IS_STANDALONE_FUN(StandaloneFun),
        (is_record(StandaloneFun, standalone_fun) orelse
         is_function(StandaloneFun))).
