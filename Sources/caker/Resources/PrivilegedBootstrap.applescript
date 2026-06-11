-- Accepts two arguments:
--   item 1: content for /etc/paths.d/com.aldunelabs.caker (empty string = skip)
--   item 2: content for /etc/sudoers.d/caked (empty string = skip)
on run argv
	set pathsContent to item 1 of argv
	set sudoersContent to item 2 of argv

	if pathsContent is not "" then
		do shell script "/bin/mkdir -p /etc/paths.d && printf '%s' " & quoted form of pathsContent & " > /etc/paths.d/com.aldunelabs.caker && /bin/chmod 0644 /etc/paths.d/com.aldunelabs.caker && /usr/sbin/chown root:wheel /etc/paths.d/com.aldunelabs.caker" with administrator privileges
	end if

	if sudoersContent is not "" then
		do shell script "/bin/mkdir -p /etc/sudoers.d && printf '%s' " & quoted form of sudoersContent & " > /etc/sudoers.d/caked && /bin/chmod 0440 /etc/sudoers.d/caked && /usr/sbin/chown root:wheel /etc/sudoers.d/caked" with administrator privileges
	end if
end run
