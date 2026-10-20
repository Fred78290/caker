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
	static func installScript(for architecture: WindowsArchitecture) -> String {
		self.installScript(for: architecture, usingFramebufferShim: architecture.usesFramebufferShim)
	}

	static func installScript(for architecture: WindowsArchitecture, usingFramebufferShim: Bool) -> String {
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
		dism /Image:W:\ /Add-Driver /Driver:%T%\drivers /Recurse\#(architecture.usesCakerGPUDriver ? " /ForceUnsigned" : "")
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

		rem Display resizing (only with caker's GPU driver, see displayScript): a script started at logon
		if exist %T%\display.ps1 copy /y %T%\display.ps1 W:\ProgramData\caker\display.ps1 >> %LOG% || goto fail

		rem The certificate of the GPU driver build (see Tools/WindowsGPUDriver): SetupComplete.cmd trusts it
		if exist %T%\caker-test-signing.cer copy /y %T%\caker-test-signing.cer W:\ProgramData\caker\caker-test-signing.cer >> %LOG% || goto fail

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

		rem Display resizing: a script that follows the size the host asks the GPU driver for, started in the session of
		rem whoever logs on (SetupComplete runs as SYSTEM, whose own scheduled tasks would have no access to the display)
		set DISPLAYRS=none
		if exist C:\ProgramData\caker\display.ps1 (
		  reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Run /v CakerDisplay /t REG_SZ /d "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\ProgramData\caker\display.ps1" /f >nul 2>&1
		  set DISPLAYRS=!errorlevel!
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
		  ping -n 6 127.0.0.1 >nul
		  sc query cakeagent | find "RUNNING" >nul 2>&1 && set AGENT=!AGENT!-running
		  rem a service that isn't running can't say why: run the agent in front for a few seconds and keep what it prints
		  if "!AGENT!"=="!AGENT:running=!" (
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

		(echo done& echo winfsp=%MSI%& echo service=%SVC%& echo share=%SHARE%& echo vsock=%VSOCK%& echo agent=%AGENT%& echo ssh=%SSH%& echo gpudriver=%GPUDRV%& echo display=%DISPLAYRS%)> S:\EFI\caker\installed
		mountvol S: /D
		shutdown /s /t 5 /c "caker: Windows installation complete"
		"""#)

	/// Applies the display size the host asks for. When `VZVirtualMachineView` resizes, Virtualization.framework
	/// changes the virtio GPU's size and the virtio-win driver (viogpudo) learns it, but nothing applies it: the helper
	/// virtio-win ships for that (viogpuap) only looks at the first display device, which here is the Microsoft Basic
	/// Display Driver Windows keeps for the firmware's framebuffer (see Tools/WindowsEFI), never the GPU. This finds the
	/// GPU, asks the driver (`D3DKMTEscape`, `VIOGPU_GET_CUSTOM_RESOLUTION`) and applies what it says whenever it changes.
	/// It runs in the session of whoever logs on (an `HKLM` Run entry). Only installed with caker's GPU driver
	/// (Tools/WindowsGPUDriver): with the stock one, Virtualization.framework shows a corrupted picture after a mode change.
	static let displayScript = crlf(
		#"""
		$ErrorActionPreference = 'SilentlyContinue'
		Add-Type @"
		using System; using System.Runtime.InteropServices;
		public class VG {
		 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct DISPLAY_DEVICE { public int cb; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string DeviceName; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceString; public int StateFlags; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceID; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceKey; }
		 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct DEVMODE { [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmDeviceName; public ushort dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra; public uint dmFields; public int dmPositionX, dmPositionY; public uint dmDisplayOrientation, dmDisplayFixedOutput; public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmFormName; public ushort dmLogPixels; public uint dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency, dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight; }
		 [StructLayout(LayoutKind.Sequential)] public struct OPENADAPTER { public IntPtr hDc; public uint hAdapter; public uint luidLow; public int luidHigh; public uint VidPnSourceId; }
		 [StructLayout(LayoutKind.Sequential)] public struct CLOSEADAPTER { public uint hAdapter; }
		 [StructLayout(LayoutKind.Sequential)] public struct ESC { public uint hAdapter; public uint hDevice; public int Type; public uint Flags; public IntPtr pData; public uint Size; public uint hContext; }
		 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool EnumDisplayDevices(string dev, uint i, ref DISPLAY_DEVICE d, uint flags);
		 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool EnumDisplaySettings(string dev, int mode, ref DEVMODE dm);
		 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int ChangeDisplaySettingsEx(string dev, ref DEVMODE dm, IntPtr hwnd, uint flags, IntPtr p);
		 [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr CreateDC(string drv, string dev, string port, IntPtr init);
		 [DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr hdc);
		 [DllImport("gdi32.dll")] public static extern int D3DKMTOpenAdapterFromHdc(ref OPENADAPTER a);
		 [DllImport("gdi32.dll")] public static extern int D3DKMTCloseAdapter(ref CLOSEADAPTER a);
		 [DllImport("gdi32.dll")] public static extern int D3DKMTEscape(ref ESC e);
		}
		"@

		# The virtio GPU is not necessarily the first display device
		function Find-Gpu {
		  for ($i = 0; $i -lt 16; $i++) {
		    $d = New-Object VG+DISPLAY_DEVICE
		    $d.cb = [Runtime.InteropServices.Marshal]::SizeOf($d)
		    if ([VG]::EnumDisplayDevices([NullString]::Value, [uint32]$i, [ref]$d, 0) -and $d.DeviceID -like 'PCI\VEN_1AF4&DEV_1050*') { return $d.DeviceName }
		  }
		}

		$buffer = [Runtime.InteropServices.Marshal]::AllocHGlobal(8)
		$adapter = 0
		$name = $null
		$last = ''

		while ($true) {
		  if (-not $adapter) {
		    $name = Find-Gpu
		    if ($name) {
		      $hdc = [VG]::CreateDC($null, $name, $null, [IntPtr]::Zero)
		      $open = New-Object VG+OPENADAPTER
		      $open.hDc = $hdc
		      if ([VG]::D3DKMTOpenAdapterFromHdc([ref]$open) -eq 0) { $adapter = $open.hAdapter }
		      [void][VG]::DeleteDC($hdc)
		    }
		  }

		  if ($adapter) {
		    # VIOGPU_ESCAPE { USHORT Type = VIOGPU_GET_CUSTOM_RESOLUTION; USHORT DataLength; USHORT X; USHORT Y }
		    [Runtime.InteropServices.Marshal]::WriteInt16($buffer, 0, 1)
		    [Runtime.InteropServices.Marshal]::WriteInt16($buffer, 2, 4)
		    [Runtime.InteropServices.Marshal]::WriteInt32($buffer, 4, 0)
		    $escape = New-Object VG+ESC
		    $escape.hAdapter = $adapter
		    $escape.pData = $buffer
		    $escape.Size = 8

		    if ([VG]::D3DKMTEscape([ref]$escape) -eq 0) {
		      $width = [Runtime.InteropServices.Marshal]::ReadInt16($buffer, 4) -band 0xFFFF
		      $height = [Runtime.InteropServices.Marshal]::ReadInt16($buffer, 6) -band 0xFFFF
		      $wanted = "$width x $height"

		      # Only a change of what the host asks for is applied (and the first value), so a resolution the user picks in
		      # Windows' settings isn't undone every second
		      if ($width -ge 640 -and $height -ge 480 -and $wanted -ne $last) {
		        $mode = New-Object VG+DEVMODE
		        $mode.dmSize = [Runtime.InteropServices.Marshal]::SizeOf($mode)

		        if ([VG]::EnumDisplaySettings($name, -1, [ref]$mode) -and ($mode.dmPelsWidth -ne $width -or $mode.dmPelsHeight -ne $height)) {
		          $mode.dmPelsWidth = $width
		          $mode.dmPelsHeight = $height
		          $mode.dmFields = 0x80000 -bor 0x100000
		          [void][VG]::ChangeDisplaySettingsEx($name, [ref]$mode, [IntPtr]::Zero, 0, [IntPtr]::Zero)
		        }

		        $last = $wanted
		      }
		    } else {
		      # The adapter went away (driver reset): look for it again
		      $close = New-Object VG+CLOSEADAPTER
		      $close.hAdapter = $adapter
		      [void][VG]::D3DKMTCloseAdapter([ref]$close)
		      $adapter = 0
		    }
		  }

		  Start-Sleep -Milliseconds 1000
		}
		"""#)

	/// The answer file for the installed system: a local administrator account that logs on automatically,
	/// and no out-of-box experience. `language` is the image's default (e.g. `en-US`).
	static func unattend(username: String, password: String, computerName: String, language: String, architecture: WindowsArchitecture) -> String {
		func escaped(_ value: String) -> String {
			value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
		}

		return crlf(
			"""
			<?xml version="1.0" encoding="utf-8"?>
			<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
			  <settings pass="specialize">
			    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="\(architecture.unattendArchitecture)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			      <ComputerName>\(escaped(computerName))</ComputerName>
			      <TimeZone>UTC</TimeZone>
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
			        <LogonCount>1</LogonCount>
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

	/// `set IMAGE=...` for install.cmd: which edition of install.wim to apply.
	static func config(imageIndex: Int) -> String {
		crlf("@echo off\nset IMAGE=/Index:\(imageIndex)\n")
	}
}
