flatobj = require('./flatobj.coffee')


```


function propdump(o) {
	if(typeof o !== "object") {
		return o;
	}
	let d = {};
	for(const prop in o) {
		d[prop] = propdump(o[prop]);
	}
	return d;
}

let controller_elements = {};
let prev_events = {};

let log = [];

function dump_joys() {
	for(let pad of navigator.getGamepads()) {
		dump_joy(pad);
	}
}

/*window.addEventListener(
	"gamepadconnected",
	(e) => {
		console.log("Here!");
		console.log(JSON.stringify(propdump(e.gamepad)));
	}
);*/

```

loggers = {}

dump_joy = (pad) ->
	return if prev_events[pad.index] == pad.timestamp
	
	unix_time = Date.now()/1000
	logger = loggers[pad.index]
	if not logger
		handle = await logdir.getFileHandle "#{pad.index}-#{pad.id}.jsons", create: true
		logger = await handle.createWritable keepExistingData: true
		loggers[pad.index] = logger

	prev_events[pad.index] = pad.timestamp
	d = propdump(pad)
	d.unix_time = unix_time
	
	wtf = await logger.write JSON.stringify(d)
	el = controller_elements[pad.index]
	if not el
		el = document.createElement("div")
		document.getElementById("controllers").append(el)
		controller_elements[pad.index] = el

	el.innerHTML = JSON.stringify(flatobj.flatobj(d))

window.download = () ->
	output = new JSZip()
	for await [name, fh] from logdir.entries()
		f = await fh.getFile()
		c = await f.text()
		output.file name, c
	
	content = await output.generateAsync type: "blob", compression: "DEFLATE"
	saveAs content, "joydump-#{session_id}.zip"
	###
	console.log("download");
	//let jsonBlob = new Blob([JSON.stringify(log)], { type: 'application/javascript;charset=utf-8' });
	let datestr = (new Date()).toISOString();
	let filebase = "joydump-" + datestr;
	output.file(filebase + ".json", JSON.stringify(log));
	output.generateAsync({type: "blob", compression: "DEFLATE"})
	.then((content) => {
		saveAs(content, filebase+".zip");
	});
	###

logdir = null
session_id = null
do ->
	if not navigator.storage.getDirectory
		error "Your browser doesn't support the File System Access API. Please uprage your browser."
		return
	

	session_id = (new Date()).toISOString()
	root = await navigator.storage.getDirectory()
	logsdir = await root.getDirectoryHandle "joydump", create: true
	
	#testhandle = await logsdir.getFileHandle "test", create: true
	#readable = await testhandle.getFile()
	#console.log "Contents", await readable.text()
	#writable = await testhandle.createWritable keepExistingData: true
	#console.log writable
	#await writable.write("Foo\n")
	
	logdir = await logsdir.getDirectoryHandle session_id, create: true
	
	setInterval(dump_joys, 10)
