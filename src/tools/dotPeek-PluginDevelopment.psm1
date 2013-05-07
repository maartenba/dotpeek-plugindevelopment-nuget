﻿function Get-DotPeekPath {
    if ((Test-Path "hklm:\Software\Wow6432Node\JetBrains\dotPeek\v1.1" -IsValid) -eq $True) {
        return (Get-ItemProperty hklm:\Software\Wow6432Node\JetBrains\dotPeek\v1.1).InstallDir;
    }
    if ((Test-Path "${Env:ProgramFiles(x86)}\JetBrains\DotPeek\v1.0" -IsValid) -eq $True) {
        return "${Env:ProgramFiles(x86)}\JetBrains\DotPeek\v1.0";
    }
}

function Get-DotPeekInstalledVersion {
    if ((Test-Path "hklm:\Software\Wow6432Node\JetBrains\dotPeek\v1.1" -IsValid) -eq $True) {
        return "1.1";
    }
    if ((Test-Path "${Env:ProgramFiles(x86)}\JetBrains\DotPeek\v1.0" -IsValid) -eq $True) {
        return "1.0";
    }
}

function Resolve-ProjectName {
    param(
        [parameter(ValueFromPipelineByPropertyName = $true)]
        [string[]]$ProjectName
    )
    
    if($ProjectName) {
        $projects = Get-Project $ProjectName
    }
    else {
        # All projects by default
        $projects = Get-Project -All
    }
    
    $projects
}

function Get-MSBuildProject {
    param(
        [parameter(ValueFromPipelineByPropertyName = $true)]
        [string[]]$ProjectName
    )
    Process {
        (Resolve-ProjectName $ProjectName) | % {
            $path = $_.FullName
            @([Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection.GetLoadedProjects($path))[0]
        }
    }
}

function Set-MSBuildProperty {
    param(
        [parameter(Position = 0, Mandatory = $true)]
        $PropertyName,
        [parameter(Position = 1, Mandatory = $true)]
        $PropertyValue,
        [parameter(Position = 2, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ProjectName
    )
    Process {
        (Resolve-ProjectName $ProjectName) | %{
            $buildProject = $_ | Get-MSBuildProject
            $buildProject.SetProperty($PropertyName, $PropertyValue) | Out-Null
            $buildProject.Save()
            $_.Save()
        }
    }
}

function Get-MSBuildProperty {
    param(
        [parameter(Position = 0, Mandatory = $true)]
        $PropertyName,
        [parameter(Position = 2, ValueFromPipelineByPropertyName = $true)]
        [string]$ProjectName
    )
    
    $buildProject = Get-MSBuildProject $ProjectName
    $buildProject.GetProperty($PropertyName)
}

function Initialize-DotPeekPlugin {
    if ((Test-Path Get-DotPeekPath -IsValid) -eq $False) {
        [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        $result = [Windows.Forms.MessageBox]::Show("You currently do not have JetBrains dotPeek installed. Would you like to download it now?", "JetBrains dotPeek", [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Information);
        if ($result -eq [Windows.Forms.DialogResult]::Yes) {
            Start-Process -FilePath "http://www.jetbrains.com/decompiler/download/index.html"
        }
        
        [Windows.Forms.MessageBox]::Show("After installing JetBrains dotPeek, please run the Configure-DotPeekPlugin CmdLet from the NuGet package manager console.", "JetBrains dotPeek", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Information);
    } else {
        # Set correct Build Action for Actions.xml
        $item = (Get-Project).ProjectItems | where-object {$_.Name -eq "Actions.xml"} 
        $item.Properties.Item("BuildAction").Value = [int]3
        
        # Reference dotPeek assemblies
        Get-ChildItem -Path ((Get-DotPeekPath) + "\JetBrains*.dll") | %{
            (Get-Project).Object.References.Add( $_.FullName ) | Out-Null
            try { (Get-Project).Object.References.Item( [System.IO.Path]::GetFileNameWithoutExtension( $_.Name )).CopyLocal = $False | Out-Null  } catch { }
        }
        if ((Get-DotPeekInstalledVersion) -eq "1.0") {
            Get-ChildItem -Path ((Get-DotPeekPath) + "\dot*.exe") | %{
                (Get-Project).Object.References.Add( $_.FullName ) | Out-Null 
                try { (Get-Project).Object.References.Item( [System.IO.Path]::GetFileNameWithoutExtension( $_.Name )).CopyLocal = $False | Out-Null  } catch { }
            }
        }
        if ((Get-DotPeekInstalledVersion) -eq "1.1") {
            Get-ChildItem -Path ((Get-DotPeekPath) + "\dot*.dll") | %{
                (Get-Project).Object.References.Add( $_.FullName ) | Out-Null 
                try { (Get-Project).Object.References.Item( [System.IO.Path]::GetFileNameWithoutExtension( $_.Name )).CopyLocal = $False | Out-Null  } catch { } 
            }
        }
        
        # Update project file
        $project = Get-Project
        $project.Save()
        
        # Define constants
        $defineConstants = (Get-MSBuildProperty DefineConstants $project.Name).UnevaluatedValue
        if ((Get-DotPeekInstalledVersion) -eq "1.0") {
            Set-MSBuildProperty DefineConstants "$defineConstants;JET_MODE_ASSERT;DP10" $project.Name
        }
        if ((Get-DotPeekInstalledVersion) -eq "1.1") {
            Set-MSBuildProperty DefineConstants "$defineConstants;JET_MODE_ASSERT;DP11" $project.Name
        }
        
        # Post-build event
        $dotPeekVersion = (Get-DotPeekInstalledVersion)
        $postBuildEvent = (Get-MSBuildProperty PostBuildEvent $project.Name).UnevaluatedValue
        Set-MSBuildProperty PostBuildEvent "$postBuildEvent
mkdir `$(LOCALAPPDATA)\JetBrains\dotPeek\v$dotPeekVersion\plugins
xcopy /Y `$(TargetDir)*.dll `$(LOCALAPPDATA)\JetBrains\dotPeek\v$dotPeekVersion\plugins
xcopy /Y `$(TargetDir)*.pdb `$(LOCALAPPDATA)\JetBrains\dotPeek\v$dotPeekVersion\plugins" $project.Name

        # Start action
        Set-MSBuildProperty StartAction "Program" $project.Name
        $startPath = (Get-DotPeekPath)
        if ((Get-DotPeekInstalledVersion) -eq "1.0") {
            Set-MSBuildProperty StartProgram "$startPath\dotPeek.exe" $project.Name
        }
        if ((Get-DotPeekInstalledVersion) -eq "1.1") {
            Set-MSBuildProperty StartProgram "$startPath\dotPeek32.exe" $project.Name
        }
        Set-MSBuildProperty StartArguments "/Internal" $project.Name
    }
}

function Remove-DotPeekPlugin {
    # Unreference dotPeek assemblies
    Get-ChildItem -Path ((Get-DotPeekPath) + "\JetBrains*.dll") | %{
        $reference = $_.Name;
        (Get-Project).Object.References | Where-Object { $_.Name + ".dll" -eq $reference } | %{ $_.Remove() | Out-Null }
    }
    if ((Get-DotPeekInstalledVersion) -eq "1.0") {
        Get-ChildItem -Path ((Get-DotPeekPath) + "\dot*.exe") | %{
            $reference = $_.Name;
            (Get-Project).Object.References | Where-Object { $_.Name + ".dll" -eq $reference } | %{ $_.Remove() | Out-Null }
        }
    }
    if ((Get-DotPeekInstalledVersion) -eq "1.1") {
        Get-ChildItem -Path ((Get-DotPeekPath) + "\dot*.dll")  | %{
            $reference = $_.Name;
            (Get-Project).Object.References | Where-Object { $_.Name + ".dll" -eq $reference } | %{ $_.Remove() | Out-Null }
        }
    }
}

Export-ModuleMember -Function *