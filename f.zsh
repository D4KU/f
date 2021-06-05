depth_dec_key=alt-j
depth_inc_key=alt-k
show_hidden_key=ctrl-f
exact_key=ctrl-e
print_key=ctrl-g

keys=($depth_dec_key,$depth_inc_key,$show_hidden_key,$exact_key,$print_key)

_core() {
  local path_opt
  local exact_opt
  local header=$header_tmpl
  header=${header/:depth:/$depth}
  header=${header/:pwd:/$(pwd)}

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
    $depth_dec_key)
      let "depth--"
      return 1
      ;;
    $depth_inc_key)
      let "depth++"
      return 1
      ;;
    $exact_key)
      let "exact = (exact + 1) % 2"
      return 1
      ;;
    $show_hidden_key)
      let "show_hidden = (show_hidden + 1) % 2"
      return 1
      ;;
    $print_key)
      print -z "$selection"
      ;;
  esac
  return 0
}

f() {
  local show_hidden=1
  local exact=0
  local depth=${1:-6}
  local header_tmpl=':exact: :sh: :depth:'
  local find_opt=(-type f)
  local fzf_opt=(
    --multi
    --preview "highlight -O ansi -l {}"
    --expect=ctrl-d,enter,${keys[@]}
  )
  local query
  local key
  local selection

  while true; do
    _core
    (($?)) && continue

    local filelist=()
    while IFS= read -r file
    do
      filelist+=("$file")
    done <<< "$selection"

    case "$key" in
      ctrl-d)
        cd "$(dirname "${filelist[-1]}")"
        ;;
      enter)
        [[ -n "$selection" ]] && ${EDITOR:-vim} "${filelist[@]}"
        ;;
    esac
    return 0
  done
}

c() {
  local show_hidden=1
  local exact=0
  local depth=${1:-1}
  local header_tmpl=':exact: :sh: :depth: :pwd:'
  local find_opt=(-type d)
  local fzf_opt=(
    +m
    --expect=alt-h,alt-l,enter,left,right,${keys[@]}
  )
  local query
  local key
  local selection

  while true; do
    _core
    (($?)) && continue

    case "$key" in
      alt-h | left)
        cd ..
        ;;
      alt-l | right)
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

# cd sideways to sibling directory
cs() {
  local dir=$(find .. -mindepth 1 -maxdepth 1 -type d -print 2> /dev/null | fzf +m)
  cd "$dir"
}

# cd to selected parent directory
# go up n dirs or go to dir in pwd
u() {
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
            local dir="$(get_parent_dirs $(realpath "$PWD") | fzf --tac)"
            cd "$dir"
            ;;
        *)
            cd $(printf "%0.0s../" $(seq 1 $1));
            ;;
    esac
}

