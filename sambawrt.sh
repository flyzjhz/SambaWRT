#!/bin/bash
# Samba setup script for OpenWRT 12.09 (Attitude Adjustment)
# Created by Gunnaro
# Licensed under MIT
# Version 1.0 Initial release
# Known issue:	~ Causing configuration conflict with luci-app-samba
#				~ Can't access Shared folder without login
#				~ Uninstall function isn't well coded (Use with cautions!)

# Intro
clear
echo "=============================="
echo "Samba Setup Script for OpenWRT"
echo "=============================="
echo
echo "Script ini akan menginstall Samba server dan konfigurasinya"
echo "Anda hanya perlu memasukkan beberapa data"
echo "Seperti hostname, username, password, dll."
echo
read -p "Tekan Enter untuk melanjutkan.." -n1 -s
echo

# Check if Samba installed or not
if [ -e /etc/config/samba ]; then
	while :
	do
	clear
		# Main Menu
		echo "=============================="
		echo "Samba Setup Script for OpenWRT"
		echo "=============================="
		echo
		echo "Sepertinya Samba sudah terinstall"
		echo "Apa yang ingin anda lakukan?"
		echo ""
		echo "1) Tambah user"
		echo "2) Hapus user"
		echo "3) Uninstall Samba server"
		echo "4) Keluar"
		echo ""
		read -p "Masukkan pilihan [1-4]: " pilihan

		# Menu no 1, Add user
		case $pilihan in
			1)
			while true; do	
				echo
				read -p "Masukkan username: " namauser
				echo "Username anda adalah \"$namauser\", Apa ini benar?"
				read -p "Tekan Y untuk melanjutkan, tombol lain untuk menggantinya: " -n1 respon1
				if [ "$respon1" == "Y" ] || [ "$respon1" == "y" ]; then # Check to read respond
					echo
					user="$(grep -o "$namauser" /etc/passwd)"
					if [ "$user" == "$namauser" ]; then # Check if username exist
					 echo
					 echo "Username sudah ada, coba username lain"
					 else
					 break
					fi
				fi
			done

				# Add user to system (Randomize user ID)
				echo "------------------------------"
				echo "Menambahkan user"

				cat >> /etc/passwd << EOF
$namauser:*:$[ 1000 + $[ RANDOM % 10000 ]]:1111:smbgroup:/mnt/share/$namauser:/bin/false
EOF

				# Add password to user
				echo "------------------------------"
				echo "Masukkan password untuk user $namauser"

				smbpasswd -a $namauser

				# Add share folder
				echo "------------------------------"
				echo "Menambahkan folder user"

				cat >> /etc/config/samba << EOF
config 'sambashare'
	option 'name' '$namauser'
	option 'path' '/mnt/share/$namauser'
	option 'read_only' 'no'
	option 'create_mask' '0770'
	option 'dir_mask' '0770'
	option 'guest_ok' 'no'
    	
EOF

				# Create user folder & permission
				mkdir -p /mnt/share/${namauser}
				mkdir -p /mnt/share/${namauser}/Private
				touch /mnt/share/${namauser}/.profile
				chown -R $namauser:smbgroup /mnt/share/${namauser}
				chmod -R u=rwx,g=rwx,o= /mnt/share/${namauser}

				#Permission private folder
				chmod u=rwx,go= /mnt/share/${namauser}/Private

				echo "------------------------------"
				echo "Merestart Samba"

				/etc/init.d/samba restart

				echo "===================================="
				echo "Tambah user selesai"
				echo "Username: $namauser"
				echo "Akses melalui: 	~ (Linux) smb://192.168.1.1/$namauser"
				echo "		~ (Windows) net use Z: \\\192.168.1.1\\ $namauser"
			exit
			;;

			# Menu no 2, Delete user
			2)
			while true; do	
				echo
				read -p "Masukkan username: " namauser
				echo "Username yang akan anda hapus adalah \"$namauser\", Apa ini benar?"
				read -p "Tekan Y untuk melanjutkan, tombol lain untuk menggantinya: " -n1 respon1
				if [ "$respon1" == "Y" ] || [ "$respon1" == "y" ]; then
					user="$(grep -o -m 1 "$namauser" /etc/passwd | head -1)"
					if [ "$user" == "$namauser" ]; then # Check if username exist
					 echo
					echo "------------------------------"
					echo "Menghapus user dan folder user"

					sed -i -e '/'"$namauser"'/{s/.*//;x;N;N;N;N;N;N;d;};x;${p;x;}' -e '/^$/ d' /etc/config/samba
					sed -i -e '/'"$namauser"'/{N;N;N;N;N;N;d;}' /etc/samba/smb.conf
					sed -i "/$namauser/d" /etc/passwd
					rm -rf /mnt/share/${namauser}

					echo "------------------------------"
					echo "Merestart Samba"

					/etc/init.d/samba restart
					
					echo "============================="
					echo "Hapus user selesai"
					 else
					 	echo
					 	echo "Username tidak ada, coba username lain"
					fi
					break
				fi
				done
			exit
			;;

			# Menu no 3, Remove Samba server
			3)
			while true; do
					echo "++ Peringatan! ++"
					echo "Men uninstall akan menghapus seluruh user & group"
					echo "yang dibuat setelah Samba server terpasang"
					echo "----------------------------------------------"
					echo "Apakah Anda ingin Menghapus Samba server?"
					read -p "Tekan Y untuk melanjutkan, tombol lain untuk berhenti: " -n1 respon
					if [ "$respon" == "Y" ] || [ "$respon" == "y" ]; then
						echo 
						echo "Menghapus Samba server"

						opkg remove samba36-server

						echo "----------------------"
						echo "Menghapus share folder"

						rm -rf /mnt/share/*

						echo "----------------------"
						echo "Menghapus user & group"

						sed -i '6,$d' /etc/passwd 	# WARNING!! This Assume that first user created in 6th Line
						sed -i '11d' /etc/group		# WARNING!! This Assume that samba group created in 11th Line

						echo "----------------------"
						echo "Menghapus Konfigurasi firewall & init"

						sed -i '92,109d' /etc/config/firewall
						sed -i '5,9d' /etc/rc.local

						echo "============================="						
						echo "Samba server telah dihapus"
						break
					fi
					echo
					echo "Gagal menghapus Samba server"
					break
				done
			exit
			;;

			# Menu no 4, Exit
			4)
			exit
			;;
		esac
	done
else

# Setup & first user creation
echo
while true; do
		read -p "Masukkan hostname: " namaserver
		echo "Hostname anda adalah \"$namaserver\", Apa ini benar?"
		read -p "Tekan Y untuk melanjutkan, tombol lain untuk menggantinya: " -n1 respon
		if [ "$respon" == "Y" ] || [ "$respon" == "y" ]; then
			echo
			break
		fi
			echo
		done

while true; do
		echo "Hostname: $namaserver"		
		echo
		read -p "Masukkan username admin: " namaadmin
		echo "Username anda adalah \"$namaadmin\", Apa ini benar?"
		read -p "Tekan Y untuk melanjutkan, tombol lain untuk menggantinya: " -n1 respon1
		if [ "$respon1" == "Y" ] || [ "$respon1" == "y" ]; then
			echo
			break
		fi
			echo
		done

echo "Hostname: $namaserver"	
echo "username: $namaadmin"
echo "-----------------------"

# Samba server installation
echo "Menginstall Samba server"

opkg update
opkg install samba36-server ntfs-3g

# Insert Samba rules to firewall
echo "------------------------------"
echo "Konfigurasi firewall"

cat >> /etc/config/firewall << EOF

config 'rule'
        option 'src' 'lan'
        option 'proto' 'udp'
        option 'dest_port' '137-138'
        option 'target' 'ACCEPT'
    
config 'rule'
        option 'src' 'lan'
        option 'proto' 'tcp'
        option 'dest_port' '139'
        option 'target' 'ACCEPT'
    
config 'rule'
        option 'src' 'lan'
        option 'proto' 'tcp'
        option 'dest_port' '445'
        option 'target' 'ACCEPT'
EOF

# Add user to system
echo "------------------------------"
echo "Menambahkan user & group"

cat >> /etc/passwd << EOF
$namaadmin:*:$[ 1000 + $[ RANDOM % 10000 ]]:1111:smbgroup:/mnt/share/:/bin/false
EOF

cat>> /etc/group << EOF
smbgroup:x:1111:
EOF

# Add password to user
echo "------------------------------"
echo "Masukkan password untuk user $namaadmin"

smbpasswd -a $namaadmin

# Samba config user level
echo "------------------------------"
echo "Konfigurasi Samba server"

cat << EOF > /etc/samba/smb.conf.template 
[global]
	netbios name = |NAME| 
	workgroup = |WORKGROUP|
	server string = |DESCRIPTION|
	browseable = yes
	deadtime = 10
	syslog = 10
	encrypt passwords = true
	passdb backend = smbpasswd
	obey pam restrictions = yes
	socket options = TCP_NODELAY
	unix charset = ISO-8859-1
	local master = yes
	preferred master = yes
	os level = 20
	security = user
	null passwords = yes
	guest account = nobody
	invalid users = root
	smb passwd file = /etc/samba/smbpasswd
EOF
 
# Add share folder
echo "------------------------------"
echo "Menambahkan share folder"

cat >> /etc/config/samba << EOF
config 'samba'
	option 'name' '$namaserver'
	option 'workgroup' 'WORKGROUP'
	option 'description' '$namaserver'
	option 'homes' '1'
    	
config 'sambashare'
	option 'read_only' 'no'
	option 'create_mask' '0700'
	option 'dir_mask' '0700'
	option 'name' '$namaadmin'
	option 'path' '/mnt/share/'
	option 'guest_ok' 'no'
    	
config 'sambashare'
        option 'name' 'Shared'
        option 'path' '/mnt/share/Public'
        # option 'guest_ok' 'yes' # E: Permission denied
        option 'guest_ok' 'no' # W: Auth using any credentials
        option 'create_mask' '0777'
        option 'dir_mask' '0777'
        option 'read_only' 'no'
    	
EOF

#Create share folder
mkdir /mnt/share/Public

# Start Samba on boot
echo "------------------------------"
echo "Konfigurasi Samba server agar start saat booting"

cat >> /etc/rc.local << EOF

smbd -D
nmbd -D

exit 0
EOF

# Write Permission
echo "------------------------------"
echo "Mengatur permission"

chmod -R 777 /mnt/share
chown -R $namaadmin:smbgroup /mnt/share/
chmod -R u=rwx,g=rx,o= /mnt/share/
#chown -R nobody /mnt/share/Public

# Starting Samba
echo "------------------------------"
echo "Menjalankan Samba server"

/etc/init.d/samba enable
/etc/init.d/samba start

echo "========================================"
echo "Instalasi selesai"
echo "Username admin: $namaadmin"
echo "Akses melalui : 	~ (Linux) smb://192.168.1.1/"
echo "		~ (Windows) net use Z: \\192.168.1.1\ "
fi