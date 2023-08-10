
{Dexie} = require 'dexie'
$ = require 'jquery'
flatobj = require('./flatobj.coffee')
JSZip = require 'jszip'
{saveAs} = require 'file-saver'
console.log saveAs

gamepads = {}
gamepads_seen = 0
session_base = "joydump-"
session_id = session_base + (new Date()).toISOString()

_is_object = (obj) -> obj == Object obj

cloneProps = (o) ->
	if not _is_object o
		return o
	d = {}
	for prop of o
		d[prop] = cloneProps(o[prop])
	return d

# This may not be unique per session in some very weird setups
get_pad_id = (pad) ->
	return "#{pad.id}-#{pad.index}"

control_el = $ "#controllers"
control_els = {}
new_gamepad = (pad) ->
	#pad = e.gamepad
	pad_id = get_pad_id pad
	gamepads[pad_id] =
		pad_id: pad_id
		pad: pad # This seems to get stale on chrome!
		timestamp: undefined
	control_el.append "<b>#{pad_id}</b>"
	control_els[pad_id] = $("<pre class='controller'></pre>").appendTo control_el
	console.log "Joystick connected", pad

fake_pad = ->
	buttons = for i in [0...30]
		value: (Math.random() > 0.5) + 0
	axes = for i in [0...4]
		(Math.random() - 0.5)*2


	id: "Totally fake gamepad"
	timestamp: Math.round(performance.now()/1000)*1000
	buttons: buttons
	axes: axes
	connected: true

_gamepad_viz_els = {}
_new_gamepad_viz_el = (pad, pad_id) ->
	el = $("<div class='gamepad_viz'>").appendTo $("#controllers")
	console.log pad_id
	el.append "<b>#{pad_id}</b>"
	container = $("<div class='control_value_container'>").appendTo el

	"""
	table = $("<table class='table'>").appendTo el
	headers = $("<tr>").appendTo $("<thead class='table-dark'>").appendTo table
	values = $("<tr>").appendTo table
	axis_els = for _, i in pad.axes
		headers.append "<th>A#{i}</th>"
		$("<td>").appendTo(values)

	button_els = for _, i in pad.buttons
		headers.append "<th>B#{i}</th>"
		$("<td>").appendTo(values)
	_gamepad_viz_els[pad_id] =
		axes: axis_els
		buttons: button_els
	"""

gamepad_viz = (pad) ->
	pad_id = get_pad_id pad
	if pad_id not of _gamepad_viz_els
		_new_gamepad_viz_el(pad, pad_id)
	
	els = _gamepad_viz_els[pad_id]
	for v, i in pad.axes
		els.axes[i].text v.toFixed 3
	for b, i in pad.buttons
		els.buttons[i].text b.value

getGamepads = ->
	pads = navigator.getGamepads()

	#fake = fake_pad()
	#fake.index = pads.length + 1
	#pads = pads.concat([fake])

	return pads


dump_gamepads = (database) ->
	unix_time = Date.now()/1000
	session_time = performance.now()
	for pad in getGamepads()
		continue if not pad
		pad_id = get_pad_id pad
		if pad_id not of gamepads
			new_gamepad pad

		padinfo = gamepads[pad_id]
		continue if not pad.connected
		continue if pad.timestamp == padinfo.timestamp
		padinfo.timestamp = pad.timestamp

		# TODO: Check disk usage of such spam
		pad_dump = cloneProps pad
		ev =
			unix_time: unix_time
			session_time: session_time
			pad_id: padinfo.pad_id
			pad: pad_dump
		database.events.add ev
		
		text = "Axes: " + (v.toFixed(2) for v in pad.axes).join "\t"
		text += " Buttons: " + (v.value for v in pad.buttons).join " "
		control_els[pad_id].text text
		#gamepad_viz pad
	#usage = await navigator.storage.estimate()
	#console.log usage.usage/1e6
	return

get_databases = ->
	names = await Dexie.getDatabaseNames()
	names.sort()
	names.reverse()
	
	return names.filter (n) -> n.startsWith session_base


list_databases = ->
	# TODO: The newest isn't necessarily this session
	names = await get_databases()
	
	dl_button = (name) ->
		"""
		<button class="btn btn-primary" type="button" onclick="javascript:download_database('#{name}')">
			<i class="bi bi-filetype-csv"></i> CSV
		</button>
		<button class="btn btn-primary" type="button" onclick="javascript:dump_database('#{name}')">
			<i class="bi bi-filetype-json"></i>LDJSON
		</button>
		
		"""


	table = $ "#current_session"
	table.empty()
	current = table.append """<tr>
			<td>#{dl_button(session_id)}</td>
			<td>#{session_id}</td>
			<td>
				Current session
			</td>
		</tr>"""
	table = $ "#old_sessions"
	table.empty()
	for name in names
		continue if name == session_id
		table.append """
			<tr>
				<td>#{dl_button(name)}</td>
				<td>#{name}</td>
				<td>
				<button class="btn btn-danger" type="button" onclick="javascript:remove_database('#{name}')">
			<i class="bi bi-trash"></i> Delete
			</button>
				</td>
			</tr>
			"""

delete_old_databases = ->

error = (msg) ->
	alert msg
	throw "Stop the show!"

stripped_event = (ev) ->
	row =
		unix_time: ev.unix_time
		session_time: ev.session_time
		pad_time: ev.pad.timestamp
		axes: ev.pad.axes
		buttons: (v.value for n, v of ev.pad.buttons)
		mapping: ev.pad.mapping
	return row

objects2csv = (objs) ->
	output_header = null
	output = ""
	for row in objs
		[hdr, values] = flatobj row
		unless output_header?
			csvheader = header = (h.substring(1).replaceAll('.', '_') for h in hdr).join(",")
			output_header = csvheader
			output += csvheader + "\n"
		csvrow = values.join(",")
		output += csvrow + "\n"
	return output

window.download_database = (dbid) ->
	db = await new Dexie(dbid).open()
	table = db.table "events"
	
	pad_data = {}
	
	rows = await table.toArray()
	for ev in rows
		row = stripped_event ev

		pad_id = ev.pad_id
		if pad_id not of pad_data
			pad_data[pad_id] = []
		
		pad_data[pad_id].push row
		
	if Object.keys(pad_data).length == 0
		error "No data in this session"
	
	output = new JSZip()

	for pad_id, data of pad_data
		#d = header + "\n" + data.rows.join("\n")
		csv = objects2csv data
		output.file pad_id + ".csv", csv
	content = await output.generateAsync type: "blob", compression: "DEFLATE"
	saveAs content, "#{dbid}.zip"

window.dump_database = (dbid) ->
	# TODO: No copypaste!
	db = await new Dexie(dbid).open()
	table = db.table "events"
	
	pad_data = {}
	console.log "Loading json", dbid
	for ev in await table.toArray()
		pad_id = ev.pad_id
		if pad_id not of pad_data
			pad_data[pad_id] = ""
		
		row = stripped_event ev
		pad_data[pad_id] += JSON.stringify(row) + "\n"
		
	if Object.keys(pad_data).length == 0
		error "No data in this session"
	
	output = new JSZip()

	for pad_id, data of pad_data
		output.file pad_id + ".jsons", data
	content = await output.generateAsync type: "blob", compression: "DEFLATE"
	saveAs content, "#{dbid}-jsons.zip"



window.remove_database = (dbid) ->
	await Dexie.delete dbid
	await list_databases()

update_data_usage = ->
	usage = await navigator.storage.estimate()
	mb = usage.usage/1e6
	percentage = (usage.usage/usage.quota)*100
	$("#data_usage").text "#{percentage.toFixed 1}% (#{mb.toFixed 1}MB)"

do ->
	console.log session_id
	database = new Dexie session_id
	database.version(1).stores events: "++row"
	await database.open()

	await list_databases()
	
	#window.addEventListener "gamepadconnected", new_gamepad
	dumper = -> dump_gamepads database
	setInterval dumper, 10
	setInterval update_data_usage, 100
	#usage = await navigator.storage.estimate()
