# The list of required arguments
# ARG windowsservercoreImage
# ARG dotnet1WindowsComponentVersion
# ARG dotnet2WindowsComponentVersion
# ARG jdkWindowsComponent
# ARG gitWindowsComponent
# ARG mercurialWindowsComponentName
# ARG teamcityMinimalAgentImage

# Id teamcity-agent
# Tag ${versionTag}-${tag}
# Tag ${versionTag}-windowsservercore
# Tag ${latestTag}-windowsservercore
# Platform ${windowsPlatform}
# Repo ${repo}
# Weight 13

## ${agentCommentHeader}

# Based on ${teamcityMinimalAgentImage}
FROM ${teamcityMinimalAgentImage} AS buildagent

# Based on ${windowsservercoreImage} 12
ARG windowsservercoreImage
FROM ${windowsservercoreImage}

COPY scripts/*.cs /scripts/

# Install ${powerShellComponentName}
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG dotnet1WindowsComponent
ARG dotnet2WindowsComponent
ARG jdkWindowsComponent
ARG gitWindowsComponent
ARG mercurialWindowsComponent

RUN [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls' ; \
    $code = Get-Content -Path "scripts/Web.cs" -Raw ; \
    Add-Type -TypeDefinition "$code" -Language CSharp ; \
    $downloadScript = [Scripts.Web]::DownloadFiles($Env:jdkWindowsComponent, 'jdk.zip', $Env:gitWindowsComponent, 'git.zip', $Env:mercurialWindowsComponent, 'hg.msi', $Env:dotnet1WindowsComponent, 'dotnet1.zip', $Env:dotnet2WindowsComponent, 'dotnet2.zip') ; \
    Remove-Item -Force -Recurse $Env:ProgramFiles\dotnet; \
# Install [${dotnet2WindowsComponentName}](${dotnet2WindowsComponent})
    Expand-Archive dotnet2.zip -Force -DestinationPath $Env:ProgramFiles\dotnet; \
    Remove-Item -Force dotnet2.zip; \
    Get-ChildItem -Path $Env:ProgramFiles\dotnet -Include *.lzma -File -Recurse | foreach { $_.Delete()}; \
# Install [${dotnet1WindowsComponentName}](${dotnet1WindowsComponent})
    Expand-Archive dotnet1.zip -Force -DestinationPath $Env:ProgramFiles\dotnet; \
    Remove-Item -Force dotnet1.zip; \
    Get-ChildItem -Path $Env:ProgramFiles\dotnet -Include *.lzma -File -Recurse | foreach { $_.Delete()}; \
# Install [${jdkWindowsComponentName}](${jdkWindowsComponent})
    Expand-Archive jdk.zip -DestinationPath $Env:ProgramFiles\Java ; \
    Get-ChildItem $Env:ProgramFiles\Java | Rename-Item -NewName "OpenJDK" ; \
    Remove-Item $Env:ProgramFiles\Java\OpenJDK\demo -Force -Recurse ; \
    Remove-Item $Env:ProgramFiles\Java\OpenJDK\sample -Force -Recurse ; \
    Remove-Item $Env:ProgramFiles\Java\OpenJDK\src.zip -Force ; \
    Remove-Item -Force jdk.zip ; \
# Install [${gitWindowsComponentName}](${gitWindowsComponent})
    $gitPath = $Env:ProgramFiles + '\Git'; \
    Expand-Archive git.zip -DestinationPath $gitPath ; \
    Remove-Item -Force git.zip ; \
    # avoid circular dependencies in gitconfig
    $gitConfigFile = $gitPath + '\etc\gitconfig'; \
    $configContent = Get-Content $gitConfigFile; \
    $configContent = $configContent.Replace('path = C:/Program Files/Git/etc/gitconfig', ''); \
    Set-Content $gitConfigFile $configContent; \
# Install [${mercurialWindowsComponentName}](${mercurialWindowsComponent})
    Start-Process msiexec -Wait -ArgumentList /q, /i, hg.msi ; \
    Remove-Item -Force hg.msi

COPY --from=buildagent /BuildAgent /BuildAgent

EXPOSE 9090

VOLUME C:/BuildAgent/conf

CMD ./BuildAgent/run-agent.ps1

    # Configuration file for TeamCity agent
ENV CONFIG_FILE="C:/BuildAgent/conf/buildAgent.properties" \
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

USER ContainerAdministrator
RUN setx /M PATH ('{0};{1}\bin;C:\Program Files\Git\cmd;C:\Program Files\Mercurial' -f $env:PATH, $env:JAVA_HOME)
USER ContainerUser