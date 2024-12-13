#!/usr/bin/bash

# Set variables for logging and email notifications
LOG_FILE="/var/log/task_automation.log"
EMAIL="nbv131103@gmail.com"

# Ensure the log file exists
touch "$LOG_FILE"

# Log messages function
log_message() {
	echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Welcome message
log_message "Welcome to the Task Automation Program"

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
	log_message "Error: This script must be run as root. Use 'sudo ./task_automation.sh'"
	exit 1
fi

# Collect task details
read -p "Name the task you want to automate: " taskName
read -p "What is the frequency for $taskName? (Daily = 1, Weekly = 7, Monthly = 30): " taskFrequency
read -p "Enter script file name and full file path: " taskPath_File

# Validate script file existence
if [ ! -f "$taskPath_File" ]; then
	log_message "Error: The specified script file does not exist at $taskPath_File!"
	echo "Sending error notification email to $EMAIL..."
	echo "Task automation failed. Script not found: $taskPath_File" | mailx -s "Task Automation Error" "$EMAIL"
	exit 1
fi

# Check if taskName already exists in /etc/anacrontab
if grep -q "$taskName" /etc/anacrontab; then
	log_message "Error: A task with the name '$taskName' already exists in anacrontab."
	echo "Sending error notification email to $EMAIL..."
	echo "Task automation failed. Duplicate task name: $taskName" | mailx -s "Task Automation Error" "$EMAIL"
	exit 1
fi

# Dependency handling
read -p "Is this task dependent on another task? (yes/no): " isDependent

if [[ "$isDependent" == "yes" ]]; then
	read -p "Enter the name of the task this is dependent on: " parentTask
	read -p "Enter additional delay time (in minutes) for $taskName to wait after $parentTask completes: " delayMinutes

	# Check if parent task exists in /etc/anacrontab
	if ! grep -q "$parentTask" /etc/anacrontab; then
    	log_message "Error: The parent task '$parentTask' does not exist in anacrontab."
    	echo "Sending error notification email to $EMAIL..."
    	echo "Task automation failed. Parent task not found: $parentTask" | mailx -s "Task Automation Error" "$EMAIL"
    	exit 1
	fi

	# Adjust the task's start time relative to the parent task
	log_message "Adding task '$taskName' as dependent on '$parentTask' with a delay of $delayMinutes minutes..."
	echo "$taskFrequency    $delayMinutes    $taskName    /bin/bash $taskPath_File || (echo 'Task $taskName failed' | mailx -s 'Task Failure Notification' $EMAIL)" | sudo tee -a /etc/anacrontab > /dev/null
else
	# Add task without dependency
	log_message "Adding task '$taskName' to anacrontab..."
	echo "$taskFrequency    0    $taskName    /bin/bash $taskPath_File || (echo 'Task $taskName failed' | mailx -s 'Task Failure Notification' $EMAIL)" | sudo tee -a /etc/anacrontab > /dev/null
fi

# Confirmation message
log_message "Task '$taskName' with frequency '$taskFrequency' has been successfully added to /etc/anacrontab."
log_message "Sending success email notification..."
echo "Task '$taskName' has been successfully automated!" | mailx -s "Task Automation Success" "$EMAIL"



log_message "Task Automation Completed."
