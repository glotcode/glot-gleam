-module(webauthn_ffi).

-export([
    new_registration_challenge/3,
    register/3,
    new_authentication_challenge/4,
    authenticate/6
]).

new_registration_challenge(Origin, RpId, UserVerification) ->
    try
        Challenge = 'Elixir.Wax':new_registration_challenge([
            {origin, Origin},
            {rp_id, RpId},
            {user_verification, UserVerification}
        ]),
        {ok, {base64url(maps:get(bytes, Challenge)), erlang:term_to_binary(Challenge)}}
    catch
        Class:Reason:Stacktrace ->
            {error, format_error(Class, Reason, Stacktrace)}
    end.

register(AttestationObject, ClientDataJson, ChallengeState) ->
    try
        Challenge = erlang:binary_to_term(ChallengeState),
        case 'Elixir.Wax':register(AttestationObject, ClientDataJson, Challenge) of
            {ok, {AuthenticatorData, _AttestationResult}} ->
                AttestedCredentialData = maps:get(attested_credential_data, AuthenticatorData),
                CoseKey = maps:get(credential_public_key, AttestedCredentialData),
                {ok,
                    {
                        maps:get(credential_id, AttestedCredentialData),
                        erlang:term_to_binary(CoseKey),
                        maps:get(sign_count, AuthenticatorData),
                        maps:get(aaguid, AttestedCredentialData)
                    }};
            {error, Error} ->
                {error, format_value(Error)}
        end
    catch
        Class:Reason:Stacktrace ->
            {error, format_error(Class, Reason, Stacktrace)}
    end.

new_authentication_challenge(Origin, RpId, UserVerification, Credentials) ->
    try
        AllowCredentials = [
            {CredentialId, erlang:binary_to_term(CoseKeyState)}
         || {CredentialId, CoseKeyState} <- Credentials
        ],
        Challenge = 'Elixir.Wax':new_authentication_challenge([
            {origin, Origin},
            {rp_id, RpId},
            {user_verification, UserVerification},
            {allow_credentials, AllowCredentials}
        ]),
        AllowCredentialIds = [
            base64url(CredentialId)
         || {CredentialId, _CoseKey} <- maps:get(allow_credentials, Challenge)
        ],
        {ok,
            {
                base64url(maps:get(bytes, Challenge)),
                AllowCredentialIds,
                erlang:term_to_binary(Challenge)
            }}
    catch
        Class:Reason:Stacktrace ->
            {error, format_error(Class, Reason, Stacktrace)}
    end.

authenticate(CredentialId, AuthenticatorData, Signature, ClientDataJson, ChallengeState, Credentials) ->
    try
        Challenge = erlang:binary_to_term(ChallengeState),
        StoredCredentials = [
            {StoredCredentialId, erlang:binary_to_term(CoseKeyState)}
         || {StoredCredentialId, CoseKeyState} <- Credentials
        ],
        case 'Elixir.Wax':authenticate(
            CredentialId,
            AuthenticatorData,
            Signature,
            ClientDataJson,
            Challenge,
            StoredCredentials
        ) of
            {ok, VerifiedAuthenticatorData} ->
                Aaguid = case maps:get(attested_credential_data, VerifiedAuthenticatorData, nil) of
                    nil -> <<>>;
                    AttestedCredentialData -> maps:get(aaguid, AttestedCredentialData, <<>>)
                end,
                {ok, {maps:get(sign_count, VerifiedAuthenticatorData), Aaguid}};
            {error, Error} ->
                {error, format_value(Error)}
        end
    catch
        Class:Reason:Stacktrace ->
            {error, format_error(Class, Reason, Stacktrace)}
    end.

base64url(Binary) ->
    base64:encode(Binary, #{mode => urlsafe, padding => false}).

format_error(Class, Reason, Stacktrace) ->
    iolist_to_binary(
        io_lib:format("~tp: ~tp~n~tp", [Class, Reason, Stacktrace])
    ).

format_value(Value) ->
    iolist_to_binary(io_lib:format("~tp", [Value])).
