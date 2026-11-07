package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.SharedPreferences;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
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
public class DurableEditTest {
    Context context;
    SharedPreferences data;
    SharedPreferences other;

    @Before public void setup() {
        context = RuntimeEnvironment.getApplication();
        data = context.getSharedPreferences("durable", 0);
        data.edit().clear().putString("pin", "oldPin").putString("api", "oldApi").commit();
        other = context.getSharedPreferences("daily_lms_credentials", 0);
        other.edit().clear().putString("pin", "lmsValue").commit();
    }

    /** commit() applies to memory like SharedPreferencesImpl, then reports a disk failure. */
    SharedPreferences failingCommits(SharedPreferences target, int failures) {
        int[] remaining = {failures};
        return (SharedPreferences) Proxy.newProxyInstance(getClass().getClassLoader(), new Class[]{SharedPreferences.class}, (p, m, args) -> {
            Object result = m.invoke(target, args);
            if (!m.getName().equals("edit")) return result;
            SharedPreferences.Editor editor = (SharedPreferences.Editor) result;
            return Proxy.newProxyInstance(getClass().getClassLoader(), new Class[]{SharedPreferences.Editor.class}, (ep, em, ea) -> {
                if (em.getName().equals("apply")) fail("durable edits must not use apply()");
                Object er = em.invoke(editor, ea);
                if (em.getName().equals("commit") && remaining[0]-- > 0) return false;
                return er instanceof SharedPreferences.Editor ? ep : er;
            });
        });
    }

    @Test public void successfulEditsPersist() throws Exception {
        DurableEdit.putString(failingCommits(data, 0), "pin", "newPin");
        DurableEdit.remove(failingCommits(data, 0), "api");
        assertEquals("newPin", data.getString("pin", null));
        assertFalse(data.contains("api"));
        DurableEdit.clear(failingCommits(data, 0));
        assertTrue(data.getAll().isEmpty());
        assertEquals("lmsValue", other.getString("pin", null));
    }

    @Test public void failedWriteThrowsAndRestoresPreviousValue() {
        Map<String, ?> before = data.getAll();
        assertThrows(DurableEdit.PersistenceException.class, () -> DurableEdit.putString(failingCommits(data, 1), "pin", "newPin"));
        assertThrows(DurableEdit.PersistenceException.class, () -> DurableEdit.putString(failingCommits(data, 1), "fresh", "value"));
        assertEquals(before, data.getAll());
    }

    @Test public void failedDeleteThrowsAndKeepsValue() {
        assertThrows(DurableEdit.PersistenceException.class, () -> DurableEdit.remove(failingCommits(data, 1), "pin"));
        assertEquals("oldPin", data.getString("pin", null));
    }

    @Test public void failedDeleteAllThrowsAndKeepsEveryValue() {
        Map<String, ?> before = data.getAll();
        assertThrows(DurableEdit.PersistenceException.class, () -> DurableEdit.clear(failingCommits(data, 1)));
        assertEquals(before, data.getAll());
    }

    @Test public void failedRollbackStillThrowsAndRestoresCache() {
        Map<String, ?> before = data.getAll();
        assertThrows(DurableEdit.PersistenceException.class, () -> DurableEdit.clear(failingCommits(data, 2)));
        assertEquals(before, data.getAll());
    }

    void inject(Object object, String name, Object value) throws Exception {
        Field field = FlutterSecureStorage.class.getDeclaredField(name); field.setAccessible(true); field.set(object, value);
    }

    @Test public void storageWriteAndDeleteSurfaceDiskFailureWithoutDeletingOriginals() throws Exception {
        FlutterSecureStorage storage = new FlutterSecureStorage(context);
        HashMap<String, Object> options = new HashMap<>(); options.put("resetOnError", "true");
        inject(storage, "config", new FlutterSecureStorageConfig(options));
        inject(storage, "preferences", failingCommits(data, Integer.MAX_VALUE));
        inject(storage, "storageCipher", new StorageCipher() {
            public byte[] encrypt(byte[] value) { return value; }
            public byte[] decrypt(byte[] value) { return value; }
            public void deleteKey(Context ignored) { fail("must never delete a key"); }
        });
        Map<String, ?> before = data.getAll();
        assertThrows(DurableEdit.PersistenceException.class, () -> storage.write("pin", "newPin"));
        assertThrows(DurableEdit.PersistenceException.class, () -> storage.delete("pin"));
        assertThrows(DurableEdit.PersistenceException.class, storage::deleteAll);
        assertEquals(before, data.getAll());
        assertEquals("lmsValue", other.getString("pin", null));
    }
}
