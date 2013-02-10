#!/bin/bash
# 
# Home Backup Script
#
# 1) Eliminates duplicate files by md5sum check.
# 2) Sorts files into directories by EXIF data.  Puts all others into other folder by created date.
# 3) Removes random files like picasa.ini and thumbs.db.  Removes empty folders and fixes permissions/ownership.
# 4) Does a reverse mirror with lftp up to a target FTP host.
#



share="/data/Pictures" # the target share to operate against
filedb="/tmp/filelist.txt" # location for temp list of files
md5db="/tmp/md5list.txt" # location for temp md5 list
lockfile="/tmp/backup.lck" # lockfile
checkdays=0 # number of days back to check for dupes - 0 means all
backuptries=10 # number of tries to back up your data with a clean return code
ownuser="nobody" # the user that should own all the files in the share
owngroup="samba" # the group that should own all the files in the share
noexif="Unsortable" # name of folder in share to put files that dont have exif data. Relative to share target
remotedir="/" # remote FTP target directory for backups
filedepth="8" # maximum levels deep to rename files and folders with spaces
bwlimit="262144" # bandwidth limit in bytes per second
fileperms="775" # chmod files to this permissions set
dirperms="775" # chmod diretories to this permissions set


if [[ -f $lockfile ]]; then
	echo $0 is already running.  $lockfile exists.
	echo
	echo To remove run:
	echo rm -f $lockfile
	exit 1
fi

which exiftags &> /dev/null
if [[ $? -ne 0 ]]; then
	echo "$0 requires exiftags to be installed."
	echo "Install it by running: yum install exiftags -y -q"
	exit 1
fi

which lftp &> /dev/null
if [[ $? -ne 0 ]]; then
	echo "$0 requires lftp to be installed."
	echo "Install it by running: yum install lftp -y -q"
	exit 1
fi


if [ -f ~/.homebackup.cfg ]; then
	ftpuser=$(cat ~/.homebackup.cfg | grep User | sed -e 's/User //')
	ftppass=$(cat ~/.homebackup.cfg | grep Password | sed -e 's/Password //')
	ftpserver=$(cat ~/.homebackup.cfg | grep Server | sed -e 's/Server //')
	echo "Backing up data to $ftpuser@$ftpserver."
else
	cat << EOF
No ~/.homebackup.cfg file found.  Please create one with your FTP information just like the following:

User myftpuser
Password myftppassword
Server ftp.myftp.com

EOF
exit 1
fi


touch $lockfile
rm -f $md5db.* 2> /dev/null
rm -f $md5db 2> /dev/null
rm -f $filedb 2> /dev/null
dirruns=0
fileruns=0
mindepth="0"
umask 0000


if [ ! -d "$share/$noexif" ]; then
	#echo -e -n "\r\nCreated directory: $share/$noexif"
	mkdir $share/$noexif
fi

echo "Target: $share"

# Step 1: Find & Remove Duplicates
echo -n "Removing spaces from directories"
while [[ $dirruns -le $filedepth ]]; do
	echo -n "."
	dirruns=$(( $dirruns + 1 ))
	find $share -mindepth $mindepth -maxdepth $dirruns -type d ! -name "*;*" ! -name "*&*" | while read directory; do
		echo $directory | grep " " &>/dev/null
		if [[ $? -eq 0 ]]; then
			cleandir=$( echo ${directory} | tr "()$ " "_" )
			cleandir=$( echo ${cleandir} | sed -e 's/ /_/g')
			if [ ! -d $cleandir ]; then
				#echo mv -n "$directory" "$cleandir"
				mv -n "$directory" "$cleandir"
			else 
				echo -n -e "\rMoving contents of $directory into existing directory $cleandir.                                                                           "
				mv -n "$directory/*" "$cleandir/" 2> /dev/null
				filecount=$(ls -al "$directory" | wc -l) #remove the source dir if it was emptied
				if [[ $filecount -le 2 ]]; then
					echo -n -e "\rRemoving $directory because it is now empty.                                                                                           "
					rm -rf "$directory"
				fi
				#echo Cant move $directory to"$cleandir" because it already exists!
			fi
		fi
	done
	mindepth=$(( $mindepth + 1 ))
done
echo
echo -n "Removing spaces from files"
mindepth="0"
while [[ $fileruns -le $filedepth ]]; do
	echo -n "."
	fileruns=$(( $fileruns + 1 ))
	find $share -mindepth $mindepth -maxdepth $fileruns -type f ! -name "*;*" ! -name "*&*" | while read file; do
		echo "$file" | grep " " > /dev/null
		if [[ $? -eq 0 ]]; then
			cleanfile=$( echo ${file} | tr "()$ " "_" )
			#echo $file $cleanfile
			if [ ! -f "$cleanfile" ]; then
				#echo mv -n "$file" "$cleanfile"
				mv -n "$file" "$cleanfile"
			fi
		fi
	done
	mindepth=$(( $mindepth + 1 ))
done
echo
echo "Removing Thumbs.db files..."
find $share -type f -name "Thumbs.db" -exec rm -f {} \; # remove thumbnail files
echo "Removing Picasa.ini files..."
find $share -type f -name "Picasa.ini" -exec rm -f {} \;
find $share -type f -name ".picasa.ini" -exec rm -f {} \;
echo "Removing ehthumbs_vista.db files..."
find $share -type f -name "ehthumbs_vista.db" -exec rm -f {} \;


echo "Fetching md5 sums..."
find $share -mtime $checkdays -type f ! -name "*;*" ! -name "*&*" -exec md5sum "{}" 2>/dev/null >> $md5db \;
cut -f1 -d\  $md5db > $md5db.cut
sort $md5db.cut > $md5db.sorted
echo "Detecting duplicate files..."
uniq -d $md5db.sorted > $md5db.dupes
if [ -s "$md5db.dupes" ]; then
	for dupe in `cat $md5db.dupes`; do
		grep $dupe $md5db >> $md5db.dupefiles
	done
	cat $md5db.dupefiles | while read item; do
		delnum="0"
		thismd5=$(echo "$item" | cut -f1 -d\ )
		numdupes=$(grep $thismd5 $md5db.dupefiles | wc -l)
		delnum=$(echo "$numdupes - 1" | bc)
		dellist=$(grep $thismd5 $md5db | tail -n $delnum)
		delaction=$(echo "$dellist" | cut -f2- -d\ )
		echo "$delaction" | while read del; do
			echo rm -f "\"$del\"" >> $md5db.delactions
		done
	done
	echo "Choosing which duplicate files to delete..."
	sort $md5db.delactions >> $md5db.delactions.sorted
	uniq $md5db.delactions.sorted >> $md5db.delactions.final
	echo "Deleting duplicate files..."
	bash < $md5db.delactions.final 
	numdels=$(cat $md5db.delactions.final | wc -l)
	echo Cleaned up $numdels duplicate files.

else
	echo No duplicate files detected.
fi







# Step 2: Sort our files into year folders nicely by exif date or creation date
echo -n "Fetching list of files... "
find $share -type f ! -name "*;*" ! -name "*&*" > $filedb
echo "`wc -l $filedb | cut -f1 -d\ ` files found."
echo "Moving files with EXIF data into directories sorted by date..."
find $share -type f ! -name "*;*" ! -name "*&*" | while read file; do
	basename=`basename "$file"`
	echo -n -e "\rProcessing $basename...                                                                                                        "
	#echo "$file"
	exiftime=$(exiftags -q -i "$file" 2> /dev/null | grep -i 'Image Created' | sed -e 's/Image Created: //' | cut -f1 -d: | cut -f1 -d- )
	exiftimelen=$(echo $exiftime | grep -v 'No EXIF time' | wc -c)
	if [[ $exiftimelen -ge 4 ]]; then
		if [ ! -d "$share/$exiftime" ]; then
			#echo -e -n "\r\nMaking directory: $share/$exiftime"
			mkdir "$share/$exiftime"
		fi
		if [ ! -f "$share/$exiftime/$basename" ]; then
			#echo -e -n "\r\nMoving $file to $share/$exiftime/$basename"
			mv -n "$file" "$share/$exiftime/$basename"
		else
			mv -n "$file" "$share/$exiftime/$RANDOM$basename"
		fi
	else
		#echo -e -n "\r\nNo EXIF time found for $file"
		if [ ! -f "$share/$noexif/$basename" ]; then
			echo -e -n "\r\nMoving $file to $share/$noexif/$basename"
			mv -n "$file" "$share/$noexif/$basename"
		else
			mv -n "$file" "$share/$noexif/$RANDOM$basename"
		fi
	fi
done
echo -e -n "\r"

if [[ -d $share/0000 ]]; then
	mv -n $share/0000/* $share/$noexif/
fi

echo "Sorting files in unsorted directory by creation date..."
find $share/$noexif -type f | while read noexiffile; do
	destdir=$(stat "$noexiffile" | grep Modify | cut -f2  -d\ | cut -f1 -d-)
	if [ ! -d $share/$destdir ]; then
		mkdir -p $share/$destdir
	fi
	destfile=$(basename "$noexiffile");
	if [ ! -f "$share/$destdir/$destfile" ]; then
		mv -n "$noexiffile" "$share/$destdir/$destfile"
	else
		mv -n "$noexiffile" "$share/$destdir/$ANDOM$destfile"
	fi
done

echo "Moving unsorted files into directory...                                                       "
find $share -maxdepth 1 -type f | while read unsorted; do
	if [[ -f "$unsorted" ]]; then
		basename=`basename "$unsorted"`
		mv -n "$unsorted" "$share/$noexif/$basename"
	fi
done


echo "Removing empty directories..."
# I am not exactly sure why this must be run multiple times to delete every empty folder, but it must.
find $share -type d -empty -exec rmdir {} \; 2> /dev/null
find $share -type d -empty -exec rmdir {} \; 2> /dev/null
find $share -type d -empty -exec rmdir {} \; 2> /dev/null
find $share -type d -empty -exec rmdir {} \; 2> /dev/null
find $share -type d -empty -exec rmdir {} \; 2> /dev/null
find $share -type d -empty -exec rmdir {} \; 2> /dev/null
find $share -type d -empty -exec rmdir {} \; 2> /dev/null
find $share -type d -empty -exec rmdir {} \; 2> /dev/null
find $share -type d -empty -exec rmdir {} \; 2> /dev/null
echo "Setting ownership..."
chown -R $ownuser:$owngroup "$share"
echo "Fixing permissions on directories..."
find $share -type d -exec chmod $dirperms {} \; 
echo "Fixing permissions on files..."
find $share -type f -exec chmod $fileperms {} \;




# Step 3: Rsync the resultant files to safety
echo "Backing up data to remote host..."
if [ -f ~/.lftprc ]; then
	mv -n ~/.lftprc ~/.lftprc.backup
fi
cat << EOF > ~/.lftprc	
set net:connection-limit 1
set net:limit-rate ${bwlimit}
EOF
if [ -f ~/.lftprc.backup ]; then
	mv -n ~/.lftprc.backup ~/.lftprc
fi

failures=0
result=1
while [[ "$result" -ne "0" ]] && [[ "$failures" -le "$backuptries" ]]; do
	# Input backup command here.  Use $ftpuser $ftppass $ftpserver and $share variables where necessary.
	lftp -u $ftpuser,$ftppass -e "mirror --reverse --only-newer $share $remotedir" $ftpserver # lftp sync up without a delete
	#rsync --bwlimit=250 -avn --delete $share $ftpuser@$ftpserver:  # rsync with a delete after
	result=$?
	if [[ $result -ne 0 ]]; then
		failures=$(($failures + 1))
		echo "Backup failure detected.  Try $failures of $backuptries."
	fi
done


rm -f $md5db.* 2> /dev/null
rm -f $md5db 2> /dev/null
rm -f $filedb 2> /dev/null
rm -f $md5db.delactions 2> /dev/null
rm -f $md5db.delactions.sorted 2> /dev/null
rm -f $md5db.final 2> /dev/null
rm -f $lockfile
exit 0
