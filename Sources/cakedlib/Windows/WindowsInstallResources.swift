//
//  WindowsInstallResources.swift
//  Caker
//
//  The scripts the Windows installation media carries. They run inside WinPE, where `cmd.exe` batch files,
//  `diskpart` and `dism` are all there is: no PowerShell, no curl, and no way to show anything on screen
//  (nothing refreshes the virtual display once the firmware hands over to Windows), so every step logs to
//  the media and the host reads the outcome back from `caker\result` once the VM has powered off.
//

import Foundation

enum WindowsInstallResources {
	/// Files on the media are read by Windows tools, which want CRLF line endings.
	static func crlf(_ text: String) -> String {
		text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: "\r\n")
	}

	/// Replaces WinPE's default shell (which would start Windows Setup) so the install script runs instead.
	/// Windows Setup would only look for an answer file on removable media, which Virtualization.framework's
	/// USB mass storage doesn't report itself as.
	static let winpeshl = crlf(
		#"""
		[LaunchApps]
		%SYSTEMDRIVE%\Windows\System32\wpeinit.exe
		%SYSTEMDRIVE%\Windows\System32\cmd.exe, /c %SYSTEMDRIVE%\Windows\System32\pe.cmd
		"""#)

	/// Finds the installation media (the volume holding `caker\media.id`, which gets a drive letter some
	/// seconds after WinPE starts), runs its install script, then powers the VM off either way.
	static let peScript = crlf(
		#"""
		@echo off
		set M=
		set /a N=0
		:media
		for %%d in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do if exist %%d:\caker\media.id set M=%%d:
		if defined M goto found
		set /a N+=1
		if %N% geq 150 goto done
		ping -n 3 127.0.0.1 >nul
		goto media
		:found
		rem Load the virtio GPU driver so the display can take over from the firmware's (see EFI\framebuffer.c).
		drvload %M%\caker\drivers\viogpudo\viogpudo.inf >nul 2>&1
		call %M%\caker\install.cmd %M%
		:done
		wpeutil shutdown
		"""#)

	/// Partitions the empty system disk, applies the Windows image, adds the virtio drivers and the boot files.
	static func installScript(for architecture: WindowsArchitecture, whqlOnly: Bool = false) -> String {
		self.installScript(for: architecture, usingFramebufferShim: architecture.usesFramebufferShim, whqlOnly: whqlOnly)
	}

	/// `whqlOnly`: every driver is signed by Microsoft, so nothing is added with `/ForceUnsigned` (an unsigned one fails the install).
	static func installScript(for architecture: WindowsArchitecture, usingFramebufferShim: Bool, whqlOnly: Bool = false) -> String {
		// The framebuffer helpers and the loader that starts them (see WindowsArchitecture.usesFramebufferShim)
		let shim =
			usingFramebufferShim
			? #"""
			mkdir S:\EFI\caker 2>nul
			copy /y %T%\framebuffer.efi S:\EFI\caker\framebuffer.efi >> %LOG% || goto fail
			rem Windows Boot Manager moves to windows.efi and the loader takes its place at the removable media path,
			rem so the framebuffer driver is up before Windows starts (see EFI\loader.c).
			mkdir S:\EFI\BOOT 2>nul
			copy /y S:\EFI\Microsoft\Boot\bootmgfw.efi S:\EFI\BOOT\windows.efi >> %LOG% || goto fail
			copy /y %T%\loader.efi \#(architecture.removableBootPath) >> %LOG% || goto fail
			"""# : "rem Windows Boot Manager stays at the removable media path, no EFI helper is needed"

		return crlf(
		#"""
		@echo off
		rem Installs Windows from WinPE: install.cmd <installation media drive>, e.g. install.cmd C:
		setlocal EnableExtensions
		set M=%1
		set T=%M%\caker
		set LOG=%T%\install.log
		echo [%time%] start > %LOG%
		call %T%\config.cmd
		call :say Installing Windows

		rem The target is the only disk without partitions (the installation media always has some).
		rem diskpart's output is localized, so rely on exit codes: selecting a partition fails on an empty disk.
		set N=0
		for /l %%d in (0,1,7) do (
		  > X:\probe.txt echo select disk %%d
		  diskpart /s X:\probe.txt >nul 2>&1 && (
		    >> X:\probe.txt echo select partition 1
		    diskpart /s X:\probe.txt >nul 2>&1 || (set DISK=%%d& set /a N+=1)
		  )
		)
		if not "%N%"=="1" (call :say expected exactly one empty disk, found %N% & goto fail)
		call :say Target disk %DISK%

		(
		echo select disk %DISK%
		echo clean
		echo convert gpt
		echo create partition efi size=260
		echo format quick fs=fat32 label=System
		echo assign letter=S
		echo create partition msr size=16
		echo create partition primary
		echo format quick fs=ntfs label=Windows
		echo assign letter=W
		) > X:\partition.txt
		call :say Partitioning the disk
		diskpart /s X:\partition.txt >> %LOG% 2>&1 || goto fail

		set WIM=%M%\sources\install.wim
		if not exist %WIM% set WIM=%M%\sources\install.esd
		call :say Applying the Windows image (%IMAGE%), this takes a few minutes
		dism /Apply-Image /ImageFile:%WIM% %IMAGE% /ApplyDir:W:\
		set RESULT=%errorlevel%
		copy /y X:\Windows\Logs\DISM\dism.log %T%\dism.log >nul 2>&1
		if not "%RESULT%"=="0" goto fail

		call :say Adding the virtio drivers
		dism /Image:W:\ /Add-Driver /Driver:%T%\drivers /Recurse\#(architecture.usesCakerGPUDriver && whqlOnly == false ? " /ForceUnsigned" : "")
		set RESULT=%errorlevel%
		copy /y X:\Windows\Logs\DISM\dism.log %T%\dism.log >nul 2>&1
		if not "%RESULT%"=="0" goto fail

		mkdir W:\Windows\Panther W:\Windows\Setup\Scripts 2>nul
		copy /y %T%\unattend.xml W:\Windows\Panther\unattend.xml >> %LOG% || goto fail
		copy /y %T%\SetupComplete.cmd W:\Windows\Setup\Scripts\SetupComplete.cmd >> %LOG% || goto fail

		rem Directory sharing: WinFsp and the virtio-fs service are installed by SetupComplete.cmd on first boot
		mkdir W:\ProgramData\caker 2>nul
		copy /y %T%\winfsp.msi W:\ProgramData\caker\winfsp.msi >> %LOG% || goto fail
		copy /y %T%\virtiofs.exe W:\ProgramData\caker\virtiofs.exe >> %LOG% || goto fail

		rem OpenSSH server: SetupComplete.cmd installs it from this copy (the media is gone by then)
		if exist %T%\openssh\sshd.exe (
		  xcopy /e /i /y /q %T%\openssh W:\ProgramData\caker\openssh >> %LOG% || goto fail
		  if exist %T%\authorized_keys copy /y %T%\authorized_keys W:\ProgramData\caker\authorized_keys >> %LOG% || goto fail
		)

		rem cakeagent: SetupComplete.cmd installs the service from these copies (the media is gone by then)
		if exist %T%\cakeagent.exe (
		  copy /y %T%\cakeagent.exe W:\ProgramData\caker\cakeagent.exe >> %LOG% || goto fail
		  xcopy /y /i /q %T%\certs W:\ProgramData\caker\certs >> %LOG% || goto fail
		)

		rem The certificate of the GPU driver build (see Tools/WindowsGPUDriver): SetupComplete.cmd trusts it
		rem The frame segment (MiB) asked for: SetupComplete.cmd puts it in the display driver's key
		if exist %T%\frame-segment.txt copy /y %T%\frame-segment.txt W:\ProgramData\caker\frame-segment.txt >> %LOG% || goto fail

		if exist %T%\caker-test-signing.cer copy /y %T%\caker-test-signing.cer W:\ProgramData\caker\caker-test-signing.cer >> %LOG% || goto fail

		rem The same for the sound driver (see Tools/WindowsAudioDriver)
		if exist %T%\caker-audio-test-signing.cer copy /y %T%\caker-audio-test-signing.cer W:\ProgramData\caker\caker-audio-test-signing.cer >> %LOG% || goto fail

		call :say Writing the boot files
		bcdboot W:\Windows /s S: /f UEFI >> %LOG% 2>&1 || goto fail
		\#(shim)

		call :say Done, powering off
		echo OK> %T%\result
		goto end

		:fail
		call :say Installation failed
		echo FAILED> %T%\result

		:end
		exit /b 0

		rem Shows a progress line and keeps it in the log
		:say
		echo %*
		echo [%time%] %* >> %LOG%
		exit /b 0
		"""#)
	}

	/// Runs once as SYSTEM when the installed Windows finishes setting itself up. It installs the sharing support,
	/// leaves a marker on the EFI system partition (a FAT32 volume the host can read, holding the exit codes of
	/// what it installed) and powers the VM off, which is how the host knows first boot is over:
	/// Virtualization.framework stops a VM whose guest reboots, so a stop alone says nothing about whether setup
	/// is complete.
	static let setupComplete = crlf(
		#"""
		@echo off
		setlocal EnableDelayedExpansion
		powercfg /hibernate off

		rem Directory sharing: WinFsp (the user-mode file system layer) and the virtio-fs service from the virtio-win
		rem drivers, which mounts each share the host exposes. The service waits for WinFsp's launcher and for the
		rem virtio-fs driver, which install.cmd added to the image.
		start /wait "" msiexec /i C:\ProgramData\caker\winfsp.msi /qn /norestart
		set MSI=%errorlevel%
		sc create VirtioFsSvc binpath= C:\ProgramData\caker\virtiofs.exe start= auto depend= WinFsp.Launcher/VirtioFsDrv DisplayName= "Virtio FS Service"
		set SVC=%errorlevel%

		mountvol S: /S
		mkdir S:\EFI\caker 2>nul

		rem Start the service now to see whether a share shows up (it only does if the VM has directory shares)
		net start VirtioFsSvc >nul 2>&1
		ping -n 11 127.0.0.1 >nul
		if exist Z:\ (set SHARE=mounted) else (set SHARE=none)

		rem GPU driver: Windows only loads the test-signed build of viogpudo (Tools/WindowsGPUDriver) once its certificate
		rem is trusted and test-signing is on, which takes effect at the next start (the one after this script)
		set GPUDRV=none
		if exist C:\ProgramData\caker\caker-test-signing.cer (
		  set GPUDRV=0
		  certutil -f -addstore Root C:\ProgramData\caker\caker-test-signing.cer >nul 2>&1 || set GPUDRV=!errorlevel!
		  certutil -f -addstore TrustedPublisher C:\ProgramData\caker\caker-test-signing.cer >nul 2>&1 || set GPUDRV=!errorlevel!
		  bcdedit /set testsigning on >nul 2>&1 || set GPUDRV=!errorlevel!
		  pnputil /scan-devices >nul 2>&1
		)

		rem Sound driver: like the GPU driver it is test-signed, so Windows loads it once its certificate is trusted and
		rem test-signing is on (that also takes effect at the next start). It only binds to Virtualization.framework's
		rem sound device.
		set AUDIORS=none
		if exist C:\ProgramData\caker\caker-audio-test-signing.cer (
		  set AUDIORS=0
		  certutil -f -addstore Root C:\ProgramData\caker\caker-audio-test-signing.cer >nul 2>&1 || set AUDIORS=!errorlevel!
		  certutil -f -addstore TrustedPublisher C:\ProgramData\caker\caker-audio-test-signing.cer >nul 2>&1 || set AUDIORS=!errorlevel!
		  bcdedit /set testsigning on >nul 2>&1 || set AUDIORS=!errorlevel!
		  pnputil /scan-devices >nul 2>&1
		)

		rem Display resizing: with caker's GPU driver the agent makes the guest follow the size the host asks the driver
		rem for (cakeagent runs a helper in the logged-on user's session). It is off unless this value is set, because with
		rem the stock driver Virtualization.framework shows a corrupted picture after a mode change.
		set DISPLAYRS=none
		if exist C:\ProgramData\caker\caker-test-signing.cer (
		  reg add HKLM\Software\Caker /v FollowDisplaySize /t REG_DWORD /d 1 /f >nul 2>&1
		  set DISPLAYRS=!errorlevel!
		)

		rem Frame segment: the INF gives the display driver a 64 MiB one (a mode whose surface doesn't fit it is refused, see
		rem WindowsDisplayLimit); a size asked for at build time replaces that value in the driver's key, which the driver
		rem reads when it starts. Fails (and says so in the marker) when the driver has no key yet, so nothing is claimed
		rem that didn't happen.
		set SEGRS=none
		if exist C:\ProgramData\caker\frame-segment.txt (
		  set /p SEGMIB=<C:\ProgramData\caker\frame-segment.txt
		  powershell -NoProfile -ExecutionPolicy Bypass -Command "$n = [int]'!SEGMIB!'; $c = 0; Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' | Where-Object { (Get-ItemProperty $_.PSPath).MatchingDeviceId -like '*dev_1050*' } | ForEach-Object { Set-ItemProperty $_.PSPath -Name MinFrameSegmentSizeMiB -Value $n -Type DWord; $c++ }; if ($c -eq 0) { exit 1 }" >nul 2>&1
		  set SEGRS=!errorlevel!
		)

		rem OpenSSH server (a Feature on Demand that isn't in the image): the Win32-OpenSSH build from the media, as a
		rem service that starts with Windows. Administrators log in with the keys in administrators_authorized_keys,
		rem which sshd only trusts when only SYSTEM and Administrators can write it; the password works too.
		set SSH=none
		if exist C:\ProgramData\caker\openssh\sshd.exe (
		  xcopy /e /i /y /q C:\ProgramData\caker\openssh "C:\Program Files\OpenSSH"
		  powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\OpenSSH\install-sshd.ps1"
		  set SSH=!errorlevel!
		  mkdir C:\ProgramData\ssh 2>nul
		  if not exist C:\ProgramData\ssh\ssh_host_ed25519_key "C:\Program Files\OpenSSH\ssh-keygen.exe" -A
		  powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\OpenSSH\FixHostFilePermissions.ps1" -Confirm:$false
		  if exist C:\ProgramData\caker\authorized_keys (
		    copy /y C:\ProgramData\caker\authorized_keys C:\ProgramData\ssh\administrators_authorized_keys
		    icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /grant "SYSTEM:F" "Administrators:F"
		  )
		  netsh advfirewall firewall add rule name="OpenSSH Server (sshd)" dir=in action=allow protocol=TCP localport=22
		  sc config sshd start= auto
		  net start sshd
		  sc query sshd | find "RUNNING" >nul 2>&1 && set SSH=!SSH!-running
		)

		rem cakeagent: listens on vsock (the viosock driver) like the Linux and macOS agents, authenticated with the certificates.
		set AGENT=none
		if exist C:\ProgramData\caker\cakeagent.exe (
		  mkdir "C:\Program Files\CakeAgent" "C:\ProgramData\CakeAgent\certs" 2>nul
		  copy /y C:\ProgramData\caker\cakeagent.exe "C:\Program Files\CakeAgent\cakeagent.exe"
		  copy /y C:\ProgramData\caker\certs\* C:\ProgramData\CakeAgent\certs\
		  rem the private key is for the administrators and the service (SYSTEM) only
		  icacls C:\ProgramData\CakeAgent /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F"
		  "C:\Program Files\CakeAgent\cakeagent.exe" service install --listen=vsock://any:5000 --ca-cert=C:\ProgramData\CakeAgent\certs\ca.pem --tls-cert=C:\ProgramData\CakeAgent\certs\server.pem --tls-key=C:\ProgramData\CakeAgent\certs\server.key
		  set AGENT=!errorlevel!
		  sc failure cakeagent reset= 86400 actions= restart/5000/restart/10000/restart/30000 >nul 2>&1
		  sc failureflag cakeagent 1 >nul 2>&1
		  rem Windows Server: started in the first seconds of boot, the Go runtime of the agent dies with "mcall called on m->g0
		  rem stack" before it reaches the service manager (event 7009, "timeout while waiting for the service to connect", seen
		  rem on Windows Server 2025 x64, mostly in the first seconds of boot). So the service is not started by the service manager
		  rem but by a task 15 s after boot, which starts it again every 10 s (up to 30 times) until it runs: a start that failed with
		  rem 7009 isn't a service failure, the recovery actions above don't cover it, and the task scheduler doesn't retry a task
		  rem whose command returned an error. On a fresh Windows Server 2022 it took 7 tries, on 2025 one at most. Windows clients
		  rem start it at boot like any service.
		  rem x64 guests (seen on Windows 11 and Server 2022, on an Intel iMac with 20 threads: 8 starts out of 8 crashed at any time
		  rem after boot, 0 of 8 without it): the Go runtime dies with "mcall called on m->g0 stack" when it interrupts a thread
		  rem asynchronously (SetThreadContext), so the service runs without asynchronous preemption, in its own environment.
		  rem ARM64 guests keep it.
		  if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" reg add HKLM\SYSTEM\CurrentControlSet\Services\CakeAgent /v Environment /t REG_MULTI_SZ /d "GODEBUG=asyncpreemptoff=1" /f >nul 2>&1
		  set DELAYED=0
		  set INSTALLTYPE=
		  for /f "tokens=3" %%t in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v InstallationType 2^>nul ^| find "InstallationType"') do set INSTALLTYPE=%%t
		  if /i "!INSTALLTYPE!"=="Server" (
		    sc config cakeagent start= demand >nul 2>&1
		    schtasks /create /tn "CakeAgent delayed start" /sc onstart /delay 0000:15 /ru SYSTEM /rl highest /f /tr "cmd /c for /l %%i in (1,1,30) do sc query cakeagent | findstr RUNNING >nul || (sc start cakeagent & ping -n 11 127.0.0.1 >nul)" >nul 2>&1 && set DELAYED=1
		  )
		  ping -n 6 127.0.0.1 >nul
		  sc query cakeagent | find "RUNNING" >nul 2>&1 && set AGENT=!AGENT!-running
		  rem installed, and the task above starts it at every boot: the host can count on it (agent=0-delayed)
		  if "!DELAYED!"=="1" if "!AGENT!"=="0" set AGENT=0-delayed
		  rem a service that isn't running can't say why: run the agent in front for a few seconds and keep what it prints
		  if "!AGENT!"=="!AGENT:running=!" if not "!AGENT!"=="0-delayed" (
		    sc stop cakeagent >nul 2>&1
		    start "" /b "C:\Program Files\CakeAgent\cakeagent.exe" serve --listen=vsock://any:5000 --ca-cert=C:\ProgramData\CakeAgent\certs\ca.pem --tls-cert=C:\ProgramData\CakeAgent\certs\server.pem --tls-key=C:\ProgramData\CakeAgent\certs\server.key > S:\EFI\caker\agent.log 2>&1
		    ping -n 9 127.0.0.1 >nul
		    taskkill /f /im cakeagent.exe >nul 2>&1
		  )
		)

		rem virtio-vsock: the viosock driver is demand-start, so it only runs when the VM has a vsock device
		set VSOCK=none
		sc query VirtioSocket >nul 2>&1 && set VSOCK=installed
		sc query VirtioSocket | find "RUNNING" >nul 2>&1 && set VSOCK=running

		(echo done& echo winfsp=%MSI%& echo service=%SVC%& echo share=%SHARE%& echo vsock=%VSOCK%& echo agent=%AGENT%& echo ssh=%SSH%& echo gpudriver=%GPUDRV%& echo display=%DISPLAYRS%& echo framesegment=%SEGRS%& echo audio=%AUDIORS%)> S:\EFI\caker\installed
		mountvol S: /D
		shutdown /s /t 5 /c "caker: Windows installation complete"
		"""#)

	/// The answer file for the installed system: a local administrator account that logs on automatically,
	/// and no out-of-box experience. `language` is the image's default (e.g. `en-US`). `productKey`, when given, is
	/// applied in the specialize pass (the `WINDOWS_KEY` provisioning variable).
	static func unattend(username: String, password: String, computerName: String, language: String, architecture: WindowsArchitecture, productKey: String? = nil, autologon: Bool = false) -> String {
		func escaped(_ value: String) -> String {
			value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
		}

		let productKeyElement = productKey.map { "\n      <ProductKey>\(escaped($0))</ProductKey>" } ?? ""

		return crlf(
			"""
			<?xml version="1.0" encoding="utf-8"?>
			<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
			  <settings pass="specialize">
			    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="\(architecture.unattendArchitecture)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			      <ComputerName>\(escaped(computerName))</ComputerName>
			      <TimeZone>UTC</TimeZone>\(productKeyElement)
			    </component>
			  </settings>
			  <settings pass="oobeSystem">
			    <component name="Microsoft-Windows-International-Core" processorArchitecture="\(architecture.unattendArchitecture)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			      <InputLocale>\(escaped(language))</InputLocale>
			      <SystemLocale>\(escaped(language))</SystemLocale>
			      <UILanguage>\(escaped(language))</UILanguage>
			      <UserLocale>\(escaped(language))</UserLocale>
			    </component>
			    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="\(architecture.unattendArchitecture)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			      <OOBE>
			        <HideEULAPage>true</HideEULAPage>
			        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
			        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
			        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
			        <HideLocalAccountScreen>true</HideLocalAccountScreen>
			        <ProtectYourPC>3</ProtectYourPC>
			        <SkipMachineOOBE>true</SkipMachineOOBE>
			        <SkipUserOOBE>true</SkipUserOOBE>
			      </OOBE>
			      <UserAccounts>
			        <LocalAccounts>
			          <LocalAccount wcm:action="add">
			            <Name>\(escaped(username))</Name>
			            <Group>Administrators</Group>
			            <Password>
			              <Value>\(escaped(password))</Value>
			              <PlainText>true</PlainText>
			            </Password>
			          </LocalAccount>
			        </LocalAccounts>
			      </UserAccounts>
			      <AutoLogon>
			        <Enabled>true</Enabled>
			        <LogonCount>\(autologon ? WindowsInstallationMedia.autologonForeverCount : 1)</LogonCount>
			        <Username>\(escaped(username))</Username>
			        <Password>
			          <Value>\(escaped(password))</Value>
			          <PlainText>true</PlainText>
			        </Password>
			      </AutoLogon>
			    </component>
			  </settings>
			</unattend>
			""")
	}

	/// Where the agent update goes in a Windows guest: `VMLocation.installAgent` sends the new `cakeagent.exe` and this
	/// script there, over SSH (`SetupComplete.cmd` made `C:\ProgramData\caker`).
	static let agentUpdateDirectory = "C:/ProgramData/caker"
	static let agentUpdateExecutable = "cakeagent-update.exe"
	static let agentUpdateScript = "install-agent.ps1"

	/// PowerShell run in the guest over SSH to install the agent, or to replace it when the service is already there:
	/// the same steps as `SetupComplete.cmd`, for a guest whose agent is missing or older than `snapshot`. The new
	/// executable is already at `C:\ProgramData\caker\cakeagent-update.exe`. The script deletes itself (it carries the
	/// agent's private key) and the executable, whatever happens. Exit code 0 means the agent is running with `snapshot`.
	static func agentUpdatePowerShell(snapshot: String, port: UInt16, caCert: String, serverCert: String, serverKey: String) -> String {
		#"""
		$ErrorActionPreference = 'Stop'
		$ProgressPreference = 'SilentlyContinue'

		$snapshot = '\#(snapshot)'
		$new = 'C:\ProgramData\caker\\#(agentUpdateExecutable)'
		$dir = 'C:\Program Files\CakeAgent'
		$exe = "$dir\cakeagent.exe"
		$certs = 'C:\ProgramData\CakeAgent\certs'

		function Write-Pem($path, $text) {
			if (-not (Test-Path $path)) {
				Write-Output "Creating $path"
				[IO.File]::WriteAllText($path, $text.Trim() + "`n", [Text.Encoding]::ASCII)
			}
		}

		try {
			$service = Get-Service cakeagent -ErrorAction SilentlyContinue

			if ($service -and (Test-Path $exe)) {
				if ((& $exe version 2>&1 | Out-String) -match $snapshot) {
					Write-Output 'CakeAgent already installed, skipping'
					exit 0
				}

				Write-Output 'CakeAgent already installed, updating'

				# The service owns a helper in the logged-on user's session, which keeps the executable open too
				Stop-Service cakeagent -Force -ErrorAction SilentlyContinue
				Start-Sleep 2
				Get-Process cakeagent -ErrorAction SilentlyContinue | Stop-Process -Force
				Start-Sleep 1
				Copy-Item $new $exe -Force
				Start-Service cakeagent
			} else {
				Write-Output 'Installing CakeAgent'

				New-Item -ItemType Directory -Force $dir, $certs | Out-Null

				Write-Pem "$certs\ca.pem" @'
		\#(caCert)
		'@
				Write-Pem "$certs\server.pem" @'
		\#(serverCert)
		'@
				Write-Pem "$certs\server.key" @'
		\#(serverKey)
		'@

				icacls $certs /inheritance:r /grant:r 'SYSTEM:(OI)(CI)F' 'Administrators:(OI)(CI)F' | Out-Null
				Copy-Item $new $exe -Force

				& $exe service install --listen=vsock://any:\#(port) --ca-cert="$certs\ca.pem" --tls-cert="$certs\server.pem" --tls-key="$certs\server.key"

				if ($LASTEXITCODE -ne 0) {
					throw "cakeagent service install failed: $LASTEXITCODE"
				}

				sc.exe failure cakeagent reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
				sc.exe failureflag cakeagent 1 | Out-Null

				# The Go runtime of the agent crashes on x64 guests with asynchronous preemption (see SetupComplete.cmd)
				if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {
					New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\CakeAgent -Name Environment -PropertyType MultiString -Value 'GODEBUG=asyncpreemptoff=1' -Force | Out-Null
				}

				Start-Service cakeagent
			}

			Start-Sleep 5

			if ((Get-Service cakeagent).Status -ne 'Running') {
				throw 'the cakeagent service is not running'
			}

			Write-Output 'CakeAgent running'
		} finally {
			Remove-Item $new -Force -ErrorAction SilentlyContinue
			Remove-Item $PSCommandPath -Force -ErrorAction SilentlyContinue
		}
		"""#
	}

	/// `set IMAGE=...` for install.cmd: which edition of install.wim to apply.
	static func config(imageIndex: Int) -> String {
		crlf("@echo off\nset IMAGE=/Index:\(imageIndex)\n")
	}
}
