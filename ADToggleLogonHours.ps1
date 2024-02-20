<################################################################################################

Author: Tino JR (scripts@tinojr.org)
Version: 1.0
Date: 01/09/2024

.SYNOPSIS
This script is used to toggle logon hours (all on or all off) for a given AD user.

.DESCRIPTION
This script is used to toggle logon hours (all on or all off) for a given AD user.
This can be used to target an individual user or all members of an AD group. If you run the script
without the '-CommitChanges' parameter, it will run in 'WhatIf' mode. This is a good way to just
check users. Note, if a user has never had modified logon hours, the default value is null.

.PARAMETER User
Required    : Yes
DataType    : String
Description : This is used to toggle a single AD user.

.PARAMETER Group
Required    : Yes
DataType    : String
Description : This is used to toggle all members of a specific AD group.

.PARAMETER AddLogonHourRestrictions
Required    : Yes
DataType    : Switch
Description : This will disable logon hours (24/7) for each user.

.PARAMETER RemoveLogonHourRestrictions
Required    : Yes
DataType    : Switch
Description : This will enable logon hours (24/7) for each user.

.PARAMETER CommitChanges
Required    : Yes
DataType    : Switch
Description : The script runs in WhatIf mode. Use this switch to toggle hours.

.EXAMPLE
C:\Scripts\ToggleLogonHours.ps1 -User JSmith -AddLogonHourRestrictions
C:\Scripts\ToggleLogonHours.ps1 -User JSmith -AddLogonHourRestrictions -CommitChanges
C:\Scripts\ToggleLogonHours.ps1 -Group Facilities -AddLogonHourRestrictions
####################################################################################################>

[CmdletBinding(DefaultParameterSetName='RestrictLogonHoursUser')]
param(
    [Parameter(Mandatory=$true,ParameterSetName='RestrictLogonHoursUser')]
    [Parameter(Mandatory=$true,ParameterSetName='RemoveLogonHourRestrictionsUser')]
    [ValidateNotNullOrEmpty()]
    [String]$User,
    [Parameter(Mandatory=$true,ParameterSetName='RestrictLogonHoursGroupMembers')]
    [Parameter(Mandatory=$true,ParameterSetName='RemoveLogonHourRestrictionsGroupMembers')]
    [ValidateNotNullOrEmpty()]
    [String]$Group,
    [Parameter(Mandatory=$true,ParameterSetName='RestrictLogonHoursUser')]
    [Parameter(Mandatory=$true,ParameterSetName='RestrictLogonHoursGroupMembers')]
    [Switch]$AddLogonHourRestrictions,
    [Parameter(Mandatory=$true,ParameterSetName='RemoveLogonHourRestrictionsUser')]
    [Parameter(Mandatory=$true,ParameterSetName='RemoveLogonHourRestrictionsGroupMembers')]
    [Switch]$RemoveLogonHourRestrictions,
    [Parameter(Mandatory=$false)]
    [Switch]$CommitChanges
)

###### Variables
# Stopwatch Start
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch 
$StopWatch.Start()
$dc = $env:LOGONSERVER -replace '\\'
$SleepSeconds = 2
$Properties =  @('WhenCreated','WhenChanged','logonHours')
[array]$ADObjectDetails = @()
[array]$ADLog = @()
$date = (Get-Date).ToString('MMddyyyy-hhmmtt')
$ProgressPreference = 'Continue'
IF($PSVersionTable.PSVersion.ToString() -ge 7.2){$PSStyle.Progress.View = 'Classic'}
IF(![string]::IsNullOrEmpty($User)){
    $ADObject = $User
    $ADObjectType = 'User'
}ELSEIF(![string]::IsNullOrEmpty($Group)){
    $ADObject = $Group
    $ADObjectType = 'Group'
}ELSE{
    Throw "Wait, no user or group??!"
}

##### Output
$outputpath = Split-Path -Path $($MyInvocation.MyCommand.Path) -Parent
IF($AddLogonHourRestrictions.IsPresent){
    $FileName = "SetLogonHours_$(IF($CommitChanges.IsPresent){'CommitChanges'}ELSE{'WhatIf'})_AddRestrictions_$date.csv"
    $ActivityText = "Restricting Hours $(IF($CommitChanges.IsPresent){'(Committing Changes)'}ELSE{'(WhatIf)'})"
}ELSEIF($RemoveLogonHourRestrictions.IsPresent){
    $FileName = "SetLogonHours_$(IF($CommitChanges.IsPresent){'CommitChanges'}ELSE{'WhatIf'})_RemoveRestrictions_$date.csv"
    $ActivityText = "Removing Restrictions $(IF($CommitChanges.IsPresent){'(Committing Changes)'}ELSE{'(WhatIf)'})"
}
$OutputCSV = Join-Path -Path $outputpath -ChildPath $FileName

##### AD check
Try{
    Import-Module ActiveDirectory -ErrorAction Stop
}
Catch{
    Write-Output -InputObject "Warning: Unable to load AD module, will try again: $($_.Exception.Message)"
    Start-Sleep -Seconds $SleepSeconds
    Try {
        Import-Module ActiveDirectory -ErrorAction Stop
    }
    Catch {
        Throw "Error: Unable to load ActiveDirectory module: $($_.Exception.Message)"            
    }
}


##### Get AD Details
IF($ADObjectType -eq 'User'){
    Try{
        $ADObjectDetails = Get-ADUser -Identity $ADObject -Server $dc -ErrorAction Stop | Select-Object -ExpandProperty DistinguishedName
    }
    Catch{
        Throw "Unable to query AD and get user ($ADObject): $($_.Exception.Message)"
    }
}ELSEIF($ADObjectType -eq 'Group'){
    Try{
        $ADObjectDetails = Get-ADGroup -Identity $ADObject -Server $dc -Properties Members -ErrorAction Stop | Select-Object -ExpandProperty Members
    }
    Catch{
        Throw "Unable to query AD and get group ($ADObject): $($_.Exception.Message)"
    }
}


##### Set Logon Hours Variable
IF($AddLogonHourRestrictions.IsPresent){
    [byte[]]$hours=@(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)    
}ELSEIF($RemoveLogonHourRestrictions.IsPresent){
    [byte[]]$hours=@(255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255)
}ELSE{
    Throw "No Switch was called to enable or disable hours!"
}


##### Set logon hours for Group members
$maxcount = ($ADObjectDetails|Measure-Object).Count
$loopcount = 0
$ADObjectDetails | ForEach-Object {
    $DN = $_
    $CN = $DN.Split(',')[0] -Replace 'CN='
    [array]$ADUser = @()
    [array]$TMP = @()
    $StatusError = ''
    $Status = ''
    $ErrorCount = 0

    # Progress Bar
    $loopcount++
    $activity = $ActivityText
    $currentoperation = "Current User: $CN"
    $progresscalculation = ($loopcount/$maxcount)
    $lcountf = "{0:N0}" -f $loopcount
    $mcountf = "{0:N0}" -f $maxcount
    $pformat = "{0:P2}" -f $progresscalculation
    Write-Progress -Activity $activity -Status "$pformat   ($lcountf of $mcountf)" -PercentComplete ($progresscalculation*100) -CurrentOperation $currentoperation

    # Query Before
    Try{
        $ADUser = Get-ADUser -Identity $DN -Properties $Properties -Server $dc |Select-Object -Property SamAccountName,UserPrincipalName,Enabled,@{N='logonHours_Before';E={[string]$_.logonHours -replace ' ',','}},@{N='WhenChanged_Before';E={$_.WhenChanged}},WhenCreated
        $ErrorMSG = ''
    }
    Catch{
        $Status = 'Error'
        $ErrorCount++
        $ErrorMSG = "Error ($ErrorCount): Unable to perform initial query for AD user ($CN) using DN: $($_.Exception.Message)"
        IF([string]::IsNullOrEmpty($StatusError)){$StatusError=$ErrorMSG}ELSE{$ErrorMSG+=" ; $StatusError";$StatusError=$ErrorMSG}
    }

    IF([string]::IsNullOrEmpty($StatusError)){
        # Set Hours
        Try{
            IF($CommitChanges.IsPresent){
                Set-ADUSer -Identity $DN -Replace @{logonHours = $hours} -Server $dc -ErrorAction Stop
            }
            $ErrorMSG = ''
            $Status = 'Success'
        }
        Catch{
            $ErrorCount++
            $ErrorMSG = "Error ($ErrorCount): 1st attempt - Unable to set logon hours for AD user ($CN): $($_.Exception.Message)"
            IF([string]::IsNullOrEmpty($StatusError)){$StatusError=$ErrorMSG}ELSE{$ErrorMSG+=" ; $StatusError";$StatusError=$ErrorMSG}
            Try{
                IF($CommitChanges.IsPresent){
                    Set-ADUSer -Identity $ADUser.SamAccountName -Replace @{logonHours = $hours} -Server $dc -ErrorAction Stop
                }
                $ErrorMSG = ''
                $Status = 'Warning'
            }
            Catch{
                $Status = 'Error'
                $ErrorCount++
                $ErrorMSG = "Error ($ErrorCount): 2nd attempt - Unable to set logon hours for AD user ($CN) using Sam. : $($_.Exception.Message)"
                IF([string]::IsNullOrEmpty($StatusError)){$StatusError=$ErrorMSG}ELSE{$ErrorMSG+=" ; $StatusError";$StatusError=$ErrorMSG}
            }
        }

        # Pause
        Start-Sleep -Seconds $SleepSeconds

        # Query After
        Try{
            $TMP = Get-ADUser -Identity $DN -Properties $Properties -Server $dc |Select-Object -Property @{N='logonHours_After';E={[string]$_.logonHours -replace ' ',','}},@{N='WhenChanged_After';E={$_.WhenChanged}}
            $ErrorMSG = ''
        }
        Catch{
            $ErrorCount++
            $ErrorMSG = "Error ($ErrorCount): Unable to query AD user ($CN) using DN for 'after' results. : $($_.Exception.Message)"
            IF([string]::IsNullOrEmpty($StatusError)){$StatusError=$ErrorMSG}ELSE{$ErrorMSG+=" ; $StatusError";$StatusError=$ErrorMSG}
        }

    }
     
    # Update Arrays
    $ADUser | Add-Member NoteProperty -Name 'UserOrGroupType' -Value $ADObjectType -Force
    $ADUser | Add-Member NoteProperty -Name 'UserOrGroupName' -Value $ADObject -Force
    $ADUser | Add-Member NoteProperty -Name 'logonHours_After' -Value $TMP.logonHours_After -Force
    $ADUser | Add-Member NoteProperty -Name 'WhenChanged_After' -Value $TMP.WhenChanged_After -Force
    $ADUser | Add-Member NoteProperty -Name 'DN_Lookup' -Value $DN -Force
    $ADUser | Add-Member NoteProperty -Name 'ErrorCount' -Value $ErrorCount -Force
    $ADUser | Add-Member NoteProperty -Name 'Error' -Value $StatusError -Force
    $ADUser | Add-Member NoteProperty -Name 'Status' -Value $Status -Force
    $ADLog += $ADUser | Select-Object *

    # Check loop counter
    IF($loopcount -ge $maxcount){Write-Progress -Completed -Activity $activity -Status "Complete"}
}

# Export All Data
$ADLog | Select-Object -Property Status,UserOrGroupType,UserOrGroupName,DN_Lookup,SamAccountName,UserPrincipalName,Enabled,logonHours_Before,logonHours_After,WhenChanged_Before,WhenChanged_After,WhenCreated,ErrorCount,Error | Export-Csv -Path $OutputCSV -NoTypeInformation

#### Stop stopwatch
$StopWatch.Stop()
Write-Output -InputObject "`nTotal Duration: $($StopWatch.Elapsed.ToString().Split('.')[0])`n"