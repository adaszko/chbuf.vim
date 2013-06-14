# What is it?

An interactive way of jumping to buffers and recently edited files.  Recent
files list is obtained via `v:oldfiles` variable (see `:help v:oldfiles`).

# Status

Should work on Mac OS X, Linux, Windows.  If it isn't, it's a bug.

# Installation

Assuming you have Pathogen up and running:

    $ cd ~/.vim/bundle
    $ git clone git://github.com/adaszko/chbuf.vim

# Usage

Just add a mapping of your choice to `.vimrc`, e.g.:

    noremap <silent> <Leader>b :call chbuf#SwitchBuffer()<CR>

# To Do

 * Make C-s, C-v and C-t open splits or tab respectively for selected buffer
 * Allow only S-Enter when file is no longer readable
 * Make functions script-private once they are sufficiently tested
 * Documentation
 * Move getline.vim into separate repository
 * Tiny GIF screencast

# License

BSD3
