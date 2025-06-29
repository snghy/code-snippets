set-strictmode -v latest
$errorActionPreference = 'stop'

function ip {
  param([parameter(valueFromPipeline=$true)]$intf)

  $addr = $intf|netIpAddress -addressFam ipv4
  $gway = ($intf|netIpConfiguration).ipv4DefaultGateway
  if ($null -ne $gway) {
    $gway = ($intf|netIpConfiguration).ipv4DefaultGateway.nexthop
  }
  $dhcp = ($intf|netIPInterface -addressFam ipv4).dhcp 
  $dns = ($intf|dnsClientServerAddress -AddressFam ipv4).serveraddresses
  $id = ($intf|netadapter).interfaceGuid
  $nic = Get-wmiObject -class Win32_NetworkAdapterConfiguration -filter "settingID = '$id'"
  $wins = @($nic.winsPrimaryServer, $nic.winsSecondaryServer)
  [PSCustomObject]@{
     Dhcp=$dhcp
     IPAddr=$addr.ipv4Address; PrefixLen=$addr.PrefixLength; Gateway=$gway
     Dns=$dns; Wins=$wins
  }
}

function set-WinsServer {
  param($primary=$null, $secondary=$null)

  $id = ($intf|netadapter).interfaceGuid
  $nic = get-wmiObject -class Win32_NetworkAdapterConfiguration -filter "settingID = '$id'"
  $nic.SetWINSServer("$primary","$secondary")
}

function clear-ipv4Intf {
  ## remove any existing ip address and gateway
  param([parameter(valueFromPipeline=$true)]$intf, $dns=$false, $wins=$false)

  $intf | set-netIpInterface -addressFam ipv4 -dhcp dis
  try {
    $intf | remove-netIpAddress -addressFam ipv4 -confirm:$false
    $intf | remove-netRoute -confirm:$false
  } catch {}
  if ($dns) {
    $intf | set-dnsclientServerAddress -reset
  }
  if ($wins) {
    set-WinsServer >$null
  }
}

# get an ipv4 interface
$adp = netAdapter | ?{$_.status -eq 'up'}
$intf = $adp|netIpInterface -addressFam ipv4

# configure the static ipv4 settings
$ipv4='192.168.152.1'
$prefixLen=24
$gateway='192.168.152.124'
$dns = '192.168.152.124', '192.168.152.1'
$wins = '192.168.152.124'
$intf | new-netIPAddress -ipAddr $ipv4 -prefixLen $prefixLen -defaultg $gateway
$intf | set-dnsClientServerAddress -Server $dns
$intf | set-WinsServer $wins >$null

# enable DHCP
$intf | set-netIpInterface -addressFam ipv4 -dhcp en
$intf | set-dnsClientServerAddress -reset

## note
$intf|ip
$intf|fl dhcp
$intf|netipaddress
$intf|netipconfiguration
$intf|netroute
$adp|netadapterBinding

$intf | clear-ipv4Intf
$adp | disable-netadapterBinding -component ms_tcpip6
$adp | restart-netAdapter
