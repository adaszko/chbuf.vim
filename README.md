What is it?
===========

A yet another Vim script for buffer switching.


Status
======

Works, requires some more work to make it really handy.


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

 * Make C-s, C-v and C-t open splits or tab respectively for selected buffer
 * Block ENTER when nothing was found
 * Allow only S-Enter when file is no longer readable
 * Make functions script-private once they are sufficiently tested
 * Move getline.vim into separate repository
 * Tiny GIF screencast


License
=======

BSD3
