---
external help file: capu-help.xml
Module Name: capu
online version: https://github.com/pauby/capu/blob/master/docs/Update-Package.md
schema: 2.0.0
---

# Update-Package

## SYNOPSIS
Update automatic package

## SYNTAX

```
Update-Package [-NoCheckUrl] [-NoCheckChocoVersion] [[-ChecksumFor] <String>] [[-Timeout] <Int32>] [-Force]
 [-NoHostOutput] [[-Result] <String>] [<CommonParameters>]
```

## DESCRIPTION
This function is used to perform necessary updates to the specified files in the package.
It shouldn't be used on its own but must be part of the script which defines two functions:

- au_SearchReplace
  The function should return HashTable where keys are file paths and value is another HashTable
  where keys and values are standard search and replace strings
- au_GetLatest
  Returns the HashTable where the script specifies information about new Version, new URLs and
  any other data.
You can refer to this variable as the $Latest in the script.
  While Version is used to determine if updates to the package are needed, other arguments can
  be used in search and replace patterns or for whatever purpose.

With those 2 functions defined, calling Update-Package will:

- Call your au_GetLatest function to get the remote version and other information.
- If remote version is higher then the nuspec version, function will:
    - Check the returned URLs, Versions and Checksums (if defined) for validity (unless NoCheckXXX variables are specified)
    - Download files and calculate checksum(s), (unless already defined or ChecksumFor is set to 'none')
    - Update the nuspec with the latest version
    - Do the necessary file replacements
    - Pack the files into the nuget package

You can also define au_BeforeUpdate and au_AfterUpdate functions to integrate your code into the update pipeline.

## EXAMPLES

### EXAMPLE 1
```
notepad update.ps1
```

import-module au

function global:au_SearchReplace {
    ".\tools\chocolateyInstall.ps1" = @{
        "(^\[$\]url32\s*=\s*)('.*')"          = "\`$1'$($Latest.URL32)'"
        "(^\[$\]checksum32\s*=\s*)('.*')"     = "\`$1'$($Latest.Checksum32)'"
        "(^\[$\]checksumType32\s*=\s*)('.*')" = "\`$1'$($Latest.ChecksumType32)'"
    }
}

function global:au_GetLatest {
    $download_page = Invoke-WebRequest -Uri https://github.com/hluk/CopyQ/releases

    $re  = "copyq-.*-setup.exe"
    $url = $download_page.links | ?
href -match $re | select -First 1 -expand href
    $version = $url -split '-|.exe' | select -Last 1 -Skip 2

    return @{ URL32 = $url; Version = $version }
}

Update-Package -ChecksumFor 32

## PARAMETERS

### -ChecksumFor
Specify for which architectures to calculate checksum - all, 32 bit, 64 bit or none.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: All
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Force package update even if no new version is found.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoCheckChocoVersion
Do not check if latest returned version already exists in the Chocolatey community feed.
Ignored when Force is specified.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoCheckUrl
Do not check URL and version for validity.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoHostOutput
Do not show any Write-Host output.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Result
Output variable.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Timeout
Timeout for all web operations, by default 100 seconds.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSCustomObject with type AUPackage.
## NOTES
All function parameters accept defaults via global variables with prefix \`au_\` (example: $global:au_Force = $true).

## RELATED LINKS

[Update-AUPackages]()

