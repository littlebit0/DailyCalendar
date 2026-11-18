package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.SharedPreferences;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipherFactory;
import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import java.lang.reflect.Proxy;
import java.util.*;
import static org.junit.Assert.*;

/**
 * Daily (#937): `initialize` with old EncryptedSharedPreferences (ESP) data.
 * ESP and the custom store share one preferences file in production; the fake
 * ESP below keeps its entries under "esp:" in that same file and, like
 * androidx ESP, its getAll() throws when the file holds an entry it did not
 * write. Cipher setup is replaced because Robolectric has no AndroidKeyStore.
 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class EncryptedPreferencesInitializeTest {
    static final String ESP = "esp:";
    Context context;
    FlutterSecureStorageConfig config;
    SharedPreferences file;
    String session;
    String pin;

    @Before public void setup() {
        context = RuntimeEnvironment.getApplication();
        config = new FlutterSecureStorageConfig(new HashMap<>());
        file = context.getSharedPreferences(config.getEffectiveDataPrefsName(), 0);
        file.edit().clear().commit();
        new NamespacedConfigSource(context, config.getEffectiveDataPrefsName()).edit().clear().commit();
        context.getSharedPreferences("FlutterSecureStorageConfiguration", 0).edit().clear().commit();
        session = config.getSharedPreferencesKeyPrefix() + "_session";
        pin = config.getSharedPreferencesKeyPrefix() + "_pin";
        file.edit().putString(ESP + session, "token").putString(ESP + pin, "hash").commit();
    }

    /** ESP view of [file]: entries under "esp:", getAll() fails on any other entry. */
    SharedPreferences fakeEsp() {
        return (SharedPreferences) Proxy.newProxyInstance(getClass().getClassLoader(),
                new Class[]{SharedPreferences.class}, (p, m, args) -> {
                    switch (m.getName()) {
                        case "getAll": {
                            Map<String, Object> all = new HashMap<>();
                            for (Map.Entry<String, ?> e : file.getAll().entrySet()) {
                                if (!e.getKey().startsWith(ESP)) throw new SecurityException("Could not decrypt key");
                                all.put(e.getKey().substring(ESP.length()), e.getValue());
                            }
                            return all;
                        }
                        case "edit": {
                            SharedPreferences.Editor editor = file.edit();
                            return Proxy.newProxyInstance(getClass().getClassLoader(),
                                    new Class[]{SharedPreferences.Editor.class}, (ep, em, ea) -> {
                                        if (em.getName().equals("remove")) { editor.remove(ESP + ea[0]); return ep; }
                                        Object r = em.invoke(editor, ea);
                                        return r instanceof SharedPreferences.Editor ? ep : r;
                                    });
                        }
                        default: throw new UnsupportedOperationException(m.getName());
                    }
                });
    }

    StorageCipher cipher(int failAt) {
        int[] calls = {0};
        return new StorageCipher() {
            public byte[] encrypt(byte[] input) throws Exception {
                if (++calls[0] == failAt) throw new Exception("cipher failure");
                return input.clone();
            }
            public byte[] decrypt(byte[] input) { return input.clone(); }
            public void deleteKey(Context ignored) { fail("must never delete a key"); }
        };
    }

    /**
     * Storage whose cipher setup behaves like the real algorithm migration: it
     * commits the data-file markers first, then succeeds or fails.
     */
    FlutterSecureStorage storage(boolean setupFails, int encryptFailAt) {
        return new FlutterSecureStorage(context) {
            @Override SharedPreferences initializeEncryptedSharedPreferencesManager(Context ignored) {
                return fakeEsp();
            }
            @Override void initializeStorageCipher(NamespacedConfigSource source, SecurePreferencesCallback<Void> callback) {
                storageCipherFactory = new StorageCipherFactory(source, "RSA_ECB_OAEPwithSHA_256andMGF1Padding",
                        "AES_GCM_NoPadding", config, file);
                SharedPreferences.Editor markers = file.edit();
                storageCipherFactory.stageDataAlgorithms(markers);
                markers.commit();
                if (setupFails) { callback.onError(new Exception("cipher setup failed")); return; }
                storageCipher = cipher(encryptFailAt);
                callback.onSuccess(null);
            }
        };
    }

    Exception initialize(FlutterSecureStorage storage) {
        Exception[] result = {null};
        boolean[] done = {false};
        storage.initialize(config, new SecurePreferencesCallback<Void>() {
            public void onSuccess(Void unused) { done[0] = true; }
            public void onError(Exception e) { done[0] = true; result[0] = e; }
        });
        assertTrue(done[0]);
        return result[0];
    }

    boolean migratedFlag() {
        return new NamespacedConfigSource(context, config.getEffectiveDataPrefsName())
                .getBoolean("ENCRYPTED_PREFERENCES_MIGRATED", false);
    }

    void assertEspIntactAndRetryable() {
        assertEquals("token", file.getString(ESP + session, null));
        assertEquals("hash", file.getString(ESP + pin, null));
        assertFalse(file.contains(session));
        assertFalse(EncryptedPreferencesMigration.hasAlgorithmMarkers(file));
        assertFalse(migratedFlag());
    }

    void assertRetrySucceeds() throws Exception {
        FlutterSecureStorage retry = storage(false, 0);
        assertNull(initialize(retry));
        assertEquals("token", retry.read(session));
        assertEquals("hash", retry.read(pin));
        assertFalse(file.contains(ESP + session));
        assertFalse(file.contains(ESP + pin));
        assertTrue(migratedFlag());
    }

    @Test public void copyFailureReportsErrorKeepsEspAndRetryRecovers() throws Exception {
        assertNotNull(initialize(storage(false, 2)));
        assertEspIntactAndRetryable();
        assertRetrySucceeds();
    }

    @Test public void cipherSetupFailureReportsErrorKeepsEspAndRetryRecovers() throws Exception {
        assertNotNull(initialize(storage(true, 0)));
        assertEspIntactAndRetryable();
        assertRetrySucceeds();
    }

    @Test public void successMovesEveryValueOnce() throws Exception {
        assertRetrySucceeds();
        // A later start skips ESP and reads the migrated values.
        FlutterSecureStorage restarted = storage(false, 0);
        assertNull(initialize(restarted));
        assertEquals("token", restarted.read(session));
    }
}
