module("luci.controller.turboacc", package.seeall)

local uci = require("luci.model.uci").cursor()

local function trim(s)
	if not s then
		return ""
	end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function read_file(path)
	local fp = io.open(path, "r")
	if not fp then
		return ""
	end

	local data = fp:read("*a") or ""
	fp:close()
	return trim(data)
end

local function get_selected_ifaces()
	local cfg = uci:get_all("turboacc", "config") or {}
	local ifaces = {}
	local values = cfg.default_qdisc_ifaces

	local function add_iface(name)
		if type(name) == "string" and name ~= "" then
			ifaces[#ifaces + 1] = name
		end
	end

	if type(values) == "table" then
		for _, name in ipairs(values) do
			add_iface(name)
		end
	else
		add_iface(values)
	end

	table.sort(ifaces)
	return ifaces
end

local function get_iface_qdisc(iface)
	if type(iface) ~= "string" or not iface:match("^[%w%._:@%-]+$") then
		return {
			iface = iface or "",
			status = "invalid",
			line = "",
		}
	end

	if not nixio.fs.access("/sys/class/net/" .. iface) then
		return {
			iface = iface,
			status = "missing",
			line = "",
		}
	end

	local line = trim(luci.sys.exec("tc qdisc show dev " .. iface .. " 2>/dev/null"))
	local qdisc = line:match("^qdisc%s+(%S+)")

	return {
		iface = iface,
		status = qdisc or "unknown",
		line = line,
	}
end

function index()
	if not nixio.fs.access("/etc/config/turboacc") then
		return
	end
	local page
	page = entry({"admin", "network", "turboacc"}, cbi("turboacc"), _("Turbo ACC Center"), 101)
	page.i18n = "turboacc"
	page.dependent = true
	
	entry({"admin", "network", "turboacc", "status"}, call("action_status"))
end

local function fastpath_status()
	return luci.sys.call("/etc/init.d/turboacc check_status fastpath 0") == 0
end

local function bbr_status()
	return luci.sys.call("/etc/init.d/turboacc check_status bbr") == 0
end

local function fullconenat_status()
	return luci.sys.call("/etc/init.d/turboacc check_status fullconenat") == 0
end

function action_status()
	local ifaces = get_selected_ifaces()
	local iface_states = {}

	for _, iface in ipairs(ifaces) do
		iface_states[#iface_states + 1] = get_iface_qdisc(iface)
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		fastpath_state = fastpath_status(),
		fullconenat_state = fullconenat_status(),
		bbr_state = bbr_status(),
		tcp_congestion_control = read_file("/proc/sys/net/ipv4/tcp_congestion_control"),
		default_qdisc = read_file("/proc/sys/net/core/default_qdisc"),
		default_qdisc_ifaces = ifaces,
		iface_qdisc_states = iface_states,
	})
end
