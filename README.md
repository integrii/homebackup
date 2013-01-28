homebackup.sh
=============

Turns the chaos of your family picture storage into de-duplicated and sorted niceness; then backs it up.


Over the many years of taking digital photography, my home server was just piling up with crap.  Because I knew that I had a backup script running each week for that file share, I would get lazy and drag everything I found on my PC onto the samba server and consider it safe. To make matters even more complicated, my wife would come along with Picasa and export multiple copies of things into the share in various folder names.  Eventually this turned into complete file chaos and I was rather sure that I had tens or hundreds of gigs of storage wasted.  

Even worse, I had no idea where anything was.  Folders were all named whatever we felt like naming them at time of import.  While it made sense at the time - in the long run it ended up being a cluttered mess.

To fix the problem, I needed to do three things at a regular interval:
* Remove duplicate files
* Sort the files by EXIF data or creation date
* Back the resultant files up to a remote FTP

Thus homebackup.sh was born.  The script does exactly those things using exiftags and lftp.

The script is bash so it runs nearly everywhere.  This also means it is easy to modify and add your own code.  Want to do a network rsync instead of lftp?  Just replace the lftp command with an rsync and you're good to go.
