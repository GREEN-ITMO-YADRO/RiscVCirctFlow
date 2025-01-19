{
  if (!inside && $0 ~ /^module/) {
    inside = 1
  } else if (inside && $0 ~ /^}/) {
    inside = 0
  } else {
    if (inside) {
      # strip the leading indent.
      sub(/^  /, "")
    }

    print
  }
}
