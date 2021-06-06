f_depth_dec_key=${F_DEPTH_DEC_KEY:-alt-j}
f_depth_inc_key=${F_DEPTH_INC_KEY:-alt-k}
f_show_hidden_key=${F_SHOW_HIDDEN_KEY:-alt-s}
f_exact_key=${F_EXACT_KEY:-alt-e}
f_print_key=${F_PRINT_KEY:-alt-p}
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
  f{1..12}
)
#replace spaces in list with commas
f_keys=$(tr ' ' , <<< "$f_keys")

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
  esac
  return 0
}

f::f() {
  local show_hidden=${F_SHOW_HIDDEN:-1}
  local exact={F_EXACT:-0}
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
        [[ -n "$selection" ]] && ${EDITOR:-vim} "${filelist[@]}"
        ;;
    esac
    return 0
  done
}

f::c() {
  local show_hidden=${F_SHOW_HIDDEN:-1}
  local exact={F_EXACT:-0}
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
    *[!0-9]*)
      cd $(pwd | sed -r "s|(.*/$1[^/]*/).*|\1|")
      ;;
    '')
      local declare dirs=()
      get_parent_dirs() {
        if [[ -d "${1}" ]]; then dirs+=("$1"); else return; fi
        if [[ "${1}" == '/' ]]; then
          for _dir in "${dirs[@]}"; do echo $_dir; done
        else
          get_parent_dirs $(dirname "$1")
        fi
      }
    local dir="$(get_parent_dirs $(realpath "$PWD") | fzf --cycle --tac)"
    cd "$dir"
    ;;
  *)
    cd $(printf "%0.0s../" $(seq 1 $1));
    ;;
  esac
}

if [[ -z "$F_NO_ALIASES" ]]; then
  alias ${F_F:-f}=f::f
  alias ${F_U:-u}=f::u
  alias ${F_C:-c}=f::c
  alias ${F_S:-s}=f::s
fi
