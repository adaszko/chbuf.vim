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

 * Implement matching algorithm more suitable for buffer names
 * Tab-completion up to longest common prefix
 * Make Tab behave as enter when longest common prefix is unambiguous
 * Score higher subsequences occuring after directory separator
 * Make functions script-private once they are sufficiently tested
 * Should <S-Return> also :lcd into file's directory?
 * Tiny screencast


License
=======

BSD3
