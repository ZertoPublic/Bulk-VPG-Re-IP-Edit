#requires -Version 5
#requires -RunAsAdministrator
<#
.SYNOPSIS
   This script will import a CSV with updated Re-IP configuration changes for currently created VPGs. Before running this script the Export script needs to be run to create the necessary CSV. 
.DESCRIPTION
   Detailed explanation of script
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
$CSVImportFile = "Import CSV Directory"
$ZertoServer = "ZVM IP"
$ZertoPort = "9669"
$ZertoUser = "ZVM User Account"
$ZertoPassword = "ZVM User Password"
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
# Importing CSV and building list of VPGs
#------------------------------------------------------------------------------#
$CSVImport = Import-Csv $CSVImportFile
$VPGsToConfigure = $CSVImport | select -ExpandProperty VPGName -Unique
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

$CreateVPGURL = $baseURL+"vpgSettings"
#------------------------------------------------------------------------------#
# Starting for each VPG action
#------------------------------------------------------------------------------#
foreach ($VPG in $VPGsToConfigure)
{
$VPGName = $VPG
# Getting VPG Identifier
$VPGidentifier = $CSVImport | Where-Object {$_.VPGName -eq $VPGName} | select -ExpandProperty VPGidentifier -Unique
# Getting list of VMs to reconfigure
$VMsToConfigure = $CSVImport | Where-Object {$_.VPGName -eq $VPGName} | select -ExpandProperty VMName -Unique
# Creating edit VPG JSON
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
# Skipping if unable to obtain valid VPG setting identifier
#------------------------------------------------------------------------------#
if ($ValidVPGSettingsIdentifier -eq $true)
{
#------------------------------------------------------------------------------#
# Getting ZVR IDs for the VPG
#------------------------------------------------------------------------------#
$VPGSettingsURL = $baseURL+"vpgSettings/"+$VPGSettingsIdentifier
$VPGSettings = Invoke-RestMethod -Uri $VPGSettingsURL -Headers $zertoSessionHeader_json -ContentType $TypeJSON
# Getting recovery site ID (needed anyway for network settings)
$VPGRecoverySiteIdentifier = $VPGSettings.Basic.RecoverySiteIdentifier
# Getting network info
$VINetworksURL = $baseURL+"virtualizationsites/$VPGRecoverySiteIdentifier/networks"
$VINetworksCMD = Invoke-RestMethod -Uri $VINetworksURL -TimeoutSec 100 -Headers $zertoSessionHeader_json -ContentType $TypeJSON
#------------------------------------------------------------------------------#
# Starting per VM actions
#------------------------------------------------------------------------------#
foreach ($VM in $VMsToConfigure)
{
$VMName = $VM
# Getting VM settings from the CSV
$VMSettings = $CSVImport | Where-Object {$_.VPGName -eq $VPGName -and $_.VMName -eq $VMName} | select
$VMIdentifier = $CSVImport | Where-Object {$_.VPGName -eq $VPGName -and $_.VMName -eq $VMName} | select -ExpandProperty VMIdentifier -Unique
$VMNICIdentifiers = $VMSettings.VMNICIdentifier
#------------------------------------------------------------------------------#
# Starting per VM NIC actions
#------------------------------------------------------------------------------#
foreach ($VMNIC in $VMNICIdentifiers)
{
$VMNICIdentifier = $VMNIC
# Getting VM NIC settings
$VMNICSettings = $VMSettings | Where-Object {$_.VMNICIdentifier -eq $VMNICIdentifier} | select *
$VMNICFailoverNetworkName = $VMNICSettings.VMNICFailoverNetworkName
$VMNICFailoverDNSSuffix = $VMNICSettings.VMNICFailoverDNSSuffix
$VMNICFailoverShouldReplaceMacAddress = $VMNICSettings.VMNICFailoverShouldReplaceMacAddress
$VMNICFailoverGateway = $VMNICSettings.VMNICFailoverGateway
$VMNICFailoverDHCP = $VMNICSettings.VMNICFailoverDHCP
$VMNICFailoverPrimaryDns = $VMNICSettings.VMNICFailoverPrimaryDns
$VMNICFailoverSecondaryDns = $VMNICSettings.VMNICFailoverSecondaryDns
$VMNICFailoverStaticIp = $VMNICSettings.VMNICFailoverStaticIp
$VMNICFailoverSubnetMask = $VMNICSettings.VMNICFailoverSubnetMask
$VMNICFailoverTestNetworkName = $VMNICSettings.VMNICFailoverTestNetworkName
$VMNICFailoverTestDNSSuffix = $VMNICSettings.VMNICFailoverTestDNSSuffix
$VMNICFailoverTestShouldReplaceMacAddress = $VMNICSettings.VMNICFailoverTestShouldReplaceMacAddress
$VMNICFailoverTestGateway = $VMNICSettings.VMNICFailoverTestGateway
$VMNICFailoverTestDHCP = $VMNICSettings.VMNICFailoverTestDHCP
$VMNICFailoverTestPrimaryDns = $VMNICSettings.VMNICFailoverTestPrimaryDns
$VMNICFailoverTestSecondaryDns = $VMNICSettings.VMNICFailoverTestSecondaryDns
$VMNICFailoverTestStaticIp = $VMNICSettings.VMNICFailoverTestStaticIp
$VMNICFailoverTestSubnetMask = $VMNICSettings.VMNICFailoverTestSubnetMask
# Setting answers to lower case for API to process
$VMNICFailoverShouldReplaceMacAddress = $VMNICFailoverShouldReplaceMacAddress.ToLower()
$VMNICFailoverDHCP = $VMNICFailoverDHCP.ToLower()
$VMNICFailoverTestShouldReplaceMacAddress = $VMNICFailoverTestShouldReplaceMacAddress.ToLower()
$VMNICFailoverTestDHCP = $VMNICFailoverTestDHCP.ToLower()
# Translating network names to ZVR Network Identifiers
$VMNICFailoverNetworkIdentifier = $VINetworksCMD | where-object {$_.VirtualizationNetworkName -eq $VMNICFailoverNetworkName} | select -ExpandProperty NetworkIdentifier
$VMNICFailoverTestNetworkIdentifier = $VINetworksCMD | where-object {$_.VirtualizationNetworkName -eq $VMNICFailoverTestNetworkName} | select -ExpandProperty NetworkIdentifier
#------------------------------------------------------------------------------#
# Building VMNIC JSON
#------------------------------------------------------------------------------#
$VMNICJSON =
" {
 ""Failover"":{
 ""Hypervisor"":{
 ""DnsSuffix"":""$VMNICFailoverDNSSuffix"",
 ""IpConfig"":{
 ""Gateway"":""$VMNICFailoverGateway"",
 ""IsDhcp"":$VMNICFailoverDHCP,
 ""PrimaryDns"":""$VMNICFailoverPrimaryDns"",
 ""SecondaryDns"":""$VMNICFailoverSecondaryDns"",
 ""StaticIp"":""$VMNICFailoverStaticIp"",
 ""SubnetMask"":""$VMNICFailoverSubnetMask""
 },
 ""NetworkIdentifier"":""$VMNICFailoverNetworkIdentifier"",
 ""ShouldReplaceMacAddress"":$VMNICFailoverShouldReplaceMacAddress
 }
 },
 ""FailoverTest"":{
 ""Hypervisor"":{
 ""DnsSuffix"":""$VMNICFailoverTestDNSSuffix"",
 ""IpConfig"":{
 ""Gateway"":""$VMNICFailoverTestGateway"",
 ""IsDhcp"":$VMNICFailoverTestDHCP,
 ""PrimaryDns"":""$VMNICFailoverTestPrimaryDns"",
 ""SecondaryDns"":""$VMNICFailoverTestSecondaryDns"",
 ""StaticIp"":""$VMNICFailoverTestStaticIp"",
 ""SubnetMask"":""$VMNICFailoverTestSubnetMask""
 },
 ""NetworkIdentifier"":""$VMNICFailoverTestNetworkIdentifier"",
 ""ShouldReplaceMACAddress"":$VMNICFailoverTestShouldReplaceMacAddress
 }
 },
 ""NicIdentifier"":""$VMNICIdentifier""
 }"
#------------------------------------------------------------------------------#
# Creating URL and sending PUT command to API
#------------------------------------------------------------------------------#
$EditVMNICURL = $baseURL+"vpgSettings/"+$VPGSettingsIdentifier+"/vms/"+$VMIdentifier+"/nics/"+$VMNICIdentifier
Try
{
$EditVMNIC = Invoke-RestMethod -Method PUT -Uri $EditVMNICURL -Body $VMNICJSON -Headers $zertoSessionHeader_json -ContentType $TypeJSON -TimeoutSec 100
}
Catch {
Write-Host $_.Exception.ToString()
$error[0] | Format-List -Force
}
# Waiting for API processing
sleep 3
# End of for each VMNIC below
}
# End of for each VMNIC above
#
# End of for each VM below
}
# End of for each VM above
#------------------------------------------------------------------------------#
# Committing VPG settings
#------------------------------------------------------------------------------#
$CommitVPGSettingURL = $baseURL+"vpgSettings/"+"$VPGSettingsIdentifier"+"/commit"
write-host "CommitVPGSettingURL:$CommitVPGSettingURL"
Try
{
Invoke-RestMethod -Method Post -Uri $CommitVPGSettingURL -Headers $zertoSessionHeader_json -ContentType $TypeJSON -TimeoutSec 100
$VPGEditOutcome = "PASSED"
}
Catch {
$VPGEditOutcome = "FAILED"
Write-Host $_.Exception.ToString()
$error[0] | Format-List -Force
}
write-host "VPG:$VPGName VPGEditOutcome=$VPGEditOutcome"
# Sleeping before processing next VPG
write-host "Waiting 5 seconds before processing next VPG"
sleep 5
# End of check for valid VPG settings ID below
}
# End of check for valid VPG settings ID above
#
# End of per VPG actions below
}
# End of per VPG actions above
