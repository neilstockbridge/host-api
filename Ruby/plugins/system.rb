# encoding: utf-8
#
# Copyright (C) 2011-2013 Neil Stockbridge
# License: GPLv2

require "socket"


class Array

  def first_where
    self.each do |item|
      return item if yield item
    end
    nil
  end

end


module System

  NAMESPACE = "com.example.System"

  PARAMS_OF_METHOD = {
    "memory" =>                   %w||,
    "sensors" =>                  %w||,
    "operating_system" =>         %w||,
    "system_load" =>              %w||,
    "time" =>                     %w||,
    "file_systems" =>             %w||,
    "disc_usage" =>               %w|path_to_dir|,
    "lvm" =>                      %w||,
    "packages_awaiting_update" => %w||,
  }

  class << self

  #/proc/meminfo:
  #MemTotal:        3996248 kB
  #MemFree:            8452 kB
  #Buffers:            4408 kB
  #Cached:            78380 kB
  #SwapTotal:      524280 kB
  #SwapFree:       378036 kB
  def memory
    installed, idle, available, swap_capacity, swap_free = nil
    `egrep '^(MemTotal|MemFree|Buffers|Cached|SwapTotal|SwapFree):' /proc/meminfo`.each_line do |line|
      metric, value, units = line.split /[: ]+/
      case metric
        when "MemTotal"
          installed = value.to_i
        when "MemFree"
          idle = value.to_i
          available ||= 0
          available += idle
        when "Buffers", "Cached"
          available ||= 0
          available += value.to_i
        when "SwapTotal"
          swap_capacity = value.to_i
        when "SwapFree"
          swap_free = value.to_i
      end
    end
    humanized = lambda do |number|
      ( number / 1024.0).round if number
    end
    { "installed" =>     (humanized[ installed] or "unknown"),
      "available" =>     (humanized[ available] or "unknown"),
      "idle" =>          (humanized[ idle] or "unknown"),
      "swap capacity" => (humanized[ swap_capacity] or "N/A"),
      "swap free" =>     (humanized[ swap_free] or "N/A"),
    }
  end


  def sensors

    readings = {}
    # Make a list of discs that support reporting their temperature:
    hot_discs = []

    # The sensors available will depend upon the host:
    case Socket.gethostname
      when "yourhostname"

        # Example of reading the temperature via ACPI
        line = File.read "/proc/acpi/thermal_zone/THRM/temperature"
        #temperature:             49 C
        if line.match /^temperature: +(\d+) C$/
          readings["CPU temperature"] = $1.to_i
        end

        # Example of reading coretemp via sensors
        #Core 0:      +26.0°C  (high = +80.0°C, crit = +86.0°C)
        core = {}
        output_of("sensors").each_line do |line|
          if line.match %r{^Core (\d): +\+(\d+\.\d)°C}
            core[ $1] = $2.to_f
          end
        end
        unless core.empty?
          readings["CPU temperature"] = core.values.reduce( 0.0) {|tt, rd| tt + rd} / core.values.count
        end

        # Example of reading an I2C chip via sensors
        #CPU Fan:    4115 RPM  (min = 39705 RPM, div = 2)  ALARM
        #M/B Temp:    +40.0°C  (high = +32.0°C, hyst = +20.0°C)  ALARM  sensor = thermistor
        #CPU Temp:    +71.0°C  (high = +80.0°C, hyst = +75.0°C)  sensor = thermistor
        #Physical id 0:  +33.0°C  (high = +85.0°C, crit = +105.0°C)
        #fan1:                   946 RPM  (min =    0 RPM)  ALARM
        #fan2:                  1008 RPM  (min =    0 RPM)  ALARM
        #fan3:                   964 RPM  (min =    0 RPM)  ALARM
        #SYSTIN:                 +27.0°C  (high =  +0.0°C, hyst =  +0.0°C)  ALARM  sensor = diode
        #CPUTIN:                 +28.5°C  (high = +80.0°C, hyst = +75.0°C)  sensor = diode
        #PECI Agent 0:           +31.0°C  (high = +80.0°C, hyst = +75.0°C)  sensor = Intel PECI
        output_of("sensors").each_line do |line|
          case line
            when /^CPU Fan: +(\d+) RPM/
              readings["CPU fan"] = $1.to_i
            when /^M\/B Temp: +\+(\d+\.\d)°C/
              readings["Mainboard temperature"] = $1.to_f
            when /^CPU Temp: +\+(\d+\.\d)°C/
              readings["CPU temperature"] = $1.to_f
            when /^Physical id 0: +\+(\d+\.\d)°C/
              readings["CPU temperature"] = $1.to_f
            when /^(fan\d): +(\d+) RPM/
              readings[ $1] = $2.to_i
            when /^PECI Agent 0: +\+(\d+\.\d)°C/
              readings["Mainboard temperature"] = $1.to_f
          end
        end

        hot_discs << "hda"

      when "your-other-host"
        # Example of reading IPMI
        #Baseboard Temp   | 34 degrees C      | ok
        #Basebrd FanBoost | 34 degrees C      | ok
        #FntPnl Amb Temp  | 20 degrees C      | ok
        #FP Amb FanBoost  | 20 degrees C      | ok
        #Processor1 Temp  | 28 degrees C      | ok
        #Proc1 FanBoost   | 28 degrees C      | ok
        #Power Cage Temp  | 32 degrees C      | ok
        #Power Cage Fan   | 6840 RPM          | ok
        #System Fan 3     | 4182 RPM          | ok
        #System Fan 1     | 4539 RPM          | ok
        #Proc Fan 1       | 3519 RPM          | ok
        #Hot Swap Temp    | 30 degrees C      | ok
        system_fans = []
        output_of("ipmitool -I open sdr list").each_line do |line|
          case line
            when /^FntPnl Amb Temp .* (\d+) degrees C/
              readings["Ambient temperature"] = $1.to_i
            when /^Baseboard Temp .* (\d+) degrees C/
              readings["Mainboard temperature"] = $1.to_i
            when /^Processor1 Temp .* (\d+) degrees C/
              readings["CPU temperature"] = $1.to_i
            when /^Power Cage Temp .* (\d+) degrees C/
              readings["PSU temperature"] = $1.to_i
            when /^Power Cage Fan .* (\d+) RPM/
              readings["PSU fan"] = $1.to_i
            when /^System Fan \d .* (\d+) RPM/
              system_fans << $1.to_i
            when /^Proc Fan 1 .* (\d+) RPM/
              readings["CPU fan"] = $1.to_i
          end
        end
        unless system_fans.empty?
          readings["System fan"] = system_fans.min
        end
    end

    if hot_discs != []
      command = "hddtemp "+ hot_discs.map{|d| "/dev/#{d}"}.join(" ")
      output_of( command).each_line do |line|
        if line.match /^.dev.(\w+): .+: (\d+)°C/
          readings["#{$1} temperature"] = $2.to_i
        end
      end
    end

    readings
  end


  def operating_system
    vs = File.read "/etc/debian_version"
    ubuntu_version = `lsb_release -r 2>/dev/null | awk '{print $2}'`.chomp
    ("Ubuntu "+ubuntu_version if 0 == vs.to_i) or ("Debian "+ vs)
  end


  def system_load
    `cut -d' ' -f1 /proc/loadavg`.to_f
  end


  def time
    Time.now.strftime "%FT%T%z"
  end


  # Provides a map from devices to details of mounted file systems that are not
  # tmps or similar.  The keys in the map are device paths such as "/dev/sda1"
  # and the details are maps with keys:
  #
  #  + capacity:    The total capacity or size of the device ( in MB)
  #  + available:   The MB that are still available for use
  #  + mount_point: The mount point, e.g. "/" or "/srv"
  #
  def file_systems
    file_systems = {}
    # EXAMPLE OUTPUT OF `df --local --portability`:
    #Filesystem     1024-blocks      Used Available Capacity Mounted on
    #/dev/sda1         25803068  17084780   7407568      70% /
    #udev               1989328         4   1989324       1% /dev
    #none               1998124     19032   1979092       1% /tmp
    #tmpfs               799252      1204    798048       1% /run
    #none                  5120         0      5120       0% /run/lock
    #none               1998124       156   1997968       1% /run/shm
    #/dev/sda2        128033332 110326828  11202732      91% /media/133gb
    line_number = 1
    output_of("df --local --portability").each_line do |line| line.chomp!
      if 1 == line_number
        if line.split != %w{Filesystem 1024-blocks Used Available Capacity Mounted on}
          raise "Unexpected output format"
        end
      else
        device, capacity, used, available, percent_used, mount_point = line.split
        unless %w{none tmpfs udev cgroup varrun varlock}.include? device
          capacity, available = [ capacity, available].map {|n| (n.to_f / 1024.0).round }
          file_systems[ device] = { :capacity =>    capacity,
                                    :available =>   available,
                                    :mount_point => mount_point,
                                  }
        end
      end
      line_number += 1
    end
    file_systems
  end


  # @return [Array] A list of entries.  Each entry is an Array with the following items:
  #                   + name, usage(KB), list of child entries
  def disc_usage path_to_dir
    bugger "path must be absolute" unless path_to_dir.start_with? "/"
    bugger "path must not trail slash" if path_to_dir.end_with? "/"
    root = Node.new  path_to_dir
    output_of("du -xk \"#{path_to_dir}\"").each_line do |line|
      line.chomp!
      usage, path = line.split "\t"
      # Rip off the common prefix and the separator:
      path = path.slice  path_to_dir.length+1 .. -1
      # The root path will be nil
      node = root
      if path != nil
        elements = path.split "/"
        name = elements.last
        elements.each do |element|
          # Find the child of "node" with name "element"
          parent = node
          node = parent.children.first_where {|child| child.name == element }
          if node.nil?
            node = Node.new  element
            parent.children << node
          end
        end
      end
      node.usage = usage.to_i
    end
    root
  end


  class Node

    attr_accessor :name, :usage, :children

    def initialize name
      @name = name
      @children = []
    end

    def to_json options = {}
      [@name,@usage,@children].to_json options
    end
  end


  def lvm
    #EXAMPLE OUTPUT OF vgdisplay:
    #  --- Volume group ---
    #  VG Name               vg0
    #  System ID             
    #  Format                lvm2
    #  Metadata Areas        1
    #  Metadata Sequence No  20
    #  VG Access             read/write
    #  VG Status             resizable
    #  MAX LV                0
    #  Cur LV                19
    #  Open LV               18
    #  Max PV                0
    #  Cur PV                1
    #  Act PV                1
    #  VG Size               233.69 GiB
    #  PE Size               4.00 MiB
    #  Total PE              59825
    #  Alloc PE / Size       25856 / 101.00 GiB
    #  Free  PE / Size       33969 / 132.69 GiB
    #  VG UUID               nkB8XD-IW6m-ibPl-542d-Ddvq-8emH-FCGlyo
    volume_groups = {}
    current_vg = nil
    output_of("vgdisplay").each_line do |line|
      case line
        when /^  VG Name +(.+)$/
          current_vg = $1
          volume_groups[ current_vg] = {:volumes => {} }
        when /^  VG Size +(\d+\.\d+) GiB$/
          volume_groups[ current_vg][:capacity] = $1.to_f
        when /^  Free  PE \/ Size +\d+ \/ (\d+\.\d+) GiB$/
          volume_groups[ current_vg][:available] = $1.to_f
      end
    end

    #EXAMPLE OUTPUT OF lvdisplay:
    #  --- Logical volume ---
    #  LV Name                /dev/vg0/1G-temp
    #  VG Name                vg0
    #  LV UUID                21DMyT-4zTe-rXxS-2BRn-ept1-wqAg-HmnNkH
    #  LV Write Access        read/write
    #  LV Status              available
    #  # open                 0
    #  LV Size                1.00 GiB
    #  Current LE             256
    #  Segments               1
    #  Allocation             inherit
    #  Read ahead sectors     auto
    #  - currently set to     256
    #  Block device           252:0
    #   
    #  --- Logical volume ---
    current_lv = nil
    current_vg = nil
    output_of("lvdisplay").each_line do |line|
      case line
        when /^  LV Name +.+?([^\/\s]+)$/
          current_lv = $1
        when /^  VG Name +(.+)$/
          current_vg = $1
        when /^  LV Size +(\d+\.\d+) GiB$/
          volume_groups[ current_vg][:volumes][ current_lv] = {:size => $1.to_f }
      end
    end

    volume_groups
  end


  def packages_awaiting_update
    `apt-get update --quiet --quiet 2>/dev/null`
    # SAMPLE OUTPUT FROM THE "apt-get upgrade --quiet --quiet --simulate" COMMAND:
    #Inst linux-sound-base [1.0.13-5] (1.0.13-5etch1 Debian-Security:4.0/stable)
    #Conf linux-sound-base (1.0.13-5etch1 Debian-Security:4.0/stable)
    packages = []
    `apt-get dist-upgrade --quiet --quiet --simulate`.each_line do |line|
      if line.match %r{^Inst ([\w\-\.]+) }
        packages << $1
      end
    end
    packages
  end


  def orphaned_packages
    `deborphan`
  end


 private

  def output_of command
    IO.popen( command) {|stream| stream.read }
  end

  def bugger message
    raise JsonRpc::Error.new 1, message
  end

  end # of class methods
end

