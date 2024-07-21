#!/bin/bash

# Coler Code
Purple='\033[0;35m'
Cyan='\033[0;36m'
cyan='\033[0;36m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
White='\033[0;96m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Detect the Linux distribution
detect_distribution() {
	if [ -f /etc/os-release ]; then
		source /etc/os-release
		case "${ID}" in
		ubuntu | debian)
			p_m="apt-get"
			;;
		centos)
			p_m="yum"
			;;
		fedora)
			p_m="dnf"
			;;
		*)
			echo -e "${red}Unsupported distribution!${rest}"
			exit 1
			;;
		esac
	else
		echo -e "${red}Unsupported distribution!${rest}"
		exit 1
	fi
}

# Install Dependencies
check_dependencies() {
	detect_distribution

	local dependencies
	dependencies=("wget" "curl" "unzip" "socat" "jq")

	for dep in "${dependencies[@]}"; do
		if ! command -v "${dep}" &>/dev/null; then
			echo -e "${cyan} ${dep} ${yellow}is not installed. Installing...${rest}"
			sudo "${p_m}" install "${dep}" -y
		fi
	done
}

# Check and nstall waterwall
install_waterwall() {
	LATEST_RELEASE=$(curl --silent "https://api.github.com/repos/radkesvat/WaterWall/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
	INSTALL_DIR="/root/Waterwall"
	FILE_NAME="Waterwall"

	if [ ! -f "$INSTALL_DIR/$FILE_NAME" ]; then
		check_dependencies
		echo ""
		echo -e "${cyan}============================${rest}"
		echo -e "${cyan}Installing Waterwall...${rest}"

		if [ -z "$LATEST_RELEASE" ]; then
			echo -e "${red}Failed to get the latest release version.${rest}"
			return 1
			LATEST_RELEASE
		fi

		echo -e "${cyan}Latest version: ${yellow}${LATEST_RELEASE}${rest}"

		# Determine the download URL based on the architecture
		ARCH=$(uname -m)
		if [ "$ARCH" == "x86_64" ]; then
			DOWNLOAD_URL="https://github.com/radkesvat/WaterWall/releases/download/${LATEST_RELEASE}/Waterwall-linux-64.zip"
		elif [ "$ARCH" == "aarch64" ]; then
			DOWNLOAD_URL="https://github.com/radkesvat/WaterWall/releases/download/${LATEST_RELEASE}/Waterwall-linux-arm64.zip"
		else
			echo -e "${red}Unsupported architecture: $ARCH${rest}"
			return 1
		fi

		# Create the installation directory if it doesn't exist
		mkdir -p "$INSTALL_DIR"

		# Download the ZIP file directly into INSTALL_DIR
		ZIP_FILE="$INSTALL_DIR/Waterwall.zip"
		curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL"
		if [ $? -ne 0 ]; then
			echo -e "${red}Download failed.${rest}"
			return 1
		fi

		# Unzip the downloaded file directly into INSTALL_DIR
		unzip "$ZIP_FILE" -d "$INSTALL_DIR" >/dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo -e "${red}Unzip failed.${rest}"
			rm -f "$ZIP_FILE"
			return 1
		fi

		rm -f "$ZIP_FILE"

		# Set executable permission for Waterwall binary
		sudo chmod +x "$INSTALL_DIR/$FILE_NAME"
		if [ $? -ne 0 ]; then
			echo -e "${red}Failed to set executable permission for Waterwall.${rest}"
			return 1
		fi

		echo -e "${green}Waterwall installed successfully in $INSTALL_DIR.${rest}"
		echo -e "${cyan}============================${rest}"
		return 0
	fi
}


#===================================


# Core.json
create_core_json() {
	if [ ! -d /root/Waterwall ]; then
		mkdir -p /root/Waterwall
	fi

	if [ ! -f ~/Waterwall/core.json ]; then
		echo -e "${cyan}Creating core.json...${rest}"
		echo ""
		cat <<EOF >~/Waterwall/core.json
{
    "log": {
        "path": "log/",
        "core": {
            "loglevel": "DEBUG",
            "file": "core.log",
            "console": true
        },
        "network": {
            "loglevel": "DEBUG",
            "file": "network.log",
            "console": true
        },
        "dns": {
            "loglevel": "SILENT",
            "file": "dns.log",
            "console": false
        }
    },
    "dns": {},
    "misc": {
        "workers": 0,
        "ram-profile": "server",
        "libs-path": "libs/"
    },
    "configs": [
        "config.json"
    ]
}
EOF
	fi
}

#2
# Bgp4 Tunnel
bgp4() {
	create_bgp4_iran() {
		echo -e "${cyan}============================${rest}"
		echo -en "${green}Enter the local port: ${rest}"
		read -r local_port
		echo -en "${green}Enter the remote address: ${rest}"
		read -r remote_address
		echo -en "${green}Enter the remote (${yellow}Connection${green}) port [${yellow}Default: 2249${green}]: ${rest}"
		read -r remote_port
		remote_port=${remote_port:-2249}

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "bgp_client",
    "nodes": [
        {
            "name": "input",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": $local_port,
                "nodelay": true
            },
            "next": "bgp_client"
        },
        {
            "name": "bgp_client",
            "type": "Bgp4Client",
            "settings": {},
            "next": "output"
        },
        {
            "name": "output",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "$remote_address",
                "port": $remote_port
            }
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
	}

	create_bgp4_kharej() {
		echo -e "${cyan}============================${rest}"
		echo -en "${green}Enter the local (${yellow}Connection${green}) port [${yellow}Default: 2249${green}]: ${rest}"
		read -r local_port
		local_port=${local_port:-2249}
		echo -en "${green}Enter the remote (${yellow}Server Config ${green}) port: ${rest}"
		read -r remote_port

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "bgp_server",
    "nodes": [
        {
            "name": "input",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": $local_port,
                "nodelay": true
            },
            "next": "bgp_server"
        },
        {
            "name": "bgp_server",
            "type": "Bgp4Server",
            "settings": {},
            "next": "output"
        },
        {
            "name": "output",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "127.0.0.1",
                "port": $remote_port
            }
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
	}

	create_bgp4_multiport_iran() {
		echo -e "${cyan}============================${rest}"
		echo -en "${cyan}Enter the starting local port [${yellow}greater than 23${green}]: ${rest}"
		read -r start_port
		echo -en "${cyan}Enter the ending local port [${yellow}less than 65535${green}]: ${rest}"
		read -r end_port
		echo -en "${cyan}Enter the remote address: ${rest}"
		read -r remote_address
		echo -en "${cyan}Enter the remote (${yellow}Connection${green}) port [${yellow}Default: 2249${green}]: ${rest}"
		read -r remote_port
		remote_port=${remote_port:-2249}

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "bgp_Multiport_client",
    "nodes": [
        {
            "name": "input",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": [$start_port,$end_port],
                "nodelay": true
            },
            "next": "port_header"
        },
        {
            "name": "port_header",
            "type": "HeaderClient",
            "settings": {
                "data": "src_context->port"
            },
            "next": "bgp_client"
        },
        {
            "name": "bgp_client",
            "type": "Bgp4Client",
            "settings": {},
            "next": "output"
        }, 
        {
            "name": "output",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "$remote_address",
                "port": $remote_port
            }
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
	}

	create_bgp4_multiport_kharej() {
		echo -e "${cyan}============================${rest}"
		echo -en "${green}Enter the local (${yellow}Connection${green}) port [${yellow}Default: 2249${green}]: ${rest}"
		read -r local_port
		local_port=${local_port:-2249}

		install_waterwall

		json=$(
			cat <<EOF
{
    "name": "bgp_Multiport_server",
    "nodes": [
        {
            "name": "input",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": $local_port,
                "nodelay": true
            },
            "next": "bgp_server"
        },
        {
            "name": "bgp_server",
            "type": "Bgp4Server",
            "settings": {},
            "next": "port_header"
        },
        {
            "name":"port_header",
            "type": "HeaderServer",
            "settings": {
                "override": "dest_context->port"
            },
            "next": "output"

        },
        {
            "name": "output",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "127.0.0.1",
                "port": "dest_context->port"
            }
        }
    ]
}
EOF
		)
		echo "$json" >/root/Waterwall/config.json
	}
	echo -e "1. ${cyan} bgp4 Multiport Iran${rest}"
	echo -e "2. ${White} bgp4 Multiport kharej${rest}"
	echo -e "0. ${cyan} Back to Main Menu${rest}"
	echo -en "${Purple} Enter your choice: ${rest}"
	read -r choice

	case $choice in
	1)
		create_bgp4_multiport_iran
		waterwall_service
		;;
	2)
		create_bgp4_multiport_kharej
		waterwall_service
		;;
	0)
		main
		;;
	*)
		echo -e "${red}Invalid choice!${rest}"
		;;
	esac
}

# Uninstall Waterwall
uninstall_waterwall() {
	if [ -f ~/Waterwall/config.json ] || [ -f /etc/systemd/system/Waterwall.service ]; then
		echo -e "${cyan}==============================================${rest}"
		echo -en "${green}Press Enter to continue, or Ctrl+C to cancel.${rest}"
		read -r
		if [ -d ~/Waterwall/cert ] || [ -f ~/.acme/acme.sh ]; then
			echo -e "${cyan}============================${rest}"
			echo -en "${green}Do you want to delete the Domain Certificates? (yes/no): ${rest}"
			read -r delete_cert

			if [[ "$delete_cert" == "yes" ]]; then
				echo -e "${cyan}============================${rest}"
				echo -en "${green}Enter Your domain: ${rest}"
				read -r domain

				rm -rf ~/.acme.sh/"${domain}"_ecc
				rm -rf ~/Waterwall/cert
				echo -e "${green}Certificate for ${domain} has been deleted.${rest}"
			fi
		fi

		rm -rf ~/Waterwall/{core.json,config.json,Waterwall,log/}
		systemctl stop Waterwall.service >/dev/null 2>&1
		systemctl disable Waterwall.service >/dev/null 2>&1
		rm -rf /etc/systemd/system/Waterwall.service >/dev/null 2>&1
		echo -e "${cyan}============================${rest}"
		echo -e "${green}Waterwall has been uninstalled successfully.${rest}"
		echo -e "${cyan}============================${rest}"
	else
		echo -e "${cyan}============================${rest}"
		echo -e "${red}Waterwall is not installed.${rest}"
		echo -e "${cyan}============================${rest}"
	fi
}

# Create Service
waterwall_service() {
	create_core_json
	# Create a new service
	cat <<EOL >/etc/systemd/system/Waterwall.service
[Unit]
Description=Waterwall Tunnel Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/Waterwall
ExecStart=/root/Waterwall/Waterwall
Restart=always

[Install]
WantedBy=multi-user.target
EOL

	# Reload systemctl daemon and start the service
	sudo systemctl daemon-reload
	sudo systemctl restart Waterwall.service >/dev/null 2>&1
	check_waterwall_status
}
#===================================

# Trojan Service
trojan_service() {
	create_trojan_core_json
	# Create Trojan service
	cat <<EOL >/etc/systemd/system/trojan.service
[Unit]
Description=Waterwall Trojan Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/Waterwall/trojan
ExecStart=/root/Waterwall/Waterwall
Restart=always

[Install]
WantedBy=multi-user.target
EOL

	# Reload systemctl daemon and start the service
	sudo systemctl daemon-reload
	sudo systemctl restart trojan.service >/dev/null 2>&1
}

# Check Install service
check_install_service() {
	if [ -f /etc/systemd/system/Waterwall.service ]; then
		echo -e "${cyan}===================================${rest}"
		echo -e "${red}Please uninstall the existing Waterwall service before continuing.${rest}"
		echo -e "${cyan}===================================${rest}"
		exit 1
	fi
}

# Check tunnel status
check_tunnel_status() {
	# Check the status of the tunnel service
	if sudo systemctl is-active --quiet Waterwall.service; then
		echo -e "${yellow}     Waterwall :${green} [running ✔] ${rest}"
	else
		echo -e "${yellow}     Waterwall: ${red} [Not running ✗ ] ${rest}"
	fi
}

# Check Waterwall status
check_waterwall_status() {
	sleep 1
	# Check the status of the tunnel service
	if sudo systemctl is-active --quiet Waterwall.service; then
		echo -e "${cyan}Waterwall Installed successfully :${green} [running ✔] ${rest}"
		echo -e "${cyan}============================================${rest}"
	else
		echo -e "${yellow}Waterwall is not installed or ${red}[Not running ✗ ] ${rest}"
		echo -e "${cyan}==============================================${rest}"
	fi
}

# Main Menu

main() {
	clear
    
echo  "
 ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄       ▄            ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄        ▄ 
▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌     ▐░▌          ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░▌      ▐░▌
▐░█▀▀▀▀▀▀▀▀▀ ▐░█▀▀▀▀▀▀▀█░▌     ▐░▌          ▐░█▀▀▀▀▀▀▀▀▀ ▐░█▀▀▀▀▀▀▀█░▌▐░█▀▀▀▀▀▀▀█░▌▐░▌░▌     ▐░▌
▐░▌          ▐░▌       ▐░▌     ▐░▌          ▐░▌          ▐░▌       ▐░▌▐░▌       ▐░▌▐░▌▐░▌    ▐░▌
▐░█▄▄▄▄▄▄▄▄▄ ▐░█▄▄▄▄▄▄▄█░▌     ▐░▌          ▐░█▄▄▄▄▄▄▄▄▄ ▐░█▄▄▄▄▄▄▄█░▌▐░█▄▄▄▄▄▄▄█░▌▐░▌ ▐░▌   ▐░▌
▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌     ▐░▌          ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░▌  ▐░▌  ▐░▌
▐░█▀▀▀▀▀▀▀█░▌ ▀▀▀▀▀▀▀▀▀█░▌     ▐░▌          ▐░█▀▀▀▀▀▀▀▀▀ ▐░█▀▀▀▀▀▀▀█░▌▐░█▀▀▀▀█░█▀▀ ▐░▌   ▐░▌ ▐░▌
▐░▌       ▐░▌          ▐░▌     ▐░▌          ▐░▌          ▐░▌       ▐░▌▐░▌     ▐░▌  ▐░▌    ▐░▌▐░▌
▐░█▄▄▄▄▄▄▄█░▌ ▄▄▄▄▄▄▄▄▄█░▌     ▐░█▄▄▄▄▄▄▄▄▄ ▐░█▄▄▄▄▄▄▄▄▄ ▐░▌       ▐░▌▐░▌      ▐░▌ ▐░▌     ▐░▐░▌
▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌     ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░▌       ▐░▌▐░▌       ▐░▌▐░▌      ▐░░▌
 ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀▀       ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀         ▀  ▀         ▀  ▀        ▀▀ "

	echo ""
	check_tunnel_status
	echo ""
    echo ""

	echo -e "${cyan}1. Bgp4 Tunnel${rest}"
	echo -e "${cyan}2. Uninstall Waterwall${rest}"
	echo -e "${White}0. Exit${rest}"
	echo -en "${Purple}Enter your choice (1-3): ${rest}"
	read -r choice

	case $choice in
	1)
		check_install_service
		bgp4
		;;
	2)
		uninstall_waterwall
		;;
	0)
		echo -e "${cyan}Exit..${rest}"
		exit
		;;
	*)
		echo -e "${Purple}Invalid choice!${rest}"
		;;
	esac
}
main
