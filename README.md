# chbuf.vim

## What is it?

A way of jumping to loaded buffers, elements of `v:oldfiles` and `:lcd`'ing
optimised for minimal number of key strokes.

## Status

Ready to use.

## Installation

Assuming you have Pathogen up and running:

    $ cd ~/.vim/bundle
    $ git clone git://github.com/adaszko/chbuf.vim

## Setup

Just add a mapping of your choice to `.vimrc`, e.g.:

    let g:chbuf_ignore_pattern = '\v\C(^fugitive://|^/usr/local/Cellar/macvim/|^/private/var/folders/|/.git/COMMIT_EDITMSG$)'
    noremap <silent> <Leader>b :call chbuf#change_buffer(g:chbuf_ignore_pattern)<CR>
    noremap <silent> <Leader>B :call chbuf#change_buffer_old_file(g:chbuf_ignore_pattern)<CR>
    noremap <silent> <Leader>f :call chbuf#change_file('**')<CR>
    noremap <silent> <Leader>c :call chbuf#change_dir()<CR>

Note that functions above respect `ignorecase`, `wildignore` and `suffixes`.

## Bugs

It's generally slower on Windows.

## To Do

 * Write help file
 * Tiny GIF screencast

## License

BSD3
