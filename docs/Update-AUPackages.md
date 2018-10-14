---
external help file: capu-help.xml
Module Name: capu
online version: https://github.com/pauby/capu/blob/master/docs/Update-AUPackages.md
schema: 2.0.0
---

# Update-AUPackages

## SYNOPSIS
Update all automatic packages

## SYNTAX

```
Update-AUPackages [[-Name] <String[]>] [[-Options] <OrderedDictionary>] [-NoPlugins] [<CommonParameters>]
```

## DESCRIPTION
Function Update-AUPackages will iterate over update.ps1 scripts and execute each.
If it detects
that a package is updated it will push it to the Chocolatey community repository.

The function will look for AU packages in the directory pointed to by the global variable au_root
or in the current directory if mentioned variable is not set.

For the push to work, specify your API key in the file 'api_key' in the script's directory or use
cached nuget API key or set environment variable '$Env:api_key'.

The function accepts many options via ordered HashTable parameter Options.

## EXAMPLES

### EXAMPLE 1
```
Update-AUPackages p* @{ Threads = 5; Timeout = 10 }
```

Update all automatic packages in the current directory that start with letter 'p' using 5 threads
and web timeout of 10 seconds.

### EXAMPLE 2
```
$au_root = 'c:\chocolatey'; updateall @{ Force = $true }
```

Force update of all automatic ackages in the given directory.

## PARAMETERS

### -Name
Filter package names.
Supports globs.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoPlugins
Do not run plugins, defaults to global variable \`au_NoPlugins\`.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: $global:au_NoPlugins
Accept pipeline input: False
Accept wildcard characters: False
```

### -Options
Hashtable with options:
  Threads           - Number of background jobs to use, by default 10.
  Timeout           - WebRequest timeout in seconds, by default 100.
  UpdateTimeout     - Timeout for background job in seconds, by default 1200 (20 minutes).
  Force             - Force package update even if no new version is found.
  Push              - Set to true to push updated packages to Chocolatey community repository.
  PluginPath        - Additional path to look for user plugins.
If not set only module integrated plugins will work

  Plugin            - Any HashTable key will be treated as plugin with the same name as the option name.
                      A script with that name will be searched for in the AU module path and user specified path.
                      If script is found, it will be called with splatted HashTable passed as plugin parameters.

                      To list default AU plugins run:

                            ls "$(Split-Path (gmo au -list).Path)\Plugins\*.ps1"

  BeforeEach        - User ScriptBlock that will be called before each package and accepts 2 arguments: Name & Options.
                      To pass additional arguments, specify them as Options key/values.
  AfterEach         - Similar as above.
  Script            - Script that will be called before and after everything.

```yaml
Type: OrderedDictionary
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: @{}
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### AUPackage[]
## NOTES

## RELATED LINKS

[Update-Package]()

