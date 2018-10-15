---
external help file: capu-help.xml
Module Name: capu
online version:
schema: 2.0.0
---

# Get-RemoteFiles

## SYNOPSIS
Get Latest URL32 and/or URL64 into tools directxory.

## SYNTAX

```
Get-RemoteFiles [-Purge] [[-FileNameBase] <String>] [[-FileNameSkip] <Int32>]
```

## DESCRIPTION
This function will download the binaries pointed to by $Latest.URL32 and $Latest.URL34.
The function is used to embed binaries into the Chocolatey package.

The function will keep original remote file name but it will add suffix _x32 or _x64.
This is intentional because you can use those to match particular installer via wildcards,
e.g.
\`gi *_x32.exe\`.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -FileNameBase
Override remote file name, use this one as a base.
Suffixes _x32/_x64 are added.
Use this parameter if remote URL doesn't contain file name but generated hash.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FileNameSkip
By default last URL part is used as a file name.
Use this paramter to skip parts 
if file name is specified earlier in the path.

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

### -Purge
Delete existing file having $Latest.FileType extension.
Otherwise, when state of the package remains after the update, older installers
will pile up and may get included in the updated package.

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

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
