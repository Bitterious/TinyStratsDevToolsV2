export type TSConnection = {
	Valid: boolean,
	Disconnect: (self:TSConnection) -> ()
}
export type TSSignal = {
	Connect: (self:TSSignal, fn:(...any)->()) -> TSConnection
}
local function create_signal(): (TSSignal, (...any) -> ())
	local internal_connected = {}
	local signal = {}
	function signal:Connect(fn:(...any)->())
		local connection = {
			Valid = true,
			Function = fn,
		}
		function connection:Disconnect()
			assert(connection.Valid)
			connection.Valid = false
			internal_connected[connection] = nil
		end
		internal_connected[connection] = true
		return connection
	end
	local function emit(...)
		local varargs = {...}
		for fn, valid in internal_connected do
			pcall(coroutine.wrap(fn.Function), table.unpack(varargs))
		end
	end
	return signal, emit
end

return create_signal