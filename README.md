# What is it?

An highly interactive way of jumping to buffers, files listed in `.viminfo` and
those from current directory.

# Status

Should work on Mac OS X, Linux and Windows.  If it isn't, it's a bug.

# Installation

Assuming you have Pathogen up and running:

    $ cd ~/.vim/bundle
    $ git clone git://github.com/adaszko/chbuf.vim

# Usage

Just add a mapping of your choice to `.vimrc`, e.g.:

    noremap <silent> <Leader>b :call chbuf#ChangeBuffer()<CR>
    noremap <silent> <Leader>f :call chbuf#ChangeFile('**')<CR>

# To Do

 * Write help file
 * Decouple getline.vim into a separate project
 * Tiny GIF screencast

# License

BSD3
