# [osTicket](https://github.com/osTicket/osTicket) vagrant server environment

This is what I use to write plugins, test things, write patches etc.

Built to assist with development, assumes you have or can clone osticket source into folder `osticket`

Based on `ubuntu/xenial64` with Apache2, PHP 7.0 (libapache) and MySQL Server (5.7)

## How to use
* Install [Vagrant](https://www.vagrantup.com/docs/installation/) (With Virtualbox or Hyperv etc)
* Download this repo (git clone https://github.com/clonemeagain/osticket-vagrant)
* Then, download/clone osTicket into a folder called `osticket` Either from source: `git clone https://github.com/osTicket/osTicket osticket`, or Release: http://osticket.com/download
* Configure the variables in Vagrantfile with your environment details, Timezone/proxy server etc.
* Configure the variables in provision.sh script. 
* Run the up command: `vagrant up`
* Go make a coffee while it downloads Ubuntu, installs software & configures everything.

When it's done, and you see the message: `Ready to Rock!`, it should have a link, like http://localhost:8080 click that to start the install process.

If you've installed it, and configured it, and made a bunch of test tickets etc, simply export your database into the project root folder as `dbname.sql` where dbname is the name of your database. The provision script will detect it and install the database. If you also have an ost-config.php file inside /include/ then it will skip copying it. 

## Recommended Vagrant Plugins:
* `vagrant plugin install vagrant-proxyconf` - Lets you use a local proxy server to cache install packages etc. Autoconfigures apt. [link to repo](https://github.com/tmatilai/vagrant-proxyconf)
* `vagrant plugin install vagrant-vbguest` - Ensures the vm has the Virtualbox Guest Additions installed, and keeps them up to date. [link to repo](https://github.com/dotless-de/vagrant-vbguest)


## Debugging:
Xdebug is enabled and installed by default (so, don't use this in production)
Simply run a compatible debugger IDE on your host machine to start debugging! (it will connect back automatically, so, have a debugger using DBGP port 9000, like Eclipse)

## View logs:
Open the folder "logs" in the project folder, or /var/www/html/logs on the vagrant VM

## Scrap it and rebuild:
Run command `vagrant destroy` then `vagrant up`
Regular rebuild (fast) `vagrant up --provision`
You shouldn't need to rebuild it often, unless you're changing the provision script.

## Todo:
I'm thinking of checking for the osticket folder, and if not present, downloading the source automatically. See if anyone is keen.
- Requires git on vm
