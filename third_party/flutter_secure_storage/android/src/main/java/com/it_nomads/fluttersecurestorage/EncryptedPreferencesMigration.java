package com.it_nomads.fluttersecurestorage;

import android.content.SharedPreferences;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Consumer;

/**
 * Daily (#937): moves EncryptedSharedPreferences (ESP) values to the custom
 * cipher store without losing the originals. Every value is written in one
 * commit first; ESP entries are removed only after that commit succeeded.
 */
final class EncryptedPreferencesMigration {
    static final String ALGORITHM_KEY_MARKER = "__daily_algorithm_key";
    static final String ALGORITHM_STORAGE_MARKER = "__daily_algorithm_storage";

    private EncryptedPreferencesMigration() {}

    /** String values whose key contains [prefix], as the plugin stores them. */
    static Map<String, String> prefixedStrings(Map<String, ?> all, String prefix) {
        Map<String, String> values = new HashMap<>();
        for (Map.Entry<String, ?> entry : all.entrySet()) {
            if (entry.getValue() instanceof String value && entry.getKey().contains(prefix)) {
                values.put(entry.getKey(), value);
            }
        }
        return values;
    }

    static void copy(Map<String, String> espValues, SharedPreferences esp, SharedPreferences target,
                     StorageCipher cipher, Consumer<SharedPreferences.Editor> markers) throws Exception {
        // Throws before any write on an encryption failure, and restores the
        // previous values when the single commit fails. ESP is untouched.
        PreservingCipherMigration.publish(espValues, target, cipher, markers);
        // The values are durable in the custom store. A failed cleanup only
        // leaves unread ESP entries behind: the migrated flag skips them.
        SharedPreferences.Editor cleanup = esp.edit();
        for (String key : espValues.keySet()) cleanup.remove(key);
        cleanup.commit();
    }

    static boolean hasAlgorithmMarkers(SharedPreferences data) {
        return data.contains(ALGORITHM_KEY_MARKER) || data.contains(ALGORITHM_STORAGE_MARKER);
    }

    static boolean removeAlgorithmMarkers(SharedPreferences data) {
        return data.edit().remove(ALGORITHM_KEY_MARKER).remove(ALGORITHM_STORAGE_MARKER).commit();
    }
}
