import ctypes as ct
import json
import sys
import unittest
from unittest.mock import Mock, patch

import keychain_store as store


class SessionTests(unittest.TestCase):
    def test_json_missing_and_corrupt_data(self):
        with patch.object(store, 'SecurityStore') as factory:
            factory.return_value.read.return_value = None
            self.assertIsNone(store.session('read'))
            factory.return_value.read.return_value = b'{"token":"fixture"}'
            self.assertEqual(store.session('read'), {'token': 'fixture'})
            for data in [b'[]', b'bad-token-value', b'\xff']:
                factory.return_value.read.return_value = data
                with self.assertRaises(store.KeychainError) as error:
                    store.session('read')
                self.assertNotIn('bad-token', str(error.exception))

    def test_invalid_write_rejected_before_keychain(self):
        with patch.object(store, 'SecurityStore') as factory:
            for value in [None, [], {'x': float('nan')}, {'x': 'a' * 65536}]:
                with self.assertRaises(store.KeychainError):
                    store.session('write', value)
            with self.assertRaises(store.KeychainError):
                store.session('delete')
            factory.assert_not_called()

    def test_write_encodes_only_dictionary(self):
        with patch.object(store, 'SecurityStore') as factory:
            store.session('write', {'fixture': '한글'})
            self.assertEqual(json.loads(factory.return_value.write.call_args.args[0]), {'fixture': '한글'})


@unittest.skipUnless(sys.platform == 'darwin', 'macOS framework ABI')
class NativeBridgeTests(unittest.TestCase):
    def setUp(self):
        self.store = store.SecurityStore()
        # Every Security call is replaced. CoreFoundation allocation/conversion is real.
        self.interaction = patch.object(self.store.sec, 'SecKeychainSetUserInteractionAllowed', return_value=0).start()
        self.update = patch.object(self.store.sec, 'SecItemUpdate', return_value=0).start()
        self.add = patch.object(self.store.sec, 'SecItemAdd', return_value=0).start()
        self.copy = patch.object(self.store.sec, 'SecItemCopyMatching', return_value=store.NOT_FOUND).start()
        self.addCleanup(patch.stopall)

    def test_read_real_cfdata_and_dedicated_query(self):
        cf = self.store.cf
        cf.CFDictionaryGetValue.argtypes = [ct.c_void_p, ct.c_void_p]
        cf.CFDictionaryGetValue.restype = ct.c_void_p
        cf.CFStringGetCString.argtypes = [ct.c_void_p, ct.c_void_p, ct.c_long, ct.c_uint32]
        cf.CFStringGetCString.restype = ct.c_bool
        data = b'{"fixture":true}'
        def copy(query, result):
            for key, expected in [('kSecAttrService', store.SERVICE), ('kSecAttrAccount', store.ACCOUNT)]:
                ref = cf.CFDictionaryGetValue(query, self.store.constant(key))
                buffer = ct.create_string_buffer(256)
                self.assertTrue(cf.CFStringGetCString(ref, buffer, len(buffer), 0x08000100))
                self.assertEqual(buffer.value.decode(), expected)
            self.assertEqual(cf.CFDictionaryGetValue(query, self.store.constant('kSecUseAuthenticationUI')), self.store.constant('kSecUseAuthenticationUIFail'))
            result._obj.value = cf.CFDataCreate(None, data, len(data))
            return 0
        self.copy.side_effect = copy
        self.assertEqual(self.store.read(), data)
        self.interaction.assert_called_once_with(False)
        self.update.assert_not_called()
        self.add.assert_not_called()

    def test_not_found_and_denied_are_distinct(self):
        self.assertIsNone(self.store.read())
        self.copy.return_value = -25293
        with self.assertRaises(store.KeychainError):
            self.store.read()
        self.add.assert_not_called()
        self.update.assert_not_called()

    def test_update_does_not_delete_or_insert(self):
        self.store.write(b'{"fixture":true}')
        self.update.assert_called_once()
        self.add.assert_not_called()

    def test_insert_only_when_missing_and_handle_insert_race(self):
        self.update.side_effect = [store.NOT_FOUND, 0]
        self.add.return_value = store.DUPLICATE
        self.store.write(b'{"fixture":true}')
        self.assertEqual(self.update.call_count, 2)
        self.add.assert_called_once()

    def test_write_denied_never_replaces_existing_item(self):
        self.update.return_value = -25293
        with self.assertRaises(store.KeychainError):
            self.store.write(b'{"fixture":true}')
        self.add.assert_not_called()


if __name__ == '__main__':
    unittest.main()
