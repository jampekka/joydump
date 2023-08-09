
{Dexie} = require 'dexie'
$ = require 'jquery'
flatobj = require('./flatobj.coffee')
JSZip = require 'jszip'
{saveAs} = require 'file-saver'
console.log saveAs

gamepads = []
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

control_el = $ "#controllers"
control_els = {}
new_gamepad = (e) ->
	pad = e.gamepad
	#num = gamepads_seen; gamepads_seen += 1
	#dbid = "joydump/#{session_id}/#{num}"
	#db = new Dexie dbid
	#db.version(1).stores events: "++row"
	pad_number = gamepads.length
	gamepads.push
		pad_number: pad_number
		pad: pad
		prev_timestamp: undefined
	control_els[pad_number] = control_el.append "<div></div>"
	console.log "Joystick connected", pad

dump_gamepads = (database) ->
	unix_time = Date.now()/1000
	session_time = performance.now()
	for padinfo in gamepads
		pad = padinfo.pad
		continue if not pad.connected
		continue if pad.timestamp == padinfo.timestamp
		padinfo.timestamp = pad.timestamp

		# TODO: Check disk usage of such spam
		pad_dump = cloneProps pad
		ev =
			unix_time: unix_time
			session_time: session_time
			pad_number: padinfo.pad_number
			pad: pad_dump
		database.events.add ev
			

		control_els[padinfo.pad_number].text JSON.stringify stripped_event ev
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

	table = $ "#current_session"
	table.empty()
	current = table.append """<tr>
		<td>
			<button class="btn btn-primary" type="button" onclick="javascript:download_database('#{session_id}')">
			<i class="bi bi-download"></i> Download
			</button>
			</td>
			<td>#{session_id}</td>
			<td>
			</td>
		</tr>"""
	table = $ "#old_sessions"
	table.empty()
	for name in names
		continue if name == session_id
		table.append """
			<tr>
				<td>
				<button class="btn btn-primary" type="button" onclick="javascript:download_database('#{name}')">
			<i class="bi bi-download"></i> Download
			</button>
				</td>
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

window.download_database = (dbid) ->
	db = await new Dexie(dbid).open()
	table = db.table "events"
	
	pad_data = {}

	for ev in await table.toArray()
		row = stripped_event ev

		[header, row] = flatobj.flatobj row
		header = (h.substring(1).replaceAll('.', '_') for h in header).join(",")
		row = row.join(",")
		
		pad_id = "#{ev.pad.id}-#{ev.pad_number}"
		if pad_id not of pad_data
			pad_data[pad_id] =
				rows: []
				header: header
		data = pad_data[pad_id]
		
		if header != data.header
			error "Data header mismatch! Contact Jami!"
		
		data.rows.push row
		
	if Object.keys(pad_data).length == 0
		error "No data in this session"
	
	output = new JSZip()

	for pad_id, data of pad_data
		d = header + "\n" + data.rows.join("\n")
		output.file pad_id + ".csv", d
	content = await output.generateAsync type: "blob", compression: "DEFLATE"
	saveAs content, "#{dbid}.zip"

window.remove_database = (dbid) ->
	await Dexie.delete dbid
	await list_databases()

do ->
	#console.log new Date()
	console.log session_id
	database = new Dexie session_id
	database.version(1).stores events: "++row"
	await database.open()
	await list_databases()

	window.addEventListener "gamepadconnected", new_gamepad
	dumper = -> dump_gamepads database
	setInterval dumper, 10
	#usage = await navigator.storage.estimate()
