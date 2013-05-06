param($installPath, $toolsPath, $package, $project)

Import-Module (Join-Path $toolsPath dotPeek-PluginDevelopment.psm1) | Out-Null

Remove-DotPeekPlugin