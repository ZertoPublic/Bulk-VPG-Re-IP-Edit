#requires -Version 5
#requires -RunAsAdministrator
<#
.SYNOPSIS
   <Synopsis of script>
.DESCRIPTION
   This script exports the current Re-IP configuration for VPGs within a Zerto environment that will later be used as part of the Re-Configure NIC's import script. 
.EXAMPLE
   Examples of script execution
.VERSION 
   Applicable versions of Zerto Products script has been tested on.  Unless specified, all scripts in repository will be 5.0u3 and later.  If you have tested the script on multiple
   versions of the Zerto product, specify them here.  If this script is for a specific version or previous version of a Zerto product, note that here and specify that version 
   in the script filename.  If possible, note the changes required for that specific version.  
.LEGAL
   Legal Disclaimer:

----------------------
This script is an example script and is not supported under any Zerto support program or service.
The author and Zerto further disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.

In no event shall Zerto, its authors or anyone else involved in the creation, production or delivery of the scripts be liable for any damages whatsoever (including, without 
limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or the inability 
to use the sample scripts or documentation, even if the author or Zerto has been advised of the possibility of such damages.  The entire risk arising out of the use or 
performance of the sample scripts and documentation remains with you.
----------------------
#>
#------------------------------------------------------------------------------#
# Declare variables
#------------------------------------------------------------------------------#
#Examples of variables:

##########################################################################################################################
#Any section containing a "GOES HERE" should be replaced and populated with your site information for the script to work.#  
##########################################################################################################################

#------------------------------------------------------------------------------#
# Configure the variables below
#------------------------------------------------------------------------------#
$ExportDataDir = "CSV Export Directory"
$ZertoServer = "ZVM IP"
$ZertoPort = "9669"
$ZertoUser = "Zerto User Account"
$ZertoPassword = "Zerto User Password"
########################################################################################################################
# Nothing to configure below this line - Starting the main function of the script
########################################################################################################################
Write-Host -ForegroundColor Yellow "Informational line denoting start of script GOES HERE." 
Write-Host -ForegroundColor Red "   Legal Disclaimer:

----------------------
This script is an example script and is not supported under any Zerto support program or service.
The author and Zerto further disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.

In no event shall Zerto, its authors or anyone else involved in the creation, production or delivery of the scripts be liable for any damages whatsoever (including, without 
limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or the inability 
to use the sample scripts or documentation, even if the author or Zerto has been advised of the possibility of such damages.  The entire risk arising out of the use or 
performance of the sample scripts and documentation remains with you.
----------------------
"
#------------------------------------------------------------------------------#
# Setting certificate exception to prevent authentication issues to the ZVM
#------------------------------------------------------------------------------#
add-type @"
 using System.Net;
 using System.Security.Cryptography.X509Certificates;
 public class TrustAllCertsPolicy : ICertificatePolicy {
 public bool CheckValidationResult(
 ServicePoint srvPoint, X509Certificate certificate,
 WebRequest request, int certificateProblem) {
 return true;
 }
 }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
#------------------------------------------------------------------------------#
# Building Zerto API string and invoking API
#------------------------------------------------------------------------------#
$baseURL = "https://" + $ZertoServer + ":"+$ZertoPort+"/v1/"
# Authenticating with Zerto APIs
$xZertoSessionURL = $baseURL + "session/add"
$authInfo = ("{0}:{1}" -f $ZertoUser,$ZertoPassword)
$authInfo = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
$authInfo = [System.Convert]::ToBase64String($authInfo)
$headers = @{Authorization=("Basic {0}" -f $authInfo)}
$sessionBody = '{"AuthenticationMethod": "1"}'
$TypeJSON = "application/json"
$TypeXML = "application/xml"
Try
{
$xZertoSessionResponse = Invoke-WebRequest -Uri $xZertoSessionURL -Headers $headers -Method POST -Body $sessionBody -ContentType $TypeJSON
}
Catch {
Write-Host $_.Exception.ToString()
$error[0] | Format-List -Force
}
# Extracting x-zerto-session from the response, and adding it to the actual API
$xZertoSession = $xZertoSessionResponse.headers.get_item("x-zerto-session")
$zertoSessionHeader_json = @{"Accept"="application/json"
"x-zerto-session"=$xZertoSession}

#------------------------------------------------------------------------------#
# Header for XML Content
#------------------------------------------------------------------------------#
$zertoSessionHeader_xml = @{"Accept"="application/xml"
"x-zerto-session"=$xZertoSession}

#------------------------------------------------------------------------------#
# Creating Arrays for populating ZVM info from the API
#------------------------------------------------------------------------------#
$VPGArray = @()
$VMArray = @()
$VMVolumeArray = @()
$VMNICArray = @()
#------------------------------------------------------------------------------#
# Creating VPGArray, VMArray, VMVolumeArray, VMNICArray
#------------------------------------------------------------------------------#
# URL to create VPG settings
$CreateVPGURL = $baseURL+"vpgSettings"
# Build List of VPGs
$vpgListApiUrl = $baseURL+"vpgs"
$vpgList = Invoke-RestMethod -Uri $vpgListApiUrl -TimeoutSec 100 -Headers $zertoSessionHeader_xml -ContentType $TypeXML
# Build List of VMs
$vmListApiUrl = $baseURL+"vms"
$vmList = Invoke-RestMethod -Uri $vmListApiUrl -TimeoutSec 100 -Headers $zertoSessionHeader_xml -ContentType $TypeXML
# Select IDs from the API array
$zertoprotectiongrouparray = $vpgList.ArrayOfVpgApi.VpgApi | Select-Object OrganizationName,vpgname,vmscount,vpgidentifier
$vmListarray = $vmList.ArrayOfVmApi.VmApi | select-object *
#------------------------------------------------------------------------------#
# Starting for each VPG action of collecting ZVM VPG data
#------------------------------------------------------------------------------#
foreach ($VPGLine in $zertoprotectiongrouparray)
{
$VPGidentifier = $VPGLine.vpgidentifier
$VPGOrganization = $VPGLine.OrganizationName
$VPGVMCount = $VPGLine.VmsCount
$JSON =
"{
""VpgIdentifier"":""$VPGidentifier""
}"
#------------------------------------------------------------------------------#
# Posting the VPG JSON Request to the API
#------------------------------------------------------------------------------#
Try
{
$VPGSettingsIdentifier = Invoke-RestMethod -Method Post -Uri $CreateVPGURL -Body $JSON -ContentType $TypeJSON -Headers $zertoSessionHeader_json
$ValidVPGSettingsIdentifier = $true
}
Catch {
$ValidVPGSettingsIdentifier = $false
}
#------------------------------------------------------------------------------#
# Getting VPG settings from API
#------------------------------------------------------------------------------#
# Skipping if unable to obtain valid VPG setting identifier
if ($ValidVPGSettingsIdentifier -eq $true)
{
$VPGSettingsURL = $baseURL+"vpgSettings/"+$VPGSettingsIdentifier
$VPGSettings = Invoke-RestMethod -Uri $VPGSettingsURL -Headers $zertoSessionHeader_json -ContentType $TypeJSON
# Getting recovery site ID (needed anyway for network settings)
$VPGRecoverySiteIdentifier = $VPGSettings.Basic.RecoverySiteIdentifier
# Getting site info
$VISitesURL = $baseURL+"virtualizationsites"
$VISitesCMD = Invoke-RestMethod -Uri $VISitesURL -TimeoutSec 100 -Headers $zertoSessionHeader_json -ContentType $TypeJSON
# Getting network info
$VINetworksURL = $baseURL+"virtualizationsites/$VPGRecoverySiteIdentifier/networks"
$VINetworksCMD = Invoke-RestMethod -Uri $VINetworksURL -TimeoutSec 100 -Headers $zertoSessionHeader_json -ContentType $TypeJSON
# Getting VPG Settings
$VPGName = $VPGSettings.Basic.Name
# Getting VM IDs in VPG
$VPGVMIdentifiers = $VPGSettings.VMs.VmIdentifier
#------------------------------------------------------------------------------#
# Starting for each VM ID action for collecting ZVM VM data
#------------------------------------------------------------------------------#
foreach ($_ in $VPGVMIdentifiers)
{
$VMIdentifier = $_
# Get VMs settings
$GetVMSettingsURL = $baseURL+"vpgSettings/"+$VPGSettingsIdentifier+"/vms/"+$VMIdentifier
$GetVMSettings = Invoke-RestMethod -Method Get -Uri $GetVMSettingsURL -TimeoutSec 100 -Headers $zertoSessionHeader_json -ContentType $TypeJSON
# Getting the VM name and disk usage
$VMNameArray = $vmListarray | where-object {$_.VmIdentifier -eq $VMIdentifier} | Select-Object *
$VMName = $VMNameArray.VmName
#------------------------------------------------------------------------------#
# Get VM Nic settings for the current VPG
#------------------------------------------------------------------------------#
$GetVMSettingNICsURL = $baseURL+"vpgSettings/"+$VPGSettingsIdentifier+"/vms/"+$VMIdentifier+"/nics"
$GetVMSettingNICs = Invoke-RestMethod -Method Get -Uri $GetVMSettingNICsURL -TimeoutSec 100 -Headers $zertoSessionHeader_xml -ContentType $TypeXML
$VMNICIDs = $GetVMSettingNICs.ArrayOfVpgSettingsVmNicApi.VpgSettingsVmNicApi | select-object NicIdentifier -ExpandProperty NicIdentifier
#------------------------------------------------------------------------------#
# Starting for each VM NIC ID action for collecting ZVM VM NIC data
#------------------------------------------------------------------------------#
foreach ($_ in $VMNICIDs)
{
$VMNICIdentifier = $_
$GetVMSettingNICURL = $baseURL+"vpgSettings/"+$VPGSettingsIdentifier+"/vms/"+$VMIdentifier+"/nics/"+$VMNICIdentifier
$GetVMSettingNIC = Invoke-RestMethod -Method Get -Uri $GetVMSettingNICURL -TimeoutSec 100 -Headers $zertoSessionHeader_xml -ContentType $TypeXML
# Building arrays
$VMSettingNICIDArray1 = $GetVMSettingNIC.VpgSettingsVmNicApi.Failover.Hypervisor
$VMSettingNICIDArray2 = $GetVMSettingNIC.VpgSettingsVmNicApi.Failover.Hypervisor.IpConfig
$VMSettingNICIDArray3 = $GetVMSettingNIC.VpgSettingsVmNicApi.FailoverTest.Hypervisor
$VMSettingNICIDArray4 = $GetVMSettingNIC.VpgSettingsVmNicApi.FailoverTest.Hypervisor.IpConfig
# Setting failover values
$VMNICFailoverDNSSuffix = $VMSettingNICIDArray1.DnsSuffix
$VMNICFailoverNetworkIdentifier = $VMSettingNICIDArray1.NetworkIdentifier
$VMNICFailoverShouldReplaceMacAddress = $VMSettingNICIDArray1.ShouldReplaceMacAddress
$VMNICFailoverGateway = $VMSettingNICIDArray2.Gateway
$VMNIsFailoverDHCP = $VMSettingNICIDArray2.IsDhcp
$VMNICFailoverPrimaryDns = $VMSettingNICIDArray2.PrimaryDns
$VMNICFailoverSecondaryDns = $VMSettingNICIDArray2.SecondaryDns
$VMNICFailoverStaticIp = $VMSettingNICIDArray2.StaticIp
$VMNICFailoverSubnetMask = $VMSettingNICIDArray2.SubnetMask
# Nulling blank content
if ($VMNICFailoverDNSSuffix.nil -eq $true){$VMNICFailoverDNSSuffix = $null}
if ($VMNICFailoverGateway.nil -eq $true){$VMNICFailoverGateway = $null}
if ($VMNICFailoverPrimaryDns.nil -eq $true){$VMNICFailoverPrimaryDns = $null}
if ($VMNICFailoverSecondaryDns.nil -eq $true){$VMNICFailoverSecondaryDns = $null}
if ($VMNICFailoverStaticIp.nil -eq $true){$VMNICFailoverStaticIp = $null}
if ($VMNICFailoverSubnetMask.nil -eq $true){$VMNICFailoverSubnetMask = $null}
# Setting failover test values
$VMNICFailoverTestDNSSuffix = $VMSettingNICIDArray3.DnsSuffix
$VMNICFailoverTestNetworkIdentifier = $VMSettingNICIDArray3.NetworkIdentifier
$VMNICFailoverTestShouldReplaceMacAddress = $VMSettingNICIDArray3.ShouldReplaceMacAddress
$VMNICFailoverTestGateway = $VMSettingNICIDArray4.Gateway
$VMNIsFailoverTestDHCP = $VMSettingNICIDArray4.IsDhcp
$VMNICFailoverTestPrimaryDns = $VMSettingNICIDArray4.PrimaryDns
$VMNICFailoverTestSecondaryDns = $VMSettingNICIDArray4.SecondaryDns
$VMNICFailoverTestStaticIp = $VMSettingNICIDArray4.StaticIp
$VMNICFailoverTestSubnetMask = $VMSettingNICIDArray4.SubnetMask
# Nulling blank content
if ($VMNICFailoverTestDNSSuffix.nil -eq $true){$VMNICFailoverTestDNSSuffix = $null}
if ($VMNICFailoverTestGateway.nil -eq $true){$VMNICFailoverTestGateway = $null}
if ($VMNICFailoverTestPrimaryDns.nil -eq $true){$VMNICFailoverTestPrimaryDns = $null}
if ($VMNICFailoverTestSecondaryDns.nil -eq $true){$VMNICFailoverTestSecondaryDns = $null}
if ($VMNICFailoverTestStaticIp.nil -eq $true){$VMNICFailoverTestStaticIp = $null}
if ($VMNICFailoverTestSubnetMask.nil -eq $true){$VMNICFailoverTestSubnetMask = $null}
# Mapping Network IDs to Names
$VMNICFailoverNetworkName = $VINetworksCMD | Where-Object {$_.NetworkIdentifier -eq $VMNICFailoverNetworkIdentifier} | Select VirtualizationNetworkName -ExpandProperty VirtualizationNetworkName
$VMNICFailoverTestNetworkName = $VINetworksCMD | Where-Object {$_.NetworkIdentifier -eq $VMNICFailoverTestNetworkIdentifier} | Select VirtualizationNetworkName -ExpandProperty VirtualizationNetworkName
#------------------------------------------------------------------------------#
# Adding all VM NIC setting info to $VMNICArray
#------------------------------------------------------------------------------#
$VMNICArrayLine = new-object PSObject
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VPGName" -Value $VPGName
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VPGidentifier" -Value $VPGidentifier
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMName" -Value $VMName
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMIdentifier" -Value $VMIdentifier
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICIdentifier" -Value $VMNICIdentifier
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverNetworkName" -Value $VMNICFailoverNetworkName
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverDNSSuffix" -Value $VMNICFailoverDNSSuffix
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverShouldReplaceMacAddress" -Value $VMNICFailoverShouldReplaceMacAddress
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverGateway" -Value $VMNICFailoverGateway
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverDHCP" -Value $VMNIsFailoverDHCP
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverPrimaryDns" -Value $VMNICFailoverPrimaryDns
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverSecondaryDns" -Value $VMNICFailoverSecondaryDns
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverStaticIp" -Value $VMNICFailoverStaticIp
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverSubnetMask" -Value $VMNICFailoverSubnetMask
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverTestNetworkName" -Value $VMNICFailoverTestNetworkName
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverTestDNSSuffix" -Value $VMNICFailoverTestDNSSuffix
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverTestShouldReplaceMacAddress" -Value $VMNICFailoverTestShouldReplaceMacAddress
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverTestGateway" -Value $VMNICFailoverTestGateway
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverTestDHCP" -Value $VMNIsFailoverTestDHCP
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverTestPrimaryDns" -Value $VMNICFailoverTestPrimaryDns
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverTestSecondaryDns" -Value $VMNICFailoverTestSecondaryDns
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverTestStaticIp" -Value $VMNICFailoverTestStaticIp
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VMNICFailoverTestSubnetMask" -Value $VMNICFailoverTestSubnetMask
$VMNICArray += $VMNICArrayLine
# End of per VM NIC actions below
}
# End of per VM NIC actions above
#
# End of per VM actions below
}
# End of per VM actions above
#------------------------------------------------------------------------------#
# Deleting VPG edit settings ID (same as closing the edit screen on a VPG in the ZVM without making any changes)
#------------------------------------------------------------------------------#
Try
{
Invoke-RestMethod -Method Delete -Uri $VPGSettingsURL -TimeoutSec 100 -Headers $zertoSessionHeader_xml -ContentType $TypeXML
}
Catch [system.exception]
{
}
#
# End of check for valid VPG settings ID below
}
# End of check for valid VPG settings ID above
#
# End of per VPG actions below
}
# End of per VPG actions above
#
#------------------------------------------------------------------------------#
# Exporting VM Nic Settings
#------------------------------------------------------------------------------#
$VMNICArray | export-csv $ExportDataDir"ZVRVMNICS.csv" -NoTypeInformation
