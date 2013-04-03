What is it?
===========

A yet another Vim script for buffer switching.


Status
======

Works, but wouldn't recommend using it yet.


Installation
============

Assuming you have Pathogen up and running:

    $ cd ~/.vim/bundle
    $ git clone git://github.com/adaszko/chbuf.vim


Usage
=====

Just add a mapping of your choice to `.vimrc`:

    noremap <silent> <Leader>b :call chbuf#SwitchBuffer()<CR>


To Do
=====

 * Clean up occasional "Press ENTER of type command to continue" messages
 * Make C-s, C-v and C-t open splits or tab respectively for selected buffer
 * Make functions script-private once they are sufficiently tested
 * Tiny GIF screencast


License
=======

BSD3
