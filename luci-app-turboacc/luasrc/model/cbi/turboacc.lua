local kernel_version = luci.sys.exec("echo -n $(uname -r)")

local function read_proc_config()
	local config = luci.sys.exec("zcat /proc/config.gz 2>/dev/null")
	if not config or config == "" then
		return ""
	end
	return config
end

local function qdisc_supported(config, symbol)
	return config:find("CONFIG_NET_SCH_" .. symbol .. "=y", 1, true)
		or config:find("CONFIG_NET_SCH_" .. symbol .. "=m", 1, true)
end

local function collect_qdiscs()
	local config = read_proc_config()
	local candidates = {
		{ name = "cake", symbol = "CAKE" },
		{ name = "fq_codel", symbol = "FQ_CODEL" },
		{ name = "fq", symbol = "FQ" },
		{ name = "fq_pie", symbol = "FQ_PIE" },
		{ name = "codel", symbol = "CODEL" },
		{ name = "pie", symbol = "PIE" },
		{ name = "sfq", symbol = "SFQ" },
	}
	local qdiscs = {}

	for _, item in ipairs(candidates) do
		if qdisc_supported(config, item.symbol) then
			qdiscs[#qdiscs + 1] = item.name
		end
	end

	if #qdiscs == 0 then
		qdiscs = { "fq_codel", "cake" }
	end

	return qdiscs
end

local function collect_ifaces()
	local ifaces = {}

	for name in nixio.fs.dir("/sys/class/net") do
		if name ~= "lo" then
			ifaces[#ifaces + 1] = name
		end
	end

	table.sort(ifaces)
	return ifaces
end

m = Map("turboacc")
m.title	= translate("Turbo ACC Acceleration Settings")
m.description = translate("Opensource Flow Offloading driver (Fast Path or Hardware NAT)")

m:append(Template("turboacc/turboacc_status"))

s = m:section(TypedSection, "turboacc", "")
s.addremove = false
s.anonymous = true

-- nftables: nft_flow_offload is built-in mod
if nixio.fs.access("/lib/modules/" .. kernel_version .. "/nft_flow_offload.ko") then
sw_flow = s:option(Flag, "sw_flow", translate("Software flow offloading"))
sw_flow.default = 0
sw_flow.description = translate("Software based offloading for routing/NAT")
sw_flow:depends("sfe_flow", 0)
end

if luci.sys.call("cat /etc/openwrt_release | grep -Eq 'filogic|mt762' ") == 0 then
hw_flow = s:option(Flag, "hw_flow", translate("Hardware flow offloading"))
hw_flow.default = 0
hw_flow.description = translate("Requires hardware NAT support, implemented at least for mt762x")
hw_flow:depends("sw_flow", 1)
end

if luci.sys.call("cat /etc/openwrt_release | grep -Eq 'mediatek' ") == 0 then
if nixio.fs.access("/lib/modules/" .. kernel_version .. "/mt7915e.ko") then
hw_wed = s:option(Flag, "hw_wed", translate("MTK WED WO offloading"))
hw_wed.default = 0
hw_wed.description = translate("Requires hardware support, implemented at least for Filogic 8x0")
hw_wed:depends("hw_flow", 1)
end
end

if nixio.fs.access("/lib/modules/" .. kernel_version .. "/shortcut-fe-cm.ko")
or nixio.fs.access("/lib/modules/" .. kernel_version .. "/fast-classifier.ko")
then
sfe_flow = s:option(Flag, "sfe_flow", translate("Shortcut-FE flow offloading"))
sfe_flow.default = 0
sfe_flow.description = translate("Shortcut-FE based offloading for routing/NAT")
sfe_flow:depends("sw_flow", 0)
end

-- nftables
if nixio.fs.access("/lib/modules/" .. kernel_version .. "/nft_fullcone.ko") then
fullcone_nat = s:option(Flag, "fullcone_nat", translate("FullCone NAT"))
fullcone_nat.default = 0
fullcone_nat.description = translate("Using FullCone NAT can improve gaming performance effectively")
fullcone6 = s:option(Flag, "fullcone6", translate("IPv6 Full Cone NAT"))
fullcone6.default = 0
fullcone6.description = translate("Enabling IPv6 Full Cone NAT adds an extra layer of NAT to IPv6. In IPv6, if you obtain an IPv6 prefix through IPv6 Prefix Delegation, each device can be assigned a public IPv6 address, eliminating the need for IPv6 Full Cone NAT.")
fullcone6:depends("fullcone_nat", 1)
end

if nixio.fs.access("/lib/modules/" .. kernel_version .. "/tcp_bbr.ko") then
bbr_cca = s:option(Flag, "bbr_cca", translate("BBR CCA"))
bbr_cca.default = 0
bbr_cca.description = translate("Using BBR CCA can improve TCP network performance effectively")

default_qdisc = s:option(ListValue, "default_qdisc", translate("Default qdisc"))
default_qdisc.default = "fq_codel"
default_qdisc.rmempty = false
default_qdisc.description = translate("Set net.core.default_qdisc for new interfaces. If interfaces are selected below, apply it immediately with tc.")
for _, qdisc in ipairs(collect_qdiscs()) do
	default_qdisc:value(qdisc, qdisc)
end
default_qdisc:depends("bbr_cca", 1)

default_qdisc_ifaces = s:option(DynamicList, "default_qdisc_ifaces", translate("Apply qdisc to interfaces now"))
default_qdisc_ifaces.placeholder = translate("Select interfaces")
default_qdisc_ifaces.description = translate("Choose the network interfaces that should receive the qdisc immediately. New interfaces still follow net.core.default_qdisc.")
for _, ifname in ipairs(collect_ifaces()) do
	default_qdisc_ifaces:value(ifname, ifname)
end
default_qdisc_ifaces:depends("bbr_cca", 1)
end

return m
