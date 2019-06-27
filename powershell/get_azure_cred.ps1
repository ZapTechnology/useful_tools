# This script has been tested in 
#   Windows 10 Powershell 4.0
#
# To properly execute this script the Azure user must have permissions in AD
# - Create an app
# - Create a service principal
# - Map Contributor role to service princpal
#
# Reference: https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authenticate-service-principal-cli


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
}

# Determine which subscription

$subscriptions = Get-AzureRmSubscription
echo "Here are the subscriptions associated with your account:"
echo ""

$subscriptions | ForEach-Object{
    if($_.SubscriptionName -ne $null) {$_.SubscriptionName} else {$_.Name}
}

echo ""

if($subscriptions.Length -eq 1)
{
    $SubName = $subscriptions.SubscriptionName
}

while (-NOT ($SubName)) {
    $SubName=Read-Host "Enter the subscription name you want to use"
}
    
# Set subscription and tenant ID's
$context = Set-AzureRmContext -SubscriptionName $SubName

$SubscriptionID=$context.Subscription.SubscriptionId

CreateLockManagerRole -SubscriptionId $SubscriptionID

$TenantID=$context.Subscription.TenantId

$AppName = "Octopus Deploy"
    

# Prompt for application password
while (-NOT($AppPwd)){
	$AppPwd = Read-Host "Enter password for your application '$AppName'"
}


# Create App

# If AppName is multiple words then replace whites spaces with "-"
$HTTPName = $AppName | %{$_ -replace (' '),('-')}

# Need proper enddate
$EndDate="2099-12-31 00:00:00Z"

$HomePage="https://www.octopusdeploy.com"
$IdentifierUris="https://$([guid]::NewGuid().ToString())-not-used"

$SecureAppPwd=ConvertTo-SecureString $AppPwd -asplaintext -force
$newADApp = New-AzureRmADApplication -DisplayName $AppName -HomePage $HomePage -IdentifierUris $IdentifierUris -Password $SecureAppPwd -EndDate $EndDate

$AppID = $newADApp.ApplicationId

if($AppID -eq $null){
	throw "Can't find application Id, AD application creation may have failed. Make sure you don't have exising AD application with '$AppName'"
}

# Create Service Principal for App
$newServicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $AppID

echo ""
echo "Created service principal for application."
echo "" 

$ServicePrincipalName = $AppName

# Delay until Service Principal appears in Active Directory
while (-NOT ($SP_Present)){
	echo "Delay until Service Principal '$AppName' appears in Active Directory"
    $servicePrincipals = Get-AzureRmADServicePrincipal -SearchString "$AppName"

	foreach($sp in $servicePrincipals){
		if($sp.DisplayName -eq $AppName){
			$SP_Present = $AppName
			echo "Service Principal '$SP_Present' found."
			echo ""
		}
	}

    sleep 30
}


# Map role to service principal

$roleAssignment = New-AzureRmRoleAssignment -RoleDefinitionName 'Contributor' -ServicePrincipalName $AppID

if($roleAssignment -eq $null){
	throw "Failed to assign Contributor role to service principal '$AppName"
}

$roleAssignment = New-AzureRmRoleAssignment -RoleDefinitionName 'Lock Manager' -ServicePrincipalName $AppID

if($roleAssignment -eq $null){
	throw "Failed to assign Lock Manager role to service principal '$AppName"
}

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
