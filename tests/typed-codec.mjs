import assert from 'node:assert/strict';
import { decodeInput, validateInput, formatResult, MAX_UINT64, MAX_STRING } from '../web/contract.js';

assert.equal(decodeInput('bool', 'false'), false);
assert.equal(decodeInput('bool', 'true'), true);
for (const value of ['0', '1', '', 'False', 'true ', ' false', 'yes', false, true]) {
  assert.throws(() => decodeInput('bool', value));
}
assert.equal(formatResult('bool', false), 'false');
assert.equal(formatResult('bool', true), 'true');
for (const value of ['false', 0, 1, undefined, null]) assert.throws(() => formatResult('bool', value));

for (const value of ['0', '00001', '9007199254740993', String(MAX_UINT64)]) {
  assert.equal(decodeInput('uint64', value), BigInt(value));
  assert.equal(formatResult('uint64', BigInt(value)), String(BigInt(value)));
}
for (const value of ['-1', '+1', '1.0', '1e3', '0x10', '', ' ', ' 1', '1 ',
  String(MAX_UINT64 + 1n), '9'.repeat(257), 0, 1n, null]) {
  assert.throws(() => decodeInput('uint64', value));
}
for (const value of [-1n, MAX_UINT64 + 1n, 0, 9007199254740992, '1', null]) {
  assert.throws(() => formatResult('uint64', value));
}
for (const value of ['', '\nα\n\n<b>&\n', 'line\r\nnext', 'x'.repeat(MAX_STRING)]) {
  assert.equal(decodeInput('string', value), value);
  assert.equal(formatResult('string', value), value);
}
assert.throws(() => validateInput('string', 'x'.repeat(MAX_STRING + 1)));
assert.throws(() => formatResult('unknown', 'value'));
console.log('typed scalar codec boundary checks passed');
