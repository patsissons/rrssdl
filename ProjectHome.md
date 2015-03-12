# What is rrssdl #
This is just a simple yet powerful ruby system that allows for downloading the link tag in an RSS feed item.  The main trunk source is actually the TV Show variant (which is what i have built first), however, it would be easy to branch the code to handle other types of RSS feeds.

# Why rrssdl #
rrssdl was created with the intention of using it in combination with the rTorrent client (however this would work equally as well with transmission or any other client that can watch a directory).  The configuration is very simple, and at the same time offers a lot of versatility.  The system design was created with the idea in mind that it should be easy to implement new features.  I will always be open to receiving new feature requests.  rrssdl is designed to be very light weight, and use minimal resources, and at the same time be very easy to configure to specific needs.

# Current Features #
  * Logging (now with log4r!)
  * download to a specific path
  * download to a different path if troubles parsing the title (season/ep validation)
  * specify your own collection of regex's for title validation ( and season and ep parsing)
  * choose which shows you want enabled
  * choose which feeds you want enabled
  * set a timeout for feeds (abort if feed is not responding or responding too slowly)
  * multi-threaded, but thread safe (feed refreshing)
  * Daemon mode (run in the background, linux/unix only)
  * Config reload via SIGHUP
  * Exit cleanly via SIGINT (Ctrl-C)
  * Persist state in a state file (location is configurable)
  * Advanced configuration file (easily extensible for new features)
  * Post download commands for shows, feeds, and globally

# Todo #
  * TTL for feeds
  * Download link referrer for feeds
  * PID file when in daemon mode (plus config key for location)
  * Attempt to create dirs if they don't exists
  * Config option to keep original filename
  * Append .torrent if not terminated by .torrent
  * Try to download to review dir if download dir raises exception
  * Switch to yaml config file format

# News #
  * 2009-Jan-14
    * starting the conversion process to using log4r, should be a day or two
    * going to try and knock off a bunch of the todo items in the next few days
    * rrssdl trunk is currently broken, so don't update yet!
  * 2008-Oct-20 - Version 0.2 BETA released (SAME DAY RELEASES YEA!!!)
    * I was bored so i fixed a ton of bugs tonight
    * things should be pretty solid now
    * No official download yet, as soon as i get some feedback on this release i will look into creating an official download
  * 2008-Oct-20 - Version 0.1 BETA released
    * initial release, functionality works, but don't expect it to be bug free

# Status #
rrssdl is an active project, i intend to fully keep it up to date.  I have a lot of other features I want to add to this project, and they will slowly get added as I find time (and more quickly if someone requests it)

# Dependencies #
  * Ruby (not sure which version, but anything recent will probably work)
  * Some Ruby libs (all should come standard with your ruby package)
    * rss/1.0
    * rss/2.0
    * open-uri
    * optparse
    * timeout
    * thread
    * log4r (NEW!!!)
      * this may not come with your ruby package.  ubuntu people `apt-get install liblog4r-ruby`

# Beta Testing #
Feel like beta testing rrssdl? well you are more than welcome to do so.  There are no official downloads at the moment, so the only way to get things running is through SVN.  This means you'll need a subversion client, and one of the following command lines:

  * **Tester** (trunk): `svn checkout http://rrssdl.googlecode.com/svn/trunk/ rrssdl`
  * **Tester** ([revision 30](https://code.google.com/p/rrssdl/source/detail?r=30)): `svn -r 30 checkout http://rrssdl.googlecode.com/svn/trunk/ rrssdl`
  * **Developer**: `svn checkout https://rrssdl.googlecode.com/svn/trunk/ rrssdl --username USER_NAME`

Right now i am the only one who is in the developer class, but if you have interest in helping me with rrssdl i will be happy to add you.