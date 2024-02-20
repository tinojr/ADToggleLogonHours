# ADToggleLogonHours
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