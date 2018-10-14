---
external help file: capu-help.xml
Module Name: capu
online version: https://github.com/pauby/capu/blob/master/docs/Get-AUPackages.md
schema: 2.0.0
---

# Get-AUPackages

## SYNOPSIS
Get AU packages

## SYNTAX

```
Get-AUPackages [[-Name] <String[]>]
```

## DESCRIPTION
Returns list of directories that have update.ps1 script in them and package name
doesn't start with the '_' char (unpublished packages, not considered by Update-AUPackages
function).

Function looks in the directory pointed to by the global variable $au_root or, if not set, 
the current directory.

## EXAMPLES

### EXAMPLE 1
```
gau p*
```

Get all automatic packages that start with 'p' in the current directory.

### EXAMPLE 2
```
$au_root = 'c:\packages'; lsau 'cpu-z*','p*','copyq'
```

Get all automatic packages  in the directory 'c:\packages' that start with 'cpu-z' or 'p' and package which name is 'copyq'.

## PARAMETERS

### -Name
{{Fill Name Description}}

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

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
