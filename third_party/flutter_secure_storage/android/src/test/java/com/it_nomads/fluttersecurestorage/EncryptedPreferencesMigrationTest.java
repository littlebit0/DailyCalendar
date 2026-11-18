package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.SharedPreferences;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import java.lang.reflect.Proxy;
import java.util.*;
import static org.junit.Assert.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class EncryptedPreferencesMigrationTest {
    static final String PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg";
    SharedPreferences esp;
    SharedPreferences target;
    Map<String, String> values;

    @Before public void setup() {
        Context context = RuntimeEnvironment.getApplication();
        esp = context.getSharedPreferences("esp", 0);
        target = context.getSharedPreferences("target", 0);
        esp.edit().clear().putString(PREFIX + "_session", "token")
                .putString(PREFIX + "_pin", "hash").putString("other", "ignored").commit();
        target.edit().clear().commit();
        values = EncryptedPreferencesMigration.prefixedStrings(esp.getAll(), PREFIX);
    }

    /** Fails on the [failAt]-th encryption (1-based), or never when 0. */
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

    void copy(SharedPreferences into, StorageCipher cipher) throws Exception {
        EncryptedPreferencesMigration.copy(values, esp, into, cipher,
                e -> e.putString(EncryptedPreferencesMigration.ALGORITHM_KEY_MARKER, "RSA_ECB_OAEPwithSHA_256andMGF1Padding")
                      .putString(EncryptedPreferencesMigration.ALGORITHM_STORAGE_MARKER, "AES_GCM_NoPadding"));
    }

    @Test public void snapshotHoldsOnlyPrefixedValues() {
        assertEquals(Set.of(PREFIX + "_session", PREFIX + "_pin"), values.keySet());
    }

    @Test public void encryptionFailureOnALaterKeyKeepsEveryOriginal() {
        Map<String, ?> before = esp.getAll();
        assertThrows(Exception.class, () -> copy(target, cipher(2)));
        assertEquals(before, esp.getAll());
        assertTrue(target.getAll().isEmpty());
    }

    @Test public void failedCommitKeepsEveryOriginal() {
        Map<String, ?> before = esp.getAll();
        SharedPreferences failing = (SharedPreferences) Proxy.newProxyInstance(getClass().getClassLoader(),
                new Class[]{SharedPreferences.class}, (p, m, args) -> {
                    Object result = m.invoke(target, args);
                    if (!m.getName().equals("edit")) return result;
                    SharedPreferences.Editor editor = (SharedPreferences.Editor) result;
                    return Proxy.newProxyInstance(getClass().getClassLoader(),
                            new Class[]{SharedPreferences.Editor.class}, (ep, em, ea) -> {
                                Object er = em.invoke(editor, ea);
                                if (em.getName().equals("commit")) return false;
                                return er instanceof SharedPreferences.Editor ? ep : er;
                            });
                });
        assertThrows(Exception.class, () -> copy(failing, cipher(0)));
        assertEquals(before, esp.getAll());
        assertFalse(EncryptedPreferencesMigration.hasAlgorithmMarkers(target));
    }

    @Test public void successMovesEveryValueThenRemovesOriginals() throws Exception {
        copy(target, cipher(0));
        for (String key : values.keySet()) {
            assertNotNull(target.getString(key, null));
            assertFalse(esp.contains(key));
        }
        assertEquals("ignored", esp.getString("other", null));
        assertTrue(EncryptedPreferencesMigration.hasAlgorithmMarkers(target));
    }

    @Test public void removingMarkersLeavesOtherEntries() {
        target.edit().putString(EncryptedPreferencesMigration.ALGORITHM_KEY_MARKER, "x")
                .putString(EncryptedPreferencesMigration.ALGORITHM_STORAGE_MARKER, "y")
                .putString("kept", "z").commit();
        assertTrue(EncryptedPreferencesMigration.removeAlgorithmMarkers(target));
        assertFalse(EncryptedPreferencesMigration.hasAlgorithmMarkers(target));
        assertEquals("z", target.getString("kept", null));
    }
}
