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

    let g:chbuf_ignore_pattern = '\v\C(^fugitive://|^/usr/local/Cellar/macvim/|^/private/var/folders/|/.git/COMMIT_EDITMSG$)'
    noremap <silent> <Leader>b :call chbuf#ChangeBuffer(g:chbuf_ignore_pattern)<CR>
    noremap <silent> <Leader>B :call chbuf#ChangeBufferOldFile(g:chbuf_ignore_pattern)<CR>
    noremap <silent> <Leader>f :call chbuf#ChangeFile('**')<CR>
    noremap <silent> <Leader>c :call chbuf#ChangeDir()<CR>

Note that functions above respect `ignorecase`, `wildignore` and `suffixes`.

# Bugs

It's generally slower on Windows.

# To Do

 * Write help file
 * Tiny GIF screencast

# License

BSD3
