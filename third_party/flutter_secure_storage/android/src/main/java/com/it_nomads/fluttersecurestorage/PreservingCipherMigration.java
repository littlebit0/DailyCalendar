package com.it_nomads.fluttersecurestorage;

import android.content.SharedPreferences;
import android.util.Base64;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Consumer;

/** Publish ciphertext and its algorithm identity in one atomic preferences file. */
public final class PreservingCipherMigration {
    private PreservingCipherMigration() {}

    public static void publish(Map<String, String> plaintext, SharedPreferences data,
            StorageCipher cipher, Consumer<SharedPreferences.Editor> markers) throws Exception {
        Map<String, String> encrypted = new HashMap<>();
        for (Map.Entry<String, String> entry : plaintext.entrySet()) {
            byte[] original = entry.getValue().getBytes(StandardCharsets.UTF_8);
            byte[] encoded = cipher.encrypt(original);
            if (!Arrays.equals(original, cipher.decrypt(encoded))) {
                throw new java.io.IOException("Migration ciphertext verification failed");
            }
            encrypted.put(entry.getKey(), Base64.encodeToString(encoded, Base64.DEFAULT));
        }
        Map<String, String> before = new HashMap<>();
        for (String key : encrypted.keySet()) before.put(key, data.getString(key, null));
        before.put("__daily_algorithm_key", data.getString("__daily_algorithm_key", null));
        before.put("__daily_algorithm_storage", data.getString("__daily_algorithm_storage", null));
        SharedPreferences.Editor editor = data.edit();
        for (Map.Entry<String, String> entry : encrypted.entrySet()) editor.putString(entry.getKey(), entry.getValue());
        markers.accept(editor);
        if (!editor.commit()) {
            // Restore the process cache as well as disk: commit(false) can have
            // updated memory. No old key is deleted, even if rollback also fails.
            SharedPreferences.Editor rollback = data.edit();
            for (Map.Entry<String, String> entry : before.entrySet()) {
                if (entry.getValue() == null) rollback.remove(entry.getKey());
                else rollback.putString(entry.getKey(), entry.getValue());
            }
            boolean restored = rollback.commit();
            throw new java.io.IOException(restored ? "Migration commit failed; original restored" : "Migration commit and rollback failed; keys retained");
        }
    }
}
