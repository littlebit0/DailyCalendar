package com.it_nomads.fluttersecurestorage.ciphers;

/**
 * Daily (#968): a wrapped AES key is stored but the Android Keystore key that
 * wrapped it is gone (for example after a backup restore to another device).
 * The stored values can never be decrypted again; a new Keystore key is not
 * created in their place.
 */
public class KeyStoreKeyMissingException extends Exception {
    public KeyStoreKeyMissingException(String message) {
        super(message);
    }

    /** True when [error] or one of its causes is a missing Keystore key. */
    public static boolean isCause(Throwable error) {
        for (Throwable cause = error; cause != null; cause = cause.getCause()) {
            if (cause instanceof KeyStoreKeyMissingException) return true;
            if (cause.getCause() == cause) break;
        }
        return false;
    }
}
