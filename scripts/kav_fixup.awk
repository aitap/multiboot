($1 == "menuentry") {
	$0 = $0 "\nloopback loop /data/kav.iso"
}
($1 ~ /linux|initrd/) {$2 = "(loop)" $2}
($1 == "linux") { $0 = $0 " isoloop=kav.iso" }
($1 != "source") {print}
