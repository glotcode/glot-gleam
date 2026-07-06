-module(file_system_ffi).

-export([is_dir/1, is_file/1, list_dir/1, read_file/1, write_file/2]).

is_dir(Path) ->
    filelib:is_dir(Path).

is_file(Path) ->
    filelib:is_regular(Path).

list_dir(Path) ->
    case file:list_dir(Path) of
        {ok, Entries} ->
            {ok, [unicode:characters_to_binary(Entry) || Entry <- Entries]};
        {error, Reason} ->
            {error, unicode:characters_to_binary(file:format_error(Reason))}
    end.

read_file(Path) ->
    case file:read_file(Path) of
        {ok, Contents} ->
            {ok, unicode:characters_to_binary(Contents)};
        {error, Reason} ->
            {error, unicode:characters_to_binary(file:format_error(Reason))}
    end.

write_file(Path, Content) ->
    case filelib:ensure_dir(Path) of
        ok ->
            case file:write_file(Path, Content) of
                ok ->
                    {ok, nil};
                {error, Reason} ->
                    {error, unicode:characters_to_binary(file:format_error(Reason))}
            end;
        {error, Reason} ->
            {error, unicode:characters_to_binary(file:format_error(Reason))}
    end.
