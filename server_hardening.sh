#!/bin/bash

# Global settings placed here incase they ever need to be modified
CPU_THRESHOLD=80		# Manual setting For limit CPU Usage
DISK_THRESHOLD=80		# Manual Setting for limit on Disk Space
SSH_PORT="2222"			# secure SSH port Listening
REPORT_DIR="ACME_Hardening"	# Creating log folder ACME HARDENING in folder where script is ran
REPORT_FILE="$REPORT_DIR/server_health.log" # Creates script report SERVER_HEALTH.log in newly created folder.

# Creates the Report directory if it doesn't already exist
mkdir -p "$REPORT_DIR"

# Wipes file and starts anew so old data is replaced with updated data so we are not constantly making new documents and flooding the system with old reports.
> "$REPORT_FILE"

echo "----Beginning_Server_Hardening_Check----"

# Beginning of report with cross platform in mind
echo "----ACME CORP HEALTH REPORT----" >> "$REPORT_FILE"
echo "Time: $(date)" >> "$REPORT_FILE" # adds current date to the header and appends it to the Report File.
echo "System: $(hostname)" >> "$REPORT_FILE" # Adds server name to the header and appends it to the Report File.
echo "-------------------------------" >> "$REPORT_FILE"

# Server Detection for Cross platform functions detecting if OS is Ubuntu or CentOS based
if [ -f /etc/debian_version ]; then
	OS_TYPE="ubuntu"
else
	OS_TYPE="centos"
fi


# NOTE TO SELF: EACH BLOCK WILL FROM HERE-ON-OUT WILL BE CLEARLY LABLED AND COMMENTED ON ITS FUNCTION FOR EASIER EDITING IN CASE OF ERRORS OR UPGRADING AND BLOCKS ARE DIVIDED BY double dotted lines

echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"
echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"

# BLOCK 1: NETWORK CONNECTIVITY CHECK

echo "----NETWORK_CONNECTIVITY_SCAN----"

#Block checks to see if Network can communicate out to Cisco DNS and Google Servers once each with a 2 second delay timer
echo -e "\n----NETWORK_CONNECTIVITY_SCAN----" >> "$REPORT_FILE" # Adds the Network Vulnerability Scan to a new Line

if OUT=$(ping -c 1 -W 2 208.67.220.220) || OUT=$(ping -c 1 -W 2 8.8.8.8); then # ping Cisco DNS once. if it fails, pings google DNS
	echo "----NETWORK_ONLINE----" >> "$REPORT_FILE" # If pings works, Network is online and appends it to $REPORT_FILE
else
	echo "----NETWORK_OFFLINE----" >> "$REPORT_FILE" # else Pings Do not work Network is offline and appends result to $REPORT_FILE
fi # End of Block

echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"
echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"


# BLOCK 2: STORAGE DISK USAGE CHECK

echo "----STORAGE_DISK_CHECK----"

# Shows Percentage of how full Drive is
echo -e "\n----STORAGE_DISK_CHECK----" >> "$REPORT_FILE"

DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

#Disk Threshold check 
if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
	echo "DISK USAGE HIGH! USAGE IS ${DISK_USAGE}% (Limit: ${DISK_THRESHOLD}%)" >> "$REPORT_FILE"
else
	echo "DISK SPACE NORMAL! USAGE IS ${DISK_USAGE}%" >> "$REPORT_FILE"
fi # End of Block

echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"
echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"


# BLOCK 3: TESTING THE HEALTH OF THE BRAIN OF YOUR COMPUTER, AND PUTS IT IN A NEW LINE WITH \n
echo -e "\n----CPU_PERFORMANCE_CHECK----" >> "$REPORT_FILE"

# Creates container CPU_IDLE and uses batch mode to take a picture, pipes to grep and throws everything away but Cpu(s), pipes to awk to print the 8th column (cpu usage). pipes to cut to removes decimal point for a full number in report.
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d. -f1)

# Creates container CPU_USAGE for the number in the report. subtracts from 100 to give a percentage of CPU's total Real usage.
CPU_USAGE=$((100 - CPU_IDLE))

# Is the CPU usage too High or is it just fine. -gt stands for greater than and will report a warning if the cpu is above 80%
if [ "$CPU_USAGE" -gt "$CPU_THRESHOLD" ]; then
	echo "High CPU Load, Usage at ${CPU_USAGE}%" >> "$REPORT_FILE" #If greater than 80% system prints warning and appends to report.
else
	echo "CPU at normal Load, Usage at ${CPU_USAGE}%" >> "$REPORT_FILE" # If Bellow 80% System Prints an Okay and appends it to report.
fi # End of Block

echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"
echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"

# BLOCK 4: SSH HARDENING CHECK

# Checks to see if SSH is turned off

# reports action to Bash
echo "----SSH_SERVICE_CHECK----"

echo -e "\n----SSH_SERVICE_CHECK----" >> "$REPORT_FILE"

if ! systemctl is-active --quiet ssh && ! systemctl is-active --quiet sshd; then
	echo "SSH Service OFF (Maximum Network Lockdown)" >> "$REPORT_FILE"
else
	echo "SSH Service ON (Auditing Configuration File...)" >> "$REPORT_FILE"

	#Checking the active port, root login rules and password rule in config files
	CURRENT_SSH_PORT=$(ss -tulpn | grep -E "ssh" | awk '{print $5}' | awk -F':' '{print $NF}' | sort -u | head -n1)
	ROOT_LOGIN=$(sshd -T | grep 'permitrootlogin' | awk '{print $2}')
	PASSWORD_AUTH=$(sshd -T | grep 'passwordauthentication' | awk '{print $2}')

	# Checking Custom Port
	if [ "$CURRENT_SSH_PORT" = "$SSH_PORT" ]; then
		echo "Running on SECURE custom port $SSH_PORT" >> "$REPORT_FILE"
	else
		echo "Running on INSECURE default port $CURRENT_SSH_PORT" >> "$REPORT_FILE"
	fi
	
	# Checking the ROOT LOGIN and PASSWORD AUTHENTICATION
	if [ "$ROOT_LOGIN" = "no" ]; then
        	echo "Direct root logins blocked" >> "$REPORT_FILE"
	else
		echo "Root can log in via network" >> "$REPORT_FILE"
	fi
	
	# Checking Password Authentication
	if [ "$PASSWORD_AUTH" = "no" ]; then
		echo "Disable SSH password login Auth PASS (Enforcing SSH Keys Only)" >> "$REPORT_FILE"
	else
		echo "Disable SSH password login Auth FAIL (Vulnerable to password brute-forcing)" >> "$REPORT_FILE"
	fi
fi # End of Block

echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"
echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"

# BLOCK 5: FIREWALL RULES AND BEST SECURITY CHECK

echo "----FIrewall_Rules_check----"

echo -e "\n----FIREWALL_RULES_AND_BEST_SECURITY_PRACTICES----" >> "$REPORT_FILE"

# Ubuntu Firewall Status
if [ "$OS_TYPE" = "ubuntu" ]; then
	FW_STATUS=$(sudo ufw status | head -n1 | awk '{print $2}')
	if [ "$FW_STATUS" = "active" ]; then
		echo "Ubuntu UFW Firewall is ON and Enforcing Rules" >> "$REPORT_FILE"
	else
		echo "Ubuntu UFW Firewall is OFF!" >> "$REPORT_FILE"
	fi

# Checking CentOS/RHEL Firewall Status
elif [ "$OS_TYPE" = "centos" ] || [ "$OS_TYPE" = "rhel" ]; then
	if systemctl is-active --quiet firewalld; then
		echo "CentOS Firewalld is ON and enforcing ruleset" >> "$REPORT_FILE"
	else
		echo "CentOS Firewalld is OFF!" >> "$REPORT_FILE"
	fi
fi # End of block

echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"
echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"

# BLOCK 6: ACCESS CONTROLS 

# Reports Action to bash
echo "----KERNEL_ACCESS_CONTROLS_CHECK----"

echo -e "\n----KERNEL_ACCESS_CONTROLS_CHECK----" >> "$REPORT_FILE"

# Checking Ubuntu AppArmor
if [ "$OS_TYPE" = "ubuntu" ]; then
	if [ -f /sys/module/apparmor/parameters/enabled ]; then
		AA_STATUS=$(cat /sys/module/apparmor/parameters/enabled)
	else
		AA_STATUS="N"
	fi

	if [ "$AA_STATUS" = "Y" ]; then
		echo "Ubuntu Kernel IS Protected!" >> "$REPORT_FILE"
	else
		echo "Ubuntu Kernel is NOT Protected!" >> "$REPORT_FILE"
	fi
fi # End of Block

echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"
echo "-----------------------------------------------------------------------------" >> "$REPORT_FILE"


# BLOCK 7: ANTI-ROOTKIT AND INTRUSION DETECTION SYSTEM (IDS)

# Reports Action to bash

echo "----SECURITY_TOOLS_CHECK----"

echo -e "\n----Security Tools Check----" >> "$REPORT_FILE"

# Checking if rootkit sniffers are installed (rkhunter or chkrootkit)
if [ -x "$(command -v rkhunter)" ] || [ -x "$(command -v chkrootkit)" ]; then
	echo "Rootkit signature scanners installed" >> "$REPORT_FILE"
else
	echo "NO Rootkit scanners installed!" >> "$REPORT_FILE"
fi

# Intrusion Detection system check (AIDE, Samhain or Fail2ban) 
if systemctl is-active --quiet fail2ban; then
	echo "IDS tool Active" >> "$REPORT_FILE"
else
	echo "No IDS systems found" >> "$REPORT_FILE"
fi # End of Block


#LAST BLOCK: END LINE OF THE SCRIPT THATS PLACED ON A NEW LINE.
echo -e "\n ----END OF ACME CORP HEALTH REPORT----" >> "$REPORT_FILE"

echo "----END_OF_ACME_CORP_HEALTH_REPORT----"
