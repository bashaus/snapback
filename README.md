# Snapback

Version 0.1 Alpha

Create MySQL snapshots for easy development rollback.

## Project Details

### Use case

Large databases can be cumbersome to reload particularly when testing database migrations. 
This gem utilises logical volume management (LVM) to create database snapshots, allowing you to rollback to specified point in time.

### Problem domain

This scripts automates the concepts that are discussed in the following articles:

* lullabot.com -- [MySQL Backups Using LVM Snapshots](http://www.lullabot.com/articles/mysql-backups-using-lvm-snapshots)
* tldp.org -- [Taking a Backup Using Snapshots](http://tldp.org/HOWTO/LVM-HOWTO/snapshots_backup.html)
* mysqlperformanceblog.com -- [Faster Point In Time Recovery with LVM2 Snaphots and Binary Logs](http://www.mysqlperformanceblog.com/2012/02/23/faster-point-in-time-recovery-with-lvm2-snaphots-and-binary-logs/)

If you'd like more information on how to setup LVM on a Linux installation, see:

* howtogeek.com -- [What is Logical Volume Management and How Do You Enable It in Ubuntu?](http://www.howtogeek.com/howto/36568/what-is-logical-volume-management-and-how-do-you-enable-it-in-ubuntu/)


### Dependencies

* Linux (tested on Ubuntu 12.04.1 LTS)
* Sudo shell access
* Ruby (tested on version 1.8.7)
* Logical volume management (tested on version 2.02.66(2))
* MySQL (tested on version 5.5.29-0ubuntu0.12.04.1)

### Installation

    # If the MySQL client libraries aren't already installed, you may need to run this
    sudo apt-get update
    sudo apt-get install build-essential
    sudo apt-get install libmysql-ruby
    sudo apt-get install libmysqlclient-dev

    # Install the gem
    sudo gem install snapback

The gem should also automatically install the following gems:

* mysql
* colorize
* open4
* ruby-lvm

You must then enable multiple tablespaces.
Add a line to the [mysqld] section of your MySQL my.cnf:

[mysqld]
innodb_file_per_table=ON

### Configuration

If you're on Ubuntu (or other Linux system that uses AppArmor), you may need to allow MySQL to use the mounted directories.

    sudo nano /etc/apparmor.d/usr.sbin/mysqld

Add the following lines to the file:

    /mnt/mysql/ rwk,
    /mnt/mysql/** rwk,

Restart AppArmor and MySQL

    service apparmor restart
    service mysql restart

### Usage

Only recommended for use on virtual machines.
Not recommended for production environments.

## Setup

To start using this application, you must run this once:

    sudo snapback install

This creates the appropriate directories and checks that you have the required programs installed.
It will also ask you questions about your environment and save your configuration in your home directory.

## Creating a new database

To create a new database, you must specify the following values: 

* The name of the new database
* The size you expect the database to be (+10% for good measure)

E.g.: Create a database called "camera" which should hold 1G

    sudo snapback create camera --size 1G

## Snapshot an existing database

To make a snapshot, you must specify the following values:

* The name of the database being snapshot
* The amount you expect the database to grow by (+10% for good measure). Remember that deleting items in the database will cause the database grow (as you're recording changes, not size of files).

E.g.: Snapshot a database called "camera", where the changes will amount to an extra 100MB.

    sudo snapback snapshot camera --size 100M

## Rollback a database to the snapshot

Once you've finished trying to make changes in your database, you can create a snapshot 

E.g.: Rollback the database "camera" back to the date of the snapshot.

    sudo snapback rollback camera

## Drop a database

Once you've finished with the database, you can drop it from MySQL and remove the logical volumes.

E.g.: Drop the database "camera".

    sudo snapback drop camera

## Mount existing devices

If you want to mount a logical volume (e.g.: after a reboot), you can use the mount command.

E.g.: Continue using the database "camera"

    sudo snapback mount camera

## Unmount existing devices

If (for any reason) you want to unmount a logical volume (e.g.: disable a database temporarily), you can use the unmount command.

E.g.: Stop using the database "camera"

    sudo snapback unmount camera

## LVM Issues

If you're getting an error message similar to following:

    File descriptor ? (/home/?/.snapback.yml) leaked on lvcreate invocation.

You can circumvent this error by adding the following environmental variable before your command:

    LVM_SUPPRESS_FD_WARNINGS=1

For example:

    sudo LVM_SUPPRESS_FD_WARNINGS=1 sudo snapback snapshot camera --size 100M

## Licence

Copyright (C) 2013, [Bashkim Isai](http://www.bashkim.com.au)

This script is distributed under the MIT licence.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Contributors

* @bashaus -- [Bashkim Isai](http://www.bashkim.com.au/)

If you fork this project and create a pull request add your GitHub username, your full name and website to the end of list above.
