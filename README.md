# What is it?

An interactive way of jumping to buffers and recently edited files.  Recent
files list is obtained via `v:oldfiles` variable (see `:help v:oldfiles`).

# Status

Should work on Mac OS X, Linux and Windows.  If it isn't, it's a bug.

# Installation

Assuming you have Pathogen up and running:

    $ cd ~/.vim/bundle
    $ git clone git://github.com/adaszko/chbuf.vim

# Usage

Just add a mapping of your choice to `.vimrc`, e.g.:

    noremap <silent> <Leader>b :call chbuf#SwitchBuffer()<CR>

# To Do

 * Introduce a variable that specifies ignored patterns
 * Make functions script-private once they are sufficiently tested
 * Documentation
 * Move getline.vim into separate repository
 * Tiny GIF screencast

# License

BSD3
