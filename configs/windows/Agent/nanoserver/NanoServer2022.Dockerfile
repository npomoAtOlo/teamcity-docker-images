# The list of required arguments
# ARG nanoserverImage
# ARG powershellImage
# ARG teamcityWindowsservercoreImage

# Id teamcity-agent
# Tag ${versionTag}-${tag}
# Tag ${latestTag}
# Tag ${versionTag}
# Platform ${windowsPlatform}
# Repo ${repo}
# Weight 2

## ${agentCommentHeader}

# @AddToolToDoc [${jdkWindowsComponentName}](${jdkWindowsComponent})
# @AddToolToDoc ${powerShellComponentName}
# @AddToolToDoc [${gitWindowsComponentName}](${gitWindowsComponent})
# @AddToolToDoc [${dotnetWindowsComponentName}](${dotnetWindowsComponent})

# Based on ${powershellImage} 3
FROM ${powershellImage} AS dotnet

# On some agents, Windows 2022 requires administrator permissions to modify "C:/" folder within ...
# ... PowerShell container.
USER ContainerAdministrator

COPY scripts/*.cs /scripts/

SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Based on ${teamcityWindowsservercoreImage}
ARG teamcityWindowsservercoreImage
FROM ${teamcityWindowsservercoreImage} AS tools

# Workaround for https://github.com/PowerShell/PowerShell-Docker/issues/164
ARG nanoserverImage
# Based on ${nanoserverImage} 2
FROM ${nanoserverImage}

ENV ProgramFiles="C:\Program Files" \
    # set a fixed location for the Module analysis cache
    PSModuleAnalysisCachePath="C:\Users\ContainerUser\AppData\Local\Microsoft\Windows\PowerShell\docker\ModuleAnalysisCache" \
    # Persist %PSCORE% ENV variable for user convenience
    PSCORE="$ProgramFiles\PowerShell\pwsh.exe"

# PowerShell
COPY --from=dotnet ["C:/Program Files/PowerShell", "C:/Program Files/PowerShell"]

# In order to set system PATH, ContainerAdministrator must be used
USER ContainerAdministrator
RUN setx /M PATH "%PATH%;%ProgramFiles%\PowerShell"
USER ContainerUser

# intialize powershell module cache
RUN pwsh -NoLogo -NoProfile -Command " \
    $stopTime = (get-date).AddMinutes(15); \
    $ErrorActionPreference = 'Stop' ; \
    $ProgressPreference = 'SilentlyContinue' ; \
    while(!(Test-Path -Path $env:PSModuleAnalysisCachePath)) {  \
        Write-Host "'Waiting for $env:PSModuleAnalysisCachePath'" ; \
        if((get-date) -gt $stopTime) { throw 'timout expired'} \
        Start-Sleep -Seconds 6 ; \
    }"

# JDK
COPY --from=tools ["C:/Program Files/Java/OpenJDK", "C:/Program Files/Java/OpenJDK"]
# Git
COPY --from=tools ["C:/Program Files/Git", "C:/Program Files/Git"]
# .NET
COPY --from=tools ["C:/Program Files/dotnet", "C:/Program Files/dotnet"]
COPY --from=tools /BuildAgent /BuildAgent

EXPOSE 9090

VOLUME C:/BuildAgent/conf

    # Configuration file for TeamCity agent
ENV CONFIG_FILE="C:\BuildAgent\conf\buildAgent.properties" \
    # Java home directory
    JAVA_HOME="C:\Program Files\Java\OpenJDK" \
    # Opt out of the telemetry feature
    DOTNET_CLI_TELEMETRY_OPTOUT=true \
    # Disable first time experience
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true \
    # Configure Kestrel web server to bind to port 80 when present
    ASPNETCORE_URLS=http://+:80 \
    # Enable detection of running in a container
    DOTNET_RUNNING_IN_CONTAINER=true \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps perfomance
    NUGET_XMLDOC_MODE=skip

# In order to set system PATH, ContainerAdministrator must be used
USER ContainerAdministrator
RUN setx /M PATH "%PATH%;%JAVA_HOME%\bin;C:\Program Files\Git\cmd;C:\Program Files\dotnet"
# Grant Permissions for ContainerUser (Default Account), OI - Object Inherit, CI - Container Inherit, F - full control
RUN cmd /c icacls.exe C:\\BuildAgent\\* /grant:r DefaultAccount:(OI)(CI)F
RUN cmd /c icacls.exe C:\\BuildAgent\\* /grant:r Users:(OI)(CI)F
USER ContainerUser

# Trigger first run experience by running arbitrary cmd to populate local package cache
RUN dotnet help

CMD ["pwsh", "./BuildAgent/run-agent.ps1"]