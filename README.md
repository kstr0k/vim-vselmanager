#    <span class="flh"><a name="vselmanager.txt" href="#vselmanager.txt" class="t"><em>vselmanager</em></a>: vim visual selection manager &mdash; save &amp; restore visual selections</span>

The easiest way to access the documentation for this plugin is to type `:h vselmanager.txt` in Vim after [installing](#vselmanager-install) it. Also, have a look at the [changelog](doc/CHANGES.md).

This plugin is a fork of the original [`visualMarks`](https://github.com/iago-lito/vim-visualMarks) repository. There's also an unrelated [visualMarks.vim](https://github.com/viaa/VimPlugins/blob/master/visualMarks.vim).

<a name="vselmanager-toc" href="#vselmanager-toc" class="t"></a>

|  |  |
| -- | -- |
| INTRODUCTION |              <a href="#vselmanager-introduction" class="l"><em>vselmanager-introduction</em></a> |
| USAGE        |              <a href="#vselmanager-usage" class="l"><em>vselmanager-usage</em></a> |
| MAPPINGS     |              <a href="#vselmanager-mappings" class="l"><em>vselmanager-mappings</em></a> |
| VMARK NAMES  |              <a href="#vselmanager-vmark-names" class="l"><em>vselmanager-vmark-names</em></a> |
| COMMANDS     |              <a href="#vselmanager-commands" class="l"><em>vselmanager-commands</em></a> |
| SETTINGS     |              <a href="#vselmanager-settings" class="l"><em>vselmanager-settings</em></a> |
| INSTALLING   |              <a href="#vselmanager-install" class="l"><em>vselmanager-install</em></a> |
| LICENSE      |              <a href="#vselmanager-license" class="l"><em>vselmanager-license</em></a> |
| CREDITS      |              <a href="#vselmanager-credits" class="l"><em>vselmanager-credits</em></a> |

## <span class="c">INTRODUCTION                                   &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="vselmanager-introduction" href="#vselmanager-introduction" class="t"><sub><sup><em>vselmanager-introduction</em></sup></sup></a>

This plugin lets you save visual selections to named "visual marks" ("**vmarks**")
and later restore them, just as Vim's native marks do for cursor
positions (but they are entirely separate entities). Vmark names are
per-file (not global) and persistent.

## <span class="c">USAGE                                                 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="vselmanager-usage" href="#vselmanager-usage" class="t"><sub><sup><em>vselmanager-usage</em></sup></sup></a>

Assuming a standard setup (<a href="#vselmanager-install" class="l"><em>vselmanager-install</em></a>): in visual mode, to save the
selection to vmark "a", type 
<pre>
    \vma
</pre>

To later re-select the same area, type (in normal mode): 
<pre>
    \v`a
</pre>
and you'll be back in visual mode with the saved selection. Use lowercase
letters or <span class="s"><code>&lt;Space&gt;</code></span> as vmark names (details in <a href="#vselmanager-vmark-names" class="l"><em>vselmanager-vmark-names</em></a>).

Pressing <span class="s"><code>&lt;Tab&gt;</code></span> enters full name-editing mode with completion
(<a href="#vselmanager-input-name" class="l"><em>vselmanager-input-name</em></a>). Alternatively, the mappings can be prefixed with a
register (e.g. `"a\vm` instead of `\vma` -- <a href="#vselmanager-register-mappings" class="l"><em>vselmanager-register-mappings</em></a>).

See <a href="#vselmanager-mappings" class="l"><em>vselmanager-mappings</em></a> and <a href="#vselmanager-commands" class="l"><em>vselmanager-commands</em></a> for more actions.

### FEATURES

- no clobbering of Vim's regular marks and registers
- per-file vmarks
- vmarks persist after closing Vim
- vmarks save / restore the visual mode (<span class="l"><em>v</em></span>, <span class="l"><em>V</em></span>, <span class="l"><em>Ctrl-V</em></span>) of selections
- past-end-of-line ragged visual block selections are properly handled

## <span class="c">MAPPINGS                                           &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="vselmanager-mappings" href="#vselmanager-mappings" class="t"><sub><sup><em>vselmanager-mappings</em></sup></sup></a>

Most mappings require names (<a href="#vselmanager-vmark-names" class="l"><em>vselmanager-vmark-names</em></a>) to operate on; see
<a href="#vselmanager-input-name" class="l"><em>vselmanager-input-name</em></a> and <a href="#vselmanager-register-mappings" class="l"><em>vselmanager-register-mappings</em></a> for details on
how the plugin requests these names from the user.

### <span class="c">DEFAULT KEYS              &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="VselmanagerSetDefaultMapsx28xx29x" href="#VselmanagerSetDefaultMapsx28xx29x" class="t"><sub><sup><em>VselmanagerSetDefaultMaps()</em></sup></sup></a>  <a name="vselmanager-keys" href="#vselmanager-keys" class="t"><sub><sup><em>vselmanager-keys</em></sup></sup></a>

These are set internally by calling the function 
<pre>
    :call g:VselmanagerSetDefaultMaps( g:vselmanager_mapPrefix )
</pre>

when the global prefix is set, which, assuming a "<span class="l"><em>&lt;Leader&gt;</em></span>v" prefix, results
in the following mappings (the "mapping" column lists the **suffix** after
<code><span class="s">&lt;Plug&gt;</span>Vselmanager</code>)

<pre>
    modes  keys        mapping-suffix  Action
    v      \vm         SaveVMark       <a href="#x3AxVselmanagerSave" class="l"><em>:VselmanagerSave</em></a>
    nv     \v`         LoadVMark       <a href="#x3AxVselmanagerLoad" class="l"><em>:VselmanagerLoad</em></a>
    n      \vd         DelVMark        <a href="#x3AxVselmanagerDel" class="l"><em>:VselmanagerDel</em></a>
    nv     \vp         PutAVMark       <a href="#x3AxVselmanagerPutA" class="l"><em>:VselmanagerPutA</em></a>
    nv     \vP         PutBVMark       <a href="#x3AxVselmanagerPutB" class="l"><em>:VselmanagerPutB</em></a>
    nv     \vy         YankVMark       <a href="#x3CxPlugx3ExVselmanagerYankVMark" class="l"><em>&lt;Plug&gt;VselmanagerYankVMark</em></a>
    nv     \vgv        HistMR          <a href="#x3AxVselmanagerHistNext" class="l"><em>:VselmanagerHistNext</em></a> 0
    nv     \v&lt;Tab&gt;     HistNext        <a href="#x3AxVselmanagerHistNext" class="l"><em>:VselmanagerHistNext</em></a>
    nv     \v&lt;C-O&gt;     HistPrev        <a href="#x3AxVselmanagerHistPrev" class="l"><em>:VselmanagerHistPrev</em></a>
</pre>

Set the preferred <a href="#gx3Axvselmanager_mapPrefix" class="l"><em>g:vselmanager_mapPrefix</em></a> before the plugin loads (e.g. from
vimrc). The function does not re-bind <span class="s"><code>&lt;Plug&gt;</code></span> mappings already bound to
something else, so you can pre-bind some actions to other keys.

If <a href="#gx3Axvselmanager_mapPrefix" class="l"><em>g:vselmanager_mapPrefix</em></a> is undefined, the plugin installs no bindings
upon loading. You can thus selectively map any or all actions manually.  You
can also call <a href="#VselmanagerSetDefaultMapsx28xx29x" class="l"><em>VselmanagerSetDefaultMaps()</em></a> at some later point in the startup
sequence (e.g. from the <span class="l"><em>after-directory</em></span>).

### <span class="c">MAP ACTIONS                                     &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="vselmanager-map-actions" href="#vselmanager-map-actions" class="t"><sub><sup><em>vselmanager-map-actions</em></sup></sup></a>

- <a href="#vselmanager-keys" class="l"><em>vselmanager-keys</em></a> lists the associated command for most <span class="s"><code>&lt;Plug&gt;</code></span> mappings
- <a href="#x3CxPlugx3ExVselmanagerYankVMark" class="l"><em>&lt;Plug&gt;VselmanagerYankVMark</em></a> is described below
- all other <span class="s"><code>&lt;Plug&gt;</code></span> mappings ending in "VMark" operate on a single vmark name
- the "HistNext" and "HistPrev" mappings take an optional <span class="s"><code>[count]</code></span> prefix
  (1 if omitted)

### <a name="x3CxPlugx3ExVselmanagerYankVMark" href="#x3CxPlugx3ExVselmanagerYankVMark" class="t"><sub><sup><em>&lt;Plug&gt;VselmanagerYankVMark</em></sup></sup></a>
Yank the contents of the vmark into a register. Unlike other single-vmark
mappings, if prefixed by a register (e.g. "a), that register will act as
the destionation. The name of the vmark is always obtained as outlined in
<a href="#vselmanager-input-name" class="l"><em>vselmanager-input-name</em></a>. If this mapping is invoked without a register
prefix, the contents will be yanked into the unnamed register (`"`).

## <span class="c">VMARK NAMES                                     &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="vselmanager-vmark-names" href="#vselmanager-vmark-names" class="t"><sub><sup><em>vselmanager-vmark-names</em></sup></sup></a>

Names can be arbitrary strings, except that:
- names may not contain control chars (ASCII 0-31)
- names longer than a single char are harder to input (see below)

Additionally, some names are reserved and might be automatically assigned or
overwritten by the plugin in the future:
- numbers are reserved for vmark history
- names starting with an Uppercase letter are reserved for global vmarks
- the name "`" (backtick) is reserved for the most recently loaded vmark

### <span class="c">INPUT A VMARK NAME                               &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="vselmanager-input-name" href="#vselmanager-input-name" class="t"><sub><sup><em>vselmanager-input-name</em></sup></sup></a>

When requesting a vmark name, the plugin first reads a single char, which is
used immediately if such a vmark exists. <span class="s"><code>&lt;Esc&gt;</code></span>, <span class="s"><code>&lt;CR&gt;</code></span> or any control character
except <span class="s"><code>&lt;Tab&gt;</code></span> cancel the operation. <span class="s"><code>&lt;Tab&gt;</code></span> enters full input mode, where names
can be arbitrary strings and another <span class="s"><code>&lt;Tab&gt;</code></span> completes; again, <span class="s"><code>&lt;Esc&gt;</code></span> or entering
an empty name cancels.

### <span class="c">REGISTER NAMES AS VMARKS                  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="vselmanager-register-mappings" href="#vselmanager-register-mappings" class="t"><sub><sup><em>vselmanager-register-mappings</em></sup></sup></a>

Alternatively the mappings can be prefixed with a register, which acts purely
as a vmark name (e.g.: "a\vm). This method bypasses the input mechanism used
above (meaning such maps work in macros, don't echo any messages etc). On the
other hand, the set of Vim register names (:help <span class="l"><em>registers</em></span>) is limited, so
names created with another method might be unavailable as a prefix.

## <span class="c">COMMANDS                                           &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="vselmanager-commands" href="#vselmanager-commands" class="t"><sub><sup><em>vselmanager-commands</em></sup></sup></a>

In the following, `{vmark}` is a vmark name (<a href="#vselmanager-vmark-names" class="l"><em>vselmanager-vmark-names</em></a>).

<a name="x3AxVselmanagerSave" href="#x3AxVselmanagerSave" class="t"><em>:VselmanagerSave</em></a> `{vmark}` <br>
    Save current / most recent (<span class="l"><em>gv</em></span>) visual selection to `{vmark}`

<a name="x3AxVselmanagerLoad" href="#x3AxVselmanagerLoad" class="t"><em>:VselmanagerLoad</em></a> `{vmark}` <br>
    Restore visual selection associated with `{vmark}`

<a name="x3AxVselmanagerHistForward" href="#x3AxVselmanagerHistForward" class="t"><em>:VselmanagerHistForward</em></a> `{delta}`           &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a name="vselmanager-history-navigation" href="#vselmanager-history-navigation" class="t"><em>vselmanager-history-navigation</em></a> <br>
`:[count]VselmanagerHistNext`                         &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a name="x3AxVselmanagerHistNext" href="#x3AxVselmanagerHistNext" class="t"><em>:VselmanagerHistNext</em></a> <br>
`:[count]VselmanagerHistPrev`                         &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a name="x3AxVselmanagerHistPrev" href="#x3AxVselmanagerHistPrev" class="t"><em>:VselmanagerHistPrev</em></a> <br>
    Navigate forwards / backwards through vmarks in some unspecified order; it
    may change if vmarks are added / deleted, and in-between Vim sessions, but
    is otherwise stable. `{delta}` = 0 corresponds to the vmark most recently
    loaded by "Hist" commands, -1 to the previous one and +1 to the next one.
    `{delta}` can be any <span class="l"><em>expr</em></span>. The Next / Prev commands take a constant `[count]`
    instead, which defaults to 1. It can precede or follow the command.

<a name="x3AxVselmanagerDel" href="#x3AxVselmanagerDel" class="t"><em>:VselmanagerDel</em></a>  `{vmark}` <br>
    Remove a previously saved vmark

<a name="x3AxVselmanagerDelAll" href="#x3AxVselmanagerDelAll" class="t"><em>:VselmanagerDelAll</em></a> <br>
    Remove all vmarks from the current buffer

<a name="x3AxVselmanagerPutA" href="#x3AxVselmanagerPutA" class="t"><em>:VselmanagerPutA</em></a> `{vmark}` <br>
<a name="x3AxVselmanagerPutB" href="#x3AxVselmanagerPutB" class="t"><em>:VselmanagerPutB</em></a> `{vmark}` <br>
    Paste a vmark's contents After / Before the cursor (like <span class="l"><em>p</em></span> / <span class="l"><em>P</em></span>). In
    visual mode, overwrite the current visual selection.

<a name="x3AxVselmanagerForgetFile" href="#x3AxVselmanagerForgetFile" class="t"><em>:VselmanagerForgetFile</em></a> `{file}` <br>
    Remove all vmarks from the specified file

<a name="x3AxVselmanagerSwapVisual" href="#x3AxVselmanagerSwapVisual" class="t"><em>:VselmanagerSwapVisual</em></a> `{vmark}` <br>
    Swap the current visual selection with that of `{vmark}`; update `{vmark}`
    to point to the its new location (its corresponding text unchanged). The
    final visual selection text is the same as the initial one (but moved to
    the initial `{vmark}` location). Both visual selections should have the same
    type (e.g. both char visual or both line visual) and not overlap.


## <span class="c">SETTINGS                                           &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="vselmanager-settings" href="#vselmanager-settings" class="t"><sub><sup><em>vselmanager-settings</em></sup></sup></a>

Settings should be defined before the plugin loads (e.g. from <span class="l"><em>vimrc</em></span>; see
":help <span class="l"><em>startup</em></span>", ":help <span class="l"><em>load-plugin</em></span>").

### <span class="c">DATABASE LOCATION                   &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="gx3Axvselmanager_marksFile" href="#gx3Axvselmanager_marksFile" class="t"><sub><sup><em>g:vselmanager_DBFile</em></sup></sup></a>

Vselmanager stores all vmarks in a single JSON file. Its default path is 
<pre>
    let g:vselmanager_DBFile = fnamemodify('~/', ':p') .. '.vim-vselmanager.json'
</pre>

This template should be portable, in case you decide to change the path /
basename.

### <span class="c">DEFAULT MAP PREFIX                  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="gx3Axvselmanager_mapPrefix" href="#gx3Axvselmanager_mapPrefix" class="t"><sub><sup><em>g:vselmanager_mapPrefix</em></sup></sup></a>

Set to a prefix string to trigger automatic loading of default key mappings.
Without it, no mappings are installed by default. See <a href="#vselmanager-keys" class="l"><em>vselmanager-keys</em></a>.
Suggested: 
<pre>
    let g:vselmanager_mapPrefix = '&lt;Leader&gt;v'
</pre>

### <span class="c">BEHAVIOR AFTER SAVING A VMARK       &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="gx3Axvselmanager_exitVModeAfterMarking" href="#gx3Axvselmanager_exitVModeAfterMarking" class="t"><sub><sup><em>g:vselmanager_exitVModeAfterMarking</em></sup></sup></a>

The plugin exits visual mode after saving a vmark if this global is set to 1
(the default). Set it to 0 to remain in visual mode.

## <span class="c">INSTALLATION                                        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="vselmanager-install" href="#vselmanager-install" class="t"><sub><sup><em>vselmanager-install</em></sup></sup></a>

With the Vim 8+ built-in package system ([`:help packages`](https://vimhelp.org/repeat.txt.html#packages)):
- clone (or symlink) the git repo under <span class="l"><em>'packpath'</em></span>
- set the mapping prefix in `vimrc` (<a href="#gx3Axvselmanager_mapPrefix" class="l"><em>g:vselmanager_mapPrefix</em></a>)
- (re)start Vim and run `:helptags ALL`

For example, in Bash:
```shell
DIR=~/.vim/pack/vselmanager/start/
mkdir -p "$DIR"; cd "$DIR"
git clone "$VSELMANAGER_URL"  # replace with actual URL
echo "let g:vselmanager_mapPrefix = '<Leader>v'" >> ~/.vimrc
vim -c 'helptags ALL' -cq
```

Or use your preferred plugin manager.

## <span class="c">LICENSE                                             &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="vselmanager-license" href="#vselmanager-license" class="t"><sub><sup><em>vselmanager-license</em></sup></sup></a>

Vselmanager is released under the GPL v2.

See <a class="u" href="https://www.gnu.org/licenses/gpl-2.0.html">https://www.gnu.org/licenses/gpl-2.0.html</a>

## <span class="c">CREDITS                                             &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span><a name="vselmanager-credits" href="#vselmanager-credits" class="t"><sub><sup><em>vselmanager-credits</em></sup></sup></a>

<pre>
<span class="h">                          URL </span>
This repository           <a class="u" href="https://github.com/kstr0k/vim-visualMarks">https://github.com/kstr0k/vim-visualMarks</a>
    Alin Mr.              <a class="u" href="http://github.com/mralusw/">http://github.com/mralusw/</a>

Original visualMarks      <a class="u" href="https://github.com/iago-lito/vim-visualMarks">https://github.com/iago-lito/vim-visualMarks</a>
    Iago-lito             <a class="u" href="https://github.com/iago-lito/">https://github.com/iago-lito/</a>
    Steven Hall           <a class="u" href="https://github.com/hallzy/">https://github.com/hallzy/</a>
    </pre>

  </body>
</html>

This file is based on the [vim documentation](doc/vselmanager.txt) (`doc/vselmanager.txt`) for this plugin, which is the authoritative reference (`:h vselmanager.txt`). It was initially generated using [vimdoc2html](https://github.com/xaizek/vimdoc2html).
