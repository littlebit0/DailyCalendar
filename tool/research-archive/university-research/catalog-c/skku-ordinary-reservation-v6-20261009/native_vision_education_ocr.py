"""In-memory macOS Vision OCR; no compiler, app, raw-file or network use."""
import ctypes

PTR = ctypes.c_void_p
SIZE = ctypes.c_ulong
BOOL = ctypes.c_bool
ctypes.CDLL('/System/Library/Frameworks/Foundation.framework/Foundation')
ctypes.CDLL('/System/Library/Frameworks/Vision.framework/Vision')
objc = ctypes.CDLL('/usr/lib/libobjc.A.dylib')
objc.objc_getClass.argtypes = [ctypes.c_char_p]
objc.objc_getClass.restype = PTR
objc.sel_registerName.argtypes = [ctypes.c_char_p]
objc.sel_registerName.restype = PTR
SEND = ctypes.cast(objc.objc_msgSend, PTR).value

class Point(ctypes.Structure):
    _fields_ = [('x', ctypes.c_double), ('y', ctypes.c_double)]
class Extent(ctypes.Structure):
    _fields_ = [('width', ctypes.c_double), ('height', ctypes.c_double)]
class Rect(ctypes.Structure):
    _fields_ = [('origin', Point), ('size', Extent)]

def cls(name):
    return objc.objc_getClass(name.encode())

def call(receiver, selector, result=PTR, types=(), args=()):
    function = ctypes.CFUNCTYPE(result, PTR, PTR, *types)(SEND)
    return function(receiver, objc.sel_registerName(selector.encode()), *args)

def string(value):
    return call(cls('NSString'), 'stringWithUTF8String:', PTR,
                (ctypes.c_char_p,), (value.encode(),))

def array(values):
    storage = (PTR * len(values))(*values)
    return call(cls('NSArray'), 'arrayWithObjects:count:', PTR,
                (ctypes.POINTER(PTR), SIZE), (storage, len(values)))

def items(value):
    count = call(value, 'count', SIZE)
    return [call(value, 'objectAtIndex:', PTR, (SIZE,), (i,)) for i in range(count)]

def utf8(value):
    raw = call(value, 'UTF8String', ctypes.c_char_p)
    return raw.decode('utf8') if raw else ''

def recognize(png_bytes):
    pool = call(call(cls('NSAutoreleasePool'), 'alloc'), 'init')
    try:
        storage = ctypes.create_string_buffer(png_bytes)
        data = call(cls('NSData'), 'dataWithBytes:length:', PTR,
                    (PTR, SIZE), (ctypes.cast(storage, PTR), len(png_bytes)))
        request = call(call(cls('VNRecognizeTextRequest'), 'alloc'), 'init')
        call(request, 'setRecognitionLevel:', None, (SIZE,), (0,))
        error = PTR()
        languages = call(request, 'supportedRecognitionLanguagesAndReturnError:', PTR,
                         (ctypes.POINTER(PTR),), (ctypes.byref(error),))
        supported = [utf8(v) for v in items(languages)]
        selected = [v for v in ['ko-KR', 'en-US'] if v in supported]
        if selected:
            call(request, 'setRecognitionLanguages:', None, (PTR,),
                 (array([string(v) for v in selected]),))
        call(request, 'setUsesLanguageCorrection:', None, (BOOL,), (True,))
        options = call(cls('NSDictionary'), 'dictionary')
        handler = call(call(cls('VNImageRequestHandler'), 'alloc'),
                       'initWithData:options:', PTR, (PTR, PTR), (data, options))
        ok = call(handler, 'performRequests:error:', BOOL,
                  (PTR, ctypes.POINTER(PTR)), (array([request]), ctypes.byref(error)))
        if not ok:
            raise RuntimeError('Native OCR did not complete; no private diagnostic retained')
        observations = call(request, 'results')
        records = []
        for observation in items(observations):
            candidates = items(call(observation, 'topCandidates:', PTR, (SIZE,), (1,)))
            if not candidates:
                continue
            rect = call(observation, 'boundingBox', Rect)
            candidate = candidates[0]
            records.append({'text': utf8(call(candidate, 'string')),
                            'confidence': call(candidate, 'confidence', ctypes.c_float),
                            'box': [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]})
        return {'engine': 'macOS Vision in-memory native API', 'languages': selected,
                'observations': records, 'rawInputPersisted': False}
    finally:
        call(pool, 'drain', None)
