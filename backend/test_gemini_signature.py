import sys
sys.path.insert(0, r'c:\Users\benne\Documents\projects\zen_ai\backend')
from zen_backend.ai import gemini

class FakeModels:
    def __init__(self, behavior):
        # behavior 1: raise on request_options and timeout, succeed on bare call
        self.behavior = behavior

    def generate_content(self, *args, **kwargs):
        if 'request_options' in kwargs and self.behavior in (1,):
            raise TypeError("unexpected keyword 'request_options'")
        if 'timeout' in kwargs and self.behavior in (1,):
            raise TypeError("unexpected keyword 'timeout'")
        class R:
            pass
        r = R()
        r.text = "6"
        return r

class FakeClient:
    def __init__(self, behavior):
        self.models = FakeModels(behavior)

# Test behavior where request_options and timeout raise TypeError, final call succeeds
fake = FakeClient(behavior=1)
gemini._client_cache['test_key'] = fake
print(gemini.generate_reply([{'role':'user','content':'What is 3 + 3?'}],'test_key'))
