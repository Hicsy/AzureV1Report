# various myCo-specific azure helper functions
# Beyond scope of this module: PowerShell Gallery module (AzureAD) and Modern Auth. Run Setup-MyCo (or refer our Wiki)


<#
.SYNOPSIS
    Get an audit of all myCo's O365 staff from Azure.
.DESCRIPTION
    Uses the myCo email address login to connect to Azure and create a csv. You can update the one on our network drive.
.EXAMPLE
    Get-AzureAudit
.INPUTS
    SavePath (string) - when you would like the CSV to be saved.
.OUTPUTS
    A CSV file (tab-delimited) default: "c:\temp\myCo_StaffNumbers.csv"
.NOTES
    This assumes you have setup the AzureAD module from PowerShell Gallery. If you are not sure, run Setup-MyCo (or refer wiki)
.COMPONENT
    MyCoTools
.FUNCTIONALITY
    Controller script for the AzureAD module to quickly spit out a user report.
#>
function Get-AzureAudit {
    [CmdletBinding()]
    param (
        # Path to output a CSV file from the report
        $SavePath = "c:\temp\myCo_StaffNumbers.csv",
        # Path to open after export-success
        $CopyPath = "Shared\Clients\Managed Service Clients\myCo"
    )
    
    $CredentialURL = "https://myCo.itglue.com/1111111/passwords/2222222"
    $MFA = "https://syrah.centrastage.net/csm/search?qs=MFA-VM"
    
    Write-Host "Connecting to AzureAD... Please input info@my.co credentials:"
    Write-Host "Launching Credentials webpage: $CredentialURL"
    Write-Host "Launching RDP webpage for the MFA pc: $MFA"
    start $CredentialURL
    start $MFA

    Connect-AzureAD
    # TODO: Handle connection existing/failure/abort

    # Properties is: CSV Headings and Internally-used license names. Also added: mail aliases (slow).
    $properties = (
        "Department" ,
        "GivenName" ,
        "Surname" ,
        "Displayname" ,
        "JobTitle" ,
        "Mail" ,
        "MailNickname" ,
        "SipProxyAddress",
        @{n="Created" ; e={$_.ExtensionProperty.createdDateTime}} ,
        @{n="License" ; e={
            switch($_.assignedLicenses.skuid){
                "c7df2760-2c81-4ef7-b578-5b5392b571df"
                { "Office_E5" }
                "6fd2c87f-b296-42f0-b197-1e91e994b900"
                { "Office_E3" }
                "18181a46-0d4e-45cd-891e-60aabd171b4e"
                { "Office_E1" }
                "4b585984-651b-448a-9e53-3b10f069cf7f"
                { "Office_F1" }
                "488ba24a-39a9-4473-8ee5-19291e71b002"
                { "WIN10_VDA_E5" }
                "b05e124f-c7cc-45a0-a6aa-8cf78c946968"
                { "EMS_E5" }
                "efccb6f7-5641-4e0e-bd10-b4976e1bf68e"
                { "EMS_E3" }
                "c5928f49-12ba-48f7-ada3-0d743a3601d5"
                { "Viso_P2" }
                "f8a1db68-be16-40ed-86d5-cb42ce701560"
                { "PowerBI_Pro" }
                "a403ebcc-fae0-4ca2-8c8c-7a907fd6c235"
                { "PowerBI_Free" }
                "1e1a282c-9c54-43a2-9310-98ef728faace"
                { "Dyn365_Sales" }
                "8e7a3d30-d97d-43ab-837c-d7701cef83dc"
                { "Dyn365_Teams" }
                "f30db892-07e9-47e9-837c-80727f46fd3d"
                { "Flow_Free" }
                "e43b5b99-8dfb-405f-9987-dc307f34bcbd"
                { "Skype_CloudPBX" }
                "d3b4fe1f-9992-4930-8acb-ca6ec609365e"
                { "Skype_Pstn2_International" }
                "0dab259f-bf13-4952-b7f8-7db8f131b28d"
                { "Skype_Pstn1_Domestic" }
                "0c266dff-15dd-4b49-8397-2bb16070ed52"
                { "Skype_Pstn_Conferencing" }
                Default
                {"$PSItem"}
            }
        } } ,
        @{n="Aliases" ; e={
            $_ | Select-Object -ExpandProperty ProxyAddresses | ForEach-Object{if ($_ -notmatch "X500:/*"){Write-output $_}}
        }}
    )

    # Filter is: The list of myCo staff we support.
    # Todo: Connect-MSOL to use the 3x dynamic group memberships (updated more regularly).
    $filter = "
        AccountEnabled eq true
        and (
            UsageLocation eq 'AU'
            or Department eq 'D30-myCo Team 1'
            or Department eq 'D39-D39 -  MYCO TEAM 2'
        )
    "

    Write-Host "Downloading a list of Azure Users..."
    $Users = Get-AzureADUser -All $true -Filter $filter ;

    if($Users){
        $Users | Select-Object $properties | ConvertTo-Csv -NoTypeInformation -Delimiter "`t" | Out-File $SavePath;
        Get-ItemProperty $SavePath;
        explorer.exe (Split-Path $SavePath -Parent)    
        IF (Test-Path "s:\$CopyPath"){explorer.exe "s:\$CopyPath"}
        ELSE {if (Test-Path "z:\$CopyPath"){explorer.exe "z:\$CopyPath"}}
        $SavePath
        "Use: [CTRL]+[SHIFT]+[END] to select all data in a sheet"
    }
    else{
        Write-Warning "No Users Downloaded."
    }
}


<#
.SYNOPSIS
    I don't remember why this function is in this module...
     I think a senior wanted to join it with Local AD but wasnt sure to use Get-AdUser.
.DESCRIPTION
    Produce a simple users csv from myCo local AD for you to import into your charts.
.EXAMPLE
    Get-MyCoDevLocalADAudit
    ^^ Use it like this directly on the server
.EXAMPLE
    Get-MyCoDevLocalADAudit -Server mycodc01.myco.local
    ^^ Use like this if you are on your PC on their network. You can Tab-Autocomplete the server names.
.INPUTS
    Server (string) - The name of the network's server (you can use Tab-Autocomplete).
    SavePath (string) - Where to save the CSV. Default: c:\temp\ADUsers.csv .
.OUTPUTS
    A CSV of all Local AD users.
.NOTES
    Putting in a server name will open a remote-connection to that DC.
.COMPONENT
    MyCoTools
.FUNCTIONALITY
    Local AD Controller Script for reporting users at MyCo.
#>
function Get-MyCoDevLocalADAudit {
    [CmdletBinding()]
    param (
        # The Domain Controller to connect to.
        [Parameter(Mandatory=$false)]
        [validateSet("mycodc01.myco.local","myco01.otherco.com","myco-au-dc01.myco.com.au")]
        [string]
        $Server,
        $SavePath = "c:\temp\ADUsers.csv"
    )
    
    if($Server){
        $myDomain = $(
            $dc = ($Server).Split(".")
            write-output $($dc[1..($dc.Length -1)] -join ".")
        )
        if(!(Get-PSSession -Name "myCo" -ErrorAction SilentlyContinue)){
            # Guesses your myCo login name - most will be correct. A couple seniors with the old convention know to update theirs.
            [pscredential]$CredAD = Get-Credential "$myDomain\$env:USERNAME"
            $seshAD = New-PSSession $Server -Credential $CredAD -Name "myCo"
            Import-Module (Import-PSSession -Session $seshAD -Module ActiveDirectory) -Global -DisableNameChecking
        }
        
    }
    
    (Get-AdUser -Filter 'enabled -eq $True -and mail -like "*"' -properties mail ) | select samaccountname ,  mail | ConvertTo-Csv -NoTypeInformation | out-file $SavePath

}


Export-ModuleMember -Function Get-AzureAudit
Export-ModuleMember -Function Get-MyCoDevLocalADAudit