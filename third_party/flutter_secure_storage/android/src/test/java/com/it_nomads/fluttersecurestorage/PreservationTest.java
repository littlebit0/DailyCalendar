package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.SharedPreferences;
import com.it_nomads.fluttersecurestorage.ciphers.*;
import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import java.lang.reflect.*;
import java.util.*;
import static org.junit.Assert.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class PreservationTest {
    Context context;
    SharedPreferences data;
    FlutterSecureStorageConfig config;
    @Before public void setup() {
        context = RuntimeEnvironment.getApplication();
        data = context.getSharedPreferences("preservation", 0);
        data.edit().clear().putString("credential", "oldCiphertext").commit();
        config = new FlutterSecureStorageConfig(new HashMap<>());
    }
    StorageCipher cipher(boolean fail) {
        return new StorageCipher() {
            public byte[] encrypt(byte[] input) throws Exception { if (fail) throw new Exception("cipher failure"); return input.clone(); }
            public byte[] decrypt(byte[] input) { return input.clone(); }
            public void deleteKey(Context ignored) { fail("must never delete a key"); }
        };
    }
    void publish(SharedPreferences target, boolean fail) throws Exception {
        PreservingCipherMigration.publish(Map.of("credential", "newValue", "second", "secondValue"), target, cipher(fail),
            e -> e.putString("__daily_algorithm_key", "RSA_ECB_OAEPwithSHA_256andMGF1Padding").putString("__daily_algorithm_storage", "AES_GCM_NoPadding"));
    }
    @Test public void encryptionFailureLeavesAllOriginalsAndMarkers() throws Exception {
        Map<String, ?> before = data.getAll();
        assertThrows(Exception.class, () -> publish(data, true));
        assertEquals(before, data.getAll());
    }
    @Test public void failedCommitRestoresOriginalAndAllowsRetry() throws Exception {
        Map<String, ?> before = data.getAll();
        SharedPreferences failing = (SharedPreferences) Proxy.newProxyInstance(getClass().getClassLoader(), new Class[]{SharedPreferences.class}, (p,m,args) -> {
            Object result = m.invoke(data, args);
            if (!m.getName().equals("edit")) return result;
            SharedPreferences.Editor editor = (SharedPreferences.Editor)result;
            return Proxy.newProxyInstance(getClass().getClassLoader(), new Class[]{SharedPreferences.Editor.class}, (ep,em,ea) -> {
                Object er = em.invoke(editor, ea);
                if (em.getName().equals("commit")) return false;
                return er instanceof SharedPreferences.Editor ? ep : er;
            });
        });
        assertThrows(Exception.class, () -> publish(failing, false));
        assertEquals(before, data.getAll());
        publish(data, false);
        assertEquals("AES_GCM_NoPadding", data.getString("__daily_algorithm_storage", null));
    }
    @Test public void restartUsesCiphertextMarkersEvenWithStaleSeparateConfig() throws Exception {
        SharedPreferences legacy = context.getSharedPreferences("FlutterSecureStorageConfiguration:preservation", 0);
        legacy.edit().clear().putString("FlutterSecureSAlgorithmKey", "RSA_ECB_PKCS1Padding").putString("FlutterSecureSAlgorithmStorage", "AES_CBC_PKCS7Padding").commit();
        NamespacedConfigSource source = new NamespacedConfigSource(context, "preservation");
        StorageCipherFactory before = new StorageCipherFactory(source, "RSA_ECB_OAEPwithSHA_256andMGF1Padding", "AES_GCM_NoPadding", config, data);
        assertTrue(before.requiresReEncryption());
        assertEquals("RSA_ECB_PKCS1Padding", legacy.getString("FlutterSecureSAlgorithmKey", null));
        publish(data, false);
        StorageCipherFactory after = new StorageCipherFactory(source, "RSA_ECB_OAEPwithSHA_256andMGF1Padding", "AES_GCM_NoPadding", config, data);
        assertFalse(after.requiresReEncryption());
    }
    @Test public void migrationDoesNotTouchAnotherNamespace() throws Exception {
        SharedPreferences other = context.getSharedPreferences("daily_lms_credentials", 0);
        other.edit().putString("credential", "otherCiphertext").commit();
        publish(data, false);
        assertEquals("otherCiphertext", other.getString("credential", null));
    }
    void inject(Object object, String name, Object value) throws Exception {
        Field field = FlutterSecureStorage.class.getDeclaredField(name); field.setAccessible(true); field.set(object, value);
    }
    @Test public void readAndReadAllFailureNeverDeleteOriginalsEvenWithResetTrue() throws Exception {
        FlutterSecureStorage storage = new FlutterSecureStorage(context);
        HashMap<String,Object> options = new HashMap<>(); options.put("resetOnError", "true");
        FlutterSecureStorageConfig config = new FlutterSecureStorageConfig(options);
        inject(storage, "config", config); inject(storage, "preferences", data);
        inject(storage, "storageCipher", new StorageCipher() {
            public byte[] encrypt(byte[] value) { return value; }
            public byte[] decrypt(byte[] value) throws Exception { throw new Exception("temporarily unavailable"); }
            public void deleteKey(Context ignored) { fail("unexpected delete"); }
        });
        String key = storage.addPrefixToKey("token");
        data.edit().putString(key, "YWJjZA==").commit();
        Map<String,?> original = data.getAll();
        assertThrows(Exception.class, () -> storage.read(key));
        assertThrows(Exception.class, storage::readAll);
        assertEquals(original, data.getAll());
        assertFalse(config.shouldDeleteOnFailure());
    }
}
