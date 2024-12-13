$appname = @"
'||'  '|'           '||                                               
 '|.  .'     ...     ||   ... ...   .. .. ..      ....                
  ||  |    .|  '|.   ||    ||  ||    || || ||   .|...||               
   |||     ||   ||   ||    ||  ||    || || ||   ||                    
    |       '|..|'  .||.   '|..'|.  .|| || ||.   '|...'               
                                                                      
                                                                      
    |          '||      ||                      .                     
   |||       .. ||     ...  ... ...    ....   .||.     ....   ... ..  
  |  ||    .'  '||      ||   ||  ||   ||. '    ||    .|...||   ||' '' 
 .''''|.   |.   ||      ||   ||  ||   . '|..   ||    ||        ||     
.|.  .||.  '|..'||.     ||   '|..'|.  |'..|'   '|.'   '|...'  .||.    
                     .. |'                                            
                      ''                                              
"@

$ver = @"

                                    Version 1.0.0
"@

Write-Host "`n`n" 

Write-Host $appname -ForegroundColor Yellow

Write-Host $ver -ForegroundColor Red

Write-Host "`n" 











$scriptDir = Get-Location

$ffmpegPath = Join-Path -Path $scriptDir -ChildPath "ffmpeg.exe"

if (-not (Test-Path -Path $ffmpegPath)) {
    Write-Host "`n`n`n`n`n"
    Write-Host "ffmpeg not found at $ffmpegPath. Please ensure ffmpeg.exe is in the same folder as the script." -ForegroundColor Red
    Write-Host "`n"
    Write-Host "Press any key to exit..."
    Read-Host
    exit
}

$rootFolder = Join-Path -Path $scriptDir -ChildPath "sounds"
if (-not (Test-Path -Path $rootFolder)) {
    Write-Host "`n`n`n`n`n"
    Write-Host "'sounds' folder not found at $scriptDir. Please ensure the folder exists." -ForegroundColor Red
    Write-Host "`n"
    Write-Host "Press any key to exit..."
    Read-Host
    exit
}

$backupFolder = Join-Path -Path $scriptDir -ChildPath "BackUp_Sounds"

$audioFiles = Get-ChildItem -Path $rootFolder -Recurse -Include *.mp3, *.wav
if ($audioFiles.Count -eq 0) {
    Write-Host "`n`n`n`n`n"
    Write-Host "No audio files found in $rootFolder." -ForegroundColor Red
    Write-Host "`n"
    Write-Host "Press any key to exit..."
    Read-Host
    exit
}

Write-Host "`nFound $(($audioFiles.Count) | ForEach-Object { $_ }) audio files." -ForegroundColor Green
Write-Host "`nChoose an option:" -ForegroundColor white
Write-Host "1 - Reduce the Volumes of Audios + Create Separate Folders Depend Volume Adjustment + Create Soundevents File" -ForegroundColor Magenta
Write-Host "2 - Reduce the Volumes of Audios + Create Soundevents File" -ForegroundColor Magenta
Write-Host "3 - Create Soundevents File Only" -ForegroundColor Magenta
Write-Host ""

$validChoice = $false
while (-not $validChoice) {
    Write-Host "Enter your choice (1 / 2 / 3):" -ForegroundColor Yellow -NoNewline

    $choice = Read-Host

    if ($choice -eq "1") {
        Write-Host "`nChoose volumes (From 1 To 1000):" -ForegroundColor White
        Write-Host "1" -ForegroundColor Magenta -NoNewline
        Write-Host " - " -ForegroundColor Gray -NoNewline
        Write-Host "(Quietest volume)" -ForegroundColor DarkGreen
        Write-Host "900" -ForegroundColor Magenta -NoNewline
        Write-Host " - " -ForegroundColor Gray -NoNewline
        Write-Host "(Loudest volume)" -ForegroundColor Red
        Write-Host ""

        $volumeLevels = @{ }
        while ($volumeLevels.Count -eq 0) {
            Write-Host "Enter (Multiple Or Single Volume Level) [Example: 100,80,60,40,20]:" -ForegroundColor Yellow -NoNewline
            $userInput = Read-Host

            $volumeLevels = @{}
            $userInput.Split(',') | ForEach-Object {
                $volume = $_.Trim()
                if ($volume -match '^\d+$') {
                    $volume = [int]$volume
                    if ($volume -gt 0 -and $volume -le 1000) {
                        $scaledVolume = $volume / 100.0

                        if ($scaledVolume -lt 0.1) { $scaledVolume = 0.1 }
                        if ($scaledVolume -gt 5) { $scaledVolume = 5 }

                        $volumeLevels["${volume}_volume"] = $scaledVolume
                    }
                }
            }

            if ($volumeLevels.Count -eq 0) {
                Write-Host "Invalid input! Please enter valid volume levels between 1 and 1000" -ForegroundColor Red
            }
        }

        Write-Host "Volume levels selected: $($volumeLevels.Keys -join ', ')"

        if (-not (Test-Path -Path $backupFolder)) {
            New-Item -Path $backupFolder -ItemType Directory | Out-Null
        }

        $audioFiles = Get-ChildItem -Path $rootFolder -Recurse -Include *.mp3, *.wav
        if ($audioFiles.Count -eq 0) {
            Write-Host "No audio files found in $rootFolder." -ForegroundColor Red
            exit
        }

        foreach ($audioFile in $audioFiles) {
            $audioFilePath = $audioFile.FullName

            $relativePath = $audioFile.DirectoryName.Substring($rootFolder.Length)
            $backupFileFolder = Join-Path -Path $backupFolder -ChildPath $relativePath

            if (-not (Test-Path -Path $backupFileFolder)) {
                Write-Host "Creating backup folder: $backupFileFolder"
                New-Item -Path $backupFileFolder -ItemType Directory | Out-Null
            } else {
                Write-Host "Backup folder already exists: $backupFileFolder"
            }

            $backupFilePath = Join-Path -Path $backupFileFolder -ChildPath $audioFile.Name
            Move-Item -Path $audioFilePath -Destination $backupFilePath
            Write-Host "Moved $($audioFile.Name) to $backupFileFolder"

            foreach ($volumeLevel in $volumeLevels.GetEnumerator()) {
				$volumeFolder = Join-Path -Path $audioFile.DirectoryName -ChildPath $volumeLevel.Key
				if (-not (Test-Path -Path $volumeFolder)) {
					Write-Host "Creating volume folder: $volumeFolder"
					New-Item -Path $volumeFolder -ItemType Directory | Out-Null
				}

				$ffmpegArgs = @(
					"-loglevel", "quiet",
					"-i", "`"$backupFilePath`"",
					"-filter:a", "`"volume=$($volumeLevel.Value)`"",
					"`"$volumeFolder\$($audioFile.Name)`""
				)

				& "$ffmpegPath" @ffmpegArgs
				Write-Host "Processed $($audioFile.Name) with volume $($volumeLevel.Value)"
			}
        }

        $validChoice = $true

    } elseif ($choice -eq "2") {
        
		Write-Host "`nChoose volumes (From 1 To 1000):" -ForegroundColor White
        Write-Host "1" -ForegroundColor Magenta -NoNewline
        Write-Host " - " -ForegroundColor Gray -NoNewline
        Write-Host "(Quietest volume)" -ForegroundColor DarkGreen
        Write-Host "900" -ForegroundColor Magenta -NoNewline
        Write-Host " - " -ForegroundColor Gray -NoNewline
        Write-Host "(Loudest volume)" -ForegroundColor Red
        Write-Host ""
		
        $validVolume = $false
        while (-not $validVolume) {
            Write-Host "Enter your (Single Volume Level) [Example: 40]:" -ForegroundColor Yellow -NoNewline
            $singleVolume = Read-Host

            if ($singleVolume -match '^\d+$') {
                $singleVolume = [int]$singleVolume
                if ($singleVolume -gt 0 -and $singleVolume -le 1000) {
                    $scaledVolume = $singleVolume / 100.0

                    if ($scaledVolume -lt 0.1) { $scaledVolume = 0.1 }
                    if ($scaledVolume -gt 5) { $scaledVolume = 5 }

                    Write-Host "Single volume level selected: $singleVolume"
                    $validVolume = $true

                    if (-not (Test-Path -Path $backupFolder)) {
                        New-Item -Path $backupFolder -ItemType Directory | Out-Null
                    }

                    foreach ($audioFile in $audioFiles) {
                        $audioFilePath = $audioFile.FullName

                        $relativePath = $audioFile.DirectoryName.Substring($rootFolder.Length)
                        $backupFileFolder = Join-Path -Path $backupFolder -ChildPath $relativePath
                        if (-not (Test-Path -Path $backupFileFolder)) {
                            Write-Host "Creating backup folder: $backupFileFolder"
                            New-Item -Path $backupFileFolder -ItemType Directory | Out-Null
                        }

                        $backupFilePath = Join-Path -Path $backupFileFolder -ChildPath $audioFile.Name
                        Move-Item -Path $audioFilePath -Destination $backupFilePath
                        Write-Host "Moved $($audioFile.Name) to $backupFileFolder"

                        $ffmpegArgs = @(
                            "-loglevel", "quiet",
                            "-i", "`"$backupFilePath`"",
                            "-filter:a", "`"volume=$scaledVolume`"",
                            "`"$audioFilePath`""
                        )

                        & "$ffmpegPath" @ffmpegArgs
                        Write-Host "Processed and overwritten $($audioFile.Name) with volume $scaledVolume"
                    }

                } else {
                    Write-Host "Invalid volume! Please enter a volume between 1 and 1000." -ForegroundColor Red
                }
            } else {
                Write-Host "Invalid input! Please enter a valid number for volume." -ForegroundColor Red
            }
        }

        $validChoice = $true

    } elseif ($choice -eq "3") {
        $validChoice = $true
    } else {
        Write-Host "Invalid choice! Please choose only 1, 2, or 3." -ForegroundColor Red
    }
}

$soundEventsFolder = Join-Path -Path $scriptDir -ChildPath "soundevents"

if (-not (Test-Path -Path $soundEventsFolder)) {
    New-Item -Path $soundEventsFolder -ItemType Directory -Force | Out-Null
}

# Prompt user for file name (default to "soundevents_MVP_N_RoundEnd.vsndevts" if no input)
Write-Host "`n`n`n Enter the name of the .vsndevts file (press Enter to use the default):" -ForegroundColor Yellow -NoNewline
$userInput = Read-Host

$soundEventsFile = if ($userInput) { 
    # Ensure the file name ends with .vsndevts
    if ($userInput -notlike "*.vsndevts") {
        $userInput = "$userInput.vsndevts"
    }
    Join-Path -Path $soundEventsFolder -ChildPath $userInput
} else { 
    Join-Path -Path $soundEventsFolder -ChildPath "soundevents_GoldKingZ.vsndevts"
}

# Initialize content for the sound events file
$soundEventsContent = @"
<!-- kv3 encoding:text:version{e21c7f3c-8a33-41c5-9977-a76d3a32aa0d} format:generic:version{7412167c-06e9-4698-aff2-e63eb59037e7} -->
{
"@

# Create a hashtable to track unique entries
$uniqueEntries = @{}

# Get audio files (mp3, wav) excluding the BackUp_Sounds folder
$audioFiles = Get-ChildItem -Path $scriptDir -Recurse -File -Include *.mp3, *.wav | Where-Object { $_.Directory.FullName -notlike "*BackUp_Sounds*" }

foreach ($audioFile in $audioFiles) {
    $folderName = $audioFile.Directory.Name
    $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($audioFile.Name)

    # Calculate the relative path for the audio file
    $relativePath = $audioFile.FullName -replace [regex]::Escape($scriptDir), "sounds"

    # Clean up the relative path if it starts with an unwanted prefix
    if ($relativePath.StartsWith("sounds/sounds") -or $relativePath.StartsWith("sounds\sounds")) {
        $relativePath = $relativePath.Substring(7)
    }

    $relativePath = $relativePath -replace '\\', '/'
    $relativePath = [System.IO.Path]::ChangeExtension($relativePath, ".vsnd")

    # Create a unique entry key for each sound
    $entryKey = "$folderName" + "_" + "$fileNameWithoutExtension"
    $originalEntryKey = $entryKey
    $counter = 2
    while ($uniqueEntries.ContainsKey($entryKey)) {
        $entryKey = "$originalEntryKey$counter"
        $counter++
    }

    # Define the content for this entry
    $entryContent = @"
    "$entryKey" =
    {
        type = "csgo_mega"
        volume = 1.000000
        pitch = 1.000000
        vsnd_files_track_01 = "$relativePath"
    }
"@

    # Add the entry to the uniqueEntries hashtable
    $uniqueEntries[$entryKey] = $entryContent
}

# Check if the sound events file already exists, and remove it if it does
if (Test-Path -Path $soundEventsFile) {
    Remove-Item -Path $soundEventsFile -Force
}

# Write the entries to the sound events file
$soundEventsContent += $uniqueEntries.Values -join "`n"
$soundEventsContent += "}"

# Save the sound events content to the file
$soundEventsContent | Out-File -FilePath $soundEventsFile -Force

Write-Host "Sound events have been successfully updated to $soundEventsFile"

















$goldKingZ = @"
    _____      ____     _____       ______         __   ___    _____      __      _      _____     ______   
   / ___ \    / __ \   (_   _)     (_  __ \       () ) / __)  (_   _)    /  \    / )    / ___ \   (____  )  
  / /   \_)  / /  \ \    | |         ) ) \ \      ( (_/ /       | |     / /\ \  / /    / /   \_)      / /   
 ( (  ____  ( ()  () )   | |        ( (   ) )     ()   (        | |     ) ) ) ) ) )   ( (  ____   ___/ /_   
 ( ( (__  ) ( ()  () )   | |   __    ) )  ) )     () /\ \       | |    ( ( ( ( ( (    ( ( (__  ) /__  ___)  
  \ \__/ /   \ \__/ /  __| |___) )  / /__/ /      ( (  \ \     _| |__  / /  \ \/ /     \ \__/ /    / /____  
   \____/     \____/   \________/  (______/       ()_)  \_\   /_____( (_/    \__/       \____/    (_______) 
                                                                                                           
"@

$goldKingZDiscord = @"

                                    My Github: https://github.com/oqyh 
                                    My Discord: oQYh
                                    Our Discord Community: https://discord.com/invite/U7AuQhu 
"@

Write-Host "`n`n`n`n`n" 

Write-Host $goldKingZ -ForegroundColor Yellow

Write-Host $goldKingZDiscord -ForegroundColor Red

Write-Host "`n`n`n`n`n"

Write-Host "Sounds Finish" -ForegroundColor Green

Write-Host "Press any key to exit..."
[System.Console]::ReadKey($true) | Out-Null