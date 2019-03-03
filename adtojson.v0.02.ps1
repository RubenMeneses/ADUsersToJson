#Max #Days to keep files
$MaxDaysToKeep = 30


#Property list, SID and DN are added automatically
$PropList=[System.Collections.ArrayList]::new()
$null=$PropList.Add("Name")
$null=$PropList.Add("GivenName")
$null=$PropList.Add("Surname")
$null=$PropList.Add("UserPrincipalName")
$null=$PropList.Add("PasswordLastSet")
$null=$PropList.Add("HomeDrive")
$null=$PropList.Add("Modified")
$null=$PropList.Add("DisplayName")
$null=$PropList.Add("SamAccountName")
$null=$PropList.Add("Enabled")
$null=$PropList.Add("Created")
$null=$PropList.Add("AccountExpirationDate")
$null=$PropList.Add("telephoneNumber")
$null=$PropList.Add("EmailAddress")
$null=$PropList.Add("mobile")
$null=$PropList.Add("manager")
$null=$PropList.Add("physicalDeliveryOfficeName")
$null=$PropList.Add("otherTelephone")
$null=$PropList.Add("extensionAttribute1")
$null=$PropList.Add("extensionAttribute7")
$null=$PropList.Add("extensionAttribute15")
$null=$PropList.Add("ObjectClass")
$null=$PropList.Add("ObjectGUID")



#do not edit past this point




#region Script Directory 
function Get-ScriptDirectory 
{  
    if($hostinvocation -ne $null) 
    { 
        Split-Path $hostinvocation.MyCommand.path 
    } 
    else 
    { 
        Split-Path $script:MyInvocation.MyCommand.Path 
    } 
} 
 
 
$SCRIPT_PARENT = Get-ScriptDirectory  
#endregion 

#region Support functions
function LegacyDCFromDN()
{
	param (
        [Parameter(Mandatory = $true)]
        [string]$FullUserDistinguishedName
    )
    $domainDN = $FullUserDistinguishedName -Split "," | ? {$_ -like "DC=*"}
    $domainDN = $domainDN -join ","
   
    

    
    #check if Distingushed Name is already in mapping table
    $IsDNInTable=$Global:DistigushedNameToLegacyMapping.ContainsValue($domainDN)

    
    # add DN to table if not in list.
    if (-not $IsDNInTable) {
        #add to mapping table
        $LegacyDomainName=(Get-ADDomain $domainDN).NetBIOSName        
        $null=$Global:DistigushedNameToLegacyMapping.Add($LegacyDomainName,$domainDN)
    }

    #query table, find key where the value matches
    $KeyName=($Global:DistigushedNameToLegacyMapping.GetEnumerator() | ? { $_.Value -eq $domainDN }).name

    return $KeyName
    

}

#endregion

#create Mapping hash table
$Global:DistigushedNameToLegacyMapping = @{}


#date vars
$ExtractionDate=Get-Date
$ExtractionDateForFile=get-date($ExtractionDate) -f yyyyMMddHHmmss


#paths dynamic build
$OutputFolder=Join-Path -Path $SCRIPT_PARENT -ChildPath "Output"
$null=New-Item -ItemType Directory -Force -Path $OutputFolder
$OutputFileName="$ExtractionDateForFile-ADUsers.json"
$OutputFileFullPath=Join-Path -Path $OutputFolder -ChildPath $($OutputFileName)


#Set other vars
$FirstLine=$true

#################################################################################


#adds DN and SID if not already added
if (-not $PropList.Contains("DistinguishedName")) {$null=$PropList.Add("DistinguishedName")}
if (-not $PropList.Contains("SID")) {$null=$PropList.Add("SID")}


#Collect results in the results variable
$Results=Get-ADUser -Filter * -Properties $PropList | select $PropList

### Go through the results and store each result in a PSobject in the UserArray variable
$UserArray = @()
ForEach ($User In $Results){
    
    #Get legacy dom from DN
    $LegacyDCFromDN=LegacyDCFromDN -FullUserDistinguishedName $($User.DistinguishedName)

    #convert ad object to json
    $CurrentUserJson = ConvertTo-Json $User -Depth 3 -Compress

    #convert to object so that can be edited.
    $CurrentUserObj= ConvertFrom-Json $CurrentUserJson

    #TidyUp SID
    $CurrentUserObj.SID=$User.SID.Value

    #add extra properties, date and legacy domain
    $null=Add-Member -InputObject $CurrentUserObj -MemberType NoteProperty -Name "ExtractionDate" -Value $ExtractionDate
    $null=Add-Member -InputObject $CurrentUserObj -MemberType NoteProperty -Name "LegacyDomain" -Value $LegacyDCFromDN

    #back to json
    $CurrentUserJson= ConvertTo-Json $CurrentUserObj -Depth 3 -Compress
    
    #out to file, after the first line content is appended to file.
    if ($FirstLine) {
        $CurrentUserJson|Out-File -FilePath $OutputFileFullPath -Force -NoClobber
        $FirstLine=$false
    } else {
        $CurrentUserJson|Out-File -FilePath $OutputFileFullPath -Append -Force -NoClobber
    }

}




#################################################################################


#Delete all Files in folder older than 30 day(s)
$DatetoDelete = $ExtractionDate.AddDays(($MaxDaysToKeep*(-1)))
$AllFilesInOutputFolder=Get-ChildItem $OutputFolder
foreach ($CurrentFile in $AllFilesInOutputFolder)
{
    if ($CurrentFile.LastWriteTime -lt $DatetoDelete)
    {Remove-Item -Path $CurrentFile}
}

