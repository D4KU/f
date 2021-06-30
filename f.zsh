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
#replace spaces in list with commas
f_keys=$(tr ' ' , <<< "$f_keys")
f_tagged=()

f_help_templ=\
"Keybindings:
  Enter\t\tExit and move into selected directory
  :insert:
  $f_depth_dec_key\t\tDecrease search depth
  $f_depth_inc_key\t\tIncrease search depth
  $f_exact_key\t\tToggle fzf --exact option
  $f_show_hidden_key\t\tToggle visibilty of hidden :sel: (beginning with '.')
  $f_tag_key\t\tTag :sel: to execute command on it via 't' (see 't --help')
  F[1-12]\tSet search depth
Consult 'man fzf' for more keybindings."

f::core() {
  local path_opt
  local exact_opt
  local header=$header_tmpl
  header=${header/:depth:/$depth}
  header=${header/:pwd:/$PWD}

  # show hidden
  if [ $show_hidden = 1 ]; then
    header=${header/:sh:/all}
  else
    path_opt='*/\.*'
    header=${header/:sh:/normal}
  fi

  # exact
  if [ $exact = 1 ]; then
    exact_opt='--exact'
    header=${header/:exact:/exact}
  else
    header=${header/:exact:/fuzzy}
  fi

  local out=$(find . \
      ${find_opt[@]} \
      -not \
      -path "$path_opt" \
      -mindepth 1 \
      -maxdepth $depth \
    2> /dev/null \
    | sed 's|^\./||' \
    | fzf ${fzf_opt[@]} \
      $exact_opt \
      --cycle \
      --print-query \
      --query="$query" \
      --header="$header" \
      --preview-window=border-none)

  query=$(head -1 <<< "$out")
  key=$(head -2 <<< "$out" | tail -1)
  selection=$(tail +3 <<< "$out")

  case "$key" in
    $f_depth_dec_key)
      let "depth--"
      return 1
      ;;
    $f_depth_inc_key)
      let "depth++"
      return 1
      ;;
    f[1-9] | f1[0-2])
      depth=${key#f}
      return 1
      ;;
    $f_exact_key)
      let "exact = (exact + 1) % 2"
      return 1
      ;;
    $f_show_hidden_key)
      let "show_hidden = (show_hidden + 1) % 2"
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

f::f() {
  if [[ $1 == '--help' ]]; then
    echo "Open selected files in ${EDITOR:-vim}."
    local help=\
"$f_f_to_dir_key\t\tExit and move to (lastly) selected file's directory"
    help=${f_help_templ/:insert:/$help}
    echo ${help//:sel:/'files'}
    return 0
  fi

  local show_hidden=${F_SHOW_HIDDEN:-1}
  local exact=${F_EXACT:-0}
  local depth=${1:-$f_f_default_depth}
  local header_tmpl=':exact: :sh: :depth:'
  local find_opt=(-type f)
  local fzf_opt=(
    --multi
    --preview "highlight -O ansi -l {}"
    --expect=enter,$f_f_to_dir_key,${f_keys[@]}
  )
  local query
  local key
  local selection

  while true; do
    f::core
    (($?)) && continue

    local filelist=()
    while IFS= read -r file
    do
      filelist+=("$file")
    done <<< "$selection"

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

f::c() {
  if [[ $1 == '--help' ]]; then
    echo "Change to selected directory."
    local help=\
"$f_c_move_down_key\t\tMove into selected directory, don't exit
  $f_c_move_up_key\t\tMove one directory up, don't exit"
    help=${f_help_templ/:insert:/$help}
    echo ${help//:sel:/'directories'}
    return 0
  fi

  local show_hidden=${F_SHOW_HIDDEN:-1}
  local exact=${F_EXACT:-0}
  local depth=${1:-$f_c_default_depth}
  local header_tmpl=':exact: :sh: :depth: :pwd:'
  local find_opt=(-type d)
  local fzf_opt=(
    +m
    --expect=enter,left,right,$f_c_move_up_key,$f_c_move_down_key,${f_keys[@]}
  )
  local query
  local key
  local selection

  while true; do
    f::core
    (($?)) && continue

    case "$key" in
      $f_c_move_up_key | left)
        cd ..
        ;;
      $f_c_move_down_key | right)
        cd "$selection"
        query=''
        ;;
      enter)
        cd "$selection"
        return 0
        ;;
      *)
        return 0
        ;;
    esac
  done
}

f::s() {
  cd "$(find .. -mindepth 1 -maxdepth 1 -type d -print \
    2> /dev/null \
    | fzf +m -0 -1 --cycle)"
}

f::u() {
  case $1 in
    --help)
      echo \
"Usage: ${F_U:-u} [PATTERN]
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
      cd "$(echo $dirs | sed '/^$/d' | fzf --cycle)"
      ;;
    *[!0-9]*)
      # not a pure number was passed
      # find a dir in the current path beginning with the passed string
      # and jump to it
      cd "$(pwd | sed -r "s_(.*/$1[^/]*/).*_\1_")"
      ;;
    *)
      # matched a number
      # concatenate as many '../' as the passed number
      cd $(printf "%0.0s../" $(seq 1 $1))
      ;;
  esac
}

f::t() {
  # print files if no argument given
  [[ $# -eq 0 ]] && echo "$f_tagged" && return 0

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        echo \
"Usage: ${F_T:-t} [OPTION] [COMMAND]
Execute COMMAND on files or directories tagged by 'f' and 'c'.
Prints selection and exits if no argument given.
Example: t -k mv - ~ (move files to home and keep them tagged)

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
        echo "Missing command. See 't --help'."
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
  alias ${F_F:-f}=f::f
  alias ${F_U:-u}=f::u
  alias ${F_C:-c}=f::c
  alias ${F_S:-s}=f::s
  alias ${F_T:-t}=f::t
fi
