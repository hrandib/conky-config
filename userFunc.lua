require 'cairo'

conky_start = 1
processor = ''
distribution = ''
mounted_media = ''
cpus = -1
active_network_interface = false
fan = 0
ctemp = 0

-- Conky main function
function conky_main()
    if conky_window == nil then
        return
    end
    local cs = cairo_xlib_surface_create(conky_window.display,
                                         conky_window.drawable,
                                         conky_window.visual,
                                         conky_window.width,
                                         conky_window.height)
    cr = cairo_create(cs)
    
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    cr=nil
end

function lines(s)
    if s:sub(-1)~="\n" then s=s.."\n" end
    return s:gmatch("(.-)\n")
end

-- Returns processor name
function conky_processor()
    if processor == '' then
        local file = io.popen("lscpu | grep -Po '(?<=Model name:)(.*)'")
        processor = trim(file:read("*a"))
        file:close()
    end

    return processor
end

-- Returns distribution name
function conky_distribution()
    if distribution == '' then
        local file = io.popen('cat /etc/lsb-release | grep -Po --regexp "(?<=DISTRIB_ID=).*$"')
        distribution = trim(file:read("*a"))
        file:close()
        file = io.popen('cat /etc/lsb-release | grep -Po --regexp "(?<=DISTRIB_RELEASE=).*$"')
        distribution = distribution .. " " .. trim(file:read("*a"))
        file:close()
    end

    return distribution
end

-- Draws max n mounted partitions and its stats
function conky_mountmedia(n)
    if tonumber(conky_parse("$updates")) % 2 == 0 then
        local file = io.popen('lsblk | grep -oE ".*sd.* part /.*" | grep -oE "(/.*)"')
        local all_media = file:read("*a")
        file:close()
        local count = 1
        local media = ''
        for line in lines(all_media) do
            line = trim(line)
            local short_name = string.sub(string.sub(line, string.find(line, '/[^/]*$')), 1)
            local start, finish = string.find(short_name, '%S+%s%S+')
            if start ~= nil then
                short_name = string.sub(short_name, 1, finish)
            end
            if count <= tonumber(n) then
                media = media
                        .. "${goto 10}".. short_name .. "${goto  150}${fs_bar 7,70 " .. line
                        .. "}${goto 255}${fs_used " .. line .. "}/${fs_size " .. line .. "}"
                        .. "\n"
            else
                break
            end
            count = count + 1
        end
        mounted_media = media
        return media
    end 
        return mounted_media
end

-- Draws all cpu cores stats
function conky_drawcpus()
    if cpus == -1 or tonumber(conky_parse("$updates")) % 2 == 0 then
        local file = io.popen("lscpu -a -p='cpu' | tail -n 1")
        local ncpu = trim(file:read("*a"))
        file:close()
    
        local conky_cpus = ''
        for c = 1, tonumber(ncpu)  do
            if c % 2 ~= 0 then
                conky_cpus = conky_cpus
                             .. "${goto 20}" .. c ..": ${goto 42}${cpu cpu".. c
                             .."}%${goto 90}${cpubar 7,30 cpu".. c
                             .."}${goto 130}${freq_g ".. c
                             .."}GHz${goto 200}| ".. c+1 
                             ..":${goto 240}${cpu cpu".. c+1
                             .."}%${goto 285}${cpubar 7,30 cpu".. c+1 .."}${goto 325}${freq_g ".. c+1 .."}GHz"
                             .. "\n"
            end
        end
        cpus = conky_cpus
        return conky_cpus
    end
    return cpus   
end

-- Draws max n network interfaces
function conky_drawnetworks(n)
    local active_ifaces = {}
    if active_network_interface == false or tonumber(conky_parse("$updates")) % 2 == 0 then
        local ifaces = io.popen('ip link | grep -Po --regexp "(?<=[0-9]: ).*"')
        for line in ifaces:lines() do
            if string.find(line, "<BROADCAST") then
                local iface = string.gsub(string.match(line, "^.*:"), ":", "")
                table.insert( active_ifaces, iface)
            end
        end
        ifaces:close()
        if table.maxn(active_ifaces) >= 1 then
            local draw_other_ifaces = '${goto 10}${font FontAwesome}${font} ${color #00FF00}Network Interfaces $color \n'
            for i, iface in pairs(active_ifaces) do
                if i <= tonumber(n) then
                    draw_other_ifaces = draw_other_ifaces
                                        .. "${goto 20}".. i ..". "
                                        .. iface .." "..  "${font FontAwesome} ${font}${voffset 0} ${addrs " .. iface ..  "}" .. "\n"
                                        .. "${goto 20}${upspeedgraph " .. iface ..  " 20,175 00ffff 00ff00}${goto 202}${downspeedgraph "
                                        .. iface ..  " 20,175 FFFF00 DD3A21}" .. "\n"
                                        .. "${font FontAwesome}${goto 50}${font} ${upspeed "
                                        .. iface ..  "}${font FontAwesome}${goto 250}${font} ${downspeed " .. iface ..  "}" .. "\n"
                    if i < table.maxn( active_ifaces ) and i ~= tonumber(n) then
                        draw_other_ifaces = draw_other_ifaces .. "${goto 20}${stippled_hr 1}\n"
                    end
                end
            end
            active_network_interface = draw_other_ifaces
            return active_network_interface
        else
            return '${goto 10}${font FontAwesome}${font} ${color #00FF00}Network Interfaces $color \n${goto 50} Device not connected.\n'
        end
    end
    return active_network_interface
end

-- Returns CPU temperature in Celsius
function conky_cputemp()
    if tonumber(conky_parse("$updates")) % 2 == 0 or ctemp == 0 then
        local file = io.popen('ls -1 /sys/class/hwmon/hwmon?/name')
        all_hwmon_temp_names = file:read("*a")
        file:close()
        local cpu_temp_file = ''
        for l in lines(all_hwmon_temp_names) do
            file = io.popen('cat ' .. l)
            local name = file:read("*a")
            file:close()
            if name:match("^k10temp*") then
                cpu_temp_file = l:gsub("name", "temp1_input")
                break
            end
        end
        cpu_temp_file = io.open(cpu_temp_file, "r")
        local cpu_temp = math.floor((tonumber(cpu_temp_file:read("*a"))  / 1000) + 0.5)
        cpu_temp_file:close()
        ctemp = cpu_temp
        return cpu_temp
    end
    return ctemp
end

-- Trims given string and returns
function trim(s)
   return s:gsub("^%s+", ""):gsub("%s+$", "")
end
