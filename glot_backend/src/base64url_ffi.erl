-module(base64url_ffi).

-export([encode/1, decode/1]).

encode(Value) ->
    base64:encode(Value, #{mode => urlsafe, padding => false}).

decode(Value) ->
    try
        {ok, base64:decode(Value, #{mode => urlsafe, padding => false})}
    catch
        error:Reason:Stacktrace ->
            {error, format_error(error, Reason, Stacktrace)}
    end.

format_error(Class, Reason, Stacktrace) ->
    iolist_to_binary(
        io_lib:format("~tp: ~tp~n~tp", [Class, Reason, Stacktrace])
    ).
