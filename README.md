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

 * Spaces should indicate start of another pattern
 * Implement matching algorithm more suitable for buffer names
 * Make functions script-private once they are sufficiently tested
 * Tiny screencast


License
=======

BSD3
