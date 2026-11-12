// Runs LmsWebSession.automaticLoginScript against a described page, without a
// browser. stdin: {script, args, page}. stdout: {result, calls, fields}.
const input = JSON.parse(require('fs').readFileSync(0, 'utf8'));
const { script, args, page } = input;
const calls = [];
const fields = {};
function element(label, spec) {
  if (!spec) return null;
  const children = {};
  const e = {
    method: spec.method || 'post',
    action: spec.action || '',
    type: spec.type || 'text',
    id: spec.id || '',
    name: spec.name || '',
    textContent: spec.text || '',
    value: '',
    checked: true,
    dataset: {},
    dispatchEvent() {},
    getClientRects: () => (spec.hidden ? [] : [1]),
    querySelector: (selector) => children[selector] || null,
    querySelectorAll: (selector) =>
      selector === 'input' ? Object.values(children) : [],
    requestSubmit: () => calls.push('submit:' + label),
  };
  for (const [selector, child] of Object.entries(spec.children || {})) {
    children[selector] = element(label + ' ' + selector, child);
  }
  fields[label] = e;
  return e;
}
const selectors = {};
for (const [selector, spec] of Object.entries(page.selectors || {})) {
  selectors[selector] = element(selector, spec);
}
const errors = (page.errors || []).map((text) => element('error', { text }));
const document = {
  readyState: page.readyState || 'complete',
  querySelector(selector) {
    for (const part of selector.split(',')) {
      if (selectors[part.trim()]) return selectors[part.trim()];
    }
    return null;
  },
  querySelectorAll: (selector) => (selector.includes('.alert-danger') ? errors : []),
};
const location = {
  protocol: page.protocol || 'https:',
  port: page.port || '',
  hostname: page.hostname,
  origin: (page.protocol || 'https:') + '//' + page.hostname,
};
const window = {};
for (const name of page.functions || []) window[name] = () => calls.push('call:' + name);
const names = Object.keys(args);
const run = new Function(...names, 'location', 'document', 'window', 'setTimeout', script);
const result = run(...names.map((n) => args[n]), location, document, window, (f) => f());
const out = {};
for (const [label, e] of Object.entries(fields)) {
  out[label] = { value: e.value, checked: e.checked };
}
process.stdout.write(JSON.stringify({ result, calls, fields: out }));
