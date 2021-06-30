*f* is a collection of bare-bones *zsh* commands to edit and navigate around files,
powered by [fzf](https://github.com/junegunn/fzf). It comprises the
following commands:


#### f

A small extension to the default `fzf` command for quickly opening *files*. It
adds multi-selection, hidden file filtering, toggling of fuzzy/exact matching,
file preview, and a controllable search depth. The search depth determines in
how many directories deep files are searched for.


#### c

Quickly move to any *child* directory. It too offers hidden directory
filtering, toggling of fuzzy/exact matching, and a controllable search depth.


#### u

Move *up* to any parent directory. Given an integer *N* as argument, it moves
up *N* directories. Given a string, it tries to match it to a target parent
directory. For example, executing `u fo` in `\home\foobar\baz` moves to
`\home\foobar`. If no argument is given, a directory can be chosen via *fzf*.

#### s

Fuzzy-select a sibling directory to change directories *sideways*.

#### t

Execute a command on files or directories tagged by *f* and *c*.

# Installation

If you are using the [zinit](https://github.com/zdharma/zinit) plugin manager,
add this to your `.zshrc`: `zinit light d4ku/f`. For a manual installation,
clone this repository and source the included `f.zsh` file inside your
rc-file.


# Configuration

Provided key-bindings can be overridden by setting the corresponding variable
in your rc-file before this plugin is loaded. See [Keybindings](#keybindings)
for a list of the variables. Likewise, the following variables can be set for
further customization:

| Variable | Effect | Default |
| -------- | ------ |:-------:|
| F_F_DEFAULT_DEPTH | Search depth set when starting the `f` command | 6 |
| F_C_DEFAULT_DEPTH | Search depth set when starting the `c` command | 1 |
| F_EXACT | If 1, exact mode is enabled by default | 0 |
| F_SHOW_HIDDEN | If 1, hidden files and directories are shown by default | 1 |
| F_F, F_C, F_U, F_S, F_T | Alias override for each command | |
| F_NO_ALIASES | No aliases are created. See [Manual aliasing](#manual-aliasing) to create them manually. | 0 |


### Manual aliasing

Add this to your rc-file to override the default command names with `a`, `b`, `c`,
`d`, `e`, respectively.

```
export F_NO_ALIASES=1
alias a=f::f
alias b=f::c
alias c=f::u
alias d=f::s
alias e=f::t
```


# Keybindings

The default *fzf* keybindings like *Tab* for multi-selection are kept. Refer
to `man fzf` for the full list. The following additional mappings are provided
by this plugin:

<table>
    <thead>
        <tr>
            <th>Default</th>
            <th>Variable</th>
            <th>Commands</th>
            <th>Function</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td rowspan=2>Enter</td>
            <td rowspan=2></td>
            <td>f</td>
            <td>Exit and open file(s) in editor</td>
        </tr>
        <tr>
            <td>c, s, u</td>
            <td>Move to directory and exit</td>
        </tr>
        <tr>
            <td>Alt-D</td>
            <td>F_F_TO_DIR_KEY</td>
            <td>f</td>
            <td>Move to file's directory and exit</td>
        </tr>
        <tr>
            <td>Alt-H</td>
            <td>F_C_MOVE_UP_KEY</td>
            <td rowspan=2>c</td>
            <td>Move one directory up</td>
        </tr>
        <tr>
            <td>Alt-L</td>
            <td>F_C_MOVE_DOWN_KEY</td>
            <td>Move to directory</td>
        </tr>
        <tr>
            <td>Alt-J</td>
            <td>F_DEPTH_DEC_KEY</td>
            <td rowspan=6>f, c</td>
            <td>Decrease search depth</td>
        </tr>
        <tr>
            <td>Alt-K</td>
            <td>F_DEPTH_INC_KEY</td>
            <td>Increase search depth</td>
        </tr>
        <tr>
            <td>Alt-E</td>
            <td>F_EXACT_KEY</td>
            <td>Toggle fzf exact mode</td>
        </tr>
        <tr>
            <td>Alt-S</td>
            <td>F_SHOW_HIDDEN_KEY</td>
            <td>Toggle hidden files</td>
        </tr>
        <tr>
            <td>Alt-T</td>
            <td>F_TAG_KEY</td>
            <td>Tag file for a later command to operate on</td>
        </tr>
        <tr>
            <td>F[1-12]</td>
            <td></td>
            <td>Set search depth</td>
        </tr>
    </tbody>
</table>
