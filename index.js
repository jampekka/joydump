(() => {
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __esm = (fn, res) => function __init() {
    return fn && (res = (0, fn[__getOwnPropNames(fn)[0]])(fn = 0)), res;
  };
  var __commonJS = (cb, mod) => function __require() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

  // flatobj.coffee
  var flatobj_exports = {};
  __export(flatobj_exports, {
    flatobj: () => flatobj
  });
  var _is_object, flatobj_, flatobj;
  var init_flatobj = __esm({
    "flatobj.coffee"() {
      _is_object = function(obj) {
        return obj === Object(obj);
      };
      flatobj_ = function* (obj, me = "") {
        var i, len, n, name, names, results;
        if (!_is_object(obj)) {
          yield [me, obj];
          return;
        }
        names = function() {
          var results2;
          results2 = [];
          for (name in obj) {
            results2.push(name);
          }
          return results2;
        }();
        names.sort();
        results = [];
        for (i = 0, len = names.length; i < len; i++) {
          name = names[i];
          n = `${me}.${name}`;
          results.push(yield* flatobj_(obj[name], n));
        }
        return results;
      };
      flatobj = function(obj) {
        var name, names, ref, value, values, x;
        names = [];
        values = [];
        ref = flatobj_(obj);
        for (x of ref) {
          [name, value] = x;
          names.push(name);
          values.push(value);
        }
        return [names, values];
      };
    }
  });

  // index.coffee
  var require_joydump = __commonJS({
    "index.coffee"(exports) {
      (function() {
        var dump_joy, flatobj2, logdir, loggers, session_id;
        flatobj2 = (init_flatobj(), __toCommonJS(flatobj_exports));
        function propdump(o) {
          if (typeof o !== "object") {
            return o;
          }
          let d = {};
          for (const prop in o) {
            d[prop] = propdump(o[prop]);
          }
          return d;
        }
        let controller_elements = {};
        let prev_events = {};
        let log = [];
        function dump_joys() {
          for (let pad of navigator.getGamepads()) {
            dump_joy(pad);
          }
        }
        ;
        loggers = {};
        dump_joy = async function(pad) {
          var d, el, handle, logger, unix_time, wtf;
          if (prev_events[pad.index] === pad.timestamp) {
            return;
          }
          unix_time = Date.now() / 1e3;
          logger = loggers[pad.index];
          if (!logger) {
            handle = await logdir.getFileHandle(`${pad.index}-${pad.id}.jsons`, {
              create: true
            });
            logger = await handle.createWritable({
              keepExistingData: true
            });
            loggers[pad.index] = logger;
          }
          prev_events[pad.index] = pad.timestamp;
          d = propdump(pad);
          d.unix_time = unix_time;
          wtf = await logger.write(JSON.stringify(d));
          el = controller_elements[pad.index];
          if (!el) {
            el = document.createElement("div");
            document.getElementById("controllers").append(el);
            controller_elements[pad.index] = el;
          }
          return el.innerHTML = JSON.stringify(flatobj2.flatobj(d));
        };
        window.download = async function() {
          var c, content, f, fh, name, output, ref, x;
          output = new JSZip();
          ref = logdir.entries();
          for await (x of ref) {
            [name, fh] = x;
            f = await fh.getFile();
            c = await f.text();
            output.file(name, c);
          }
          content = await output.generateAsync({
            type: "blob",
            compression: "DEFLATE"
          });
          return saveAs(content, `joydump-${session_id}.zip`);
        };
        logdir = null;
        session_id = null;
        (async function() {
          var logsdir, root;
          if (!navigator.storage.getDirectory) {
            error("Your browser doesn't support the File System Access API. Please uprage your browser.");
            return;
          }
          session_id = (/* @__PURE__ */ new Date()).toISOString();
          root = await navigator.storage.getDirectory();
          logsdir = await root.getDirectoryHandle("joydump", {
            create: true
          });
          logdir = await logsdir.getDirectoryHandle(session_id, {
            create: true
          });
          return setInterval(dump_joys, 10);
        })();
      }).call(exports);
    }
  });
  require_joydump();
})();
//# sourceMappingURL=index.js.map
