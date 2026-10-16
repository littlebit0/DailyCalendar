"""Dedicated Dot credentials through macOS Security.framework; no helper process."""
import contextlib
import ctypes as ct
import json
import sys

SERVICE = 'com.littlebit0.dailycalendar.dot-reader'
ACCOUNT = 'oauth-session-v1'
NOT_FOUND = -25300
DUPLICATE = -25299
MAX_BYTES = 65536


class KeychainError(Exception):
    pass


class KeychainPermissionError(KeychainError):
    pass


class SecurityStore:
    def __init__(self, interactive=False):
        self.interactive = interactive
        if sys.platform != 'darwin':
            raise KeychainError('macOS Keychain is required.')
        self.cf = ct.CDLL('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
        self.sec = ct.CDLL('/System/Library/Frameworks/Security.framework/Security')
        signatures = [
            (self.cf, 'CFStringCreateWithCString', [ct.c_void_p, ct.c_char_p, ct.c_uint32], ct.c_void_p),
            (self.cf, 'CFDataCreate', [ct.c_void_p, ct.c_void_p, ct.c_long], ct.c_void_p),
            (self.cf, 'CFDataGetLength', [ct.c_void_p], ct.c_long),
            (self.cf, 'CFDataGetBytePtr', [ct.c_void_p], ct.c_void_p),
            (self.cf, 'CFGetTypeID', [ct.c_void_p], ct.c_ulong),
            (self.cf, 'CFDataGetTypeID', [], ct.c_ulong),
            (self.cf, 'CFDictionaryCreateMutable', [ct.c_void_p, ct.c_long, ct.c_void_p, ct.c_void_p], ct.c_void_p),
            (self.cf, 'CFDictionarySetValue', [ct.c_void_p, ct.c_void_p, ct.c_void_p], None),
            (self.cf, 'CFRelease', [ct.c_void_p], None),
            (self.sec, 'SecKeychainSetUserInteractionAllowed', [ct.c_ubyte], ct.c_int32),
            (self.sec, 'SecItemCopyMatching', [ct.c_void_p, ct.POINTER(ct.c_void_p)], ct.c_int32),
            (self.sec, 'SecItemUpdate', [ct.c_void_p, ct.c_void_p], ct.c_int32),
            (self.sec, 'SecItemAdd', [ct.c_void_p, ct.POINTER(ct.c_void_p)], ct.c_int32),
        ]
        for library, name, args, result in signatures:
            fn = getattr(library, name)
            fn.argtypes = args
            fn.restype = result

    def constant(self, name):
        library = self.cf if name.startswith('kCF') else self.sec
        return ct.c_void_p.in_dll(library, name).value

    def own(self, scope, reference):
        if not reference:
            raise KeychainError('Keychain allocation failed.')
        scope.callback(self.cf.CFRelease, reference)
        return reference

    def dictionary(self, scope):
        # Pass the framework's real CFType callbacks so values are retained correctly.
        keys = ct.addressof(ct.c_byte.in_dll(self.cf, 'kCFTypeDictionaryKeyCallBacks'))
        values = ct.addressof(ct.c_byte.in_dll(self.cf, 'kCFTypeDictionaryValueCallBacks'))
        return self.own(scope, self.cf.CFDictionaryCreateMutable(None, 0, keys, values))

    def put(self, dictionary, key, value):
        self.cf.CFDictionarySetValue(dictionary, self.constant(key), value)

    def query(self, scope):
        query = self.dictionary(scope)
        self.put(query, 'kSecClass', self.constant('kSecClassGenericPassword'))
        if not self.interactive:
            self.put(query, 'kSecUseAuthenticationUI', self.constant('kSecUseAuthenticationUIFail'))
        for key, text in [('kSecAttrService', SERVICE), ('kSecAttrAccount', ACCOUNT)]:
            value = self.own(scope, self.cf.CFStringCreateWithCString(None, text.encode(), 0x08000100))
            self.put(query, key, value)
        return query

    def set_interaction(self):
        # Legacy login-keychain items use this process-local switch as well as
        # kSecUseAuthenticationUI. Interactive authorization runs in its own child.
        if self.sec.SecKeychainSetUserInteractionAllowed(self.interactive) != 0:
            raise KeychainError('Keychain interaction mode unavailable.')

    def read(self):
        self.set_interaction()
        with contextlib.ExitStack() as scope:
            query = self.query(scope)
            self.put(query, 'kSecReturnData', self.constant('kCFBooleanTrue'))
            self.put(query, 'kSecMatchLimit', self.constant('kSecMatchLimitOne'))
            result = ct.c_void_p()
            status = self.sec.SecItemCopyMatching(query, ct.byref(result))
            if result.value:
                self.own(scope, result.value)
            if status == NOT_FOUND:
                return None
            if status in (-25308, -25293, -128):
                raise KeychainPermissionError('Keychain authorization is required.')
            if status != 0 or not result.value:
                raise KeychainError('Keychain access was denied or unavailable.')
            if self.cf.CFGetTypeID(result) != self.cf.CFDataGetTypeID():
                raise KeychainError('Invalid Keychain data type.')
            length = self.cf.CFDataGetLength(result)
            if not 0 < length < MAX_BYTES:
                raise KeychainError('Invalid Keychain data size.')
            return ct.string_at(self.cf.CFDataGetBytePtr(result), length)

    def write(self, data):
        self.set_interaction()
        with contextlib.ExitStack() as scope:
            query = self.query(scope)
            value = self.own(scope, self.cf.CFDataCreate(None, data, len(data)))
            updates = self.dictionary(scope)
            self.put(updates, 'kSecValueData', value)
            status = self.sec.SecItemUpdate(query, updates)
            if status == NOT_FOUND:
                self.put(query, 'kSecValueData', value)
                self.put(query, 'kSecAttrAccessible', self.constant('kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly'))
                status = self.sec.SecItemAdd(query, None)
                if status == DUPLICATE:
                    # Another process inserted the dedicated item. Update without delete/recreate.
                    status = self.sec.SecItemUpdate(self.query(scope), updates)
            if status in (-25308, -25293, -128):
                raise KeychainPermissionError('Keychain authorization is required.')
            if status != 0:
                raise KeychainError('Keychain write was denied or unavailable.')


def session(action, value=None, interactive=False):
    if action not in ('read', 'write'):
        raise KeychainError('Unsupported Keychain operation.')
    if action == 'write':
        if not isinstance(value, dict):
            raise KeychainError('Invalid credential object.')
        try:
            data = json.dumps(value, allow_nan=False).encode('utf-8')
        except (ValueError, TypeError):
            raise KeychainError('Invalid credential object.') from None
        if not 0 < len(data) < MAX_BYTES:
            raise KeychainError('Invalid credential size.')
        SecurityStore(interactive=interactive).write(data)
        return None
    data = SecurityStore(interactive=interactive).read()
    if data is None:
        return None
    try:
        value = json.loads(data)
        if not isinstance(value, dict):
            raise ValueError()
        return value
    except (ValueError, TypeError, UnicodeError):
        raise KeychainError('Invalid credential object.') from None
