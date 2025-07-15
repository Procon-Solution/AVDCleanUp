$azagentservice = get-service -DisplayName "Azure Pipelines Agent*"

if ($null -ne $azagentservice) {
    Write-Host "Azure Pipelines Agent service found"
} 

else {
    Write-Host "Azure Pipelines Agent service not found"

$ErrorActionPreference = "Stop"

# Create directory if it doesn't exist
If (-NOT (Test-Path "C:\azagent")) {
    mkdir "C:\azagent"
}

Set-Location "C:\azagent"

# Create a unique folder
for ($i = 1; $i -lt 100; $i++) {
    $destFolder = "A" + $i.ToString()
    If (-NOT (Test-Path ($destFolder))) {
        mkdir $destFolder
        set-location $destFolder
        break
    }
}

# Download and extract agent with retry logic
$agentZip = "$PWD\agent.zip"
$DefaultProxy = [System.Net.WebRequest]::DefaultWebProxy
$securityProtocol = @()
$securityProtocol += [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::SecurityProtocol = $securityProtocol

$Uri = "https://download.agent.dev.azure.com/agent/4.258.1/vsts-agent-win-x64-4.258.1.zip"
$maxRetries = 3
$retryDelay = 5 # seconds
$downloadSuccess = $false

for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    try {
        Write-Host "Attempting to download Azure DevOps agent (attempt $attempt of $maxRetries)..."
        
        # Clean up any partial download from previous attempt
        if (Test-Path $agentZip) {
            Remove-Item $agentZip -Force
        }
        
        $WebClient = New-Object Net.WebClient
        
        If ($DefaultProxy -and (-NOT $DefaultProxy.IsBypassed($Uri))) {
            $WebClient.Proxy = New-Object Net.WebProxy($DefaultProxy.GetProxy($Uri).OriginalString, $True)
        }

        $WebClient.DownloadFile($Uri, $agentZip)
        
        # Verify the download was successful by checking file exists and has content
        if ((Test-Path $agentZip) -and ((Get-Item $agentZip).Length -gt 0)) {
            Write-Host "Download completed successfully on attempt $attempt"
            $downloadSuccess = $true
            break
        } else {
            throw "Downloaded file is empty or doesn't exist"
        }
    }
    catch {
        Write-Warning "Download attempt $attempt failed: $($_.Exception.Message)"
        
        if ($WebClient) {
            $WebClient.Dispose()
        }
        
        # Clean up failed download
        if (Test-Path $agentZip) {
            Remove-Item $agentZip -Force -ErrorAction SilentlyContinue
        }
        
        if ($attempt -lt $maxRetries) {
            Write-Host "Waiting $retryDelay seconds before retry..."
            Start-Sleep -Seconds $retryDelay
        }
    }
    finally {
        if ($WebClient) {
            $WebClient.Dispose()
        }
    }
}

if (-not $downloadSuccess) {
    throw "Failed to download Azure DevOps agent after $maxRetries attempts"
}

# Extract zip with error handling
try {
    Write-Host "Extracting agent files..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($agentZip, "$PWD")
    Write-Host "Agent files extracted successfully"
}
catch {
    throw "Failed to extract agent files: $($_.Exception.Message)"
}

# Configure agent
.\config.cmd --unattended --environment --environmentname "DeploymentTEST" --agent $env:COMPUTERNAME --runasservice --work '_work' --url 'https://dev.azure.com/Procon-Solution/' --projectname 'Procon-Operations' --auth PAT --token "8DFGdQb9lQ6wWzdelptibLlWSf21ZdW9EDE9ATZi3LnsdBepa9o4JQQJ99BGACAAAAAXFLSwAAASAZDO2O4O" --acceptteeeula

    # Cleanup with error handling
    try {
        Remove-Item $agentZip -Verbose
        Write-Host "Cleanup completed successfully"
    }
    catch {
        Write-Warning "Failed to clean up agent zip file: $($_.Exception.Message)"
        # Don't throw here as the main task is complete
    }
}

######################################################################################################################################################################################################################################
######################################################################################################################################################################################################################################
######################################################################################################################################################################################################################################

$hostname = hostname

$organization = "Procon-Solution"
$project = "Procon-Operations"
$pipelineId = "76" # Example pipeline ID
$personalAccessToken = "11CBnqyNUJw7gLS1bqrcFYOTa8vxKJb63DU1UDO5QSiRzPyThHWQJQQJ99ALACAAAAAXFLSwAAASAZDOYaDk" # PAT
$vm = $hostname
# Base64 encode the PAT for basic authentication
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($personalAccessToken)"))

# Create the request URI
$uri = "https://dev.azure.com/$organization/$project/_apis/pipelines/$pipelineId/runs?api-version=7.1-preview.1"
        
# Create the request body with multiple parameters (customize the values as needed)
$body = @{
    resources = @{
        repositories = @{
            self = @{
                refName = "refs/heads/main" # Example branch
            }
        }
    }
    templateParameters = @{
        vmName     = $vm # Make sure this is the correct value
        location   = "DeploymentTEST"
    }
} | ConvertTo-Json -Depth 10

# Make the API call to trigger the pipeline
try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Body $body -ContentType "application/json"
    Write-Host "Pipeline triggered successfully!"
    $response
}
catch {
    Write-Host "Error triggering the pipeline: $($_.Exception.Message)"
    $response
}

######################################################################################################################################################################################################################################
######################################################################################################################################################################################################################################
######################################################################################################################################################################################################################################
