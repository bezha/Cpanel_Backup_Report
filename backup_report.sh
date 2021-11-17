#!/bin/bash
# Quick backup report script written by: Marco Ferrufino
#
# Description: https://staffwiki.cpanel.net/bin/view/LinuxSupport/CPanelBackups
#
# How to run this script:
# curl -s --insecure https://raw.githubusercontent.com/cPanelTechs/TechScripts/master/backup_report.sh | sh

# this shows backups enabled or disabled but i need to return the value to the check functions

backlogdir=/usr/local/cpanel/logs/cpbackup;


# check if new backups are enabled
function check_new_backups() {
 echo -e "[ cPTech Backup Report v2.1 ]";
 new_enabled=$(grep BACKUPENABLE /var/cpanel/backups/config 2>/dev/null | awk -F"'" '{print $2}')
 new_cron=$(crontab -l | grep bin\/backup | awk '{print $1,$2,$3,$4,$5}')
 if [ "$new_enabled" = "yes" ]; then new_status=''Enabled''
 else new_status=''Disabled''
 fi
 echo -e "New Backups = $new_status\t\t(cron time: $new_cron)\t\t/var/cpanel/backups/config"
}

# check if legacy or new backups are enabled.  if each one is, then show how many users are skipped
function check_legacy_backups() {
 legacy_enabled=$(grep BACKUPENABLE /etc/cpbackup.conf | awk '{print $2'})
 legacy_cron=$(crontab -l | grep cpbackup | awk '{print $1,$2,$3,$4,$5}')
 if [ $legacy_enabled = "yes" ]; then legacy_status=''Enabled''
 else legacy_status=''Disabled''
 fi
 echo -e "Legacy Backups = $legacy_status\t(cron time: $legacy_cron)\t\t/etc/cpbackup.conf"
}

# For the ftp backup server checks.  I couldn't do this with normal arrays, so using this eval hack
hput () {
  eval hash"$1"='$2'
}
hget () {
  eval echo '${hash'"$1"'#hash}'
}

# Check if any active FTP backups
#function check_new_ftp_backups() {
# any_ftp_backups=$(\grep 'disabled: 0' /var/cpanel/backups/*backup_destination 2>/dev/null)
# if [ -n "$any_ftp_backups" ]; then ftp_backup_status='Enabled'
# else ftp_backup_status='Disabled'
# fi
# echo -e "\nNew FTP Backups = $ftp_backup_status\t(as of v2.0, this script only checks for new ftp backups, not legacy)"

 # Normal arrays
# declare -a ftp_server_files=($(\ls /var/cpanel/backups/*backup_destination));
# declare -a ftp_server_names=($(for i in ${ftp_server_files[@]}; do echo $i | cut -d/ -f5 | rev | cut -d_ -f4,5,6,7,8 | rev; done));
 # Array hack is storing 'Disabled' status in $srvr_SERVER_NAME
# for i in ${ftp_server_files[@]}; do hput srvr_$(echo $i | cut -d/ -f5 | rev | cut -d_ -f4,5,6,7,8 | rev) $(\grep disabled $i | awk '{print $2}'); done
 
 # Print
# for i in ${ftp_server_names[@]}; do 
#  echo -n "Backup FTP Server: "$i" = "
#  srvr_status=$(hget srvr_$i)
#  if [ $srvr_status = 0 ]; then
#   echo -e '\033[1;32m'Enabled'\033[0m';
#   else echo -e '\033[1;31m'Disabled'\033[0m';
#  fi
# done
#}

# look at start, end times.  print number of users where backup was attempted
function print_start_end_times () {
echo -e "[ Current Backup Logs in "$backlogdir" ]";
if [ -e $backlogdir ]; then
 cd $backlogdir;
 for i in `\ls [0-9]*`; do
   echo -n $i": "; echo -n "Started "; grep "I/O" $i | awk '{print $1" "$2" "$3}';
   echo -n $i": "; echo -n "Ended   "; grep "Final" $i | awk '{print $1" "$2" "$3}';
   #echo -n $i": "; echo -n "Ended "; \ls -lrth | grep $i | awk '{print $6" "$7" "$8}';
  echo -ne " Number of users backuped up:\t";  grep "user :" $i | wc -l;
 done;
fi;
}

function print_num_expected_users () {
 echo -e "[ Expected Number of Users ]";
 wc -l /etc/trueuserdomains;
}

function exceptions_heading() {
 echo -e "[ A count of users enabled/disabled ]";
}

function list_legacy_exceptions() {
legacy_users=$(grep "LEGACY_BACKUP=1" /var/cpanel/users/* | wc -l);
if [ $legacy_enabled == "yes" ]; then
 oldxs=$(egrep "LEGACY_BACKUP=0" /var/cpanel/users/* | wc -l);
 skip_file_ct=$(wc -l /etc/cpbackup-userskip.conf 2>/dev/null)
 if [ $oldxs -gt 0 -o "$skip_file_ct" ]; then
  echo -e "Legacy Backups:";
 fi
 if [ $oldxs -gt 0 ]; then echo -e "Number of real Legacy backup users disabled: \033[1;31m$oldxs\033[0m\n"; fi;
 if [ -n "$skip_file_ct" ]; then echo -e "Extra Information: This skip file should no longer be used\n"$skip_file_ct"\n"; fi
elif [ $legacy_users -gt 0 -a $legacy_status == "Disabled" ]; then
 echo -e "\nExtra Information: Legacy Backups are disabled as a whole, but there are $legacy_users users ready to use them."
echo
fi
}

function list_new_exceptions() {
# TODO: math
newsuspended=$(egrep "=1" /var/cpanel/users/* | grep "SUSPENDED" | wc -l);
if [ "$newsuspended" != 0 ]; then
    echo -e "Users suspended:$newsuspended";
fi

if [ "$new_enabled" == "yes" ]; then
 newxs=$(egrep "BACKUP=0" /var/cpanel/users/* | grep ":BACK" | wc -l);
 echo -e "New Backup users disabled: $newxs";
 newen=$(egrep "BACKUP=1" /var/cpanel/users/* | grep ":BACK" | wc -l);
 echo -e "New Backup users enabled: $newen"
fi
}

function count_local_new_backups() {
echo -e "[ A count of the monthly backup files on local disk currently ]";
new_backup_dir=$(awk '/BACKUPDIR/ {print $2}' /var/cpanel/backups/config 2>/dev/null)
for i in `\ls /backup/monthly`; do
number_new_backups2=$(\ls /backup/monthly/$i/accounts 2>/dev/null | grep tar.gz | egrep -v ":$" | awk NF | wc -l)
echo -e "New weekly backups in $new_backup_dir/monthly/$i/accounts: "$number_new_backups2
done
}


function count_local_new_backups_weekly() {
echo -e "[ A count of the weekly backup files on local disk currently ]";
new_backup_dir=$(awk '/BACKUPDIR/ {print $2}' /var/cpanel/backups/config 2>/dev/null)
for i in `\ls /backup/weekly`; do
number_new_backups3=$(\ls /backup/weekly/$i/accounts 2>/dev/null | grep tar.gz | egrep -v ":$" | awk NF | wc -l)
echo -e "New weekly backups in $new_backup_dir/weekly/$i/accounts: "$number_new_backups3
done
}

function count_local_legacy_backups() {
legacy_backup_dir=$(awk '/BACKUPDIR/ {print $2}' /etc/cpbackup.conf)
echo -e "\nLegacy backups in $legacy_backup_dir/: "
for freq in daily weekly monthly; do 
 echo -n $freq": "; 
 \ls $legacy_backup_dir/$freq | egrep -v "^dirs$|^files$|cpbackup|status" | sed 's/\.tar.*//g' | sort | uniq | wc -l;
done
}

function show_recent_errors() {
    # Errors from backup log directory
    # echo -e "[ Count of Recent Errors ]";
    # for i in `\ls $backlogdir`; do 
    #    echo -n $backlogdir"/"$i" Ended "; 
    #    \ls -lrth $backlogdir | grep $i | awk '{print $6" "$7" "$8}'; 
    #    \egrep -i "failed|error|load to go down|Unable" $backlogdir/$i | cut -c -180 | sort | uniq -c ;
    # done | tail;
    # Errors from cPanel error log
    echo -e "\n/usr/local/cpanel/logs/error_log:"
    egrep "(die|panic) \[backup" /usr/local/cpanel/logs/error_log | awk '{printf $1"] "; for (i=4;i<=20;i=i+1) {printf $i" "}; print ""}' | uniq -c | tail -1000000

    #any_ftp_backups=$(\grep 'disabled: 0' /var/cpanel/backups/*backup_destination 2>/dev/null)
    if [ -n "$any_ftp_backups" ]; then
        # Errors from FTP backups
        echo -e "\n/usr/local/cpanel/logs/cpbackup_transporter.log:"
        egrep '] warn|] err' /usr/local/cpanel/logs/cpbackup_transporter.log | tail -5
    fi
}

function top() {
echo -e "[ TOP ]";
new_backup_dir=$(awk '/BACKUPDIR/ {print $2}' /var/cpanel/backups/config 2>/dev/null)
for i in `\ls /backup/weekly/`; do
 top5=$(\ls -lhSr /backup/weekly/$i/accounts 2>/dev/null  | grep tar.gz | tail -3 |awk '{print $5" "$9}').
      echo -e $new_backup_dir/weekly/$i/accounts: $top5
               done
                        }

# Run all functions
check_new_backups
check_legacy_backups
echo -e ""
#check_new_ftp_backups
print_start_end_times 
echo -e ""
print_num_expected_users
echo -e ""
exceptions_heading
echo
#list_legacy_exceptions
list_new_exceptions
echo -e ""
count_local_new_backups
echo -e ""
count_local_new_backups_weekly
echo -e ""
top
#echo -e ""
#show_recent_errors
#echo; echo