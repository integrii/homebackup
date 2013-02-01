homebackup.sh
=============

Turns the chaos of your family picture storage into de-duplicated and sorted niceness; then backs it up.


Over the many years of taking digital photography and video, my home server was just piling up with media.  Because I knew that I had a backup script running each week for that file share, I would get lazy and drag everything I found on my PC onto the samba server and consider it safe. To make matters even more complicated, my wife would come along with Picasa and export multiple copies of things into the share in various folder names.  Eventually this turned into complete file chaos and I was rather sure that I had tens or hundreds of gigs of storage wasted.  

Even worse still, I had no idea where anything was.  Folders were all named whatever we felt like naming them at the time of import.  While it made sense at the time - in the long run it ended up being a cluttered mess.

To fix the problem, I needed to do three things at a regular interval:
* Remove duplicate files by MD5
* Sort the files by EXIF data or creation date
* Back the leftovers files up to a remote FTP

Thus homebackup.sh was born.  The script does exactly those things using the exiftags command and lftp.

The script is bash so it runs nearly everywhere.  This also means it is easy to modify and add your own code.  If you want to do a network rsync instead of lftp, you can just replace the lftp command with an rsync and consider it done.

The overall idea here is that you can setup this script to run as a cron job every few days and then mindlessly dump any photos you care about into your server.  The script will make sense of it all and delete any duplicates you don't need along the way.  Everything organized, safe and happy.



setup
=====

Setup is almost too simple. All you need to do is make a config with your FTP server credentials in it like below:

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
bwlimit="262144" # bandwidth limit in bytes per second
fileperms="775" # chmod files to this permissions set
dirperms="775" # chmod diretories to this permissions set

```

You also may want to schedule this with a cron job.  Run crontab -e as root and enter the following.  The MAILTO variable is optional but will make your server send you email reports to you instead of root (provided your email server works at home).  This cron job is for every three days.  Change the 3 to however many days you prefer.  The 0 0 means on the first minute of the day (midnight).

```
MAILTO=myemail@mydomain.com
0 0 */3 * * /path/to/homebackup.cfg
```

disclaimer
==========
I am not responsible if you run this script and it burns down your house or deletes your life long anime collection.
