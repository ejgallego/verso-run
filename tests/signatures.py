"""Assertions for the pinned VIR native/value contract, independent of its encoder."""


def scalar_descriptor(name):
    if name == 'Bool':
        return {
            'native': {'type': {'tag': 'leanObject'}, 'metadata': {
                'declaration': 'Bool', 'constructors': [
                    {'name': 'Bool.' + case, 'representation': 'immediate', 'fields': []}
                    for case in ['false', 'true']]}},
            'value': {'tag': 'boolean', 'false': 0, 'true': 1}}
    native, value = {
        'String': ({'tag': 'string'}, {'tag': 'string'}),
        'Nat': ({'tag': 'nat'}, {'tag': 'bigint'}),
        'UInt64': ({'tag': 'unsigned', 'width': 64}, {'tag': 'bigint'}),
    }[name]
    return {'native': {'type': native}, 'value': value}


def type_name(descriptor):
    native = descriptor['native']
    if 'metadata' in native:
        return native['metadata']['declaration']
    return {'string': 'String', 'nat': 'Nat', 'unsigned': 'UInt64'}[native['type']['tag']]


def native_field(descriptor, name):
    fields = descriptor['native']['metadata']['constructors'][0]['fields']
    return next(field['type'] for field in fields if field['name'] == name)
