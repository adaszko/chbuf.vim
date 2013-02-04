What is it?
===========

It allows you to read a line interactively from a Vim script.


Status
======

Unusable yet.


Installation
============

Assuming you have Pathogen up and running:

    cd ~/.vim/bundle
    git clone git://github.com/adaszko/getline.git


Usage
=====

    :echo getline#GetLine('> ')


TODO
====

* Allow for caret to slide on top of character without erasing them
* User-specified hooks on key presses
* Right prompt computed by user code each time contents change


License
=======

BSD3
