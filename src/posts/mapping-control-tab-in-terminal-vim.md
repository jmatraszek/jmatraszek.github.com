---
title: Mapping Control-Tab in terminal Vim
layout: default.liquid
published_date: 2019-04-14 12:19:18 +0200
---
# Mapping Control-Tab in terminal Vim

One thing keeping me away from moving away from gVim to terminal Vim was the fact, that I could not map `<C-Tab>` or `<C-S-Tab>`. I this to cycle through open buffers and as an `UltiSnips` snippet trigger. A lot of people ask this question, but it's hard to find the right answer. Usually people just say that the terminal do not see the difference between `Tab` and `C-Tab`, which is, well, not quite true.

What is true, is the fact that there is no standard escape sequence for `C-Tab` or `C-S-Tab`, therefore terminals do quite reasonable thing and just send the escape sequence for `Tab` or `S-Tab`, respectively. Terminal applications only see the escape sequences, so they cannot differentiate between `Tab` and `C-Tab` — they receive the same escape sequence. We can, however, configure our terminal emulator to send a different escape sequence for `C-Tab`, than for `Tab` and then handle this properly in terminal Vim.

I use Alacritty, so I added the following two lines to `key_bindings` in `.config/alacritty/alacritty.yml`:

```
  - { key: Tab, mods: Control,       chars: "\x1b[1;5I" }
  - { key: Tab, mods: Control|Shift, chars: "\x1b[1;6I" }
```

This tells alacritty to send escape sequence `^[[1;5I` when we press `C-Tab`. We can check that by running `sed -n l`, press the required key sequence followed by an Enter (keep in mind that `^[`, `\x1b` and `\033` is just the escape sequence written in a different way).

Now, we have to handle that in Vim. Vim has its own keycodes and automatically assigns terminal escape sequences to them. Our custom escape sequences are not handled that way, so we have to assigne them manually. We can assign custom escape sequences using `set` command, but the Vim keycodes one can assign to are limited to the keycodes listed [here](http://vimdoc.sourceforge.net/htmldoc/term.html#t_ku). Unfortunatelly, `<C-Tab>` and `<C-S-Tab>` are not listed there, so it means we cannot assign escape sequence to them. We have to pick some other, unused, keycode (I used `<F15>`), assign the escape sequence and create a mapping between `<F15>` and `<C-Tab>`, so Vim treats those keycodes the same way:

```
set <F15>=^[[1;5I
set <F16>=^[[1;6I
nmap <F15> <C-Tab>
nmap <F16> <C-S-Tab>
imap <F15> <C-Tab>
imap <F16> <C-S-Tab>
```

IMPORTANT: Please note, that you have to input the actual escape sequence, not just write individual characters `^[`. To do that enter insert mode, press `C-V` and follow this with `Esc` (this will insert just the escape escape sequence) and manully insert the rest of the escape sequence or with `C-Tab` (this will insert the whole escape sequence).

You can read more on mapping keycodes in Vim [here](https://vim.fandom.com/wiki/Mapping_fast_keycodes_in_terminal_Vim).
