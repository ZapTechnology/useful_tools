# This script has been tested in 
#   Windows 10 Powershell 3.0
#
# To properly execute this script the Azure user must have permissions in AD
# - Create an app
# - Create a service principal
# - Map Contributor role to service princpal
#
# Reference: https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authenticate-service-principal-cli


# Initialize Parameters
# Create hidden directory for stuff if it doesn't exist

$PMCAzure="$HOME\.PMCAzure"

if (-Not (test-path -Path $PMCAzure)) {

    mkdir $PMCAzure
}


# Use separate log file for each important step.

$AzureCliInstallLog="$PMCAzure\AzureCliInstallLog"
$AzureLoginLog="$PMCAzure\PMCAzureLoginLog"
$AzureAccountLog="$PMCAzure\PMCAzureAccountLog"
$AzureAppLog="$PMCAzure\PMCAzureAppLog"
$AzureServicePrincipalLog="$PMCAzure\PMCAzureServicePrincipalLog"
$AzureRoleLog="$PMCAzure\PMCAzureRoleLog"
$AzureRoleMapLog="$PMCAzure\PMCAzureRoleMapLog"
$AzureRolePermsFile="$PMCAzure\PMCExampleAzureRole.json"

# Install Azure Resource Manager and Azure modules if not already installed
#
# Nothing needed here. Installs automatically on invocation
# Modules Required: AzureRM and Azure


# Login to Azure
# Prompt for username. 
# - Can't be NULL
# - Trap failed login and prompt user to try again


while (-NOT ($LoggedIn)) {
    echo "Logging into Azure."
    echo ""

    $LoggedIn=Login-AzureRmAccount -ErrorAction:SilentlyContinue

    # Record login information
    echo $LoggedIn > $AzureLoginLog

}

# Determine which subscription

$subscriptions = Get-AzureRmSubscription
echo "Here are the subscriptions associated with your account:"
echo ""

$subscriptions | ForEach-Object{
    $_.SubscriptionName
}

echo ""

if($subscriptions.Length -eq 1)
{
    $SubName = $subscriptions.SubscriptionName
}

while (-NOT ($SubName)) {
     $SubName=Read-Host "Enter the subscription name you want to use"
}
    
# Get subscription and tenant ID's
Get-AzureRmSubscription -SubscriptionName $SubName > $AzureAccountLog

Get-Content $AzureAccountLog | ForEach-Object {
    $Left = $_.Split(':')[0]
    $Right = $_.Split(':')[1]

    if ($Left -match "SubscriptionID"){
        $SubscriptionID=$Right.Trim()
    }

    if ($Left -match "TenantID"){
        $TenantID = $Right.Trim()
    }
}

$AppName = "Octopus Deploy"
    

# Prompt for application password
while (-NOT($AppPwd)){

    while (-NOT($AppPwd1)){
        $AppPwd1 = Read-Host "Enter password for your application '$AppName'"
    }

    while (-NOT($AppPwd2)){
        $AppPwd2 = Read-Host "Re-enter your password"
    }
    

    if ($AppPwd1 -match $AppPwd2){
        $AppPwd=$AppPwd1

    }
    else{
        echo "Your passwords do not match. Try again."
        echo ""
        AppPwd1=""
        AppPwd2=""
    }
        
}


# Create App

# If AppName is multiple words then replace whites spaces with "-"
$HTTPName = $AppName | %{$_ -replace (' '),('-')}

# Need proper enddate
$EndDate="2099-12-31 00:00:00Z"

$HomePage="https://www.octopusdeploy.com"
$IdentifierUris="https://$HTTPName-not-used"

New-AzureRmADApplication -DisplayName $AppName -HomePage $HomePage -IdentifierUris $IdentifierUris -Password $AppPwd -EndDate $EndDate > $AzureAppLog


Get-Content $AzureAppLog | ForEach-Object {
    $Left = $_.Split(':')[0]
    $Right = $_.Split(':')[1]

    if ($Left -match "ApplicationId"){
        $AppID = $Right.Trim()
    }
}


# Create Service Principal for App
New-AzureRmADServicePrincipal -ApplicationId $AppID > $AzureServicePrincipalLog

echo ""
echo "Created service principal for application."
echo "" 

$ServicePrincipalName = $AppName

Get-Content $AzureServicePrincipalLog | ForEach-Object {
    if ( $_ -match "$AppName" ) {
        $A = $_.Replace("$AppName","").Trim(" ") -split '\s+'
	$ServicePrincipalID = $A[1].Trim(" ")
    }
}


# Delay until Service Principal appears in Active Directory
while (-NOT ($SP_Present)){
    Get-AzureRmADServicePrincipal > tmp.txt 

    Get-Content .\tmp.txt | ForEach-Object {
        if ( $_ -match "$ServicePrincipalID" ) {
            $A = $_.Replace("$AppName","").Trim(" ") -split '\s+'
	    $SP_Present = $A[1]
	    echo "Service Principal $SP_Present found."
	    echo ""
        }
    }

    sleep 30 

    del .\tmp.txt
}


# Map role to service principal

New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $AppID > $AzureRoleMapLog

echo "Role has been mapped to service principal for application."
echo ""

# Print out final values for service principal credentials
#   Subscription ID
#   Tenant ID
#   App ID (Client ID)
#   App API Access Key

echo "Subscription ID: $SubscriptionID"
echo "Client\Application ID: $AppID"
echo "Tenant ID: $TenantID"
echo "Password\Key: $AppPwd"
echo ""
echo "Enter these on the Azure credential page in Octopus."
echo ""



