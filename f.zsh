f_preview=${F_PREVIEW:-'highlight --force -O ansi {}'}
c_preview=${C_PREVIEW:-'cd {} && ({ ls -d1 */ & ls -d1 .*/; }) 2> /dev/null'}
f_ignore_file=${F_IGNORE_FILE:-"$HOME/.fignore"}
f_f_cmd=${F_F:-f}
f_u_cmd=${F_U:-u}
f_c_cmd=${F_C:-c}
f_s_cmd=${F_S:-s}
f_t_cmd=${F_T:-t}
f_depth_dec_key=${F_DEPTH_DEC_KEY:-alt-j}
f_depth_inc_key=${F_DEPTH_INC_KEY:-alt-k}
f_show_hidden_key=${F_SHOW_HIDDEN_KEY:-alt-s}
f_exact_key=${F_EXACT_KEY:-alt-e}
f_print_key=${F_PRINT_KEY:-alt-p}
f_tag_key=${F_TAG_KEY:-alt-t}
f_f_default_depth=${F_F_DEFAULT_DEPTH:-6}
f_c_default_depth=${F_C_DEFAULT_DEPTH:-1}
f_f_to_dir_key=${F_F_TO_DIR_KEY:-alt-d}
f_c_move_up_key=${F_C_MOVE_UP_KEY:-alt-h}
f_c_move_down_key=${F_C_MOVE_down_KEY:-alt-l}

f_keys=(
  $f_depth_dec_key
  $f_depth_inc_key
  $f_show_hidden_key
  $f_exact_key
  $f_print_key
  $f_tag_key
  f{1..12}
)
# replace spaces in list with commas
f_keys=$(tr ' ' , <<< "$f_keys")

# storage for user selection
f_tagged=()

f::core() {
  local f_help_templ=\
":header:
Keybindings:
  :keyinsert:
  $f_print_key\t\tExit and paste selection into command line
  $f_depth_dec_key\t\tDecrease search depth
  $f_depth_inc_key\t\tIncrease search depth
  $f_exact_key\t\tToggle fzf --exact option
  $f_show_hidden_key\t\tToggle visibilty of hidden :type: (beginning with '.')
  $f_tag_key\t\tTag :type: to execute command on it via '${f_t_cmd}' (see '${f_t_cmd} --help')
  F[1-12]\tSet search depth
Consult 'man fzf' for more keybindings."

  if [[ $1 == '--help' ]]; then
    # replace placeholders in help template, then print
    local help=${f_help_templ/:header:/$help_header}
    help=${help/:keyinsert:/$help_keyinsert}
    echo ${help//:type:/$help_type}
    return 0
  fi

  local path_opt
  local exact_opt
  local header=$header_tmpl
  header=${header/:depth:/$depth}
  header=${header/:pwd:/$PWD}

  # show hidden
  if [ $show_hidden = 1 ]; then
    header=${header/:sh:/all}
  else
    # filter passed to 'find'
    path_opt='*/\.*'
    header=${header/:sh:/normal}
  fi

  # exact mode
  if [ $exact = 1 ]; then
    # option passed to fzf
    exact_opt='--exact'
    header=${header/:exact:/exact}
  else
    header=${header/:exact:/fuzzy}
  fi

  local fignore=()

  # read in gloal ignore file
  if [ -f "$f_ignore_file" ]; then
    while IFS= read -r line; do
      fignore+=(-o -name "$line")
    done < "$f_ignore_file"
  fi

  # read in local ignore file
  if [ -f "$PWD/.fignore" ]; then
    while IFS= read -r line; do
      fignore+=(-o -name "$line")
    done < "$PWD/.fignore"
  fi

  # this is the heart
  # find targets and pipe them to fzf
  # sed removes the './' in front of all entries
  local out=$(find . -mindepth 1 -maxdepth $depth \
      \( -path "$path_opt" ${fignore[@]} \) -prune \
      -o ${find_opt[@]} -print \
    2> /dev/null \
    | sed 's|^\./||' \
    | fzf ${fzf_opt[@]} \
      $exact_opt \
      --print-query \
      --query="$query" \
      --header="$header")

  # send information to calling function
  # first output line
  query=$(head -1 <<< "$out")
  # second line
  key=$(head -2 <<< "$out" | tail -1)
  # subsequent lines
  selection=$(tail +3 <<< "$out")

  # test keys valid for all callers
  case "$key" in
    $f_depth_dec_key)
      ((depth--))
      return 1
      ;;
    $f_depth_inc_key)
      ((depth++))
      return 1
      ;;
    f[1-9] | f1[0-2])
      depth=${key#f}
      return 1
      ;;
    $f_exact_key)
      ((exact = !exact))
      return 1
      ;;
    $f_show_hidden_key)
      ((show_hidden = !show_hidden))
      return 1
      ;;
    $f_print_key)
      print -z "$selection"
      ;;
    $f_tag_key)
      while IFS= read -r target
      do
        # Ensure no duplicates in list
        if [[ ! " ${f_tagged[@]} " =~ " ${target:a} " ]]
        then
          f_tagged+=("${target:a}")
        fi
      done <<< "$selection"
      echo $f_tagged
  esac
  return 0
}

# open file
f::f() {
  # variables read inside f::core
  local show_hidden=${F_SHOW_HIDDEN:-1}
  local exact=${F_EXACT:-0}
  local depth=${1:-$f_f_default_depth}
  local header_tmpl=':exact: :sh: :depth:'
  local find_opt=(-type f)
  local fzf_opt=(
    --multi
    --preview "$f_preview"
    --expect=enter,$f_f_to_dir_key,${f_keys[@]}
  )
  local help_type='files'
  local help_header="Open selected files in ${EDITOR:-editor}."
  local help_keyinsert=\
"Enter\t\tExit and open selected files
  $f_f_to_dir_key\t\tExit and move to (lastly) selected file's directory"

  # variables set inside f::core
  # text user typed into fzf
  local query
  # key user pressed to exit fzf
  local key
  # selected entries
  local selection

  while true; do
    f::core $1
    # continue if '1' was returned
    (($?)) && continue

    # convert newline-separated selection list into array
    local filelist=()
    while IFS= read -r file
    do
      filelist+=("$file")
    done <<< "$selection"

    # parse keys specific to this function
    case "$key" in
      $f_f_to_dir_key)
        cd "$(dirname "${filelist[-1]}")"
        ;;
      enter)
         ${EDITOR:-vim} "${filelist[@]}"
        ;;
    esac
    return 0
  done
}

# change to child directory
f::c() {
  # variables read inside f::core
  local show_hidden=${F_SHOW_HIDDEN:-1}
  local exact=${F_EXACT:-0}
  local depth=${1:-$f_c_default_depth}
  local header_tmpl=':exact: :sh: :depth: :pwd:'
  local find_opt=(-type d)
  local fzf_opt=(
    --no-multi
    --preview "$c_preview"
    --expect=enter,left,right,$f_c_move_up_key,$f_c_move_down_key,${f_keys[@]}
  )
  local help_type='directories'
  local help_header='Change to selected directory.'
  local help_keyinsert=\
"Enter\t\tExit and move into selected directory
  $f_c_move_down_key\t\tMove into selected directory, don't exit
  $f_c_move_up_key\t\tMove one directory up, don't exit"

  # variables set inside f::core
  # text user typed into fzf
  local query
  # key user pressed to exit fzf
  local key
  # selected entries
  local selection

  while true; do
    f::core $1
    # continue if '1' was returned
    (($?)) && continue

    # parse keys specific to this function
    case "$key" in
      $f_c_move_up_key|left)
        cd ..
        continue
        ;;
      $f_c_move_down_key|right)
        cd "$selection"
        query=''
        continue
        ;;
      enter)
        cd "$selection"
        ;;
    esac
    return 0
  done
}

# change to sibling directory
f::s() {
  if [[ $1 == '--help' ]]; then
    echo "Change to sibling directory sideways"
    return 0
  fi

  # find > remove '../' > fzf
  local dir=$(find .. -mindepth 1 -maxdepth 1 -type d \
    2> /dev/null \
    | sed 's|^\.\./||' \
    | fzf +m -0 -1)

  # if dir is not empty, add '../' again
  [[ ! -z $dir ]] && cd "../$dir"
}

# change to parent directory
f::u() {
  case $1 in
    --help)
      echo \
"Usage: ${f_u_cmd} [PATTERN]
Move up to parent directory matching PATTERN.
If passed nothing, the directory can be chosen via fzf.

Patterns:
  --help     Print this message and exit
  [INTEGER]  Move up INTEGER directories
  [WORD]     Move to closest parent directory beginning with WORD"
      return
      ;;
    '')
      # remove last path segment and push result on stack until only
      # root dir '/' remains
      local remain="$PWD"
      while [[ -d $remain ]] && [[ $remain != '/' ]]
      do
        remain=$(dirname "$remain")
        # the stack: a string with paths separated by newlines
        local dirs="${dirs}\n${remain}"
      done

      # pipe stack to fzf
      # the first entry is an empty line and needs removal
      cd "$(echo $dirs | sed '/^$/d' | fzf)"
      ;;
    *[!0-9]*)
      # not a pure number was passed
      # find a dir in the current path beginning with the passed string
      # and jump to it
      cd "$(pwd | sed -r "s|(.*/$1[^/]*/).*|\1|")"
      ;;
    *)
      # matched a number
      # concatenate as many '../' as the passed number
      cd $(printf "%0.0s../" $(seq 1 $1))
      ;;
  esac
}

# operate on tagged files
f::t() {
  # print files if no argument given
  [[ $# -eq 0 ]] && echo "$f_tagged" && return 0

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        echo \
"Usage: ${f_t_cmd} [OPTION] [COMMAND]
Execute COMMAND on files or directories tagged by '${f_f_cmd}' and '${f_c_cmd}'.
Prints selection and exits if no argument given.
Example: ${f_t_cmd} -k mv - ~ (move files to home and keep them tagged)

Options:
  -c, --clear  clear selection and exit
  -k, --keep   don't clear selection afterward
  -h, --help   display this help and exit

Argument '-' is expanded to selection and appended if not specified."
        return 0
        ;;
      -c|--clear)
        f_tagged=()
        return 0
        ;;
      -)
        echo "Missing command. See '${f_t_cmd} --help'."
        return 1
        ;;
      -k|--keep)
        local keep=1
        shift
        ;;
      *)
        # Something unknown was passed. Don't listen to own options
        # anymore. Continue in second loop.
        break
        ;;
    esac
  done

  local cmd=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -)
        local placeholder=1
        cmd=(${cmd[@]} ${f_tagged[@]})
        shift
        ;;
      *)
        cmd+="$1"
        shift
        ;;
    esac
  done

  # append list if no placeholder was used
  [ -z $placeholder ] && cmd=(${cmd[@]} ${f_tagged[@]})

  # execute given command
  $cmd

  # clear files
  [ -z $keep ] && f_tagged=()
}

if [[ -z "$F_NO_ALIASES" ]]; then
  alias ${f_f_cmd}=f::f
  alias ${f_u_cmd}=f::u
  alias ${f_c_cmd}=f::c
  alias ${f_s_cmd}=f::s
  alias ${f_t_cmd}=f::t
fi
