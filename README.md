homebackup.sh
=============

Turns the chaos of your family picture storage into de-duplicated and sorted niceness; then backs it up.


Over the many years of taking digital photography, my home server was just piling up with crap.  Because I knew that I had a backup script running each week for that file share, I would get lazy and drag everything I found on my PC onto the samba server and consider it safe. To make matters even more complicated, my wife would come along with Picasa and export multiple copies of things into the share in various folder names.  Eventually this turned into complete file chaos and I was rather sure that I had tens or hundreds of gigs of storage wasted.  

Even worse, I had no idea where anything was.  Folders were all named whatever we felt like naming them at time of import.  While it made sense at the time - in the long run it ended up being a cluttered mess.

To fix the problem, I needed to do three things at a regular interval:
* Remove duplicate files by MD5
* Sort the files by EXIF data or creation date
* Back the resultant files up to a remote FTP

Thus homebackup.sh was born.  The script does exactly those things using exiftags and lftp.

The script is bash so it runs nearly everywhere.  This also means it is easy to modify and add your own code.  Want to do a network rsync instead of lftp?  Just replace the lftp command with an rsync and you're good to go.

The overall idea here is that you can setup this script to run as a cron job every few days and then mindlessly dump any photos you care about into your server.  The script will make sense of it all and delete any duplicates you don't need along the way.



setup
=====

Setup is straightforward. All you need to do is make a config with your FTP server credentials in it like below:

~/.homebackup.cfg
```
User yourftpuser
Password yourftppass
Server ftp.mybackupserver.com
```

Then set the variables at the top of homebackup.sh:
```
share="/data/Pictures" # the target share to operate against
filedb="/tmp/filelist.txt" # location for temp list of files
md5db="/tmp/md5list.txt" # location for temp md5 list
lockfile="/tmp/backup.lck" # lockfile
checkdays=0 # number of days back to check for dupes - 0 means all
backuptries=10 # number of tries to back up your data with a clean return code
ownuser="nobody" # the user that should own all the files in the share
owngroup="samba" # the group that should own all the files in the share
noexif="Unsorted" # name of folder in share to put files that dont have exif data. Relative to share target
remotedir="backup" # remote FTP target directory for backups
filedepth="8" # maximum levels deep to rename files and folders with spaces
```


You also may want to schedule this with a cron job.  Run crontab -e and enter the following.  The MAILTO variable is optional but will make your server send you email reports to you instead of root (provided your email server works at home).

```
MAILTO=myemail@mydomain.com
0 0 */3 * * /path/to/homebackup.cfg
```
