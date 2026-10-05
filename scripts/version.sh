# Sourced by bump-pin.sh and ensure-bump-pr.sh.
version_re='^v?([0-9]+)\.([0-9]+)\.([0-9]+)$'

# version_older <a> <b>: succeeds when a < b; both must match $version_re.
# Components are compared as digit strings (no leading zeros, then by length,
# then lexically), because bash arithmetic overflows on very long numbers.
version_older() {
  local a b i x y
  [[ $1 =~ $version_re ]] || return 2
  a=("${BASH_REMATCH[@]:1}")
  [[ $2 =~ $version_re ]] || return 2
  b=("${BASH_REMATCH[@]:1}")
  for i in 0 1 2; do
    x=${a[i]#"${a[i]%%[!0]*}"} y=${b[i]#"${b[i]%%[!0]*}"}
    if ((${#x} != ${#y})); then
      ((${#x} < ${#y}))
      return
    fi
    [[ $x == "$y" ]] && continue
    [[ $x < $y ]]
    return
  done
  return 1
}
