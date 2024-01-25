Function Connect-3stepAPI {
    <#
    .SYNOPSIS
    Connect to the 3step API
    
    .DESCRIPTION
    Connect to the 3step API and generate a Token variable that can be used with your own Invoke-RestMethod commands '$3stepAuthenticationHeader'
    All Functions within this Module already has this variable implemented.
    
    .PARAMETER Url
    Your 3step Url
    
    .PARAMETER Token
    Your API Token
    
    .PARAMETER LogToFile
    Connect to PSLoggingFunctions module, read more on GitHub, it create a Log folder in your directory if set to True
    
    .EXAMPLE
    Connect-3stepAPI -ApplicationID $3STEPApplicationID -APISecret $3STEPAPISecret -LogToFile $False
    
    OUTPUT
    3step Authenticated: True
    3step URL = https://api.3stepit.com/assetviewapi/v1/
    Use Header Connection Variable = $3stepAuthenticationHeader
    #>
    Param(
        [parameter(mandatory)]
        $ApplicationID,
        [parameter(mandatory)]
        $APISecret,
        [parameter(mandatory)]
        $LogToFile
    )

    $Url = "https://api.3stepit.com/assetviewapi/v1/"

    $3stepAuthenticationHeader = @{
        "grant_type"    = "client_credentials"
        "client_id"     = "$ApplicationID"
        "client_secret" = "$APISecret"
    }


    Write-Log -Message "Connecting to 3step API" -Active $LogToFile

    $testConnection = Invoke-RestMethod -Method POST -Body $3stepAuthenticationHeader -Uri "$Url/access_token" -ContentType "application/x-www-form-urlencoded"
    $global:3stepAuthenticated = $false
    if ($testConnection){
        $global:3stepAuthenticated = $true
        $global:3stepUrl = $Url
        Write-Log -Message "3step Authenticated: $3stepAuthenticated`n3step URL = $3stepUrl" -Active $LogToFile
        Write-Host "3step Authenticated: $3stepAuthenticated`n3step URL = $3stepUrl`nUse Header Connection Variable ="'$3stepAuthenticationHeader'
        $global:3stepAuthenticationHeader = @{Authorization = "$($testConnection.token_type) $($testConnection.access_token)"}
        return ""
    }
    Write-Log -Message "3step Authenticated: $3stepAuthenticated" -Active $LogToFile
    Write-Host "3step Authenticated: $3stepAuthenticated"
    return $false
}

Function Find-3stepConnection {
    if (!$3stepAuthenticated) {
        Write-Warning "3step API is not authenticated, you need to run Connect-3stepAPI and make sure you put in the correct credentials!"
        return $false
    }
    return $true
}

Function Get-3stepDevices {
    <#
    .SYNOPSIS
    Retrieve all devices from 3STEP asset registry
    
    .DESCRIPTION
    Retrieve all devices from 3STEP asset registry and let the user choose if they want a HashTable object or just normal Powershell Object
    Also the ability to set which property to be the key in the hashtable.
    
    .PARAMETER HashTableKey
    The $variable[keyvalue] - The key value that will be the filter
    
    .PARAMETER AsHashTable
    If the function should return a HashTable otherwise it will be normal powershell object.
    
    .PARAMETER LogToFile
    This parameter is connected to the Module PSLoggingFunctions mot information can be found on the GitHub.
    https://github.com/rakelord/PSLoggingFunctions
    
    .EXAMPLE
    Return a HashTable with the serialnumber as Hash Key and create a log
    Get-3stepDevices -AsHashTable -HashTableKey "serialnumber" -LogToFile $True
    
    Return a Normal Powershell object and do not Log 
    Get-3stepDevices -LogToFile $False
    #>
    Param(
        [switch]
        $AsHashTable,
        $HashTableKey,
        [parameter(mandatory)]
        $LogToFile
    )
    if (Find-3stepConnection) {
        $Devices = @()
        do {
            $Results = Invoke-TryCatchLog -InfoLog "Retrieve All 3STEP Devices" -LogToFile $LogToFile -ScriptBlock { 
                Invoke-RestMethod -Headers $3stepAuthenticationHeader -Uri "$($3stepUrl)rest/devices" -UseBasicParsing -Method "GET" -ContentType "application/json" 
            }
            if ($Results.value) {
                $Devices += $Results.value
            }
            else {
                $Devices += $Results
            }
            $uri = $Results.'@odata.nextlink'
        } until (!($uri))

        if ($AsHashTable){
            $HashTable = @{}
            foreach ($device in $Devices.devices) {
                $HashTable[$device."$HashTableKey"] = $device
            }
            return $HashTable
        }

        return $Devices.devices
    }
}