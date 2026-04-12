-module(signal_handler_ffi).
-behaviour(gen_event).

-export([install/1]).
-export([init/1, handle_event/2, handle_call/2, handle_info/2, terminate/2]).
-export([code_change/3]).

install(SignalName) ->
    ok = os:set_signal(sigterm, handle),
    _ = gen_event:delete_handler(erl_signal_server, erl_signal_handler, []),
    ok = gen_event:add_handler(
        erl_signal_server,
        ?MODULE,
        [SignalName]
    ),
    nil.

init([SignalName]) ->
    {ok, SignalName}.

handle_event(sigusr1, State) ->
    erlang:halt("Received SIGUSR1"),
    {ok, State};
handle_event(sigquit, State) ->
    erlang:halt(),
    {ok, State};
handle_event(sigterm, SignalName) ->
    erlang:send(SignalName, {SignalName, sigterm_received}),
    {ok, SignalName};
handle_event(_Signal, SignalName) ->
    {ok, SignalName}.

handle_call(_Request, SignalName) ->
    {ok, ok, SignalName}.

handle_info(_Info, SignalName) ->
    {ok, SignalName}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, SignalName, _Extra) ->
    {ok, SignalName}.
