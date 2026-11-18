package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.SharedPreferences;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import org.robolectric.shadows.ShadowLog;
import java.lang.reflect.Field;
import java.util.HashMap;
import static org.junit.Assert.*;

/** Daily (#971): storage key names and stack traces stay out of release logs and errors. */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class LogPrivacyTest {
    @Test public void stackTraceIsSentOnlyInDebugBuilds() {
        Exception error = new Exception("failure");
        assertNull(FlutterSecureStoragePlugin.errorDetails(error, false));
        assertTrue(FlutterSecureStoragePlugin.errorDetails(error, true).contains("LogPrivacyTest"));
    }

    void inject(Object object, String name, Object value) throws Exception {
        Field field = FlutterSecureStorage.class.getDeclaredField(name);
        field.setAccessible(true);
        field.set(object, value);
    }

    @Test public void readFailureLogDoesNotNameTheKey() throws Exception {
        Context context = RuntimeEnvironment.getApplication();
        SharedPreferences data = context.getSharedPreferences("log-privacy", 0);
        FlutterSecureStorage storage = new FlutterSecureStorage(context);
        inject(storage, "config", new FlutterSecureStorageConfig(new HashMap<>()));
        inject(storage, "preferences", data);
        inject(storage, "storageCipher", new StorageCipher() {
            public byte[] encrypt(byte[] value) { return value; }
            public byte[] decrypt(byte[] value) throws Exception { throw new Exception("unavailable"); }
            public void deleteKey(Context ignored) { fail("unexpected delete"); }
        });
        String key = storage.addPrefixToKey("driveSessionSecretName");
        data.edit().putString(key, "YWJjZA==").commit();
        ShadowLog.clear();

        Exception error = assertThrows(Exception.class, () -> storage.read(key));

        assertFalse(error.getMessage(), error.getMessage().contains("driveSessionSecretName"));
        for (ShadowLog.LogItem item : ShadowLog.getLogs()) {
            assertFalse(item.msg, item.msg.contains("driveSessionSecretName"));
        }
    }
}
