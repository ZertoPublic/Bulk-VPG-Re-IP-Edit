# Legal Disclaimer 
This script is an example script and is not supported under any Zerto support program or service. The author and Zerto further disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.

In no event shall Zerto, its authors or anyone else involved in the creation, production or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or the inability to use the sample scripts or documentation, even if the author or Zerto has been advised of the possibility of such damages. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you.

# Bulk VPG Re-Ip Edit 
ExportNicSettings.PS1: 
This script exports the current Re-IP configuration for VPGs within a Zerto environment that will later be used as part of the Re-Configure NICs import script 

Re-ConfigureNics.PS1: 
This script will import a CSV with updated Re-IP configuration changes for currently created VPGs. Before running this script the ExportNicSettings.PS1 must be run to create the necessary CSV. 

# Getting Started 
Instructions on how to utilize these automation examples can be found in Section 7.2 Bulk Editing VM NIC Settings Including Re-IP & PortGroups in the following whitepaper: http://s3.amazonaws.com/zertodownload_docs/Marketing_Material/White%20Paper%20-%20Automating%20Zerto%20Virtual%20Replication%20with%20PowerShell%20and%20REST%20APIs.pdf

# Prerequisities
Environment Requirements: 
  - PowerShell 5.0 +
  - ZVR 5.0u3+ 

Script Requirements: 
  - Export CSV Directory 
  - Import CSV Directory
  - ZVM IP 
  - ZVM User / password 
 
# Running Script 
Once the necessary requirements have been completed select an appropriate host to run the script from. To run the script type the following:

.\ExportNICSettings

.\RE-configureNIC's.ps1
