import _ from 'lodash';
import {
  libwasm,
  decoders as decoder,
  encoders as encoder,
} from './libwasm.ts';

const eventHandler = async (event: any) => {
  const handlers = event.currentTarget.wasmEvents[event.type];
  const cbs = handlers.cbs;

  cbs.forEach(async (cb: any) => {
    let idx = libwasm.addObject(event);
    try {
      await libwasm.instance.exports.domEvent(cb.ctx, cb.fun, idx);
    } catch (e) {
      console.error(
        'domEvent failed (',
        libwasm.lastExceptionMsg,
        ')',
        libwasm.objects[idx]
      );
      libwasm.removeObject(idx);
    }
  });
};
export let jsExports = {
  env: {
    KeyboardEvent_key_Get: (rawResult: number, ctx: number) => {
      encoder.string(rawResult, libwasm.objects[ctx].key);
    },
    appendChild: (parent: number, child: number) => {
      libwasm.objects[parent].appendChild(libwasm.objects[child]);
    },
    insertBefore: (parent: number, child: number, sibling: number) => {
      libwasm.objects[parent].insertBefore(
        libwasm.objects[child],
        libwasm.objects[sibling]
      );
    },
    addCss: (cssLen: number, cssOffset: number) => {
      var style = document.createElement('style');
      style.type = 'text/css';
      style.innerHTML = decoder.string(cssLen, cssOffset);
      document.getElementsByTagName('head')[0].appendChild(style);
      libwasm.addObject(style);
    },
    addClass: (node: number, classLen: number, classOffset: number) => {
      let classNames = decoder.string(classLen, classOffset);
      _.forEach(classNames.split(' '), function (className: string) {
        libwasm.objects[node].classList.add(className);
      });
    },
    removeClass: (node: number, classLen: number, classOffset: number) => {
      let classNames = decoder.string(classLen, classOffset);
      _.forEach(classNames.split(' '), function (className: string) {
        libwasm.objects[node].classList.remove(className);
      });
    },
    changeClass: (
      node: number,
      classLen: number,
      classOffset: number,
      on: number
    ) => {
      let classNames = decoder.string(classLen, classOffset);
      if (on) {
        _.forEach(classNames.split(' '), function (className: string) {
          libwasm.objects[node].classList.add(className);
        });
      } else {
        _.forEach(classNames.split(' '), function (className: string) {
          libwasm.objects[node].classList.remove(className);
        });
      }
    },
    unmount: (childPtr: number) => {
      var child = libwasm.objects[childPtr];
      child.parentNode.removeChild(child);
    },
    removeChild: (childPtr: number) => {
      var child = libwasm.objects[childPtr];
      child.parentNode.removeChild(child);
      // TODO: we can reuse the child node (it is cheaper than recreating a new one...)
    },
    logObjects: () => {
      console.log(libwasm.objects);
      console.log(libwasm.freelists);
    },
    getRoot: () => {
      return libwasm.addObject(document.querySelector('#root'));
    },
    createElement: (type: number) => {
      const tags = [
        'a',
        'abbr',
        'address',
        'area',
        'article',
        'aside',
        'audio',
        'b',
        'base',
        'bdi',
        'bdo',
        'blockquote',
        'body',
        'br',
        'button',
        'canvas',
        'caption',
        'cite',
        'code',
        'col',
        'colgroup',
        'data',
        'datalist',
        'dd',
        'del',
        'dfn',
        'div',
        'dl',
        'dt',
        'em',
        'embed',
        'fieldset',
        'figcaption',
        'figure',
        'footer',
        'form',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'head',
        'header',
        'hr',
        'html',
        'i',
        'iframe',
        'img',
        'input',
        'ins',
        'kbd',
        'keygen',
        'label',
        'legend',
        'li',
        'link',
        'main',
        'map',
        'mark',
        'meta',
        'meter',
        'nav',
        'noscript',
        'object',
        'ol',
        'optgroup',
        'option',
        'output',
        'p',
        'param',
        'pre',
        'progress',
        'q',
        'rb',
        'rp',
        'rt',
        'rtc',
        'ruby',
        's',
        'samp',
        'script',
        'section',
        'select',
        'small',
        'source',
        'span',
        'strong',
        'style',
        'sub',
        'sup',
        'table',
        'tbody',
        'td',
        'template',
        'textarea',
        'tfoot',
        'th',
        'thead',
        'time',
        'title',
        'tr',
        'track',
        'u',
        'ul',
        'var',
        'video',
        'wbr',
      ];
      const getTagFromType = (type: number) => {
        return tags[type];
      };
      return libwasm.addObject(document.createElement(getTagFromType(type)));
    },
    setSelectionRange: (nodePtr: number, start: number, end: number) => {
      libwasm.objects[nodePtr].setSelectionRange(start, end);
    },
    innerText: (nodePtr: number, textLen: number, textOffset: number) => {
      libwasm.objects[nodePtr].innerText = decoder.string(textLen, textOffset);
    },
    setAttributeInt: (
      node: number,
      attrLen: number,
      attrOffset: number,
      value: number
    ) => {
      const attr = decoder.string(attrLen, attrOffset);
      libwasm.objects[node].setAttribute(attr, value);
    },
    setAttributeBool: (
      node: number,
      attrLen: number,
      attrOffset: number,
      value: number
    ) => {
      const attr = decoder.string(attrLen, attrOffset);
      if (value == 1) libwasm.objects[node].setAttribute(attr, value);
      else libwasm.objects[node].removeAttribute(attr);
    },
    removeAttribute: (node: number, attrLen: number, attrOffset: number) => {
      const attr = decoder.string(attrLen, attrOffset);
      libwasm.objects[node].removeAttribute(attr);
    },
    getTimeStamp: () => {
      return BigInt(window._.now());
    },
    addEventListener: (
      nodePtr: number,
      listenerTypeLen: number,
      listenerTypeOffset: number,
      ctx: number,
      fun: number,
      eventType: number
    ) => {
      let listenerTypeStr: any = decoder.string(
        listenerTypeLen,
        listenerTypeOffset
      );
      let node: any = libwasm.objects[nodePtr];
      let existing_cb: any;
      if (
        typeof node.wasmEventHandlers === 'object' &&
        typeof node.wasmEventHandlers[listenerTypeStr] === 'object'
      ) {
        console.warn(`Node had existing event handler(s):`);
        console.warn(node);
        existing_cb = node.wasmEventHandlers[listenerTypeStr];
        delete node.wasmEventHandlers[listenerTypeStr];
      }
      if (node.wasmEvents === undefined)
        var nodeEvents: any = (node.wasmEvents = {});
      else var nodeEvents: any = libwasm.objects[nodePtr].wasmEvents;
      if (
        nodeEvents[listenerTypeStr] &&
        nodeEvents[listenerTypeStr].cbs.length > 0
      ) {
        nodeEvents[listenerTypeStr].cbs.push({ ctx: ctx, fun: fun });
      } else {
        nodeEvents[listenerTypeStr] = {
          cbs: [{ ctx: ctx, fun: fun }],
          eventType: eventType,
        };
        if (existing_cb) nodeEvents[listenerTypeStr].cbs.push(existing_cb);
        node.addEventListener(listenerTypeStr, eventHandler);
      }
    },
    removeEventListener: (
      nodePtr: number,
      listenerTypeLen: number,
      listenerTypeOffset: number,
      ctx: number,
      fun: number,
      eventType: number
    ) => {
      var listenerTypeStr = decoder.string(listenerTypeLen, listenerTypeOffset);
      var node = libwasm.objects[nodePtr];
      if (node.wasmEvents === undefined) return;
      var nodeEvents = libwasm.objects[nodePtr].wasmEvents;
      if (
        nodeEvents[listenerTypeStr] &&
        nodeEvents[listenerTypeStr].cbs.length > 0
      ) {
        nodeEvents[listenerTypeStr].cbs = nodeEvents[
          listenerTypeStr
        ].cbs.filter((cb: any) => !(cb.ctx == ctx && cb.fun == fun));
      }
    },
    setPropertyBool: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      value: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      if (node && node[prop] !== undefined) node[prop] = value;
    },
    setPropertyInt: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      value: number
    ) => {
      jsExports.env.setPropertyBool(nodePtr, propLen, propOffset, value);
    },
    setProperty: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      valueLen: number,
      valueOffset: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      if (node && node[prop] !== undefined) {
        node[prop] = decoder.string(valueLen, valueOffset);
      }
    },
    getPropertyInt: (nodePtr: number, propLen: number, propOffset: number) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      if (!node || node[prop] === undefined) return false;
      return +node[prop];
    },
    getPropertyBool: (nodePtr: number, propLen: number, propOffset: number) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      if (!node || node[prop] === undefined) return false;
      return !!node[prop];
    },
    getProperty: (
      resultRaw: number,
      nodePtr: number,
      propLen: number,
      propOffset: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      if (!node || node[prop] === undefined)
        return encoder.string(resultRaw, '');
      return encoder.string(resultRaw, node[prop]);
    },
    Object_Call__void: (
      nodePtr: number,
      propLen: number,
      propOffset: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      node[prop]();
    },
    Object_Call_uint__void: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      arg: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      if (typeof node[prop] === 'function') node[prop](arg);
      else node[prop] = arg;
    },
    Object_Call_int__void: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      arg: number
    ) => {
      jsExports.env.Object_Call_uint__void(nodePtr, propLen, propOffset, arg);
    },
    Object_Call_bool__void: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      arg: number
    ) => {
      jsExports.env.Object_Call_uint__void(nodePtr, propLen, propOffset, arg);
    },
    Object_Call_double__void: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      arg: number
    ) => {
      jsExports.env.Object_Call_uint__void(nodePtr, propLen, propOffset, arg);
    },
    Object_Call_float__void: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      arg: number
    ) => {
      jsExports.env.Object_Call_uint__void(nodePtr, propLen, propOffset, arg);
    },
    Object_Call_handle__void: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      handle: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);

      if (typeof node[prop] === 'function') node[prop](libwasm.objects[handle]);
      else node[prop] = libwasm.objects[handle];
    },
    Object_Call_double_double__void: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      arg: number,
      arg2: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      node[prop](arg, arg2);
    },
    Object_Getter__Handle: (
      nodePtr: number,
      propLen: number,
      propOffset: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      if (typeof node[prop] === 'function')
        return libwasm.addObject(node[prop]());
      else return libwasm.addObject(node[prop]);
    },
    Object_Getter__string: (
      rawResult: number,
      nodePtr: number,
      propLen: number,
      propOffset: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      if (typeof node[prop] === 'function')
        encoder.string(rawResult, node[prop]());
      else encoder.string(rawResult, node[prop]);
    },
    Object_Getter__int: (
      nodePtr: number,
      propLen: number,
      propOffset: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      if (typeof node[prop] === 'function') return node[prop]();
      else return node[prop];
    },
    Object_Getter__uint: (
      nodePtr: number,
      propLen: number,
      propOffset: number
    ) => {
      return jsExports.env.Object_Getter__int(nodePtr, propLen, propOffset);
    },
    Object_Getter__ushort: (
      nodePtr: number,
      propLen: number,
      propOffset: number
    ) => {
      return jsExports.env.Object_Getter__int(nodePtr, propLen, propOffset);
    },
    Object_Getter__bool: (
      nodePtr: number,
      propLen: number,
      propOffset: number
    ) => {
      return jsExports.env.Object_Getter__int(nodePtr, propLen, propOffset);
    },
    Object_Getter__float: (
      nodePtr: number,
      propLen: number,
      propOffset: number
    ) => {
      return jsExports.env.Object_Getter__int(nodePtr, propLen, propOffset);
    },
    Object_Getter__double: (
      nodePtr: number,
      propLen: number,
      propOffset: number
    ) => {
      return jsExports.env.Object_Getter__int(nodePtr, propLen, propOffset);
    },

    Object_Call_uint__Handle: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      arg: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      return libwasm.addObject(node[prop](arg));
    },
    Object_Call_int__Handle: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      arg: number
    ) => {
      return jsExports.env.Object_Call_uint__Handle(
        nodePtr,
        propLen,
        propOffset,
        arg
      );
    },
    Object_Call_bool__Handle: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      arg: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      return libwasm.addObject(node[prop](arg));
    },
    Object_Call_uint__string: (
      rawResult: number,
      nodePtr: number,
      propLen: number,
      propOffset: number,
      arg: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      encoder.string(rawResult, node[prop](arg));
    },
    Object_Call_handle__Handle: (
      nodePtr: number,
      propLen: number,
      propOffset: number,
      handle: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      return libwasm.addObject(node[prop](libwasm.objects[handle]));
    },
    Object_Call_uint_uint__string: (
      rawResult: number,
      nodePtr: number,
      propLen: number,
      propOffset: number,
      arg: number,
      arg2: number
    ) => {
      let node = libwasm.objects[nodePtr];
      let prop = decoder.string(propLen, propOffset);
      encoder.string(rawResult, node[prop](arg, arg2));
    },
  },
};

if (process.env.NODE_ENV === 'development') {
  let reloading = false;
  async function reload(state: any, heapi32u: any) {
    const root = document.querySelector('#root');
    // TODO: how do we handle outstanding setTimeout or other schedule functions?
    // For now we assume the same callbacks will be available in the reloaded module
    // but that may not be the case.
    _.forEachRight(libwasm.objects, (obj: Element, i: number) => {
      if (i <= 2) return;
      if (libwasm.objects[i].remove) libwasm.objects[i].remove();
      delete libwasm.objects[i];
    });
    _.forEach(root?.children, (child: Element) => {
      child.remove();
    });
    root?.remove();
    document.body
      .appendChild(document.createElement('div'))
      .setAttribute('id', 'root');
    delete libwasm.exports.instance;
    delete libwasm.instance;
    libwasm.exports.instance = null;
    libwasm.exports = null;
    globalThis.gc?.();
    const { modules } = await import('./index.ts');
    libwasm.init(modules, () => {
      encoder.string(0, state, heapi32u);
      libwasm.instance.exports.loadApp(heapi32u[0], heapi32u[1]);
      reloading = false;
    });
  }
  const ws = new WebSocket('ws://localhost:3001');
  ws.onmessage = async function (event) {
    if (event.data == 'full-reload') (window as any).location.reload();
    if (event.data == 'reload') {
      if (reloading) return;
      reloading = true;
      if (
        !libwasm.instance.exports.dumpApp ||
        !libwasm.instance.exports.loadApp
      ) {
        console.debug('Cannot find dumpApp/loadApp functions in the module');
        return;
      }
      libwasm.instance.exports.dumpApp(0);
      const heapi32u = new Uint32Array(libwasm.memory.buffer);
      let len = 0;
      let offset = heapi32u[1];
      len = heapi32u[0];
      let state = String(decoder.string(len, offset));
      reload(state, heapi32u);
    }
  };
}
