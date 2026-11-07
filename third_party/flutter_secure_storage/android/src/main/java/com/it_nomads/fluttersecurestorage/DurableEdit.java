package com.it_nomads.fluttersecurestorage;

import android.content.SharedPreferences;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/**
 * Persists secure-storage edits with commit() so success is reported only after
 * the preferences file reached disk. apply() updates memory first and never
 * reports a disk failure.
 */
final class DurableEdit {
    private DurableEdit() {}

    /** Disk write failed; the in-process cache was restored to the previous values when possible. */
    static final class PersistenceException extends IOException {
        PersistenceException(String message) {
            super(message);
        }
    }

    static void putString(SharedPreferences prefs, String key, String value) throws PersistenceException {
        Map<String, String> before = snapshot(prefs, key);
        if (!prefs.edit().putString(key, value).commit()) rollback(prefs, before, false, "write");
    }

    static void remove(SharedPreferences prefs, String key) throws PersistenceException {
        Map<String, String> before = snapshot(prefs, key);
        if (!prefs.edit().remove(key).commit()) rollback(prefs, before, false, "delete");
    }

    static void clear(SharedPreferences prefs) throws PersistenceException {
        Map<String, String> before = snapshot(prefs, null);
        if (!prefs.edit().clear().commit()) rollback(prefs, before, true, "deleteAll");
    }

    /** Previous string values of [key], or of every entry when key is null; null if unreadable. */
    private static Map<String, String> snapshot(SharedPreferences prefs, String key) {
        try {
            Map<String, String> values = new HashMap<>();
            if (key != null) {
                values.put(key, prefs.contains(key) ? prefs.getString(key, null) : null);
            } else {
                for (Map.Entry<String, ?> entry : prefs.getAll().entrySet()) {
                    if (entry.getValue() instanceof String) values.put(entry.getKey(), (String) entry.getValue());
                }
            }
            return values;
        } catch (RuntimeException unreadable) {
            // Undecryptable old value: the edit still proceeds, but a failed commit cannot restore the cache.
            return null;
        }
    }

    /**
     * commit() == false may already have changed the process cache while disk kept
     * the old file. Put the old values back in memory; never delete anything here.
     */
    private static void rollback(SharedPreferences prefs, Map<String, String> before, boolean cleared,
            String operation) throws PersistenceException {
        if (before == null) {
            throw new PersistenceException("Secure storage " + operation
                    + " was not persisted; previous value unreadable, restart reloads disk state");
        }
        SharedPreferences.Editor editor = prefs.edit();
        for (Map.Entry<String, String> entry : before.entrySet()) {
            if (entry.getValue() == null) {
                if (!cleared) editor.remove(entry.getKey());
            } else {
                editor.putString(entry.getKey(), entry.getValue());
            }
        }
        // The cache is restored even when this commit also fails; disk still holds the old file.
        boolean restored = editor.commit();
        throw new PersistenceException("Secure storage " + operation + " was not persisted"
                + (restored ? "; previous value restored" : "; previous value kept in memory, disk unchanged"));
    }
}
