function base64UrlToBytes(value) {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padding = '='.repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(normalized + padding);
  const bytes = new Uint8Array(binary.length);

  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }

  return bytes;
}

function bytesToBase64Url(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = '';

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function encodeError(kind, message) {
  return JSON.stringify({ kind, message });
}

function mapRegistrationError(error) {
  if (error?.name === 'NotAllowedError') {
    return encodeError('cancelled', 'Passkey setup was canceled.');
  }

  if (error?.name === 'InvalidStateError') {
    return encodeError('failed', 'This device already has a passkey for this account.');
  }

  const message =
    typeof error?.message === 'string' && error.message !== ''
      ? error.message
      : 'Passkey setup failed.';

  return encodeError('failed', message);
}

function mapAuthenticationError(error) {
  if (error?.name === 'NotAllowedError') {
    return encodeError('cancelled', 'Passkey login was canceled.');
  }

  const message =
    typeof error?.message === 'string' && error.message !== ''
      ? error.message
      : 'Passkey login failed.';

  return encodeError('failed', message);
}

export function supportsPasskeys() {
  return (
    typeof window !== 'undefined' &&
    typeof PublicKeyCredential !== 'undefined' &&
    typeof navigator?.credentials?.get === 'function' &&
    typeof navigator?.credentials?.create === 'function'
  );
}

export async function startRegistration(optionsJson, onSuccess, onError) {
  if (
    typeof window === 'undefined' ||
    typeof PublicKeyCredential === 'undefined' ||
    typeof navigator?.credentials?.create !== 'function'
  ) {
    onError(
      encodeError('unsupported', 'This browser does not support passkey setup.')
    );
    return;
  }

  try {
    const options = JSON.parse(optionsJson);
    const credential = await navigator.credentials.create({
      publicKey: {
        challenge: base64UrlToBytes(options.challenge),
        rp: {
          id: options.rpId,
          name: options.rpId,
        },
        user: {
          id: base64UrlToBytes(options.userId),
          name: options.userName,
          displayName: options.userDisplayName,
        },
        pubKeyCredParams: options.algorithmIds.map((alg) => ({
          type: 'public-key',
          alg,
        })),
        timeout: options.timeoutSeconds * 1000,
        userVerification: options.userVerification,
        attestation: options.attestation,
        authenticatorSelection: {
          residentKey: 'preferred',
          userVerification: options.userVerification,
        },
        excludeCredentials: options.excludeCredentialIds.map((id) => ({
          id: base64UrlToBytes(id),
          type: 'public-key',
        })),
      },
    });

    if (!credential || credential.type !== 'public-key') {
      onError(encodeError('failed', 'Passkey setup did not return a valid credential.'));
      return;
    }

    const response = credential.response;

    onSuccess(
      JSON.stringify({
        attestationObject: bytesToBase64Url(response.attestationObject),
        clientDataJson: new TextDecoder().decode(response.clientDataJSON),
      })
    );
  } catch (error) {
    onError(mapRegistrationError(error));
  }
}

export async function startAuthentication(optionsJson, onSuccess, onError) {
  if (
    typeof window === 'undefined' ||
    typeof PublicKeyCredential === 'undefined' ||
    typeof navigator?.credentials?.get !== 'function'
  ) {
    onError(
      encodeError('unsupported', 'This browser does not support passkey login.')
    );
    return;
  }

  try {
    const options = JSON.parse(optionsJson);
    const allowCredentials =
      Array.isArray(options.allowCredentialIds) && options.allowCredentialIds.length > 0
        ? options.allowCredentialIds.map((id) => ({
            id: base64UrlToBytes(id),
            type: 'public-key',
          }))
        : undefined;

    const credential = await navigator.credentials.get({
      publicKey: {
        challenge: base64UrlToBytes(options.challenge),
        rpId: options.rpId,
        timeout: options.timeoutSeconds * 1000,
        userVerification: options.userVerification,
        allowCredentials,
      },
    });

    if (!credential || credential.type !== 'public-key') {
      onError(encodeError('failed', 'Passkey login did not return a valid credential.'));
      return;
    }

    const response = credential.response;

    onSuccess(
      JSON.stringify({
        credentialId: bytesToBase64Url(credential.rawId),
        authenticatorData: bytesToBase64Url(response.authenticatorData),
        signature: bytesToBase64Url(response.signature),
        clientDataJson: new TextDecoder().decode(response.clientDataJSON),
      })
    );
  } catch (error) {
    onError(mapAuthenticationError(error));
  }
}
