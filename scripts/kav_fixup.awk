($1 == "menuentry") {$0 = $0 "\n\tloopback loop /rescue/rescue.iso"}
($1 == "linux") { for (i=2;i<=NF;i++) if ($i ~ /^root=live:/) $i="root=live:/dev/wtf" }
($1 ~ /linux|initrd/) {$2 = "(loop)" $2}
($1 ~ /menuentry|linux|initrd|}/){print $0}
