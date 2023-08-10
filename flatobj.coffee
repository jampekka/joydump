# Flatten object to a list

_is_object = (obj) -> obj == Object obj

flatobj_ = (obj, me="") ->
	if not _is_object obj
		yield [me, obj]
		return
	names = (name for name of obj)
	names.sort()
	for name in names
		n = "#{me}.#{name}"
		yield from flatobj_(obj[name], n)

flatobj = (obj) ->
	names = []
	values = []
	for [name, value] from flatobj_(obj)
		names.push name
		values.push value
	return [names, values]
module.exports = flatobj

###
console.log "Here"
console.log flatobj 1

console.log Array.from flatobj
	foo: "bar"
	array: [1,2,3]
	integer: 69
	nested:
		foo: "nestbar"
		array: [3,4,5]
###

