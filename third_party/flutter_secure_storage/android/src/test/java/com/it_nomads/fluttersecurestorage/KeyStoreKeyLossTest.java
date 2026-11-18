package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.SharedPreferences;
import com.it_nomads.fluttersecurestorage.ciphers.KeyStoreKeyMissingException;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Field;
import java.security.*;
import java.security.cert.Certificate;
import java.security.spec.AlgorithmParameterSpec;
import java.util.*;
import static org.junit.Assert.*;

/**
 * Daily (#968): the Android Keystore key that wrapped the stored AES key is
 * gone, as after a backup restore to another device. Robolectric has no
 * AndroidKeyStore, so an empty in-memory "AndroidKeyStore" provider stands in
 * and counts key generation.
 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class KeyStoreKeyLossTest {
    static final String GCM_WRAPPED_KEY = "AESVGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK";
    static int generatedKeyPairs;

    Context context;
    FlutterSecureStorageConfig config;
    SharedPreferences data;
    SharedPreferences keys;
    String pin;
    String gemini;

    @Before public void setup() {
        Security.insertProviderAt(new FakeAndroidKeyStore(), 1);
        generatedKeyPairs = 0;
        context = RuntimeEnvironment.getApplication();
        config = new FlutterSecureStorageConfig(new HashMap<>());
        data = context.getSharedPreferences(config.getEffectiveDataPrefsName(), 0);
        keys = context.getSharedPreferences(config.getEffectiveKeyStoragePrefsName(), 0);
        pin = config.getSharedPreferencesKeyPrefix() + "_appLockPinHash";
        gemini = config.getSharedPreferencesKeyPrefix() + "_geminiApiKey";
        // A store written on another device: current markers, values and a
        // wrapped AES key, but no Keystore key on this device.
        data.edit().clear()
                .putString("__daily_algorithm_key", "RSA_ECB_OAEPwithSHA_256andMGF1Padding")
                .putString("__daily_algorithm_storage", "AES_GCM_NoPadding")
                .putString(pin, "c2VhbGVk")
                .putString(gemini, "c2VhbGVk")
                .commit();
        keys.edit().clear().putString(GCM_WRAPPED_KEY, "d3JhcHBlZA==").commit();
        new NamespacedConfigSource(context, config.getEffectiveDataPrefsName()).edit().clear()
                .putBoolean("ENCRYPTED_PREFERENCES_MIGRATED", true).commit();
    }

    @After public void tearDown() {
        Security.removeProvider("AndroidKeyStore");
    }

    @Test public void missingKeystoreKeyIsReportedAndNoKeyIsCreated() {
        Exception error = initialize(new FlutterSecureStorage(context));

        assertNotNull(error);
        assertTrue(KeyStoreKeyMissingException.isCause(error));
        assertEquals("DailySecureStorageKeyLost", FlutterSecureStoragePlugin.errorCode(error));
        assertEquals(0, generatedKeyPairs);
        assertEquals("c2VhbGVk", data.getString(pin, null));
        assertEquals("d3JhcHBlZA==", keys.getString(GCM_WRAPPED_KEY, null));
    }

    @Test public void otherErrorsKeepTheGenericCode() {
        assertEquals("Exception encountered",
                FlutterSecureStoragePlugin.errorCode(new Exception("unwrap failed", new InvalidKeyException())));
    }

    @Test public void readFailsWithTheKeyLostCodeAndLeavesEverything() throws Exception {
        Outcome read = call("read", "appLockPinHash");

        assertEquals("DailySecureStorageKeyLost", read.errorCode);
        assertEquals("c2VhbGVk", data.getString(pin, null));
        assertEquals("d3JhcHBlZA==", keys.getString(GCM_WRAPPED_KEY, null));
        assertEquals(0, generatedKeyPairs);
    }

    @Test public void deleteRemovesOnlyThatEntry() throws Exception {
        Outcome delete = call("delete", "appLockPinHash");

        assertTrue(delete.succeeded);
        assertFalse(data.contains(pin));
        assertEquals("c2VhbGVk", data.getString(gemini, null));
        assertEquals("d3JhcHBlZA==", keys.getString(GCM_WRAPPED_KEY, null));
        assertEquals("DailySecureStorageKeyLost", call("read", "geminiApiKey").errorCode);
    }

    @Test public void deleteAllClearsDataAndWrappedKeys() throws Exception {
        Outcome deleteAll = call("deleteAll", null);

        assertTrue(deleteAll.succeeded);
        assertTrue(data.getAll().isEmpty());
        assertTrue(keys.getAll().isEmpty());
        assertEquals(0, generatedKeyPairs);
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

    static final class Outcome implements MethodChannel.Result {
        boolean succeeded;
        String errorCode;
        public void success(Object result) { succeeded = true; }
        public void error(String code, String message, Object details) { errorCode = code; }
        public void notImplemented() { fail("not implemented"); }
    }

    Outcome call(String method, String key) throws Exception {
        FlutterSecureStoragePlugin plugin = new FlutterSecureStoragePlugin();
        Field applicationContext = FlutterSecureStoragePlugin.class.getDeclaredField("applicationContext");
        applicationContext.setAccessible(true);
        applicationContext.set(plugin, context);
        Map<String, Object> arguments = new HashMap<>();
        arguments.put("options", new HashMap<String, Object>());
        if (key != null) arguments.put("key", key);
        Outcome outcome = new Outcome();
        plugin.new MethodRunner(new MethodCall(method, arguments), outcome).run();
        assertTrue(outcome.succeeded || outcome.errorCode != null);
        return outcome;
    }

    /** An empty AndroidKeyStore; a generated key pair is only counted. */
    public static final class FakeAndroidKeyStore extends Provider {
        public FakeAndroidKeyStore() {
            super("AndroidKeyStore", 1.0, "Daily test key store");
            put("KeyStore.AndroidKeyStore", EmptyKeyStore.class.getName());
            put("KeyPairGenerator.RSA", CountingGenerator.class.getName());
        }
    }

    public static final class CountingGenerator extends KeyPairGeneratorSpi {
        public void initialize(int keysize, SecureRandom random) {}
        public void initialize(AlgorithmParameterSpec params, SecureRandom random) {}
        public KeyPair generateKeyPair() {
            generatedKeyPairs++;
            throw new IllegalStateException("a Keystore key must not be created");
        }
    }

    public static final class EmptyKeyStore extends KeyStoreSpi {
        public Key engineGetKey(String alias, char[] password) { return null; }
        public Certificate[] engineGetCertificateChain(String alias) { return null; }
        public Certificate engineGetCertificate(String alias) { return null; }
        public Date engineGetCreationDate(String alias) { return null; }
        public void engineSetKeyEntry(String alias, Key key, char[] password, Certificate[] chain) {}
        public void engineSetKeyEntry(String alias, byte[] key, Certificate[] chain) {}
        public void engineSetCertificateEntry(String alias, Certificate cert) {}
        public void engineDeleteEntry(String alias) {}
        public Enumeration<String> engineAliases() { return Collections.emptyEnumeration(); }
        public boolean engineContainsAlias(String alias) { return false; }
        public int engineSize() { return 0; }
        public boolean engineIsKeyEntry(String alias) { return false; }
        public boolean engineIsCertificateEntry(String alias) { return false; }
        public String engineGetCertificateAlias(Certificate cert) { return null; }
        public void engineStore(OutputStream stream, char[] password) {}
        public void engineLoad(InputStream stream, char[] password) {}
    }
}
