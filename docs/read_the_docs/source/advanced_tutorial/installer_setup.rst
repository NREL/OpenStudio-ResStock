Installer Setup
###############

After you have downloaded the OpenStudio installer, you will want to install Ruby (2.7.2). This will allow you to execute rake tasks contained in the `Rakefile <https://github.com/NREL/resstock/blob/develop/Rakefile>`_. Follow the instructions below for :ref:`windows-setup` or :ref:`mac-setup`.

.. _windows-setup:

Windows Setup
=============

1. Install `Ruby <http://rubyinstaller.org/downloads/archives>`_ (2.7.2). Follow the installation instructions `here <http://nrel.github.io/OpenStudio-user-documentation/getting_started/getting_started/#installation-steps>`_ ("Optional - Install Ruby").
2. Run ``gem install bundler -v 1.17.1``. 

.. note::

  If you get an error, you may have to issue the following: ``gem sources -r https://rubygems.org/`` followed by ``gem sources -a http://rubygems.org/``. If you still get an error, manually update your gem sources list by including a config file named ".gemrc" in your home directory (.e.g, /c/Users/<USERNAME>) with the following contents:

.. literalinclude:: .gemrc

3. Download the DevKit at http://rubyinstaller.org/downloads/ (e.g., DevKit-mingw64-64-4.7.2-20130224-1432-sfx.exe). Choose either the 32-bit or 64-bit version depending on which version of Ruby you installed. Run the installer and extract to a directory (e.g., C:\\RubyDevKit). Go to this directory, run ``ruby dk.rb init``, modify the config.yml file as needed, and finally run ``ruby dk.rb install``.
4. Run ``bundle install`` from the resstock directory. (If you get an error, check that ``git`` is in your ``PATH`` and that you are using the correct version of Ruby (2.7.2).)

.. _mac-setup:

Mac Setup
=========

Install `Homebrew <https://brew.sh>`_ if you don't have it already.

Run ``brew doctor``. It should give you, among other issues, a list of unexpected dylibs that you'll need to move for this to work such as:

.. code:: bash

  Unexpected dylibs:
    /usr/local/lib/libcrypto.0.9.8.dylib
    /usr/local/lib/libcrypto.1.0.0.dylib
    /usr/local/lib/libcrypto.dylib
    /usr/local/lib/libklcsagt.dylib
    /usr/local/lib/libklcskca.dylib
    /usr/local/lib/libklcsnagt.dylib
    /usr/local/lib/libklcsrt.dylib
    /usr/local/lib/libklcsstd.dylib
    /usr/local/lib/libklcstr.dylib
    /usr/local/lib/libklmspack.0.1.0.dylib
    /usr/local/lib/libklmspack.0.dylib
    /usr/local/lib/libklmspack.dylib
    /usr/local/lib/libssl.0.9.8.dylib
    /usr/local/lib/libssl.1.0.0.dylib
    /usr/local/lib/libssl.dylib
    /usr/local/lib/libz.1.2.5.dylib
    /usr/local/lib/libz.1.2.6.dylib
    /usr/local/lib/libz.1.dylib
    /usr/local/lib/libz.dylib

Highlight and copy the list (without the header "Unexpected dylibs:"). Run the following commands to move them to another location where they won't interfere.

.. code:: bash

  mkdir ~/unused_dylibs
  pbpaste | xargs -t -I % mv % ~/unused_dylibs

Install ``rbenv`` and required dependencies.

.. code:: bash

  brew install openssl libyaml libffi rbenv

Initialize ``rbenv`` by running the command below and following the instructions to add the appropriate things to your ``~/.bash_profile``.

.. code:: bash

  rbenv init

Install the appropriate ruby version.

.. code:: bash

  cd path/to/repo
  rbenv install `cat .ruby-version`

Add the path to the install ruby libraries top the bottom of your ``~/.bash_profile``

.. code:: bash

  echo "export RUBYLIB=/Applications/OpenStudio-3.2.1/Ruby" >> ~/.bash_profile
  echo "export ENERGYPLUS_EXE_PATH=\"/Applications/OpenStudio-3.2.1/EnergyPlus/energyplus-9.5.0\""

Install bundler and the libraries that bundler installs.

.. code:: bash

  gem install bundler -v 1.17.1
  bundle install
